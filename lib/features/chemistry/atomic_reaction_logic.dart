import 'dart:math' as math;

import 'atomic_models.dart';

class AtomicReaction {
  const AtomicReaction(
    this.reactants,
    this.product, {
    this.isValid = true,
    this.message = '',
    this.signature = const {},
    this.atomIds = const {},
    this.recognizedGroups = const [],
    this.polyatomicGroups = const [],
  });

  final String reactants;
  final String product;
  final bool isValid;
  final String message;
  final Map<String, int> signature;
  final Set<String> atomIds;
  final List<String> recognizedGroups;
  final List<PolyatomicGroupInstance> polyatomicGroups;

  String get equation => '$reactants → $product';
}

class ChemicalFormulaCanonicalizer {
  const ChemicalFormulaCanonicalizer._();

  static const knownFormulas = <String, String>{
    'H:2,O:1': 'H₂O',
    'Na:1,Cl:1': 'NaCl',
    'C:1,O:2': 'CO₂',
    'H:3,N:1': 'NH₃',
    'C:1,H:4': 'CH₄',
    'H:2': 'H₂',
    'O:2': 'O₂',
    'Cl:2': 'Cl₂',
    'H:1,O:1': 'OH',
    'H:1,Na:1,O:1': 'NaOH',
    'H:2,O:4,S:1': 'H₂SO₄',
    'C:1,Ca:1,O:3': 'CaCO₃',
    'C:1,Cu:1,O:3': 'CuCO₃',
    'Ca:1,H:2,O:2': 'Ca(OH)₂',
    'H:2,O:4,Na:2,S:1': 'Na₂SO₄',
    'H:1,N:1,O:3': 'HNO₃',
    'H:1,N:1,Na:1,O:3': 'NaNO₃',
    'H:4,N:1,Cl:1': 'NH₄Cl',
    'H:2,Mg:1,O:2': 'Mg(OH)₂',
    'C:1,Mg:1,O:3': 'MgCO₃',
    'C:1,Na:2,O:3': 'Na₂CO₃',
    'H:2,O:3,S:1': 'H₂SO₃',
    'H:3,O:4,P:1': 'H₃PO₄',
    'H:1,Cl:1': 'HCl',
    'H:2,O:1,S:1': 'H₂S',
    'H:2,O:2': 'H₂O₂',
    'H:1,O:2': 'HO₂',
  };

  static String signatureKey(Map<String, int> signature) {
    final symbols = signature.keys.toList()..sort();
    return symbols
        .where((symbol) => (signature[symbol] ?? 0) > 0)
        .map((symbol) => '$symbol:${signature[symbol]}')
        .join(',');
  }

  static String formula(Map<String, int> signature) =>
      knownFormulas[signatureKey(signature)] ?? _formatByPriority(signature);

  static String reactants(Map<String, int> signature) {
    final symbols = _orderedSymbols(signature);
    return symbols
        .map(
          (symbol) =>
              '${signature[symbol]! > 1 ? signature[symbol] : ''}$symbol',
        )
        .join(' + ');
  }

  static String _formatByPriority(Map<String, int> signature) =>
      _orderedSymbols(signature)
          .map((symbol) => '$symbol${_subscript(signature[symbol]!)}')
          .join();

  static List<String> _orderedSymbols(Map<String, int> signature) {
    final symbols = signature.keys
        .where((symbol) => (signature[symbol] ?? 0) > 0)
        .toList();
    final containsMetal = symbols.any(
      (symbol) => elementBySymbol(symbol)?.kind == ElementKind.metal,
    );

    int priority(String symbol) {
      final element = elementBySymbol(symbol);
      if (element?.kind == ElementKind.metal) return 0;
      if (symbol == 'H') return containsMetal ? 1 : 0;
      if (symbol == 'C') {
        return containsMetal || symbols.contains('H') ? 2 : 0;
      }
      if (symbol == 'S') return 2;
      if (symbol == 'N') return 3;
      if (symbol == 'P') return 4;
      if (symbol == 'O') return 100;
      return 5 + (element?.number ?? 0);
    }

    symbols.sort((first, second) {
      final priorityDifference = priority(first).compareTo(priority(second));
      if (priorityDifference != 0) return priorityDifference;
      return (elementBySymbol(first)?.number ?? 0).compareTo(
        elementBySymbol(second)?.number ?? 0,
      );
    });
    return symbols;
  }

