import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'flashcard_models.dart';

class FlashcardService {
  static const String _decksKey = 'astatine_flashcard_decks_v1';
  static const String _settingsKey = 'astatine_flashcard_settings_v1';

  static Future<List<FlashcardDeck>> getDecks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawJson = prefs.getString(_decksKey);
    if (rawJson == null || rawJson.isEmpty) {
      return _getInitialDecks();
    }
    try {
      final List<dynamic> decoded = jsonDecode(rawJson);
      return decoded
          .map((d) => FlashcardDeck.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return _getInitialDecks();
    }
  }

  static Future<void> saveDecks(List<FlashcardDeck> decks) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(decks.map((d) => d.toJson()).toList());
    await prefs.setString(_decksKey, encoded);
  }

  static Future<void> saveDeck(FlashcardDeck deck) async {
    final decks = await getDecks();
    final index = decks.indexWhere((d) => d.id == deck.id);
    if (index >= 0) {
      decks[index] = deck;
    } else {
      decks.insert(0, deck);
    }
    await saveDecks(decks);
  }

  static Future<void> deleteDeck(String id) async {
    final decks = await getDecks();
    decks.removeWhere((d) => d.id == id);
    await saveDecks(decks);
  }

  // Bulk Text Import Parser: supports lines like "Front | Back" or "Front : Back"
  static FlashcardDeck importFromBulkText({
    required String title,
    required String description,
    required String rawText,
    String delimiter = '|',
  }) {
    final lines = rawText.split('\n');
    final List<Flashcard> cards = [];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      String front = line;
      String back = '';
      String? hint;
      var parsedMode = 1;

      if (line.contains(delimiter)) {
        final parts = line.split(delimiter);
        front = parts[0].trim();
        back = parts.length > 1 ? parts[1].trim() : '';
        final modeValue = parts.length > 2
            ? int.tryParse(parts[2].trim())
            : null;
        if (modeValue == 1 || modeValue == 2) {
          parsedMode = modeValue!;
        } else if (parts.length > 2) {
          hint = parts[2].trim();
        }
        if (parts.length > 3) {
          hint = parts[3].trim();
        }
      } else if (line.contains(':')) {
        final parts = line.split(':');
        front = parts[0].trim();
        back = parts.length > 1 ? parts[1].trim() : '';
      }

      if (front.isNotEmpty && back.isNotEmpty) {
        cards.add(
          Flashcard(
            id: '${DateTime.now().microsecondsSinceEpoch}_${cards.length}',
            front: front,
            back: back,
            hint: hint,
            mode: parsedMode == 2 ? 2 : 1,
          ),
        );
      }
    }

    return FlashcardDeck(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'Bộ thẻ nhập nhanh' : title,
      description: description,
      cards: cards,
      createdAt: DateTime.now(),
    );
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_settingsKey);
    if (raw == null) {
      return {
        'reminderTime': '20:00',
        'reminderEnabled': true,
        'shuffleMode': false,
        'reverseCard': false,
      };
    }
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {
        'reminderTime': '20:00',
        'reminderEnabled': true,
        'shuffleMode': false,
        'reverseCard': false,
      };
    }
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }

  static List<FlashcardDeck> _getInitialDecks() {
    return [];
  }
}
