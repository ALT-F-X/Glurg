import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:glurg_app/models/card.dart';
import 'package:glurg_app/services/card_download_service.dart';
import 'package:glurg_app/utils/mana_utils.dart';

/// Scryfall "normal" card images are 488x680.
/// These fractions define where each zone sits on that image.
/// Measured from actual MTG card images.
const double _cardAspect = 488 / 680;

// Name plate zone (as fractions of card dimensions)
const double _nameLeft = 0.058;
const double _nameTop = 0.044;
const double _nameWidth = 0.884;
const double _nameHeight = 0.052;

// Art window zone
const double _artLeft = 0.049;
const double _artTop = 0.105;
const double _artWidth = 0.902;
const double _artHeight = 0.446;

// Type line zone
const double _typeLeft = 0.058;
const double _typeTop = 0.567;
const double _typeWidth = 0.884;
const double _typeHeight = 0.042;

// Text box zone
const double _textLeft = 0.062;
const double _textTop = 0.622;
const double _textWidth = 0.876;
const double _textHeight = 0.295;

// Power/toughness box zone
const double _ptLeft = 0.755;
const double _ptTop = 0.895;
const double _ptWidth = 0.188;
const double _ptHeight = 0.058;

class MagicCardDisplay extends StatefulWidget {
  final MergedCard mergedCard;
  const MagicCardDisplay({Key? key, required this.mergedCard}) : super(key: key);

  @override
  State<MagicCardDisplay> createState() => _MagicCardDisplayState();
}

class _MagicCardDisplayState extends State<MagicCardDisplay> {
  late PageController _artPageController;
  int _currentArtPage = 0;
  String? _glurgArtPath;
  String? _frameImagePath;
  final Map<String, String?> _manaSymbolPaths = {};

  @override
  void initState() {
    super.initState();
    _artPageController = PageController();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    // Load Glurg fallback art
    final glurgPath = await CardDownloadService.getGlurgArtPath();
    if (await File(glurgPath).exists()) {
      _glurgArtPath = glurgPath;
    }

    // Load the correct frame template for this card's colors
    await _loadFrameTemplate();

    // Preload mana symbol paths for this card
    await _loadManaSymbolPaths();

    if (mounted) setState(() {});
  }

  Future<void> _loadManaSymbolPaths() async {
    final card = widget.mergedCard;
    final symbolSet = <String>{};

    // Collect all unique mana symbols from all source cards
    for (final c in card.sourceCards) {
      final symbols = ManaUtils.parseManaSymbols(c.manaCost);
      for (final sym in symbols) {
        symbolSet.add(sym.symbol);
      }
    }

    // Load paths for each symbol
    for (final symbol in symbolSet) {
      final path = await CardDownloadService.getManaSymbolPath(symbol);
      _manaSymbolPaths[symbol] = path;
    }
  }

  Future<void> _loadFrameTemplate() async {
    final card = widget.mergedCard;
    final allColors = <String>[];
    for (final c in card.sourceCards) {
      allColors.addAll(c.colors);
    }
    final uniqueColors = allColors.toSet().toList();
    final frameKey = CardDownloadService.getFrameKey(uniqueColors);
    _frameImagePath = await CardDownloadService.getFrameTemplatePath(frameKey);
  }

