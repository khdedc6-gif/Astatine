class Flashcard {
  final String id;
  String front; // Câu hỏi / Mặt trước
  String back;  // Đáp án / Mặt sau
  String? hint; // Gợi ý
  CardDifficulty difficulty;
  int reviewCount;

  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.hint,
    this.difficulty = CardDifficulty.forgotten,
    this.reviewCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'front': front,
        'back': back,
        'hint': hint,
        'difficulty': difficulty.index,
        'reviewCount': reviewCount,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        front: json['front'] ?? '',
        back: json['back'] ?? '',
        hint: json['hint'],
        difficulty: CardDifficulty.values[json['difficulty'] ?? 0],
        reviewCount: json['reviewCount'] ?? 0,
      );
}

enum CardDifficulty { forgotten, memorized, easy }

class FlashcardDeck {
  final String id;
  String title;
  String description;
  List<Flashcard> cards;
  final DateTime createdAt;
  DateTime? lastStudiedAt;

  FlashcardDeck({
    required this.id,
    required this.title,
    required this.description,
    required this.cards,
    required this.createdAt,
    this.lastStudiedAt,
  });

  int get totalCards => cards.length;
  int get masteredCards => cards.where((c) => c.difficulty == CardDifficulty.easy).toSet().length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'cards': cards.map((c) => c.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'lastStudiedAt': lastStudiedAt?.toIso8601String(),
      };

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) => FlashcardDeck(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] ?? 'Bộ thẻ mới',
        description: json['description'] ?? '',
        cards: (json['cards'] as List<dynamic>? ?? [])
            .map((c) => Flashcard.fromJson(c as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        lastStudiedAt: json['lastStudiedAt'] != null
            ? DateTime.tryParse(json['lastStudiedAt'])
            : null,
      );
}

