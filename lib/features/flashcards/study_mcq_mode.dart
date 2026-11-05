import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import 'flashcard_models.dart';
import 'flashcard_service.dart';

class StudyMcqModeScreen extends StatefulWidget {
  const StudyMcqModeScreen({
    super.key,
    required this.deck,
    required this.shuffle,
  });
  final FlashcardDeck deck;
  final bool shuffle;

  @override
  State<StudyMcqModeScreen> createState() => _StudyMcqModeScreenState();
}

class _StudyMcqModeScreenState extends State<StudyMcqModeScreen> {
  late List<Flashcard> _cards;
  int _index = 0;
  int _score = 0;
  String? _selectedOption;
  bool _answered = false;
  List<String> _currentOptions = [];

  @override
  void initState() {
    super.initState();
    _cards = List.from(widget.deck.cards);
    if (widget.shuffle) _cards.shuffle(Random());
    _loadOptions();
  }

  void _loadOptions() {
    if (_cards.isEmpty) return;
    final currentCard = _cards[_index];
    final correctAnswer = currentCard.back;

    // Generate distractors from other cards in deck
    final otherAnswers = widget.deck.cards
        .where((c) => c.back != correctAnswer)
        .map((c) => c.back)
        .toList();
    otherAnswers.shuffle();

    final distractors = otherAnswers.take(3).toList();
    _currentOptions = [correctAnswer, ...distractors]..shuffle();
    _selectedOption = null;
    _answered = false;
  }

  void _answer(String option) {
    if (_answered) return;
    setState(() {
      _selectedOption = option;
      _answered = true;
      if (option == _cards[_index].back) {
        _score++;
        _cards[_index].difficulty = CardDifficulty.easy;
      } else {
        _cards[_index].difficulty = CardDifficulty.forgotten;
      }
    });
  }

  void _nextCard() async {
    await FlashcardService.saveDeck(widget.deck);
    if (_index < _cards.length - 1) {
      setState(() {
        _index++;
        _loadOptions();
      });
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: Text(
            'Kết quả Trắc nghiệm: $_score / ${_cards.length}',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF89B4FA),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Trở về'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF11111B),
        appBar: AppBar(title: const Text('Trắc nghiệm A/B/C/D')),
        body: const Center(
          child: Text('Không có thẻ.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final card = _cards[_index];

    return Scaffold(
      backgroundColor: const Color(0xFF11111B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181825),
        title: Text(
          'Trắc nghiệm: ${widget.deck.title}',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / _cards.length,
              color: const Color(0xFF89B4FA),
            ),
            const Gap(32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF181825),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF45475A)),
              ),
              child: Column(
                children: [
                  Text(
                    'CÂU HỎI',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF89B4FA),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(12),
                  Text(
                    card.front,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(24),
            ..._currentOptions.map((opt) {
              Color btnColor = const Color(0xFF313244);
              if (_answered) {
                if (opt == card.back) {
                  btnColor = const Color(0xFFA6E3A1);
                } else if (opt == _selectedOption) {
                  btnColor = const Color(0xFFF38BA8);
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btnColor,
                      foregroundColor:
                          _answered &&
                              (opt == card.back || opt == _selectedOption)
                          ? Colors.black
                          : Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _answered ? null : () => _answer(opt),
                    child: Text(
                      opt,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            if (_answered)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF89B4FA),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _nextCard,
                child: Text(
                  'Tiếp theo',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
