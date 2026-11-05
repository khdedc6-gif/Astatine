import 'package:flutter/material.dart';

import 'flashcard_models.dart';
import 'flashcard_service.dart';
import 'flashcards_dashboard.dart';
import 'study_flip_mode.dart';
import 'study_mcq_mode.dart';
import 'study_typing_mode.dart';

class DeckDetailScreen extends StatefulWidget {
  const DeckDetailScreen({super.key, required this.deck});

  final FlashcardDeck deck;

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  late FlashcardDeck _deck;

  AstatineFlashcardColors get _colors =>
      AstatineFlashcardColors.fromTheme(Theme.of(context));

  @override
  void initState() {
    super.initState();
    _deck = widget.deck;
  }

  Future<void> _addCard({Flashcard? editing}) async {
    final frontController = TextEditingController(text: editing?.front ?? '');
    final backController = TextEditingController(text: editing?.back ?? '');
    final hintController = TextEditingController(text: editing?.hint ?? '');
    var mode = editing?.mode ?? 1;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(editing == null ? 'Thêm thẻ' : 'Chỉnh sửa thẻ'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: frontController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Câu hỏi'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: backController,
                  decoration: const InputDecoration(labelText: 'Trả lời'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hintController,
                  decoration: const InputDecoration(
                    labelText: 'Gợi ý (không bắt buộc)',
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Trắc nghiệm')),
                    ButtonSegment(value: 2, label: Text('Gõ chữ')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) =>
                      setDialogState(() => mode = value.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu thẻ'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || saved != true) return;
    if (frontController.text.trim().isEmpty ||
        backController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      if (editing == null) {
        _deck.cards.add(
          Flashcard(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            front: frontController.text.trim(),
            back: backController.text.trim(),
            hint: hintController.text.trim().isEmpty
                ? null
                : hintController.text.trim(),
            mode: mode,
          ),
        );
      } else {
        editing.front = frontController.text.trim();
        editing.back = backController.text.trim();
        editing.hint = hintController.text.trim().isEmpty
            ? null
            : hintController.text.trim();
        editing.mode = mode;
      }
    });
    await FlashcardService.saveDeck(_deck);
    frontController.dispose();
    backController.dispose();
    hintController.dispose();
  }

  Future<void> _startStudy(int mode) async {
    final settings = await FlashcardService.getSettings();
    if (!mounted) return;
    final page = switch (mode) {
      1 => StudyMcqModeScreen(
        deck: _deck,
        shuffle: settings['shuffleMode'] ?? false,
      ),
      2 => StudyTypingModeScreen(
        deck: _deck,
        shuffle: settings['shuffleMode'] ?? false,
      ),
      _ => StudyFlipModeScreen(
        deck: _deck,
        shuffle: settings['shuffleMode'] ?? false,
        reverse: settings['reverseCard'] ?? false,
      ),
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        title: Text(_deck.title),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 20, 40, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _deck.description.isEmpty
                        ? 'Chưa có mô tả'
                        : _deck.description,
                    style: TextStyle(color: colors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _deck.cards.isEmpty
                            ? null
                            : () => _startStudy(0),
                        icon: const Icon(Icons.flip, size: 18),
                        label: const Text('Ôn tập'),
                      ),
                      OutlinedButton(
                        onPressed: _deck.cards.isEmpty
                            ? null
                            : () => _startStudy(1),
                        child: const Text('Trắc nghiệm'),
                      ),
                      OutlinedButton(
                        onPressed: _deck.cards.isEmpty
                            ? null
                            : () => _startStudy(2),
                        child: const Text('Gõ chữ'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Thẻ trong bộ này · ${_deck.totalCards}',
                          style: TextStyle(
                            color: colors.foreground,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _addCard(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Thêm thẻ'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          if (_deck.cards.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyCards(colors: colors, onAdd: () => _addCard()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
              sliver: SliverList.builder(
                itemCount: _deck.cards.length,
                itemBuilder: (context, index) {
                  final card = _deck.cards[index];
                  return _CardRow(
                    card: card,
                    index: index + 1,
                    colors: colors,
                    onEdit: () => _addCard(editing: card),
                    onDelete: () async {
                      setState(() => _deck.cards.removeAt(index));
                      await FlashcardService.saveDeck(_deck);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards({required this.colors, required this.onAdd});

  final AstatineFlashcardColors colors;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.note_add_outlined, size: 42, color: colors.accent),
        const SizedBox(height: 14),
        Text(
          'Bộ thẻ đang trống',
          style: TextStyle(
            color: colors.foreground,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Thêm thẻ thủ công hoặc quay lại tạo bằng bảng văn bản.',
          style: TextStyle(color: colors.muted),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Thêm thẻ đầu tiên'),
        ),
      ],
    ),
  );
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.index,
    required this.colors,
    required this.onEdit,
    required this.onDelete,
  });

  final Flashcard card;
  final int index;
  final AstatineFlashcardColors colors;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$index',
              style: TextStyle(
                color: colors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.front,
                  style: TextStyle(
                    color: colors.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(card.back, style: TextStyle(color: colors.muted)),
              ],
            ),
          ),
          Chip(
            label: Text(card.mode == 1 ? 'Trắc nghiệm' : 'Gõ chữ'),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: colors.danger),
          ),
        ],
      ),
    );
  }
}
