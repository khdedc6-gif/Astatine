import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'atomic_models.dart';
import 'atom_widgets.dart';
import 'atomic_reaction_logic.dart';

class AtomicCanvas extends StatefulWidget {
  const AtomicCanvas({
    super.key,
    required this.accent,
    required this.onReactionsChanged,
  });

  final Color accent;
  final ValueChanged<List<AtomicReaction>> onReactionsChanged;

  @override
  AtomicCanvasState createState() => AtomicCanvasState();
}

class AtomicCanvasState extends State<AtomicCanvas>
    with SingleTickerProviderStateMixin {
  static const _canvasSize = Size(1500, 1000);
  final TransformationController _transform = TransformationController();
  final GlobalKey _surfaceKey = GlobalKey();
  static const _engine = UniversalChemicalClusterEngine();
  final List<AtomNode> _atoms = [];
  final Map<String, ValueNotifier<Offset>> _positions = {};
  final Map<String, ValueNotifier<int>> _charges = {};
  final Map<String, ValueNotifier<int>> _neutronRevisions = {};
  final Map<String, ValueNotifier<bool>> _invalidStates = {};
  final ValueNotifier<List<AtomBond>> _bonds = ValueNotifier(const []);
  final ValueNotifier<Set<String>> _invalidAtomIds = ValueNotifier(const {});
  final ValueNotifier<List<PolyatomicGroupInstance>> _packages = ValueNotifier(
    const [],
  );
  final Set<String> _packagedGroupKeys = {};
  late final AnimationController _packagePulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  int _nextId = 0;
  String? _selectedId;

  @override
  void dispose() {
    _transform.dispose();
    _bonds.dispose();
    _invalidAtomIds.dispose();
    _packages.dispose();
    _packagePulse.dispose();
    for (final position in _positions.values) {
      position.dispose();
    }
    for (final charge in _charges.values) {
      charge.dispose();
    }
    for (final revision in _neutronRevisions.values) {
      revision.dispose();
    }
    for (final invalidState in _invalidStates.values) {
      invalidState.dispose();
    }
    super.dispose();
  }

  void _addAtom(ChemicalElement element, Offset position) {
    final atom = AtomNode(
      id: 'atom-${_nextId++}',
      element: element,
      x: position.dx.clamp(90, _canvasSize.width - 90).toDouble(),
      y: position.dy.clamp(90, _canvasSize.height - 90).toDouble(),
    );
    _atoms.add(atom);
    _positions[atom.id] = ValueNotifier(Offset(atom.x, atom.y));
    _charges[atom.id] = ValueNotifier(0);
    _neutronRevisions[atom.id] = ValueNotifier(0);
    _invalidStates[atom.id] = ValueNotifier(false);
  }

  void addElement(ChemicalElement element, Offset position) {
    setState(() {
      _addAtom(element, position);
      _selectedId = _atoms.last.id;
      _recomputeBonds();
    });
  }

  void addPresetAtoms(List<(String, Offset)> elements) {
    setState(() {
      for (final position in _positions.values) {
        position.dispose();
      }
      for (final charge in _charges.values) {
        charge.dispose();
      }
      for (final revision in _neutronRevisions.values) {
        revision.dispose();
      }
      for (final invalidState in _invalidStates.values) {
        invalidState.dispose();
      }
      _positions.clear();
      _charges.clear();
      _neutronRevisions.clear();
      _invalidStates.clear();
      _atoms.clear();
      _packages.value = const [];
      _packagedGroupKeys.clear();
      for (final (symbol, position) in elements) {
        final element = elementBySymbol(symbol);
        if (element == null) continue;
        _addAtom(element, position);
      }
      _selectedId = _atoms.isEmpty ? null : _atoms.first.id;
      _recomputeBonds();
    });
  }

  void clearAtoms() {
    setState(() {
      for (final position in _positions.values) {
        position.dispose();
      }
      for (final charge in _charges.values) {
        charge.dispose();
      }
      for (final revision in _neutronRevisions.values) {
        revision.dispose();
      }
      for (final invalidState in _invalidStates.values) {
        invalidState.dispose();
      }
      _positions.clear();
      _charges.clear();
      _neutronRevisions.clear();
      _invalidStates.clear();
      _atoms.clear();
      _packages.value = const [];
      _packagedGroupKeys.clear();
      _bonds.value = const [];
      _invalidAtomIds.value = const {};
      _selectedId = null;
    });
    widget.onReactionsChanged(const []);
  }

  bool addNeutronToSelectedAtom() {
    final atomId = _selectedId;
    if (atomId == null) return false;
    final atom = _atoms.where((item) => item.id == atomId).firstOrNull;
    if (atom == null) return false;
    atom.neutrons++;
    _neutronRevisions[atomId]?.value++;
    return true;
  }

  void _recomputeBonds() {
    var bonds = _engine.buildGraph(_atoms);
    var reactions = _engine.analyze(_atoms, bonds);
    final groups =
        reactions.expand((reaction) => reaction.polyatomicGroups).toList()
          ..sort(
            (first, second) =>
                second.atomIds.length.compareTo(first.atomIds.length),
          );
    var didLayout = false;
    final arrangedAtomIds = <String>{};
    for (final group in groups) {
      if (_packagedGroupKeys.add(group.packageKey)) {
        _arrangePolyatomicGroup(group, arrangedAtomIds);
        arrangedAtomIds.addAll(group.atomIds);
        didLayout = true;
        _packagePulse.forward(from: 0).then((_) {
          if (mounted) _packagePulse.reverse();
        });
      }
    }
    if (didLayout) {
      bonds = _engine.buildGraph(_atoms);
      reactions = _engine.analyze(_atoms, bonds);
    }
    _packages.value = reactions
        .expand((reaction) => reaction.polyatomicGroups)
        .toList();
    _bonds.value = bonds;
    final ionicBondCounts = <String, int>{};
    for (final bond in bonds.where((bond) => bond.kind == BondKind.ionic)) {
      ionicBondCounts.update(
        bond.firstId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      ionicBondCounts.update(
        bond.secondId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    for (final atom in _atoms) {
      _charges[atom.id]?.value = _chargeFor(
        atom,
        ionicBondCounts[atom.id] ?? 0,
      );
    }
    final invalidIds = {
      for (final reaction in reactions)
        if (!reaction.isValid) ...reaction.atomIds,
    };
    _invalidAtomIds.value = invalidIds;
    for (final atom in _atoms) {
      _invalidStates[atom.id]?.value = invalidIds.contains(atom.id);
    }
    widget.onReactionsChanged(reactions);
  }

  void _arrangePolyatomicGroup(
    PolyatomicGroupInstance group,
    Set<String> alreadyArranged,
  ) {
    final center = _atoms.where((atom) => atom.id == group.centralAtomId);
    if (center.isEmpty) return;
    final centerAtom = center.first;
    final peripheral = group.peripheralAtomIds
        .map((id) => _atoms.where((atom) => atom.id == id).firstOrNull)
        .whereType<AtomNode>()
        .toList();
    final count = peripheral.length;
    if (count == 0) return;
    final definition = group.definition;
    final radius = switch (definition.geometry) {
      MolecularGeometry.linear => count == 1 ? 90.0 : 76.0,
      MolecularGeometry.trigonalPlanar => 90.0,
      MolecularGeometry.tetrahedral => 110.0,
      MolecularGeometry.trigonalBipyramidal => 115.0,
      MolecularGeometry.octahedral => 110.0,
    };
    final angles = switch (definition.geometry) {
      MolecularGeometry.linear =>
        count == 1 ? const [-math.pi / 2] : const [0.0, math.pi],
      MolecularGeometry.trigonalPlanar => List<double>.generate(
        count,
        (index) => -math.pi / 2 + index * 2 * math.pi / count,
      ),
      MolecularGeometry.tetrahedral => const [
        -math.pi / 4,
        math.pi / 4,
        3 * math.pi / 4,
        -3 * math.pi / 4,
      ],
      MolecularGeometry.trigonalBipyramidal => const [
        -math.pi / 2,
        math.pi / 2,
        0.0,
        math.pi * 2 / 3,
        math.pi * 4 / 3,
      ],
      MolecularGeometry.octahedral => const [
        0.0,
        math.pi,
        math.pi / 2,
        -math.pi / 2,
        math.pi / 4,
        -3 * math.pi / 4,
      ],
    };
    for (var index = 0; index < count; index++) {
      final atom = peripheral[index];
      if (alreadyArranged.contains(atom.id)) continue;
      atom
        ..x = (centerAtom.x + radius * math.cos(angles[index]))
            .clamp(40, _canvasSize.width - 40)
            .toDouble()
        ..y = (centerAtom.y + radius * math.sin(angles[index]))
            .clamp(40, _canvasSize.height - 40)
            .toDouble();
      _positions[atom.id]?.value = Offset(atom.x, atom.y);
    }
  }

  void _acceptElement(ChemicalElement element, Offset globalPosition) {
    final renderObject =
        _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderObject == null) return;
    final localPosition = renderObject.globalToLocal(globalPosition);
    addElement(element, localPosition);
  }

  void _moveAtom(AtomNode atom, Offset screenDelta) {
    final scale = _transform.value.getMaxScaleOnAxis();
    final delta = screenDelta / scale;
    final movingIds = <String>{atom.id};
    for (final group in _packages.value) {
      if (group.centralAtomId == atom.id) {
        movingIds.addAll(group.atomIds);
      }
    }
    for (final member in _atoms.where(
      (candidate) => movingIds.contains(candidate.id),
    )) {
      member
        ..x = (member.x + delta.dx).clamp(40, _canvasSize.width - 40).toDouble()
        ..y = (member.y + delta.dy)
            .clamp(40, _canvasSize.height - 40)
            .toDouble();
      _positions[member.id]?.value = Offset(member.x, member.y);
    }
    _recomputeBonds();
  }

  int _chargeFor(AtomNode atom, int ionicBonds) {
    if (ionicBonds == 0) return 0;
    final electrons = atom.element.valenceElectrons;
    final isDonor = atom.element.kind == ElementKind.metal;
    final magnitude = isDonor
        ? electrons.clamp(1, 3)
        : atom.element.valencies.first.clamp(1, 3);
    return (isDonor ? magnitude : -magnitude) * ionicBonds;
  }

  @override
  Widget build(BuildContext context) => DragTarget<ChemicalElement>(
    onWillAcceptWithDetails: (_) => true,
    onAcceptWithDetails: (details) =>
        _acceptElement(details.data, details.offset),
    builder: (context, candidates, rejected) {
      final atoms = _atoms;
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              transformationController: _transform,
              constrained: false,
              minScale: 0.45,
              maxScale: 2.6,
              boundaryMargin: const EdgeInsets.all(420),
              child: SizedBox(
                key: _surfaceKey,
                width: _canvasSize.width,
                height: _canvasSize.height,
                child: DragTarget<ChemicalElement>(
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: (details) =>
                      _acceptElement(details.data, details.offset),
                  builder: (context, candidates, rejected) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned.fill(child: _CanvasGrid()),
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _bonds,
                            _invalidAtomIds,
                            _packages,
                            _packagePulse,
                          ]),
                          builder: (context, _) => CustomPaint(
                            painter: _BondPainter(
                              atoms: atoms,
                              bonds: _bonds.value,
                              invalidAtomIds: _invalidAtomIds.value,
                              packages: _packages.value,
                              packagePulse: _packagePulse.value,
                              accent: widget.accent,
                            ),
                          ),
                        ),
                      ),
                      for (final atom in atoms)
                        KeyedSubtree(
                          key: ValueKey(atom.id),
                          child: _AtomPositionLayer(
                            atom: atom,
                            position: _positions[atom.id]!,
                            size: _atomSize(atom),
                            charge: _charges[atom.id]!,
                            neutronRevision: _neutronRevisions[atom.id]!,
                            isInvalid: _invalidStates[atom.id]!,
                            isSelected: _selectedId == atom.id,
                            onSelect: () {
                              if (_selectedId != atom.id) {
                                setState(() => _selectedId = atom.id);
                              }
                            },
                            onPanDelta: (delta) => _moveAtom(atom, delta),
                          ),
                        ),
                      if (atoms.isEmpty)
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: Center(child: _EmptyCanvasHint()),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (candidates.isNotEmpty)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.06),
                    border: Border.all(
                      color: widget.accent.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 12,
              top: 12,
              child: _CanvasControls(
                accent: widget.accent,
                atomCount: atoms.length,
                onResetView: () => _transform.value = Matrix4.identity(),
                onClear: clearAtoms,
              ),
            ),
          ],
        ),
      );
    },
  );

  double _atomSize(AtomNode atom) {
    final shellCount = electronShells(atom.element.number).length;
    final radius = 25.0 + (shellCount - 1) * 14;
    return radius * 2 + 36;
  }
}

