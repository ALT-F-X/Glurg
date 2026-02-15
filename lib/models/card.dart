class MtgCard {
  final String name;
  final String manaCost;
  final int manaValue;
  final String type;
  final String? power;
  final String? toughness;
  final String oracleText;
  final String? imageUrl;
  final String? scryfallUrl;

  MtgCard({
    required this.name,
    required this.manaCost,
    required this.manaValue,
    required this.type,
    this.power,
    this.toughness,
    required this.oracleText,
    this.imageUrl,
    this.scryfallUrl,
  });

  factory MtgCard.fromJson(Map<String, dynamic> json, {String? searchName}) {
    // Handle double-faced cards
    if (json['card_faces'] != null && json['card_faces'] is List && (json['card_faces'] as List).isNotEmpty) {
      final faces = json['card_faces'] as List;

      // Pick the face that matches what the user searched for, default to front
      var faceData = faces[0] as Map<String, dynamic>;
      if (searchName != null) {
        final query = searchName.trim().toLowerCase();
        for (final face in faces) {
          final faceName = (face['name'] as String? ?? '').toLowerCase();
          if (faceName == query || faceName.contains(query)) {
            faceData = face as Map<String, dynamic>;
            break;
          }
        }
      }

      return MtgCard(
        name: faceData['name'] ?? 'Unknown',
        manaCost: faceData['mana_cost'] ?? '',
        manaValue: (faceData['mana_cost'] != null ? json['mana_value'] : null) ?? 0,
        type: faceData['type_line'] ?? 'Unknown',
        power: faceData['power'],
        toughness: faceData['toughness'],
        oracleText: faceData['oracle_text'] ?? '',
        imageUrl: faceData['image_uris']?['normal'] ?? json['image_uris']?['normal'],
        scryfallUrl: json['scryfall_uri'],
      );
    }
    
    // Handle regular single-faced cards
    return MtgCard(
      name: json['name'] ?? 'Unknown',
      manaCost: json['mana_cost'] ?? '',
      manaValue: json['mana_value'] ?? 0,
      type: json['type_line'] ?? 'Unknown',
      power: json['power'],
      toughness: json['toughness'],
      oracleText: json['oracle_text'] ?? '',
      imageUrl: json['image_uris']?['normal'],
      scryfallUrl: json['scryfall_uri'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'mana_cost': manaCost,
    'mana_value': manaValue,
    'type_line': type,
    'power': power,
    'toughness': toughness,
    'oracle_text': oracleText,
    'image_uris': {'normal': imageUrl},
    'scryfall_uri': scryfallUrl,
  };
}

/// A merged card combining multiple cards' properties
class MergedCard {
  final List<MtgCard> sourceCards;
  final int combinedManaValue;
  final int combinedPower;
  final int combinedToughness;
  final Set<String> creatureTypes;
  final Set<String> cardTypes;
  final Set<String> superTypes;
  final List<String> abilities;

  MergedCard({
    required this.sourceCards,
    required this.combinedManaValue,
    required this.combinedPower,
    required this.combinedToughness,
    required this.creatureTypes,
    required this.cardTypes,
    required this.superTypes,
    required this.abilities,
  });

  /// Create a merged card from a list of cards
  factory MergedCard.fromCards(List<MtgCard> cards) {
    // MTG supertypes and card types per comprehensive rules
    const knownSuperTypes = {'Legendary', 'Snow', 'Basic', 'World'};
    const knownCardTypes = {
      'Artifact', 'Enchantment', 'Land', 'Planeswalker',
      'Battle', 'Kindred',
    };

    if (cards.isEmpty) {
      return MergedCard(
        sourceCards: [],
        combinedManaValue: 0,
        combinedPower: 0,
        combinedToughness: 0,
        creatureTypes: {},
        cardTypes: {},
        superTypes: {},
        abilities: [],
      );
    }

    int totalManaValue = 0;
    int totalPower = 0;
    int totalToughness = 0;
    final Set<String> subtypes = {};
    final Set<String> cardTypes = {};
    final Set<String> superTypes = {};
    final List<String> abilityList = [];

    for (final card in cards) {
      // Sum mana values
      totalManaValue += card.manaValue;

      // Sum power/toughness (only for creatures)
      if (card.power != null) {
        totalPower += int.tryParse(card.power!) ?? 0;
      }
      if (card.toughness != null) {
        totalToughness += int.tryParse(card.toughness!) ?? 0;
      }

      // Parse the full type line: "Legendary Snow Artifact Creature — Human Soldier"
      final typeLine = card.type;
      final parts = typeLine.split('—');

      // Left side: supertypes and card types
      final leftWords = parts[0].trim().split(RegExp(r'\s+'));
      for (final word in leftWords) {
        if (knownSuperTypes.contains(word)) {
          superTypes.add(word);
        } else if (knownCardTypes.contains(word)) {
          cardTypes.add(word);
        }
        // "Creature" is always included in the output, so we skip it here
      }

      // Right side: subtypes (creature types like Human, Soldier, etc.)
      if (parts.length > 1) {
        final subtypeWords = parts[1].trim().split(RegExp(r'\s+'));
        subtypes.addAll(subtypeWords.where((t) => t.isNotEmpty));
      }

      // Collect abilities
      if (card.oracleText.isNotEmpty) {
        final abilities = card.oracleText
            .split('\n')
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList();
        abilityList.addAll(abilities);
      }
    }

    return MergedCard(
      sourceCards: cards,
      combinedManaValue: totalManaValue,
      combinedPower: totalPower,
      combinedToughness: totalToughness,
      creatureTypes: subtypes,
      cardTypes: cardTypes,
      superTypes: superTypes,
      abilities: abilityList,
    );
  }

  // Get the display name (all card names combined)
  String get displayName {
    return sourceCards.map((c) => c.name).join(', ');
  }

  // Get the combined type line: "Legendary Snow Artifact Creature — Human Soldier"
  String get typeLine {
    final parts = <String>[];

    // Supertypes first (Legendary, Snow, etc.)
    if (superTypes.isNotEmpty) {
      parts.addAll(superTypes);
    }

    // Card types besides Creature (Artifact, Enchantment, etc.)
    if (cardTypes.isNotEmpty) {
      parts.addAll(cardTypes);
    }

    // Creature is always present
    parts.add('Creature');

    // Subtypes after the dash
    if (creatureTypes.isNotEmpty) {
      return '${parts.join(' ')} — ${creatureTypes.join(' ')}';
    }
    return parts.join(' ');
  }

  // Get the combined ability text (separated by lines)
  String get abilitiesText {
    return abilities.join('\n\n');
  }
}
