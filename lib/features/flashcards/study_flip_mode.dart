import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import 'flashcard_models.dart';
import 'flashcard_service.dart';

class StudyFlipModeScreen extends StatefulWidget {
  const StudyFlipModeScreen({
    super.key,
    required this.deck,
    required this.shuffle,
    required this.reverse,
  });
  final FlashcardDeck deck;
  final bool shuffle;
  final bool reverse;

  @override
  State<StudyFlipModeScreen> createState() => _StudyFlipModeScreenState();
}

class _StudyFlipModeScreenState extends State<StudyFlipModeScreen>
    with SingleTickerProviderStateMixin {
  late List<Flashcard> _cards;
  int _index = 0;
  bool _flipped = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _cards = List.from(widget.deck.cards);
    if (widget.shuffle) _cards.shuffle(Random());
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _anim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipped) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
    setState(() => _flipped = !_flipped);
  }

  void _rate(CardDifficulty diff) async {
    _cards[_index].difficulty = diff;
    _cards[_index].reviewCount++;
    await FlashcardService.saveDeck(widget.deck);

    if (_index < _cards.length - 1) {
      if (_flipped) {
        _ctrl.reverse();
        _flipped = false;
      }
      setState(() => _index++);
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: Text(
            'Hoàn thành!',
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
        appBar: AppBar(title: const Text('Lật thẻ 3D')),
        body: const Center(
          child: Text('Không có thẻ.', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    final card = _cards[_index];
    final front = widget.reverse ? card.back : card.front;
    final back = widget.reverse ? card.front : card.back;

    return Scaffold(
      backgroundColor: const Color(0xFF11111B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181825),
        title: Text(
          'Lật thẻ 3D: ${widget.deck.title}',
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
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _flip,
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, child) {
                      final angle = _anim.value * pi;
                      return Container(
                        width: 450,
                        height: 280,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: angle < pi / 2
                              ? const Color(0xFF181825)
                              : const Color(0xFF313244),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF45475A)),
                        ),
                        child: Center(
                          child: Text(
                            angle < pi / 2 ? front : back,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const Gap(16),
            if (_flipped)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF38BA8),
                    ),
                    onPressed: () => _rate(CardDifficulty.forgotten),
                    child: const Text('Quên'),
                  ),
                  const Gap(12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFAB387),
                    ),
                    onPressed: () => _rate(CardDifficulty.memorized),
                    child: const Text('Tạm nhớ'),
                  ),
                  const Gap(12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA6E3A1),
                    ),
                    onPressed: () => _rate(CardDifficulty.easy),
                    child: const Text('Rất dễ'),
                  ),
                ],
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF89B4FA),
                  foregroundColor: Colors.black,
                ),
                onPressed: _flip,
                child: const Text('Lật xem Đáp án'),
              ),
          ],
        ),
      ),
    );
  }
}
