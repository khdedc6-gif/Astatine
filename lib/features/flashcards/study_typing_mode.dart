import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import 'flashcard_models.dart';
import 'flashcard_service.dart';

class StudyTypingModeScreen extends StatefulWidget {
  const StudyTypingModeScreen({
    super.key,
    required this.deck,
    required this.shuffle,
  });
  final FlashcardDeck deck;
  final bool shuffle;

  @override
  State<StudyTypingModeScreen> createState() => _StudyTypingModeScreenState();
}

class _StudyTypingModeScreenState extends State<StudyTypingModeScreen> {
  late List<Flashcard> _cards;
  int _index = 0;
  int _score = 0;
  final TextEditingController _ctrl = TextEditingController();
  bool _checked = false;
  bool _correct = false;

  @override
  void initState() {
    super.initState();
    _cards = List.from(widget.deck.cards);
    if (widget.shuffle) _cards.shuffle(Random());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _check() {
    if (_checked) return;
    final user = _ctrl.text.trim().toLowerCase();
    final ans = _cards[_index].back.trim().toLowerCase();
    final ok =
        user == ans || ans.contains(user) && user.length > (ans.length * 0.7);

    setState(() {
      _checked = true;
      _correct = ok;
      if (ok) {
        _score++;
        _cards[_index].difficulty = CardDifficulty.easy;
      } else {
        _cards[_index].difficulty = CardDifficulty.forgotten;
      }
    });
  }

  void _next() async {
    await FlashcardService.saveDeck(widget.deck);
    if (_index < _cards.length - 1) {
      setState(() {
        _index++;
        _ctrl.clear();
        _checked = false;
        _correct = false;
      });
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: Text(
            'Kết quả Nhập văn bản: $_score / ${_cards.length}',
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
        appBar: AppBar(title: const Text('Nhập đáp án')),
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
          'Nhập đáp án: ${widget.deck.title}',
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
            TextField(
              controller: _ctrl,
              enabled: !_checked,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nhập câu trả lời...',
                hintStyle: GoogleFonts.outfit(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF181825),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (_) => _checked ? _next() : _check(),
            ),
            const Gap(16),
            if (_checked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _correct
                      ? const Color(0xFFA6E3A1).withValues(alpha: 0.2)
                      : const Color(0xFFF38BA8).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _correct ? 'Chính xác!' : 'Sai. Đáp án: "${card.back}"',
                  style: GoogleFonts.outfit(
                    color: _correct
                        ? const Color(0xFFA6E3A1)
                        : const Color(0xFFF38BA8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF89B4FA),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _checked ? _next : _check,
              child: Text(
                _checked ? 'Tiếp theo' : 'Kiểm tra',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
