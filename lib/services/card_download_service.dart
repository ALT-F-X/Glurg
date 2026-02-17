import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:glurg_app/services/database_helper.dart';

class CardDownloadService {
  static const String bulkDataUrl = 'https://api.scryfall.com/bulk-data';

  /// Standard headers for Scryfall API requests (User-Agent required by their docs)
  static const Map<String, String> _scryfallHeaders = {
    'User-Agent': 'GlurgApp/1.0',
    'Accept': 'application/json',
  };

  /// Download and import all creatures with power/toughness
  /// Returns the number of cards imported
  Future<int> downloadAndImportCards({
    required Function(int current, int total) onProgress,
  }) async {
    try {
      // Step 1: Get the bulk data download URL
      onProgress(0, 100);
      final bulkDataInfo = await _getBulkDataUrl();
      final downloadUrl = bulkDataInfo['download_uri'] as String;

      // Step 2: Download the full JSON file
      onProgress(10, 100);
      final cardsJson = await _downloadCardsJson(downloadUrl, onProgress);

      // Step 3 & 4: Filter and import in chunks to save memory
      onProgress(30, 100);
      final db = DatabaseHelper.instance;
      await db.clearAllCards(); // Clear old data first

      int totalImported = 0;
      final totalCards = cardsJson.length;
      const processChunkSize = 1000; // Process 1000 cards at a time

      for (int i = 0; i < cardsJson.length; i += processChunkSize) {
        final end = (i + processChunkSize < cardsJson.length)
            ? i + processChunkSize
            : cardsJson.length;
        final chunk = cardsJson.sublist(i, end);

        // Filter this chunk to creatures
        final creatureChunk = _filterCreatures(chunk);

        // Insert this chunk
        if (creatureChunk.isNotEmpty) {
          await db.insertCards(creatureChunk);
          totalImported += creatureChunk.length;
        }

        // Update progress (30% to 100%)
        final progress = 30 + ((i / totalCards) * 70).toInt();
        onProgress(progress, 100);
      }

      // Cache art assets for card display
      await cacheGlurgArt();
      await cacheFrameTemplates();
      await cacheManaSymbols();

      onProgress(100, 100);
      return totalImported;
    } catch (e) {
      // Avoid double-wrapping exceptions
      if (e is Exception) rethrow;
      throw Exception('Failed to download cards: $e');
    }
  }

  /// Get the download URL for the oracle cards bulk data (smaller, unique cards only)
  Future<Map<String, dynamic>> _getBulkDataUrl() async {
    final response = await http.get(
      Uri.parse(bulkDataUrl),
      headers: _scryfallHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch bulk data info (HTTP ${response.statusCode}): '
        '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final bulkDataList = data['data'] as List;

    // Use "Oracle Cards" instead - smaller file with unique cards only
    final oracleCards = bulkDataList.firstWhere(
      (item) => item['type'] == 'oracle_cards',
      orElse: () => throw Exception('Oracle cards bulk data not found'),
    );

    return oracleCards as Map<String, dynamic>;
  }

  /// Download the cards JSON file with progress (streaming to temp file)
  Future<List<dynamic>> _downloadCardsJson(
    String url,
    Function(int current, int total) onProgress,
  ) async {
    final client = http.Client();
    File? tempFile;

    try {
      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/scryfall_download.json');

      // Start streaming download
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(_scryfallHeaders);
      final response = await client.send(request).timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        throw Exception('Failed to download cards JSON (${response.statusCode})');
      }

      final contentLength = response.contentLength ?? 1;
      int bytesReceived = 0;

      // Stream to file and show progress
      final fileSink = tempFile.openWrite();
      await for (final chunk in response.stream) {
        fileSink.add(chunk);
        bytesReceived += chunk.length;

        // Update progress: 10% to 25% during download
        final progress = 10 + ((bytesReceived / contentLength) * 15).toInt();
        onProgress(progress.clamp(10, 25), 100);
      }
      await fileSink.close();

      onProgress(26, 100);

      // Read and parse from file
      final jsonString = await tempFile.readAsString();
      onProgress(28, 100);

      final jsonData = jsonDecode(jsonString) as List;
      onProgress(30, 100);

      // Clean up temp file
      await tempFile.delete();

      return jsonData;
    } catch (e) {
      // Clean up on error
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
      throw Exception('Download failed: $e');
    } finally {
      client.close();
    }
  }

