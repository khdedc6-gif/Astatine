import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'flashcard_models.dart';
import 'flashcard_service.dart';
import 'study_flip_mode.dart';
import 'study_mcq_mode.dart';
import 'study_typing_mode.dart';

class DeckDetailScreen extends StatefulWidget {
  const DeckDetailScreen({super.key, required this.deck});
  final FlashcardDeck deck;
  @override
  State<DeckDetailScreen> createState() => _State();
}

class _State extends State<DeckDetailScreen> {
  late FlashcardDeck _d;
  @override
  void initState() {
    super.initState();
    _d = widget.deck;
  }

  void _edit({Flashcard? card}) async {
    final f = TextEditingController(text: card?.front ?? '');
    final b = TextEditingController(text: card?.back ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(card == null ? 'Thêm' : 'Sửa', style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: f, decoration: const InputDecoration(labelText: 'Q')),
            TextField(controller: b, decoration: const InputDecoration(labelText: 'A')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (!mounted || ok != true || f.text.isEmpty || b.text.isEmpty) return;
    setState(() {
      if (card != null) {
        card.front = f.text;
        card.back = b.text;
      } else {
        _d.cards.add(Flashcard(id: DateTime.now().millisecondsSinceEpoch.toString(), front: f.text, back: b.text));
      }
    });
    await FlashcardService.saveDeck(_d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11111B),
      appBar: AppBar(title: Text(_d.title, style: GoogleFonts.outfit(color: Colors.white))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_d.description, style: GoogleFonts.outfit(color: Colors.white70)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () async {
                  final s = await FlashcardService.getSettings();
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => StudyFlipModeScreen(deck: _d, shuffle: s['shuffleMode'] ?? false, reverse: s['reverseCard'] ?? false)));
                  setState(() {});
                }, child: const Text('Lật'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: () async {
                  final s = await FlashcardService.getSettings();
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => StudyMcqModeScreen(deck: _d, shuffle: s['shuffleMode'] ?? false)));
                  setState(() {});
                }, child: const Text('Trắc nghiệm'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: () async {
                  final s = await FlashcardService.getSettings();
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => StudyTypingModeScreen(deck: _d, shuffle: s['shuffleMode'] ?? false)));
                  setState(() {});
                }, child: const Text('Gõ'))),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Thẻ (${_d.totalCards})', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ElevatedButton(onPressed: () => _edit(), child: const Text('Thêm')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _d.cards.length,
                itemBuilder: (context, i) {
                  final c = _d.cards[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF181825), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Q: ${c.front}', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('A: ${c.back}', style: GoogleFonts.outfit(color: Colors.white70)),
                          ],
                        )),
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _edit(card: c)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                          setState(() => _d.cards.removeAt(i));
                          await FlashcardService.saveDeck(_d);
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
