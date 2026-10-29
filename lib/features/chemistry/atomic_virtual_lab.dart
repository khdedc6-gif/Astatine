import 'package:flutter/material.dart';

import 'package:astatine_dashboard/core/ui/glide_select.dart';

import 'atomic_canvas.dart';
import 'atom_widgets.dart';
import 'atomic_reaction_logic.dart';

class _AtomicSkin {
  const _AtomicSkin(this.name, this.nameVi, this.background, this.accent);
  final String name;
  final String nameVi;
  final Color background;
  final Color accent;
}

class AtomicVirtualLabScreen extends StatefulWidget {
  const AtomicVirtualLabScreen({
    super.key,
    required this.isVietnamese,
    this.languageToggle,
    this.onClose,
  });

  final bool isVietnamese;
  final Widget? languageToggle;
  final VoidCallback? onClose;

  @override
  State<AtomicVirtualLabScreen> createState() => _AtomicVirtualLabScreenState();
}

class _AtomicVirtualLabScreenState extends State<AtomicVirtualLabScreen> {
  static const _skins = <_AtomicSkin>[
    _AtomicSkin('Reactor', 'Lò phản ứng', Color(0xFF0F151E), Color(0xFF44E5F2)),
    _AtomicSkin('Aurora', 'Cực quang', Color(0xFF101A19), Color(0xFF72E0B2)),
    _AtomicSkin('Solar', 'Mặt trời', Color(0xFF1C1712), Color(0xFFFFC15C)),
    _AtomicSkin(
      'Containment',
      'Cảnh báo',
      Color(0xFF1B1317),
      Color(0xFFFF7184),
    ),
  ];
  final _canvasKey = GlobalKey<AtomicCanvasState>();
  final _reactionList = ValueNotifier<List<AtomicReaction>>(const []);
  int _skinIndex = 0;
  int _neutronCount = 0;

  @override
  void dispose() {
    _reactionList.dispose();
    super.dispose();
  }

  _AtomicSkin get _skin => _skins[_skinIndex];
  String _text(String english, String vietnamese) =>
      widget.isVietnamese ? vietnamese : english;

  void _addPreset(int index) {
    const presets = <List<(String, Offset)>>[
      [
        ('H', Offset(560, 500)),
        ('H', Offset(820, 500)),
        ('O', Offset(690, 500)),
      ],
      [('Na', Offset(610, 500)), ('Cl', Offset(750, 500))],
      [
        ('O', Offset(550, 500)),
        ('C', Offset(690, 500)),
        ('O', Offset(830, 500)),
      ],
      [],
    ];
    _canvasKey.currentState?.addPresetAtoms(presets[index]);
  }

