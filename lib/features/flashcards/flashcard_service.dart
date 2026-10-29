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
      return decoded.map((d) => FlashcardDeck.fromJson(d as Map<String, dynamic>)).toList();
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

      if (line.contains(delimiter)) {
        final parts = line.split(delimiter);
        front = parts[0].trim();
        back = parts.length > 1 ? parts[1].trim() : '';
        if (parts.length > 2) {
          hint = parts[2].trim();
        }
      } else if (line.contains(':')) {
        final parts = line.split(':');
        front = parts[0].trim();
        back = parts.length > 1 ? parts[1].trim() : '';
      }

      if (front.isNotEmpty && back.isNotEmpty) {
        cards.add(Flashcard(
          id: '${DateTime.now().microsecondsSinceEpoch}_${cards.length}',
          front: front,
          back: back,
          hint: hint,
        ));
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
    return [
      FlashcardDeck(
        id: 'deck_chem_1',
        title: 'Bảng tuần hoàn & Nguyên tố Hóa học',
        description: 'Các nguyên tố cơ bản, số hiệu nguyên tử và ký hiệu hóa học.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        cards: [
          Flashcard(id: 'c1', front: 'Hydro (H)', back: 'Số hiệu: 1, Nhóm 1', hint: 'Khí nhẹ nhất vũ trụ'),
          Flashcard(id: 'c2', front: 'Oxi (O)', back: 'Số hiệu: 8, Nhóm 16', hint: 'Duy trì sự cháy và hô hấp'),
          Flashcard(id: 'c3', front: 'Natri (Na)', back: 'Số hiệu: 11, Nhóm 1', hint: 'Kim loại kiềm, phản ứng mạnh với nước'),
          Flashcard(id: 'c4', front: 'Sắt (Fe)', back: 'Số hiệu: 26, Nhóm 8', hint: 'Kim loại chuyển tiếp phổ biến làm vật liệu'),
          Flashcard(id: 'c5', front: 'Vàng (Au)', back: 'Số hiệu: 79, Nhóm 11', hint: 'Kim loại quý, dẫn điện tốt'),
        ],
      ),
      FlashcardDeck(
        id: 'deck_math_1',
        title: 'Công thức Toán học & Hình học',
        description: 'Các định lý và công thức tính diện tích, thể tích quan trọng.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        cards: [
          Flashcard(id: 'm1', front: 'Diện tích hình tròn', back: 'S = π * r²', hint: 'r là bán kính'),
          Flashcard(id: 'm2', front: 'Thể tích hình cầu', back: 'V = (4/3) * π * r³', hint: 'Liên quan đến lập phương bán kính'),
          Flashcard(id: 'm3', front: 'Định lý Pythagoras', back: 'a² + b² = c²', hint: 'Áp dụng cho tam giác vuông'),
        ],
      ),
    ];
  }
}
