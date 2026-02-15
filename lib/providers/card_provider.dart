import 'package:flutter/material.dart';
import 'package:glurg_app/models/card.dart';
import 'package:glurg_app/services/scryfall_service.dart';

class CardListProvider extends ChangeNotifier {
  final List<MtgCard> _cards = [];
  MergedCard? _mergedCard;
  final ScryfallService _scryfallService = ScryfallService();
  bool _isLoading = false;
  String? _error;

  List<MtgCard> get cards => _cards;
  MergedCard? get mergedCard => _mergedCard;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCards => _cards.isNotEmpty;

  Future<void> addCardByName(String cardName) async {
    if (cardName.trim().isEmpty) {
      _error = 'Card name cannot be empty';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final card = await _scryfallService.searchCardByName(cardName);
      if (card != null) {
        _cards.add(card);
        _mergedCard = MergedCard.fromCards(_cards);
        _error = null;
      } else {
        _error = 'Card "$cardName" not found. Check spelling?';
      }
    } catch (e) {
      _error = 'Error: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  void removeCardAt(int index) {
    if (index < 0 || index >= _cards.length) return;
    _cards.removeAt(index);
    if (_cards.isNotEmpty) {
      _mergedCard = MergedCard.fromCards(_cards);
    } else {
      _mergedCard = null;
    }
    notifyListeners();
  }

  void clearAllCards() {
    _cards.clear();
    _mergedCard = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