  static String _subscript(int value) {
    const digits = '₀₁₂₃₄₅₆₇₈₉';
    return value == 1
        ? ''
        : value
              .toString()
              .split('')
              .map((digit) => digits[int.parse(digit)])
              .join();
  }
}

typedef ChemicalCluster = AtomicReaction;

class UniversalChemicalClusterEngine {
  const UniversalChemicalClusterEngine({
    this.connectionDistance = AtomicReactionLogic.defaultConnectionDistance,
  });

  final double connectionDistance;

  List<AtomBond> buildGraph(List<AtomNode> atoms) =>
      AtomicReactionLogic.findBonds(atoms, maxDistance: connectionDistance);

  List<ChemicalCluster> analyze(List<AtomNode> atoms, [List<AtomBond>? graph]) {
    final bonds = graph ?? buildGraph(atoms);
    return AtomicReactionLogic.reactions(atoms, bonds);
  }
}

class AtomicReactionLogic {
  static const defaultConnectionDistance = 150.0;

  static BondKind bondKind(ChemicalElement first, ChemicalElement second) {
    if (first.kind == ElementKind.metal &&
            second.kind == ElementKind.nonmetal ||
        second.kind == ElementKind.metal &&
            first.kind == ElementKind.nonmetal) {
      return BondKind.ionic;
    }
    if (first.kind == ElementKind.metal && second.kind == ElementKind.metal) {
      return BondKind.metallic;
    }
    return BondKind.covalent;
  }

  static List<AtomBond> findBonds(
    List<AtomNode> atoms, {
    double maxDistance = defaultConnectionDistance,
  }) {
    if (!maxDistance.isFinite || maxDistance <= 0) return const [];
    final cells = <(int, int), List<int>>{};
    for (var index = 0; index < atoms.length; index++) {
      final atom = atoms[index];
      if (!atom.x.isFinite || !atom.y.isFinite) continue;
      final cell = (
        (atom.x / maxDistance).floor(),
        (atom.y / maxDistance).floor(),
      );
      cells.putIfAbsent(cell, () => []).add(index);
    }

    final bonds = <AtomBond>[];
    final maxDistanceSquared = maxDistance * maxDistance;
    for (var index = 0; index < atoms.length; index++) {
      final first = atoms[index];
      if (!first.x.isFinite || !first.y.isFinite) continue;
      final cellX = (first.x / maxDistance).floor();
      final cellY = (first.y / maxDistance).floor();
      for (var x = cellX - 1; x <= cellX + 1; x++) {
        for (var y = cellY - 1; y <= cellY + 1; y++) {
          for (final neighborIndex in cells[(x, y)] ?? const <int>[]) {
            if (neighborIndex <= index) continue;
            final second = atoms[neighborIndex];
            final dx = first.x - second.x;
            final dy = first.y - second.y;
            if (dx * dx + dy * dy < maxDistanceSquared) {
              bonds.add(
                AtomBond(
                  first.id,
                  second.id,
                  bondKind(first.element, second.element),
                ),
              );
            }
          }
        }
      }
    }
    return bonds;
  }

  static List<AtomicReaction> reactions(
    List<AtomNode> atoms,
    List<AtomBond> bonds,
  ) {
    final atomsById = <String, AtomNode>{
      for (final atom in atoms) atom.id: atom,
    };
    final adjacency = <String, Set<String>>{
      for (final atom in atoms) atom.id: <String>{},
    };
    for (final bond in bonds) {
      if (!atomsById.containsKey(bond.firstId) ||
          !atomsById.containsKey(bond.secondId) ||
          bond.firstId == bond.secondId) {
        continue;
      }
      adjacency[bond.firstId]!.add(bond.secondId);
      adjacency[bond.secondId]!.add(bond.firstId);
    }

    final visited = <String>{};
    final clusters = <AtomicReaction>[];
    for (final atom in atoms) {
      if (visited.contains(atom.id) || adjacency[atom.id]!.isEmpty) continue;
      final cluster = <AtomNode>[];
      final queue = <String>[atom.id];
      visited.add(atom.id);
      while (queue.isNotEmpty) {
        final id = queue.removeLast();
        final member = atomsById[id];
        if (member == null) continue;
        cluster.add(member);
        for (final neighbor in adjacency[id]!) {
          if (visited.add(neighbor)) queue.add(neighbor);
        }
      }
      final ids = cluster.map((member) => member.id).toSet();
      final clusterBonds = bonds
          .where(
            (bond) => ids.contains(bond.firstId) && ids.contains(bond.secondId),
          )
          .toList();
      clusters.add(_analyzeCluster(cluster, clusterBonds, adjacency));
    }
    return clusters;
  }