  /// Filter to only creature cards with power/toughness
  List<Map<String, dynamic>> _filterCreatures(List<dynamic> allCards) {
    final creatures = <Map<String, dynamic>>[];

    for (final card in allCards) {
      final cardData = card as Map<String, dynamic>;

      // Handle double-faced cards
      if (cardData['card_faces'] != null) {
        final faces = cardData['card_faces'] as List;

        for (final face in faces) {
          final faceData = face as Map<String, dynamic>;
          final typeLine = faceData['type_line'] as String? ?? '';

          if (typeLine.contains('Creature') &&
              faceData['power'] != null &&
              faceData['toughness'] != null) {
            // Get colors: face colors > color_indicator > top-level colors
            final faceColors = _extractColors(faceData['colors'])
                ?? _extractColors(faceData['color_indicator'])
                ?? _extractColors(cardData['colors'])
                ?? '';
            creatures.add({
              'id': '${cardData['id']}_${faceData['name']}',
              'name': faceData['name'] as String,
              'manaCost': faceData['mana_cost'] as String? ?? '',
              'manaValue': cardData['mana_value'] as int? ?? 0,
              'type': faceData['type_line'] as String,
              'power': faceData['power'] as String?,
              'toughness': faceData['toughness'] as String?,
              'oracleText': faceData['oracle_text'] as String? ?? '',
              'colors': faceColors,
            });
          }
        }
      } else {
        // Regular single-faced card
        final typeLine = cardData['type_line'] as String? ?? '';

        if (typeLine.contains('Creature') &&
            cardData['power'] != null &&
            cardData['toughness'] != null) {
          creatures.add({
            'id': cardData['id'] as String,
            'name': cardData['name'] as String,
            'manaCost': cardData['mana_cost'] as String? ?? '',
            'manaValue': cardData['mana_value'] as int? ?? 0,
            'type': cardData['type_line'] as String,
            'power': cardData['power'] as String?,
            'toughness': cardData['toughness'] as String?,
            'oracleText': cardData['oracle_text'] as String? ?? '',
            'colors': _extractColors(cardData['colors']) ?? '',
          });
        }
      }
    }

    return creatures;
  }

  /// Convert a Scryfall colors array like ["U", "B"] to comma-separated string "U,B"
  String? _extractColors(dynamic colorsData) {
    if (colorsData == null || colorsData is! List) return null;
    final colors = colorsData.cast<String>().join(',');
    return colors.isEmpty ? null : colors;
  }

  /// Fetch and cache "It Came from Planet Glurg" art_crop for offline fallback
  Future<void> cacheGlurgArt() async {
    try {
      final artFile = File(await getGlurgArtPath());
      if (await artFile.exists()) return; // Already cached

      // Fetch card data from Scryfall
      final response = await http.get(
        Uri.parse('https://api.scryfall.com/cards/named?exact=It+Came+from+Planet+Glurg'),
        headers: _scryfallHeaders,
      );
      if (response.statusCode != 200) return;

      final cardData = jsonDecode(response.body) as Map<String, dynamic>;
      final artCropUrl = cardData['image_uris']?['art_crop'] as String?;
      if (artCropUrl == null) return;

      // Download the art image
      final artResponse = await http.get(Uri.parse(artCropUrl), headers: _scryfallHeaders);
      if (artResponse.statusCode != 200) return;

      await artFile.parent.create(recursive: true);
      await artFile.writeAsBytes(artResponse.bodyBytes);
    } catch (_) {
      // Non-critical - offline art just won't be available
    }
  }

