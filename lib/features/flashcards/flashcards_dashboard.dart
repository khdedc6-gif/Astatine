import 'package:flutter/material.dart';

import 'package:astatine_dashboard/core/ui/loading_skeleton.dart';

import 'flashcard_models.dart';
import 'flashcard_service.dart';
import 'deck_detail_screen.dart';

class FlashcardsDashboardScreen extends StatefulWidget {
  const FlashcardsDashboardScreen({super.key});

  @override
  State<FlashcardsDashboardScreen> createState() =>
      _FlashcardsDashboardScreenState();
}

class _FlashcardsDashboardScreenState extends State<FlashcardsDashboardScreen> {
  List<FlashcardDeck> _decks = [];
  bool _loading = true;
  int _section = 1;
  String _query = '';

  AstatineFlashcardColors get _colors =>
      AstatineFlashcardColors.fromTheme(Theme.of(context));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final decks = await FlashcardService.getDecks();
    if (!mounted) return;
    setState(() {
      _decks = decks;
      _loading = false;
    });
  }

  Future<void> _showCreate() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final cardsController = TextEditingController();
    final created = await showDialog<FlashcardDeck>(
      context: context,
      builder: (context) => _CreateDeckDialog(
        titleController: titleController,
        descriptionController: descriptionController,
        cardsController: cardsController,
      ),
    );
    titleController.dispose();
    descriptionController.dispose();
    cardsController.dispose();
    if (created == null) return;
    await FlashcardService.saveDeck(created);
    await _load();
  }

  Future<void> _deleteDeck(FlashcardDeck deck) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bộ thẻ?'),
        content: Text('“${deck.title}” sẽ bị xóa khỏi StudyExtens.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _colors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await FlashcardService.deleteDeck(deck.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        children: [
          _StudySidebar(
            section: _section,
            colors: colors,
            onSectionChanged: (section) => setState(() => _section = section),
          ),
          Expanded(
            child: _section == 1
                ? _buildFlashcards(colors)
                : _StudyPlaceholder(section: _section, colors: colors),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcards(AstatineFlashcardColors colors) {
    final visibleDecks = _decks
        .where(
          (deck) =>
              deck.title.toLowerCase().contains(_query.toLowerCase()) ||
              deck.description.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 34, 40, 0),
            child: _PageHeader(
              colors: colors,
              query: _query,
              onQueryChanged: (value) => setState(() => _query = value),
              onCreate: _showCreate,
            ),
          ),
        ),
        if (_loading)
          const SliverToBoxAdapter(child: FlashcardGridSkeleton())
        else if (visibleDecks.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyDeckState(
              colors: colors,
              hasSearch: _query.isNotEmpty,
              onCreate: _showCreate,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(40, 30, 40, 40),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final deck = visibleDecks[index];
                return _DeckTile(
                  deck: deck,
                  colors: colors,
                  onOpen: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeckDetailScreen(deck: deck),
                      ),
                    );
                    _load();
                  },
                  onDelete: () => _deleteDeck(deck),
                );
              }, childCount: visibleDecks.length),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 220,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
              ),
            ),
          ),
      ],
    );
  }
}

class _StudySidebar extends StatelessWidget {
  const _StudySidebar({
    required this.section,
    required this.colors,
    required this.onSectionChanged,
  });