  @override
  void didUpdateWidget(MagicCardDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload frame if card colors changed
    if (oldWidget.mergedCard != widget.mergedCard) {
      _loadFrameTemplate().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _artPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.mergedCard;

    // Compute frame colors for fallback/glow
    final cardColors = <ManaColor>{};
    for (final c in card.sourceCards) {
      cardColors.addAll(ManaUtils.colorsFromLetters(c.colors));
    }
    final frameColor = ManaUtils.getFrameColor(cardColors);
    final glowColor = ManaUtils.getGlowColor(cardColors);

    return SingleChildScrollView(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: glowColor.withValues(alpha: 0.2),
                blurRadius: 48,
                spreadRadius: 6,
              ),
            ],
          ),
          child: AspectRatio(
            aspectRatio: _cardAspect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;

                  return Stack(
                    children: [
                      // Layer 1: Frame image (or fallback color)
                      Positioned.fill(
                        child: _buildFrameBackground(frameColor),
                      ),

                      // Layer 2: Art window (covers the template card's art)
                      Positioned(
                        left: w * _artLeft,
                        top: h * _artTop,
                        width: w * _artWidth,
                        height: h * _artHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: _buildArtWindow(card),
                        ),
                      ),

                      // Page indicator dots (bottom of art area)
                      if (card.sourceCards.length > 1)
                        Positioned(
                          left: w * _artLeft,
                          top: h * (_artTop + _artHeight) - 18,
                          width: w * _artWidth,
                          height: 18,
                          child: _buildPageIndicator(card.sourceCards.length),
                        ),

                      // Layer 3: Name plate overlay
                      Positioned(
                        left: w * _nameLeft,
                        top: h * _nameTop,
                        width: w * _nameWidth,
                        height: h * _nameHeight,
                        child: _buildNameOverlay(card, frameColor),
                      ),

                      // Layer 4: Type line overlay
                      Positioned(
                        left: w * _typeLeft,
                        top: h * _typeTop,
                        width: w * _typeWidth,
                        height: h * _typeHeight,
                        child: _buildTypeOverlay(card, frameColor),
                      ),

                      // Layer 5: Text box overlay
                      Positioned(
                        left: w * _textLeft,
                        top: h * _textTop,
                        width: w * _textWidth,
                        height: h * _textHeight,
                        child: _buildTextOverlay(card),
                      ),

                      // Layer 6: P/T box overlay
                      Positioned(
                        left: w * _ptLeft,
                        top: h * _ptTop,
                        width: w * _ptWidth,
                        height: h * _ptHeight,
                        child: _buildPTOverlay(card),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Frame Background ─────────────────────────────────────────────

  Widget _buildFrameBackground(Color fallbackColor) {
    if (_frameImagePath != null) {
      return Image.file(
        File(_frameImagePath!),
        fit: BoxFit.fill,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildFallbackFrame(fallbackColor),
      );
    }
    return _buildFallbackFrame(fallbackColor);
  }

  Widget _buildFallbackFrame(Color color) {
    // Simple colored frame fallback when no template image is available
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // ── Name Plate ───────────────────────────────────────────────────

  Widget _buildNameOverlay(MergedCard card, Color frameColor) {
    final textColor = _getTextColor(frameColor);
    final allManaSymbols = <ManaSymbol>[];
    for (final c in card.sourceCards) {
      allManaSymbols.addAll(ManaUtils.parseManaSymbols(c.manaCost));
    }
    final sorted = _sortManaSymbols(allManaSymbols);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        // Fully opaque to completely mask template card text
        color: frameColor.withValues(alpha: 1.0),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                card.displayName,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: textColor == Colors.white ? Colors.black54 : Colors.white30,
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (sorted.isNotEmpty) ...[
            const SizedBox(width: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: sorted.map(_buildManaSymbol).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Art Window ───────────────────────────────────────────────────

  Widget _buildArtWindow(MergedCard card) {
    return PageView.builder(
      controller: _artPageController,
      itemCount: card.sourceCards.length,
      onPageChanged: (i) => setState(() => _currentArtPage = i),
      itemBuilder: (context, index) {
        final sc = card.sourceCards[index];
        if (sc.imageUrl != null && sc.imageUrl!.isNotEmpty) {
          return _buildOnlineArt(sc);
        }
        return _buildOfflineArt();
      },
    );
  }

  Widget _buildOnlineArt(MtgCard card) {
    final artUrl = card.imageUrl!.replaceFirst('/normal/', '/art_crop/');
    return CachedNetworkImage(
      imageUrl: artUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
        ),
      ),
      errorWidget: (_, __, ___) => CachedNetworkImage(
        imageUrl: card.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (_, __, ___) => _buildOfflineArt(),
      ),
    );
  }

  Widget _buildOfflineArt() {
    if (_glurgArtPath != null) {
      return Image.file(
        File(_glurgArtPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildArtPlaceholder(),
      );
    }
    return _buildArtPlaceholder();
  }

  Widget _buildArtPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported, color: Colors.white24, size: 32),
            SizedBox(height: 4),
            Text(
              'Download card data\nfor artwork',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int count) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black54],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) => Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == _currentArtPage ? Colors.white : Colors.white38,
          ),
        )),
      ),
    );
  }

  // ── Type Line ────────────────────────────────────────────────────

  Widget _buildTypeOverlay(MergedCard card, Color frameColor) {
    final textColor = _getTextColor(frameColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: frameColor.withValues(alpha: 1.0),
        borderRadius: BorderRadius.circular(3),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          card.typeLine,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Text Box ─────────────────────────────────────────────────────

  Widget _buildTextOverlay(MergedCard card) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E1).withValues(alpha: 1.0),
        borderRadius: BorderRadius.circular(3),
      ),
      child: SingleChildScrollView(
        child: _buildAbilitiesContent(card),
      ),
    );
  }

  Widget _buildAbilitiesContent(MergedCard card) {
    final children = <Widget>[];
    for (int i = 0; i < card.sourceCards.length; i++) {
      final sc = card.sourceCards[i];
      if (sc.oracleText.isEmpty) continue;

      if (children.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Divider(height: 1, color: Colors.black.withValues(alpha: 0.12)),
        ));
      }
      children.add(Text(
        sc.name,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ));
      children.add(const SizedBox(height: 2));
      children.add(Text(
        sc.oracleText,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 10,
          height: 1.3,
        ),
      ));
    }

    if (children.isEmpty) {
      children.add(const SizedBox(height: 8));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  // ── P/T Box ──────────────────────────────────────────────────────

  Widget _buildPTOverlay(MergedCard card) {
    // Determine P/T box styling based on card colors
    final cardColors = <ManaColor>{};
    for (final c in card.sourceCards) {
      cardColors.addAll(ManaUtils.colorsFromLetters(c.colors));
    }

    Color ptBgColor;
    Color ptTextColor;
    Color ptBorderColor;

    if (cardColors.isEmpty) {
      // Colorless: tan background with black text
      ptBgColor = const Color(0xFFD4A574);
      ptTextColor = Colors.black87;
      ptBorderColor = Colors.black26;
    } else if (cardColors.length == 1) {
      // Mono-color: use the specific frame color with appropriate text contrast
      ptBgColor = ManaUtils.getFrameColorForSingle(cardColors.first);
      // Use light text for dark colors, dark text for light colors
      ptTextColor = ManaUtils.getManaSymbolTextColor(cardColors.first) == const Color(0xFF333333)
          ? Colors.black87
          : Colors.white;
      ptBorderColor = Colors.black12;
    } else {
      // Multi-color: gold background with white text
      ptBgColor = const Color(0xFFB8860B);
      ptTextColor = Colors.white;
      ptBorderColor = Colors.black26;
    }

    return Container(
      decoration: BoxDecoration(
        color: ptBgColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: ptBorderColor, width: 1),
      ),
      child: Center(
        child: Text(
          '${card.combinedPower}/${card.combinedToughness}',
          style: TextStyle(
            color: ptTextColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: ptTextColor == Colors.white ? Colors.black54 : Colors.white30,
                blurRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mana Symbols ─────────────────────────────────────────────────

  Widget _buildManaSymbol(ManaSymbol symbol) {
    final symbolColor = ManaUtils.getManaSymbolColor(symbol.color);
    final textColor = ManaUtils.getManaSymbolTextColor(symbol.color);
    final cachedPath = _manaSymbolPaths[symbol.symbol];

    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.only(left: 1),
      decoration: BoxDecoration(
        color: symbolColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black45, width: 0.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 1, offset: Offset(0.5, 0.5)),
        ],
      ),
      child: Center(
        child: cachedPath != null
            ? SvgPicture.file(
                File(cachedPath),
                width: 16,
                height: 16,
                fit: BoxFit.contain,
              )
            : Text(
                symbol.symbol,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
              ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  List<ManaSymbol> _sortManaSymbols(List<ManaSymbol> symbols) {
    int genericCount = 0;
    final coloredSymbols = <ManaSymbol>[];
    for (final symbol in symbols) {
      if (symbol.isGeneric) {
        genericCount += int.tryParse(symbol.symbol) ?? 1;
      } else {
        coloredSymbols.add(symbol);
      }
    }
    final colorOrder = {'W': 0, 'U': 1, 'B': 2, 'R': 3, 'G': 4};
    coloredSymbols.sort((a, b) =>
        (colorOrder[a.symbol] ?? 99).compareTo(colorOrder[b.symbol] ?? 99));
    final result = <ManaSymbol>[];
    if (genericCount > 0) {
      result.add(ManaSymbol(color: ManaColor.colorless, symbol: genericCount.toString(), isGeneric: true));
    }
    result.addAll(coloredSymbols);
    return result;
  }

  Color _getTextColor(Color bg) {
    final lum = (bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114);
    return lum > 0.5 ? Colors.black87 : Colors.white;
  }
}
