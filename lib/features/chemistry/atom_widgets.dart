import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'atomic_models.dart';

class AtomWidget extends StatefulWidget {
  const AtomWidget({
    super.key,
    required this.atom,
    required this.onPanDelta,
    required this.onSelect,
    required this.neutronCount,
    required this.isInvalid,
    this.charge = 0,
    this.isSelected = false,
  });

  final AtomNode atom;
  final ValueChanged<Offset> onPanDelta;
  final VoidCallback onSelect;
  final int neutronCount;
  final bool isInvalid;
  final int charge;
  final bool isSelected;

  @override
  State<AtomWidget> createState() => _AtomWidgetState();
}

class _AtomWidgetState extends State<AtomWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isSelected) _rotation.repeat();
  }

  @override
  void didUpdateWidget(covariant AtomWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelected == widget.isSelected) return;
    if (widget.isSelected) {
      _rotation.repeat();
    } else {
      _rotation.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shells = electronShells(widget.atom.element.number - widget.charge);
    final outerRadius = 25.0 + (shells.length - 1) * 14;
    final diameter = outerRadius * 2 + 36;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => widget.onSelect(),
      onPanUpdate: (details) => widget.onPanDelta(details.delta),
      child: SizedBox(
        width: diameter,
        height: diameter + 28,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            AnimatedBuilder(
              animation: _rotation,
              builder: (context, _) => RepaintBoundary(
                child: CustomPaint(
                  size: Size.square(diameter),
                  painter: _AtomPainter(
                    shells: shells,
                    phase: _rotation.value * math.pi * 2,
                    protons: widget.atom.element.protons,
                    neutrons: widget.neutronCount,
                  ),
                ),
              ),
            ),
            Positioned(
              top: outerRadius + 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF11202D),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isInvalid
                        ? const Color(0xFFFF6670)
                        : widget.isSelected
                        ? const Color(0xFF69F0E0)
                        : const Color(0xFF79DFF0).withValues(alpha: 0.8),
                    width: widget.isSelected || widget.isInvalid ? 2 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x5500D9FF), blurRadius: 15),
                  ],
                ),
                child: SizedBox(
                  width: 39,
                  height: 39,
                  child: Center(
                    child: Text(
                      widget.atom.element.symbol,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Text(
                _chargeText(),
                style: TextStyle(
                  color: widget.charge == 0
                      ? const Color(0xFFB8CBD7)
                      : widget.charge > 0
                      ? const Color(0xFFFF8B82)
                      : const Color(0xFF77C9FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _chargeText() {
    final charge = widget.charge;
    if (charge == 0) {
      return '${widget.atom.element.symbol}  e${widget.atom.element.number}';
    }
    return '${widget.atom.element.symbol}${charge.abs() == 1 ? '' : charge.abs()}${charge > 0 ? '+' : '−'}';
  }
}

class _AtomPainter extends CustomPainter {
  const _AtomPainter({
    required this.shells,
    required this.phase,
    required this.protons,
    required this.neutrons,
  });

  final List<int> shells;
  final double phase;
  final int protons;
  final int neutrons;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ringPaint = Paint()
      ..color = const Color(0xFF67D8E8).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final electronPaint = Paint()..color = const Color(0xFF72F5FF);
    for (var shell = 0; shell < shells.length; shell++) {
      final radius = 25.0 + shell * 14;
      canvas.drawCircle(center, radius, ringPaint);
      for (var index = 0; index < shells[shell]; index++) {
        final angle =
            phase * (shell.isEven ? 1 : -1) +
            index * math.pi * 2 / shells[shell] +
            shell * 0.37;
        canvas.drawCircle(
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
          3,
          electronPaint,
        );
      }
    }

    final nucleonCount = protons + neutrons;
    final protonPaint = Paint()..color = const Color(0xFFFF6767);
    final neutronPaint = Paint()..color = const Color(0xFFB3C0CC);
    for (var index = 0; index < nucleonCount; index++) {
      final angle = index * 2.399963;
      final radius = 16 * math.sqrt((index + 0.5) / nucleonCount);
      final proton = index < protons;
      canvas.drawCircle(
        center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
        2.15,
        proton ? protonPaint : neutronPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AtomPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.shells != shells ||
      oldDelegate.protons != protons ||
      oldDelegate.neutrons != neutrons;
}

class PeriodicTablePanel extends StatefulWidget {
  const PeriodicTablePanel({
    super.key,
    required this.onAddElement,
    required this.accent,
    this.width = 250,
  });

  final ValueChanged<ChemicalElement> onAddElement;
  final Color accent;
  final double width;

  @override
  State<PeriodicTablePanel> createState() => _PeriodicTablePanelState();
}

class _PeriodicTablePanelState extends State<PeriodicTablePanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = periodicElements.where((element) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          element.symbol.toLowerCase().contains(query) ||
          element.name.toLowerCase().contains(query) ||
          element.number.toString() == query;
    }).toList();
    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: const Color(0xFF111B26),
        border: Border(
          right: BorderSide(color: widget.accent.withValues(alpha: 0.22)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 9),
            child: Row(
              children: [
                Icon(Icons.grid_view_rounded, color: widget.accent, size: 17),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'PERIODIC TABLE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${matches.length}/118',
                  style: const TextStyle(color: Color(0xFF8298AA), fontSize: 9),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 16),
                hintText: 'Tìm nguyên tố',
                hintStyle: const TextStyle(
                  color: Color(0xFF8298AA),
                  fontSize: 11,
                ),
                filled: true,
                fillColor: const Color(0xFF0B131C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.9,
              ),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final element = matches[index];
                final color = _elementColor(element.kind);
                return Tooltip(
                  message:
                      '${element.name} (${element.symbol}) • Z=${element.number} • A=${element.massNumber}',
                  child: Draggable<ChemicalElement>(
                    data: element,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _ElementCell(element: element, color: color),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.28,
                      child: _ElementCell(element: element, color: color),
                    ),
                    child: _ElementCell(element: element, color: color),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              'Kéo nguyên tố vào canvas để tạo nguyên tử',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8298AA), fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Color _elementColor(ElementKind kind) => switch (kind) {
    ElementKind.metal => const Color(0xFFFFB95E),
    ElementKind.nonmetal => const Color(0xFF5EE3CE),
    ElementKind.metalloid => const Color(0xFFB697FF),
  };
}

class _ElementCell extends StatelessWidget {
  const _ElementCell({required this.element, required this.color});

  final ChemicalElement element;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.52)),
    ),
    child: Stack(
      children: [
        Positioned(
          left: 3,
          top: 2,
          child: Text(
            '${element.number}',
            style: const TextStyle(color: Color(0xFFA7B7C4), fontSize: 7),
          ),
        ),
        Center(
          child: Text(
            element.symbol,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}
