import 'package:flutter/material.dart';
import 'package:glurg_app/models/card.dart';
import 'package:glurg_app/utils/mana_utils.dart';

class MagicCardDisplay extends StatelessWidget {
  final MergedCard mergedCard;

  const MagicCardDisplay({Key? key, required this.mergedCard}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine card colors for frame
    final cardColors = ManaUtils.getCardColorIdentity(
      mergedCard.sourceCards.map((c) => c.manaCost).toList(),
    );
    final frameColor = ManaUtils.getFrameColor(cardColors);
    final accentColor = ManaUtils.getFrameAccentColor(cardColors);

    // Parse all mana symbols for devotion display
    final allManaSymbols = <ManaSymbol>[];
    for (final card in mergedCard.sourceCards) {
      allManaSymbols.addAll(ManaUtils.parseManaSymbols(card.manaCost));
    }

    // Sort mana symbols: generic first, then WUBRG order
    final sortedManaSymbols = _sortManaSymbols(allManaSymbols);

    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: frameColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Divider(
                color: accentColor.withOpacity(0.5),
                thickness: 1,
              ),
              const SizedBox(height: 12),
              // Type Line
              Text(
                mergedCard.typeLine,
                style: TextStyle(
                  color: _getTextColor(frameColor),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Divider(
                color: accentColor.withOpacity(0.5),
                thickness: 1,
              ),
              const SizedBox(height: 12),
              // Mana Pips (Mana Devotion)
              if (allManaSymbols.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mana Value',
                      style: TextStyle(
                        color: _getTextColor(frameColor),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: sortedManaSymbols.map((symbol) => _buildManaSymbol(symbol, context)).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              // Abilities Text - organized by creature
              if (mergedCard.sourceCards.isNotEmpty) ...[
                ..._buildAbilitiesSection(mergedCard, frameColor, accentColor, context),
              ],
              // Power/Toughness Box (right side)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      border: Border.all(color: accentColor, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${mergedCard.combinedPower}/${mergedCard.combinedToughness}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManaSymbol(ManaSymbol symbol, BuildContext context) {
    final symbolColor = ManaUtils.getManaSymbolColor(symbol.color);
    final textColor = ManaUtils.getManaSymbolTextColor(symbol.color);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: symbolColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          symbol.symbol,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Color _getTextColor(Color backgroundColor) {
    final luminance = (backgroundColor.red * 0.299 +
            backgroundColor.green * 0.587 +
            backgroundColor.blue * 0.114) /
        255;
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  List<Widget> _buildAbilitiesSection(
    MergedCard card,
    Color frameColor,
    Color accentColor,
    BuildContext context,
  ) {
    final widgets = <Widget>[];

    // Display abilities for each source card separately
    for (int i = 0; i < card.sourceCards.length; i++) {
      final sourceCard = card.sourceCards[i];
      
      if (sourceCard.oracleText.isEmpty) {
        continue;
      }

      // Add creature name as a label
      widgets.add(
        Text(
          sourceCard.name,
          style: TextStyle(
            color: accentColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 4));

      // Add the oracle text
      widgets.add(
        Text(
          sourceCard.oracleText,
          style: TextStyle(
            color: _getTextColor(frameColor),
            fontSize: 12,
            height: 1.6,
          ),
        ),
      );

      // Add spacing between creatures
      if (i < card.sourceCards.length - 1) {
        widgets.add(const SizedBox(height: 12));
      }
    }

    widgets.addAll([
      const SizedBox(height: 12),
      Divider(
        color: accentColor.withOpacity(0.5),
        thickness: 1,
      ),
      const SizedBox(height: 12),
    ]);

    return widgets;
  }

  List<ManaSymbol> _sortManaSymbols(List<ManaSymbol> symbols) {
    // Combine generic mana and separate colored mana
    int genericCount = 0;
    final coloredSymbols = <ManaSymbol>[];

    for (final symbol in symbols) {
      if (symbol.isGeneric) {
        genericCount += int.tryParse(symbol.symbol) ?? 1;
      } else {
        coloredSymbols.add(symbol);
      }
    }

    // Sort colored symbols in WUBRG order
    final colorOrder = {'W': 0, 'U': 1, 'B': 2, 'R': 3, 'G': 4};
    coloredSymbols.sort((a, b) {
      final orderA = colorOrder[a.symbol] ?? 99;
      final orderB = colorOrder[b.symbol] ?? 99;
      return orderA.compareTo(orderB);
    });

    // Build result: generic first, then colors
    final result = <ManaSymbol>[];
    if (genericCount > 0) {
      result.add(ManaSymbol(
        color: ManaColor.colorless,
        symbol: genericCount.toString(),
        isGeneric: true,
      ));
    }
    result.addAll(coloredSymbols);

    return result;
  }
}
