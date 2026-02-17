import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:glurg_app/models/card.dart';
import 'package:glurg_app/services/database_helper.dart';

class ScryfallService {
  static const String baseUrl = 'https://api.scryfall.com';
  static const Map<String, String> _headers = {
    'User-Agent': 'GlurgApp/1.0',
    'Accept': 'application/json',
  };
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Search for a single card by name (offline-first)
  /// Returns null if card not found
  Future<MtgCard?> searchCardByName(String cardName) async {
    // Step 1: Check local database first
    try {
      final localCard = await _db.searchCardByName(cardName);
      if (localCard != null) {
        return localCard;
      }
    } catch (e) {
      // Database error, continue to online search
      // Silently fail and try API
    }

    // Step 2: Try online API if not found locally
    try {
      final Uri uri = Uri.parse(
        '$baseUrl/cards/named?fuzzy=${Uri.encodeComponent(cardName)}',
      );

      final response = await http.get(uri, headers: _headers).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return MtgCard.fromJson(json, searchName: cardName);
      } else if (response.statusCode == 404) {
        return null; // Card not found
      } else if (response.statusCode == 400) {
        // Scryfall returns 400 when fuzzy search is ambiguous (too many matches)
        final errorJson = jsonDecode(response.body);
        final details = errorJson['details'] as String? ?? 'Try a more specific name';
        throw Exception(details);
      } else {
        throw Exception('Failed to fetch card: ${response.statusCode}');
      }
    } on SocketException {
      // No internet connection
      throw Exception('No internet connection and card not found in offline database');
    } catch (e) {
      throw Exception('Error searching card: $e');
    }
  }

  /// Search for multiple cards by name
  /// Returns list of successfully found cards, skips not-found ones
  Future<List<MtgCard>> searchMultipleCards(List<String> cardNames) async {
    final results = <MtgCard>[];
    
    for (final name in cardNames) {
      try {
        final card = await searchCardByName(name);
        if (card != null) {
          results.add(card);
        }
      } catch (e) {
        // Skip card if error, continue with others
      }
    }
    
    return results;
  }

  /// Get random card (for testing)
  Future<MtgCard?> getRandomCard() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cards/random'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return MtgCard.fromJson(json, searchName: 'random');
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching random card: $e');
    }
  }
}
