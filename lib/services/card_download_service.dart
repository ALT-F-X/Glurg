import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:glurg_app/services/database_helper.dart';

class CardDownloadService {
  static const String bulkDataUrl = 'https://api.scryfall.com/bulk-data';

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

      onProgress(100, 100);
      return totalImported;
    } catch (e) {
      throw Exception('Failed to download cards: $e');
    }
  }

  /// Get the download URL for the oracle cards bulk data (smaller, unique cards only)
  Future<Map<String, dynamic>> _getBulkDataUrl() async {
    final response = await http.get(Uri.parse(bulkDataUrl));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch bulk data info');
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
            creatures.add({
              'id': '${cardData['id']}_${faceData['name']}',
              'name': faceData['name'] as String,
              'manaCost': faceData['mana_cost'] as String? ?? '',
              'manaValue': cardData['mana_value'] as int? ?? 0,
              'type': faceData['type_line'] as String,
              'power': faceData['power'] as String?,
              'toughness': faceData['toughness'] as String?,
              'oracleText': faceData['oracle_text'] as String? ?? '',
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
          });
        }
      }
    }

    return creatures;
  }

  /// Get estimated database size
  Future<String> getEstimatedSize() async {
    final count = await DatabaseHelper.instance.getCardCount();
    if (count == 0) return '0 MB';

    // Rough estimate: ~200 bytes per card
    final sizeInMB = (count * 200) / (1024 * 1024);
    return '${sizeInMB.toStringAsFixed(1)} MB';
  }
}
