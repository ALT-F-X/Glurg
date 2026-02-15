import 'package:flutter/material.dart';

enum ManaColor { white, blue, black, red, green, colorless, none }

class ManaSymbol {
  final String symbol; // e.g., "W", "U", "B", "R", "G", "2", etc.
  final ManaColor color;
  final bool isGeneric; // true if it's a number like "2"

  ManaSymbol({
    required this.symbol,
    required this.color,
    required this.isGeneric,
  });
}

class ManaUtils {
  /// Parse mana cost string like "{2}{W}{U}" into individual symbols
  static List<ManaSymbol> parseManaSymbols(String manaCost) {
    if (manaCost.isEmpty || manaCost == '0') return [];

    final symbols = <ManaSymbol>[];
    final regex = RegExp(r'\{([^}]+)\}');
    final matches = regex.allMatches(manaCost);

    for (final match in matches) {
      final symbol = match.group(1)!.toUpperCase();
      final manaSymbol = _createManaSymbol(symbol);
      if (manaSymbol != null) {
        symbols.add(manaSymbol);
      }
    }

    return symbols;
  }

  static ManaSymbol? _createManaSymbol(String symbol) {
    switch (symbol) {
      case 'W':
        return ManaSymbol(symbol: symbol, color: ManaColor.white, isGeneric: false);
      case 'U':
        return ManaSymbol(symbol: symbol, color: ManaColor.blue, isGeneric: false);
      case 'B':
        return ManaSymbol(symbol: symbol, color: ManaColor.black, isGeneric: false);
      case 'R':
        return ManaSymbol(symbol: symbol, color: ManaColor.red, isGeneric: false);
      case 'G':
        return ManaSymbol(symbol: symbol, color: ManaColor.green, isGeneric: false);
      case 'X':
        return ManaSymbol(symbol: symbol, color: ManaColor.colorless, isGeneric: false);
      default:
        // Handle generic mana (numbers) and hybrid mana
        if (int.tryParse(symbol) != null) {
          return ManaSymbol(symbol: symbol, color: ManaColor.colorless, isGeneric: true);
        }
        // Handle hybrid like "W/U"
        if (symbol.contains('/')) {
          return ManaSymbol(symbol: symbol, color: ManaColor.colorless, isGeneric: true);
        }
        return null;
    }
  }

  /// Determine card color identity from combined mana costs
  static Set<ManaColor> getCardColorIdentity(List<String> manaCosts) {
    final colors = <ManaColor>{};

    for (final cost in manaCosts) {
      final symbols = parseManaSymbols(cost);
      for (final symbol in symbols) {
        if (symbol.color != ManaColor.colorless && symbol.color != ManaColor.none) {
          colors.add(symbol.color);
        }
      }
    }

    // Handle hybrid mana from oracle text
    for (final cost in manaCosts) {
      if (cost.contains('W/U')) colors.addAll([ManaColor.white, ManaColor.blue]);
      if (cost.contains('W/B')) colors.addAll([ManaColor.white, ManaColor.black]);
      if (cost.contains('U/B')) colors.addAll([ManaColor.blue, ManaColor.black]);
      if (cost.contains('U/R')) colors.addAll([ManaColor.blue, ManaColor.red]);
      if (cost.contains('B/R')) colors.addAll([ManaColor.black, ManaColor.red]);
      if (cost.contains('B/G')) colors.addAll([ManaColor.black, ManaColor.green]);
      if (cost.contains('R/G')) colors.addAll([ManaColor.red, ManaColor.green]);
      if (cost.contains('R/W')) colors.addAll([ManaColor.red, ManaColor.white]);
      if (cost.contains('G/W')) colors.addAll([ManaColor.green, ManaColor.white]);
      if (cost.contains('G/U')) colors.addAll([ManaColor.green, ManaColor.blue]);
    }

    return colors;
  }

  /// Get frame color based on card colors
  static Color getFrameColor(Set<ManaColor> colors) {
    if (colors.isEmpty) {
      // Colorless frame
      return Color(0xFFD4A574); // Tan/brown
    }

    if (colors.length == 1) {
      switch (colors.first) {
        case ManaColor.white:
          return Color(0xFFF0E6D2); // White
        case ManaColor.blue:
          return Color(0xFF0E47A1); // Blue
        case ManaColor.black:
          return Color(0xFF1A1A1A); // Black
        case ManaColor.red:
          return Color(0xFFC13C00); // Red
        case ManaColor.green:
          return Color(0xFF165B33); // Green
        default:
          return Color(0xFFD4A574);
      }
    }

    // Multi-color: gold/artifact
    return Color(0xFFB8860B); // Gold
  }

  /// Get accent color (darker shade) for frame borders
  static Color getFrameAccentColor(Set<ManaColor> colors) {
    if (colors.isEmpty) {
      return Color(0xFF8B7355);
    }

    if (colors.length == 1) {
      switch (colors.first) {
        case ManaColor.white:
          return Color(0xFFD4AF37); // Gold accent
        case ManaColor.blue:
          return Color(0xFF1565C0);
        case ManaColor.black:
          return Color(0xFF000000);
        case ManaColor.red:
          return Color(0xFF8B0000);
        case ManaColor.green:
          return Color(0xFF0D3B25);
        default:
          return Color(0xFF8B7355);
      }
    }

    return Color(0xFF8B6F47); // Gold accent for multi-color
  }

  /// Get mana color for symbol display
  static Color getManaSymbolColor(ManaColor color) {
    switch (color) {
      case ManaColor.white:
        return Color(0xFFF0E6D2);
      case ManaColor.blue:
        return Color(0xFF0E47A1);
      case ManaColor.black:
        return Color(0xFF1A1A1A);
      case ManaColor.red:
        return Color(0xFFC13C00);
      case ManaColor.green:
        return Color(0xFF165B33);
      default:
        return Color(0xFF999999);
    }
  }

  /// Get text color for mana symbols (often white or gold)
  static Color getManaSymbolTextColor(ManaColor color) {
    switch (color) {
      case ManaColor.white:
        return Color(0xFF333333);
      case ManaColor.blue:
        return Color(0xFFFFD700);
      case ManaColor.black:
        return Color(0xFFFFD700);
      case ManaColor.red:
        return Color(0xFFFFD700);
      case ManaColor.green:
        return Color(0xFFFFD700);
      default:
        return Color(0xFF000000);
    }
  }
}