class _AtomPositionLayer extends StatelessWidget {
  const _AtomPositionLayer({
    required this.atom,
    required this.position,
    required this.charge,
    required this.neutronRevision,
    required this.isInvalid,
    required this.size,
    required this.isSelected,
    required this.onSelect,
    required this.onPanDelta,
  });

  final AtomNode atom;
  final ValueNotifier<Offset> position;
  final ValueNotifier<int> charge;
  final ValueNotifier<int> neutronRevision;
  final ValueNotifier<bool> isInvalid;
  final double size;
  final bool isSelected;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onPanDelta;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: charge,
    builder: (context, currentCharge, _) => ValueListenableBuilder<bool>(
      valueListenable: isInvalid,
      builder: (context, invalid, _) => ValueListenableBuilder<int>(
        valueListenable: neutronRevision,
        builder: (context, _, _) => ValueListenableBuilder<Offset>(
          valueListenable: position,
          builder: (context, center, _) => Positioned(
            left: center.dx - size / 2,
            top: center.dy - (size + 28) / 2,
            child: AtomWidget(
              atom: atom,
              charge: currentCharge,
              neutronCount: atom.neutrons,
              isInvalid: invalid,
              isSelected: isSelected,
              onSelect: onSelect,
              onPanDelta: onPanDelta,
            ),
          ),
        ),
      ),
    ),
  );
}