  /// Get the file path for cached Glurg art
  static Future<String> getGlurgArtPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/glurg_art.jpg';
  }

  // ── Frame Template Images ──────────────────────────────────────

  /// Template cards for each frame type — all use M15+ modern frame (2014+).
  /// Non-legendary, non-enchantment, non-artifact creatures for clean frames.
  static const Map<String, String> _frameTemplateCards = {
    // Mono-color (M19/M20 core set creatures)
    'W': 'Leonin Vanguard',
    'U': 'Spectral Sailor',
    'B': 'Vampire of the Dire Moon',
    'R': 'Scorch Spitter',
    'G': 'Llanowar Elves',
    // Two-color pairs (WUBRG order, Guilds/Ravnica-era)
    'WU': 'Deputy of Detention',
    'WB': 'Cruel Celebrant',
    'WR': 'Boros Challenger',
    'WG': 'Knight of Autumn',
    'UB': 'Thief of Sanity',
    'UR': 'Crackling Drake',
    'UG': 'Merfolk Mistbinder',
    'BR': 'Rakdos Headliner',
    'BG': 'Glowspore Shaman',
    'RG': 'Zhur-Taa Goblin',
    // Three+ color / gold
    'gold': 'Temur Battlecrier',
    // Colorless
    'colorless': 'Ornithopter',
  };

  /// Version tag — bump this whenever _frameTemplateCards changes so old
  /// cached images get replaced on the next database update.
  static const int _frameTemplateVersion = 2;

  /// Download and cache frame template card images for all colors
  Future<void> cacheFrameTemplates() async {
    final dir = await _getFrameDir();
    await dir.create(recursive: true);

    // Check if cached frames are from the current template version
    final versionFile = File('${dir.path}/.version');
    final currentVersion = await versionFile.exists()
        ? int.tryParse(await versionFile.readAsString()) ?? 0
        : 0;
    if (currentVersion != _frameTemplateVersion) {
      // Clear old frames so they get re-downloaded with new templates
      final files = dir.listSync().whereType<File>();
      for (final f in files) {
        if (f.path.endsWith('.jpg')) await f.delete();
      }
      await versionFile.writeAsString('$_frameTemplateVersion');
    }

    for (final entry in _frameTemplateCards.entries) {
      try {
        final file = File('${dir.path}/frame_${entry.key}.jpg');
        if (await file.exists()) continue; // Already cached

        // Respect Scryfall rate limit (50-100ms between requests)
        await Future.delayed(const Duration(milliseconds: 100));

        // Fetch card from Scryfall
        final encoded = Uri.encodeComponent(entry.value);
        final response = await http.get(
          Uri.parse('https://api.scryfall.com/cards/named?exact=$encoded'),
          headers: _scryfallHeaders,
        );
        if (response.statusCode != 200) continue;

        final cardData = jsonDecode(response.body) as Map<String, dynamic>;
        final imageUrl = cardData['image_uris']?['normal'] as String?;
        if (imageUrl == null) continue;

        // Download the card image
        await Future.delayed(const Duration(milliseconds: 100));
        final imgResponse = await http.get(
          Uri.parse(imageUrl),
          headers: _scryfallHeaders,
        );
        if (imgResponse.statusCode != 200) continue;

        await file.writeAsBytes(imgResponse.bodyBytes);
      } catch (_) {
        // Non-critical - skip this frame template
      }
    }
  }

  /// Get the path to a cached frame template image for the given color key
  static Future<String?> getFrameTemplatePath(String colorKey) async {
    final dir = await _getFrameDir();
    final file = File('${dir.path}/frame_$colorKey.jpg');
    if (await file.exists()) return file.path;
    return null;
  }

  /// Determine which frame template key to use for a set of color letters
  static String getFrameKey(List<String> colors) {
    const wubrgOrder = ['W', 'U', 'B', 'R', 'G'];
    final meaningful = colors
        .where((c) => wubrgOrder.contains(c))
        .toSet()
        .toList();
    // Sort by WUBRG order
    meaningful.sort((a, b) => wubrgOrder.indexOf(a).compareTo(wubrgOrder.indexOf(b)));

    if (meaningful.isEmpty) return 'colorless';
    if (meaningful.length == 1) return meaningful.first;
    if (meaningful.length == 2) return '${meaningful[0]}${meaningful[1]}';
    return 'gold'; // 3+ colors
  }

  static Future<Directory> _getFrameDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/frames');
  }

  /// Get estimated database size
  Future<String> getEstimatedSize() async {
    final count = await DatabaseHelper.instance.getCardCount();
    if (count == 0) return '0 MB';

    // Rough estimate: ~200 bytes per card
    final sizeInMB = (count * 200) / (1024 * 1024);
    return '${sizeInMB.toStringAsFixed(1)} MB';
  }

  // ── Mana Symbol Images ─────────────────────────────────────────

  /// Download and cache all Scryfall mana symbol images
  Future<void> cacheManaSymbols() async {
    try {
      final dir = await _getManaSymbolDir();
      await dir.create(recursive: true);

      // Fetch all available symbols from Scryfall
      final response = await http.get(
        Uri.parse('https://api.scryfall.com/symbology'),
        headers: _scryfallHeaders,
      );
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final symbols = data['data'] as List?;
      if (symbols == null) return;

      for (final sym in symbols) {
        final symbolData = sym as Map<String, dynamic>;
        final symbol = symbolData['symbol'] as String?;
        final svgUri = symbolData['svg_uri'] as String?;

        if (symbol == null || svgUri == null) continue;

        try {
          final file = File('${dir.path}/${_sanitizeSymbolName(symbol)}.svg');
          if (await file.exists()) continue; // Already cached

          // Download the SVG file (respect Scryfall rate limit)
          await Future.delayed(const Duration(milliseconds: 100));
          final imgResponse = await http.get(Uri.parse(svgUri), headers: _scryfallHeaders);
          if (imgResponse.statusCode != 200) continue;

          await file.writeAsBytes(imgResponse.bodyBytes);
        } catch (_) {
          // Skip this symbol on error
        }
      }
    } catch (_) {
      // Non-critical - skip mana symbol caching
    }
  }

  /// Get the path to a cached mana symbol SVG file
  static Future<String?> getManaSymbolPath(String symbol) async {
    final dir = await _getManaSymbolDir();
    final file = File('${dir.path}/${_sanitizeSymbolName(symbol)}.svg');
    if (await file.exists()) return file.path;
    return null;
  }

  /// Sanitize a mana symbol name for use as a filename (e.g., "W/U" -> "WU", "{2/W}" -> "2W")
  static String _sanitizeSymbolName(String symbol) {
    return symbol
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('/', '')
        .toLowerCase();
  }

  static Future<Directory> _getManaSymbolDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/mana_symbols');
  }
}