  void _fireNeutron() {
    if (_canvasKey.currentState?.addNeutronToSelectedAtom() == true) {
      setState(() => _neutronCount++);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _skin.background,
    body: SafeArea(
      child: Column(
        children: [
          _header(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth < 760 ? 204.0 : 250.0;
                return Row(
                  children: [
                    SizedBox(
                      width: tableWidth,
                      child: PeriodicTablePanel(
                        width: tableWidth,
                        accent: _skin.accent,
                        onAddElement: (element) => _canvasKey.currentState
                            ?.addElement(element, const Offset(690, 500)),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _quickActions(),
                          Expanded(
                            child: AtomicCanvas(
                              key: _canvasKey,
                              accent: _skin.accent,
                              onReactionsChanged: (reactions) =>
                                  _reactionList.value = reactions,
                            ),
                          ),
                          _equationBar(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _header() => Container(
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: _skin.background,
      border: Border(
        bottom: BorderSide(color: _skin.accent.withValues(alpha: 0.2)),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          key: const Key('atomic-lab-back'),
          tooltip: _text('Back to laboratories', 'Quay lại phòng thí nghiệm'),
          onPressed: widget.onClose,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        const SizedBox(width: 5),
        Icon(Icons.blur_circular_rounded, color: _skin.accent, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text('Atomic Model Lab', 'Mô hình nguyên tử'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'STEM WORKSPACE  /  ATOM & BOND',
                style: TextStyle(
                  color: Color(0xFF91A6B8),
                  fontSize: 8,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        if (widget.languageToggle != null) widget.languageToggle!,
        const SizedBox(width: 6),
        _skinPicker(),
        const SizedBox(width: 7),
        Icon(Icons.circle, size: 7, color: _skin.accent),
        const SizedBox(width: 5),
        Text(
          _text('LIVE', 'TRỰC TIẾP'),
          style: TextStyle(
            color: _skin.accent,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _skinPicker() => PopupMenuButton<int>(
    key: const Key('atomic-skin-picker'),
    tooltip: _text('Change lab theme', 'Đổi giao diện phòng lab'),
    initialValue: _skinIndex,
    onSelected: (value) => setState(() => _skinIndex = value),
    color: const Color(0xFF1A2531),
    itemBuilder: (context) => [
      for (var index = 0; index < _skins.length; index++)
        PopupMenuItem(
          value: index,
          child: Row(
            children: [
              Icon(Icons.circle, color: _skins[index].accent, size: 11),
              const SizedBox(width: 8),
              GlideSelect(
                selected: index == _skinIndex,
                child: Text(
                  _text(_skins[index].name, _skins[index].nameVi),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF17232E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _skin.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, color: _skin.accent, size: 15),
          const SizedBox(width: 5),
          Text(
            _text(_skin.name, _skin.nameVi),
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          const Icon(Icons.expand_more, color: Colors.white70, size: 15),
        ],
      ),
    ),
  );

  Widget _quickActions() => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF111B25),
      border: Border(
        bottom: BorderSide(color: _skin.accent.withValues(alpha: 0.15)),
      ),
    ),
    child: Row(
      children: [
        Text(
          _text('QUICK START', 'BẮT ĐẦU NHANH'),
          style: TextStyle(
            color: _skin.accent,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(width: 8),
        for (var index = 0; index < 4; index++)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: _presetButton(index),
          ),
        const Spacer(),
        IconButton(
          key: const Key('fire-neutron'),
          tooltip: _text('Fire a neutron', 'Bắn neutron'),
          visualDensity: VisualDensity.compact,
          onPressed: _fireNeutron,
          icon: Icon(
            Icons.brightness_7_outlined,
            color: _skin.accent,
            size: 17,
          ),
        ),
        Text(
          '$_neutronCount',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    ),
  );

  Widget _presetButton(int index) {
    const english = ['H₂O', 'NaCl', 'CO₂', 'Clear'];
    const vietnamese = ['H₂O', 'NaCl', 'CO₂', 'Xóa'];
    return OutlinedButton(
      key: Key('atomic-preset-$index'),
      onPressed: () => index == 3
          ? _canvasKey.currentState?.clearAtoms()
          : _addPreset(index),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD7E4EC),
        side: BorderSide(color: _skin.accent.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 28),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        _text(english[index], vietnamese[index]),
        style: const TextStyle(fontSize: 9),
      ),
    );
  }

  Widget _equationBar() => ValueListenableBuilder<List<AtomicReaction>>(
    valueListenable: _reactionList,
    builder: (context, reactions, _) {
      final equationText = reactions.isEmpty
          ? _text(
              'Move atoms close to form a cluster.',
              'Đưa các nguyên tử lại gần để tạo cụm.',
            )
          : reactions.map((reaction) => reaction.equation).join('     |     ');
      final issues = reactions
          .map((reaction) => reaction.message)
          .where((message) => message.isNotEmpty)
          .toSet()
          .toList();
      final isInvalid = reactions.any((reaction) => !reaction.isValid);
      return Container(
        constraints: const BoxConstraints(minHeight: 56, maxHeight: 112),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF111B25),
          border: Border(
            top: BorderSide(color: _skin.accent.withValues(alpha: 0.24)),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.functions_rounded, color: _skin.accent, size: 18),
                const SizedBox(width: 10),
                Text(
                  _text('EQUATION', 'PHƯƠNG TRÌNH'),
                  style: TextStyle(
                    color: _skin.accent,
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      equationText,
                      maxLines: 1,
                      style: TextStyle(
                        color: reactions.isEmpty
                            ? const Color(0xFF8298AA)
                            : Colors.white,
                        fontSize: reactions.isEmpty ? 10 : 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (issues.isNotEmpty) ...[
              const SizedBox(height: 5),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isInvalid
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline,
                      color: isInvalid
                          ? const Color(0xFFFF6870)
                          : const Color(0xFF78CBE1),
                      size: 14,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        issues.join('  •  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isInvalid
                              ? const Color(0xFFFF8990)
                              : const Color(0xFF9CB1BF),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
