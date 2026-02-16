import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class CardNameExtractor {
  /// Extracts the most likely Magic card name from OCR recognized text.
  /// Uses scoring to pick the best candidate rather than position filtering,
  /// since camera rotation makes position unreliable.
  String? extractCardName(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return null;

    String? bestCandidate;
    double bestScore = -1;

    for (final block in recognizedText.blocks) {
      // Check each line within the block separately
      for (final line in block.lines) {
        final cleaned = _cleanText(line.text);
        if (cleaned.length < 2) continue;

        final score = _scoreAsCardName(cleaned);
        if (score > bestScore) {
          bestScore = score;
          bestCandidate = cleaned;
        }
      }
    }

    // Only return if we have a reasonable confidence
    if (bestScore >= 2.0 && bestCandidate != null) {
      return bestCandidate;
    }

    return null;
  }

  /// Score how likely a text string is to be a Magic card name.
  /// Higher score = more likely to be a card name.
  double _scoreAsCardName(String text) {
    double score = 0;
    final lower = text.toLowerCase();
    final wordCount = text.split(' ').length;

    // Reject obvious non-names
    if (text.length > 40) return -10; // Too long for a card name
    if (wordCount > 6) return -10; // Too many words

    // Strong negative: rules text keywords
    const rulesWords = [
      'whenever', 'target', 'controller', 'graveyard', 'battlefield',
      'creature gets', 'you may', 'sacrifice', 'destroy', 'counter',
      'draw a card', 'each player', 'end of turn', 'beginning of',
      'enters the', 'dies', 'tapped', 'untap', 'mana pool',
      'enchanted', 'equipped', 'blocked', 'attacks', 'defends',
    ];
    for (final keyword in rulesWords) {
      if (lower.contains(keyword)) return -10;
    }

    // Strong negative: type line words (we want the name, not the type)
    const typeWords = [
      'creature', 'artifact', 'enchantment', 'sorcery', 'instant',
      'planeswalker', 'legendary', 'land', 'tribal', 'kindred',
    ];
    int typeWordCount = 0;
    for (final tw in typeWords) {
      if (lower.contains(tw)) typeWordCount++;
    }
    if (typeWordCount >= 2) return -10; // Looks like a type line

    // Strong negative: power/toughness pattern
    if (RegExp(r'^\d+/\d+$').hasMatch(text.trim())) return -10;

    // Strong negative: looks like a number (mana cost, collector number)
    if (RegExp(r'^\d+$').hasMatch(text.trim())) return -10;

    // Strong negative: artist credit or collector info
    if (lower.startsWith('illus') || lower.contains('wizards')) return -10;

    // Positive: good word count for a card name (1-4 words is ideal)
    if (wordCount >= 1 && wordCount <= 4) score += 3;
    else if (wordCount == 5) score += 1;

    // Positive: starts with a capital letter (card names are title case)
    if (text[0] == text[0].toUpperCase() && text[0] != text[0].toLowerCase()) {
      score += 2;
    }

    // Positive: most words are capitalized (title case)
    final words = text.split(' ');
    final capitalizedWords = words.where((w) =>
      w.isNotEmpty && w[0] == w[0].toUpperCase() && w[0] != w[0].toLowerCase()
    ).length;
    if (capitalizedWords == words.length) score += 2;

    // Positive: reasonable length for a card name
    if (text.length >= 3 && text.length <= 30) score += 1;

    // Positive: contains common name words/patterns
    if (lower.contains(',') && wordCount <= 4) score += 1; // "Avacyn, Angel of Hope"
    if (lower.contains('the ')) score += 0.5; // "The Ur-Dragon"
    if (lower.contains('of ')) score += 0.5; // "Sword of Fire and Ice"

    // Negative: contains digits mixed with letters (likely not a name)
    if (RegExp(r'\d').hasMatch(text) && RegExp(r'[a-zA-Z]').hasMatch(text)) {
      score -= 2;
    }

    return score;
  }

  /// Clean OCR artifacts from the text
  String _cleanText(String raw) {
    var text = raw.trim();

    // Remove mana cost symbols: {2}, {W}, {U}, etc.
    text = text.replaceAll(RegExp(r'\{[^}]*\}'), '');

    // Remove common OCR artifacts
    text = text.replaceAll(RegExp(r'[|•·©®™°]'), '');

    // Collapse multiple spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // Take only the first line if multiple lines detected
    if (text.contains('\n')) {
      text = text.split('\n').first;
    }

    return text.trim();
  }
}
