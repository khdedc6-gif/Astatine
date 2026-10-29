import 'package:flutter_test/flutter_test.dart';
import 'package:astatine_dashboard/features/flashcards/flashcard_models.dart';
import 'package:astatine_dashboard/features/flashcards/flashcard_service.dart';

void main() {
  test('Flashcard and Deck model serialization', () {
    final card = Flashcard(
      id: 'f1',
      front: 'Question',
      back: 'Answer',
      hint: 'Hint text',
      difficulty: CardDifficulty.memorized,
      reviewCount: 3,
    );

    final json = card.toJson();
    final decodedCard = Flashcard.fromJson(json);

    expect(decodedCard.id, 'f1');
    expect(decodedCard.front, 'Question');
    expect(decodedCard.back, 'Answer');
    expect(decodedCard.hint, 'Hint text');
    expect(decodedCard.difficulty, CardDifficulty.memorized);
    expect(decodedCard.reviewCount, 3);

    final deck = FlashcardDeck(
      id: 'd1',
      title: 'Test Deck',
      description: 'Description',
      cards: [card],
      createdAt: DateTime.now(),
    );

    expect(deck.totalCards, 1);
    expect(deck.masteredCards, 0);
    
    card.difficulty = CardDifficulty.easy;
    expect(deck.masteredCards, 1);

    final deckJson = deck.toJson();
    final decodedDeck = FlashcardDeck.fromJson(deckJson);
    expect(decodedDeck.title, 'Test Deck');
    expect(decodedDeck.cards.length, 1);
  });

  test('FlashcardService bulk text import parser', () {
    final rawText = 'Apple | Táo | Quả màu đỏ\nBanana | Chuối\nInvalidLineWithoutDelimiter';
    final importedDeck = FlashcardService.importFromBulkText(
      title: 'Vocabulary',
      description: 'English-Vietnamese',
      rawText: rawText,
    );

    expect(importedDeck.title, 'Vocabulary');
    expect(importedDeck.cards.length, 2);
    expect(importedDeck.cards[0].front, 'Apple');
    expect(importedDeck.cards[0].back, 'Táo');
    expect(importedDeck.cards[0].hint, 'Quả màu đỏ');
    expect(importedDeck.cards[1].front, 'Banana');
    expect(importedDeck.cards[1].back, 'Chuối');
  });
}