  final int section;
  final AstatineFlashcardColors colors;
  final ValueChanged<int> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 238,
      color: colors.sidebar,
      padding: const EdgeInsets.fromLTRB(18, 24, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 38),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.auto_awesome, color: colors.onAccent),
                ),
                const SizedBox(width: 10),
                Text(
                  'StudyExtens',
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          _SidebarItem(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: section == 0,
            colors: colors,
            onTap: () => onSectionChanged(0),
          ),
          _SidebarItem(
            icon: Icons.style_outlined,
            label: 'Flashcards',
            selected: section == 1,
            colors: colors,
            onTap: () => onSectionChanged(1),
          ),
          const Spacer(),
          _SidebarItem(
            icon: Icons.settings_outlined,
            label: 'Cài đặt',
            selected: section == 2,
            colors: colors,
            onTap: () => onSectionChanged(2),
          ),
          const SizedBox(height: 8),
          Text(
            'HỌC TẬP THÔNG MINH',
            style: TextStyle(
              color: colors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tạo bộ thẻ của riêng bạn\nvà học theo nhịp của mình.',
            style: TextStyle(color: colors.muted, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final AstatineFlashcardColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: selected,
        selectedTileColor: colors.accent.withValues(alpha: 0.14),
        leading: Icon(
          icon,
          size: 20,
          color: selected ? colors.accent : colors.muted,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? colors.foreground : colors.muted,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.colors,
    required this.query,
    required this.onQueryChanged,
    required this.onCreate,
  });

  final AstatineFlashcardColors colors;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flashcards',
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ôn tập chủ động. Nhớ lâu hơn.',
                    style: TextStyle(color: colors.muted, fontSize: 14),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tạo bộ thẻ'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        TextField(
          onChanged: onQueryChanged,
          style: TextStyle(color: colors.foreground, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Tìm bộ thẻ...',
            hintStyle: TextStyle(color: colors.muted),
            prefixIcon: Icon(Icons.search, color: colors.muted, size: 20),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyDeckState extends StatelessWidget {
  const _EmptyDeckState({
    required this.colors,
    required this.hasSearch,
    required this.onCreate,
  });

  final AstatineFlashcardColors colors;
  final bool hasSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasSearch ? Icons.search_off : Icons.style_outlined,
                size: 48,
                color: colors.accent,
              ),
              const SizedBox(height: 18),
              Text(
                hasSearch ? 'Không tìm thấy bộ thẻ' : 'Bắt đầu bằng một bộ thẻ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                hasSearch ? 'Thử từ khóa khác hoặc tạo một bộ thẻ mới.' : 'Tạo bộ thẻ đầu tiên để biến những ghi chú của bạn thành một phiên học.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: Text(
                  hasSearch ? 'Tạo bộ thẻ mới' : 'Tạo bộ thẻ đầu tiên',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({
    required this.deck,
    required this.colors,
    required this.onOpen,
    required this.onDelete,
  });

  final FlashcardDeck deck;
  final AstatineFlashcardColors colors;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = deck.totalCards == 0
        ? 0.0
        : deck.masteredCards / deck.totalCards;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deck.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: colors.muted),
                    onSelected: (_) => onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('Xóa bộ thẻ')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  deck.description.isEmpty
                      ? 'Chưa có mô tả cho bộ thẻ này.'
                      : deck.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.muted, height: 1.45),
                ),
              ),
              Text(
                '${deck.totalCards} thẻ',
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation(colors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyPlaceholder extends StatelessWidget {
  const _StudyPlaceholder({required this.section, required this.colors});

  final int section;
  final AstatineFlashcardColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        section == 0 ? 'Home sẽ sớm có mặt.' : 'Cài đặt StudyExtens',
        style: TextStyle(color: colors.muted, fontSize: 16),
      ),
    );
  }
}

class _CreateDeckDialog extends StatelessWidget {
  const _CreateDeckDialog({
    required this.titleController,
    required this.descriptionController,
    required this.cardsController,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController cardsController;

  @override
  Widget build(BuildContext context) {
    final colors = AstatineFlashcardColors.fromTheme(Theme.of(context));
    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        'Tạo bộ thẻ mới',
        style: TextStyle(color: colors.foreground, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tên bộ thẻ'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mô tả (không bắt buộc)',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Thêm thẻ bằng bảng văn bản',
                style: TextStyle(
                  color: colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Mỗi dòng một thẻ: Câu hỏi | Trả lời | 1\\n'
                'Mode 1 = trắc nghiệm · Mode 2 = gõ chữ',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cardsController,
                minLines: 7,
                maxLines: 12,
                style: TextStyle(
                  color: colors.foreground,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: 'Thủ đô Việt Nam | Hà Nội | 1\\n2 + 2 = ? | 4 | 2',
                  hintStyle: TextStyle(color: colors.muted),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: colors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (titleController.text.trim().isEmpty) return;
            final deck = cardsController.text.trim().isEmpty
                ? FlashcardDeck(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    cards: [],
                    createdAt: DateTime.now(),
                  )
                : FlashcardService.importFromBulkText(
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    rawText: cardsController.text,
                  );
            Navigator.pop(context, deck);
          },
          child: const Text('Tạo bộ thẻ'),
        ),
      ],
    );
  }
}

class AstatineFlashcardColors {
  const AstatineFlashcardColors({
    required this.background,
    required this.sidebar,
    required this.surface,
    required this.border,
    required this.foreground,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.danger,
  });

  final Color background;
  final Color sidebar;
  final Color surface;
  final Color border;
  final Color foreground;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color danger;

  factory AstatineFlashcardColors.fromTheme(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return AstatineFlashcardColors(
      background: colorScheme.surface,
      sidebar: Color.alphaBlend(
        colorScheme.onSurface.withValues(alpha: 0.035),
        colorScheme.surface,
      ),
      surface: Color.alphaBlend(
        colorScheme.onSurface.withValues(alpha: 0.065),
        colorScheme.surface,
      ),
      border: colorScheme.outline.withValues(alpha: 0.32),
      foreground: colorScheme.onSurface,
      muted: colorScheme.onSurfaceVariant,
      accent: colorScheme.primary,
      onAccent: colorScheme.onPrimary,
      danger: colorScheme.error,
    );
  }
}