class _CanvasGrid extends StatelessWidget {
  const _CanvasGrid();

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _GridPainter(),
    child: const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.1),
          radius: 1.15,
          colors: [Color(0xFF13232F), Color(0xFF0B131C)],
        ),
      ),
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF87B7C6).withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 36) {
      for (var y = 0.0; y <= size.height; y += 36) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

class _BondPainter extends CustomPainter {
  const _BondPainter({
    required this.atoms,
    required this.bonds,
    required this.invalidAtomIds,
    required this.packages,
    required this.packagePulse,
    required this.accent,
  });

  final List<AtomNode> atoms;
  final List<AtomBond> bonds;
  final Set<String> invalidAtomIds;
  final List<PolyatomicGroupInstance> packages;
  final double packagePulse;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final atom in atoms) atom.id: atom};
    for (final group in packages) {
      final members = group.atomIds
          .map((id) => byId[id])
          .whereType<AtomNode>()
          .toList();
      if (members.isEmpty) continue;
      final bounds = Rect.fromLTRB(
        members.map((atom) => atom.x).reduce(math.min) - 48,
        members.map((atom) => atom.y).reduce(math.min) - 48,
        members.map((atom) => atom.x).reduce(math.max) + 48,
        members.map((atom) => atom.y).reduce(math.max) + 48,
      );
      final definition = group.definition;
      final outline = Paint()
        ..color = accent.withValues(alpha: 0.42 + packagePulse * 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = packagePulse > 0.02
            ? const MaskFilter.blur(BlurStyle.normal, 7)
            : null;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds, const Radius.circular(18)),
        outline,
      );
      final label = TextPainter(
        text: TextSpan(
          text:
              '${definition.name} · ${definition.formula}${definition.chargeSuffix} · HT ${definition.valencyRoman}',
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            backgroundColor: const Color(0xDD101D28),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: bounds.width);
      label.paint(
        canvas,
        Offset(bounds.left + 8, bounds.top - label.height - 3),
      );
    }
    for (final bond in bonds) {
      final first = byId[bond.firstId];
      final second = byId[bond.secondId];
      if (first == null || second == null) continue;
      final start = Offset(first.x, first.y);
      final end = Offset(second.x, second.y);
      final delta = end - start;
      final length = delta.distance;
      if (length == 0) continue;
      final unit = delta / length;
      final invalid =
          invalidAtomIds.contains(first.id) ||
          invalidAtomIds.contains(second.id);
      final color = invalid
          ? const Color(0xFFFF5E67)
          : switch (bond.kind) {
              BondKind.ionic => const Color(0xFFFFB55F),
              BondKind.covalent => accent,
              BondKind.metallic => const Color(0xFFFF5E67),
            };
      final paint = Paint()
        ..color = color.withValues(alpha: 0.82)
        ..strokeWidth =
            bond.kind == BondKind.ionic || bond.kind == BondKind.metallic
            ? 2
            : 3
        ..style = PaintingStyle.stroke;
      final from = start + unit * 25;
      final to = end - unit * 25;
      if (bond.kind == BondKind.covalent) {
        final normal = Offset(-unit.dy, unit.dx) * 5;
        canvas.drawLine(from + normal, to + normal, paint);
        canvas.drawLine(from - normal, to - normal, paint);
        final middle = (start + end) / 2;
        final electron = Paint()..color = const Color(0xFF8CFAFF);
        canvas.drawCircle(middle + normal, 3.2, electron);
        canvas.drawCircle(middle - normal, 3.2, electron);
      } else if (bond.kind == BondKind.ionic) {
        final donorIsFirst = first.element.kind == ElementKind.metal;
        final arrowFrom = donorIsFirst ? from : to;
        final arrowTo = donorIsFirst ? to : from;
        final arrowDelta = arrowTo - arrowFrom;
        if (arrowDelta.distance < 1) {
          canvas.drawLine(start, end, paint);
          continue;
        }
        final arrowUnit = arrowDelta / arrowDelta.distance;
        canvas.drawLine(arrowFrom, arrowTo, paint);
        final head = arrowTo - arrowUnit * 8;
        final path = Path()
          ..moveTo(arrowTo.dx, arrowTo.dy)
          ..lineTo(head.dx - arrowUnit.dy * 5, head.dy + arrowUnit.dx * 5)
          ..lineTo(head.dx + arrowUnit.dy * 5, head.dy - arrowUnit.dx * 5)
          ..close();
        canvas.drawPath(path, Paint()..color = color);
      } else {
        canvas.drawLine(from, to, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BondPainter oldDelegate) =>
      oldDelegate.atoms != atoms ||
      oldDelegate.bonds != bonds ||
      oldDelegate.invalidAtomIds != invalidAtomIds ||
      oldDelegate.packages != packages ||
      oldDelegate.packagePulse != packagePulse ||
      oldDelegate.accent != accent;
}

class _EmptyCanvasHint extends StatelessWidget {
  const _EmptyCanvasHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
    decoration: BoxDecoration(
      color: const Color(0xCC101D28),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x3348D7E7)),
    ),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.scatter_plot_rounded, color: Color(0xFF63DDE8), size: 31),
        SizedBox(height: 8),
        Text(
          'Kéo nguyên tố từ bảng tuần hoàn vào đây',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        SizedBox(height: 4),
        Text(
          'Kéo nguyên tử để quan sát và tạo liên kết',
          style: TextStyle(color: Color(0xFF93AAB9), fontSize: 10),
        ),
      ],
    ),
  );
}

class _CanvasControls extends StatelessWidget {
  const _CanvasControls({
    required this.accent,
    required this.atomCount,
    required this.onResetView,
    required this.onClear,
  });

  final Color accent;
  final int atomCount;
  final VoidCallback onResetView;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xE8111D28),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: accent.withValues(alpha: 0.24)),
    ),
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Text(
            '$atomCount nguyên tử',
            style: const TextStyle(color: Color(0xFFBED0DB), fontSize: 10),
          ),
        ),
        IconButton(
          tooltip: 'Đặt lại góc nhìn',
          visualDensity: VisualDensity.compact,
          onPressed: onResetView,
          icon: Icon(Icons.center_focus_strong, color: accent, size: 17),
        ),
        IconButton(
          tooltip: 'Xóa canvas',
          visualDensity: VisualDensity.compact,
          onPressed: atomCount == 0 ? null : onClear,
          icon: const Icon(Icons.delete_outline, size: 17),
        ),
      ],
    ),
  );
}
