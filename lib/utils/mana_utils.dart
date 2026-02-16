import 'package:flutter/material.dart';

enum ManaColor { white, blue, black, red, green, colorless, none }

enum FrameType { colorless, mono, split, gold }

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

  /// Convert Scryfall color letters ["W", "U", "B", "R", "G"] to ManaColor set
  static Set<ManaColor> colorsFromLetters(List<String> colorLetters) {
    final colors = <ManaColor>{};
    for (final letter in colorLetters) {
      switch (letter.toUpperCase()) {
        case 'W':
          colors.add(ManaColor.white);
        case 'U':
          colors.add(ManaColor.blue);
        case 'B':
          colors.add(ManaColor.black);
        case 'R':
          colors.add(ManaColor.red);
        case 'G':
          colors.add(ManaColor.green);
      }
    }
    return colors;
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

  /// WUBRG order index for sorting colors
  static const Map<ManaColor, int> wubrgOrder = {
    ManaColor.white: 0,
    ManaColor.blue: 1,
    ManaColor.black: 2,
    ManaColor.red: 3,
    ManaColor.green: 4,
  };

  /// Sort a set of ManaColors in WUBRG order
  static List<ManaColor> sortByWubrg(Set<ManaColor> colors) {
    final list = colors.where((c) => wubrgOrder.containsKey(c)).toList();
    list.sort((a, b) => (wubrgOrder[a] ?? 99).compareTo(wubrgOrder[b] ?? 99));
    return list;
  }

  /// Determine frame type from card colors
  static FrameType getFrameType(Set<ManaColor> colors) {
    final meaningful = colors.where((c) => wubrgOrder.containsKey(c)).toSet();
    if (meaningful.isEmpty) return FrameType.colorless;
    if (meaningful.length == 1) return FrameType.mono;
    if (meaningful.length == 2) return FrameType.split;
    return FrameType.gold;
  }

  /// Get frame color for a single ManaColor
  static Color getFrameColorForSingle(ManaColor color) {
    switch (color) {
      case ManaColor.white:
        return const Color(0xFFF0E6D2);
      case ManaColor.blue:
        return const Color(0xFF0E47A1);
      case ManaColor.black:
        return const Color(0xFF1A1A1A);
      case ManaColor.red:
        return const Color(0xFFC13C00);
      case ManaColor.green:
        return const Color(0xFF165B33);
      default:
        return const Color(0xFFD4A574);
    }
  }

  /// Build a LinearGradient for a 2-color split frame (WUBRG order)
  static LinearGradient buildSplitFrameGradient(Set<ManaColor> colors) {
    final sorted = sortByWubrg(colors);
    final leftColor = getFrameColorForSingle(sorted[0]);
    final rightColor = getFrameColorForSingle(sorted[1]);
    return LinearGradient(
      colors: [leftColor, leftColor, rightColor, rightColor],
      stops: const [0.0, 0.48, 0.52, 1.0],
    );
  }

  /// Get glow color for Arena-style shadow effect
  static Color getGlowColor(Set<ManaColor> colors) {
    final type = getFrameType(colors);
    switch (type) {
      case FrameType.colorless:
        return const Color(0xFFD4A574);
      case FrameType.mono:
        return getFrameColorForSingle(colors.first);
      case FrameType.split:
        final sorted = sortByWubrg(colors);
        return Color.lerp(
          getFrameColorForSingle(sorted[0]),
          getFrameColorForSingle(sorted[1]),
          0.5,
        )!;
      case FrameType.gold:
        return const Color(0xFFB8860B);
    }
  }
}