  static AtomicReaction _analyzeCluster(
    List<AtomNode> atoms,
    List<AtomBond> bonds,
    Map<String, Set<String>> adjacency,
  ) {
    final signature = <String, int>{};
    final byId = {for (final atom in atoms) atom.id: atom};
    for (final atom in atoms) {
      signature.update(
        atom.element.symbol,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final issues = <String>[];
    for (final atom in atoms) {
      final degree = adjacency[atom.id]?.length ?? 0;
      final maxValency = atom.element.valencies.fold<int>(0, math.max);
      if (degree > maxValency) {
        issues.add(
          '${atom.element.symbol} có $degree liên kết nhưng hóa trị tối đa là $maxValency',
        );
      }
    }
    if (bonds.any((bond) => bond.kind == BondKind.metallic)) {
      issues.add('Mô hình liên kết kim loại chưa được hỗ trợ trong lab này');
    }

    final polyatomicGroups = _recognizedPolyatomicGroups(atoms, bonds);
    final groups = polyatomicGroups.map((group) {
      final label = switch (group.definition.id) {
        'hydroxide' => 'hydroxyl (OH)',
        'sulfate' => 'sulfate skeleton (SO₄)',
        'carbonate' => 'carbonate skeleton (CO₃)',
        'nitrate' => 'nitrate skeleton (NO₃)',
        _ => '${group.definition.name} (${group.definition.formula})',
      };
      return label;
    }).toList();
    final product = _formulaFor(signature);
    final reactants = _reactantsFor(signature);
    final issueMessage = issues.isEmpty ? '' : issues.toSet().join('; ');
    final groupMessage = groups.isEmpty
        ? ''
        : 'Đã đóng gói: ${polyatomicGroups.map((group) => '${group.definition.name} ${group.definition.formula}${group.definition.chargeSuffix}, hóa trị ${group.definition.valencyRoman}').join('; ')}.';
    final unknownMessage =
        ChemicalFormulaCanonicalizer.knownFormulas.containsKey(
          ChemicalFormulaCanonicalizer.signatureKey(signature),
        )
        ? ''
        : 'Chưa có chất này trong danh mục công thức; đang hiển thị công thức theo thành phần.';
    final message = [
      if (issueMessage.isNotEmpty) issueMessage,
      if (groupMessage.isNotEmpty) groupMessage,
      if (unknownMessage.isNotEmpty) unknownMessage,
    ].join(' ');

    return AtomicReaction(
      reactants,
      product,
      isValid: issues.isEmpty,
      message: message,
      signature: Map.unmodifiable(signature),
      atomIds: Set.unmodifiable(byId.keys),
      recognizedGroups: List.unmodifiable(groups),
      polyatomicGroups: List.unmodifiable(polyatomicGroups),
    );
  }

  static List<PolyatomicGroupInstance> _recognizedPolyatomicGroups(
    List<AtomNode> atoms,
    List<AtomBond> bonds,
  ) {
    final atomsById = {for (final atom in atoms) atom.id: atom};
    final covalentNeighbors = <String, Set<String>>{
      for (final atom in atoms) atom.id: <String>{},
    };
    for (final bond in bonds.where((bond) => bond.kind == BondKind.covalent)) {
      covalentNeighbors[bond.firstId]?.add(bond.secondId);
      covalentNeighbors[bond.secondId]?.add(bond.firstId);
    }

    final groups = <PolyatomicGroupInstance>[];
    for (final definition in polyatomicGroupDictionary) {
      for (final center in atoms.where(
        (atom) => atom.element.symbol == definition.centralElement,
      )) {
        final peripheralIds = (covalentNeighbors[center.id] ?? const <String>{})
            .where(
              (id) =>
                  atomsById[id]?.element.symbol == definition.peripheralElement,
            )
            .toList()
          ..sort();
        if (peripheralIds.length != definition.peripheralCount) continue;
        groups.add(
          PolyatomicGroupInstance(
            definition: definition,
            centralAtomId: center.id,
            peripheralAtomIds: List.unmodifiable(
              peripheralIds.take(definition.peripheralCount),
            ),
          ),
        );
      }
    }
    return groups;
  }

  static String _formulaFor(Map<String, int> signature) =>
      ChemicalFormulaCanonicalizer.formula(signature);

  static String _reactantsFor(Map<String, int> signature) =>
      ChemicalFormulaCanonicalizer.reactants(signature);
}
