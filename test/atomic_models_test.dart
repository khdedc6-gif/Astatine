import 'package:astatine_dashboard/features/chemistry/atomic_models.dart';
import 'package:astatine_dashboard/features/chemistry/atomic_canvas.dart';
import 'package:astatine_dashboard/features/chemistry/atomic_reaction_logic.dart';
import 'package:astatine_dashboard/features/chemistry/atom_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:astatine_dashboard/features/chemistry/atomic_virtual_lab.dart';

void main() {
  group('electron shells', () {
    test('fills shells in orbital order and conserves electron count', () {
      expect(electronShells(1), [1]);
      expect(electronShells(8), [2, 6]);
      expect(electronShells(11), [2, 8, 1]);
      expect(electronShells(20), [2, 8, 8, 2]);
      expect(electronShells(26), [2, 8, 14, 2]);
      expect(electronShells(92).fold<int>(0, (sum, count) => sum + count), 92);
    });

    test('periodic table covers all 118 elements with isotope counts', () {
      expect(periodicElements, hasLength(118));
      final sodium = elementBySymbol('Na')!;
      expect(sodium.protons, 11);
      expect(sodium.neutrons, 12);
      expect(elementBySymbol('Og')!.number, 118);
    });
  });

  group('atomic bonding', () {
    AtomNode atom(String id, String symbol, double x) =>
        AtomNode(id: id, element: elementBySymbol(symbol)!, x: x, y: 100);

    test('detects ionic and covalent bonds by element type and distance', () {
      final sodium = atom('na', 'Na', 0);
      final chlorine = atom('cl', 'Cl', 100);
      final carbon = atom('c', 'C', 500);
      final oxygen = atom('o', 'O', 600);
      final bonds = AtomicReactionLogic.findBonds([
        sodium,
        chlorine,
        carbon,
        oxygen,
      ]);
      expect(bonds, hasLength(2));
      expect(bonds.first.kind, BondKind.ionic);
      expect(bonds.last.kind, BondKind.covalent);
    });

    test('recognizes water from a connected two-hydrogen oxygen cluster', () {
      final atoms = [
        atom('h1', 'H', 0),
        atom('o', 'O', 120),
        atom('h2', 'H', 240),
      ];
      final reactions = AtomicReactionLogic.reactions(
        atoms,
        AtomicReactionLogic.findBonds(atoms),
      );
      expect(reactions, hasLength(1));
      expect(reactions.single.equation, '2H + O → H₂O');
      expect(reactions.single.polyatomicGroups, isEmpty);
    });

    test('recognizes hydroxide inside sodium hydroxide', () {
      final atoms = [
        atom('na', 'Na', 0),
        atom('o', 'O', 100),
        atom('h', 'H', 220),
      ];
      final engine = const UniversalChemicalClusterEngine();
      final bonds = engine.buildGraph(atoms);
      final clusters = engine.analyze(atoms, bonds);

      expect(clusters, hasLength(1));
      expect(clusters.single.equation, 'Na + H + O → NaOH');
      expect(clusters.single.recognizedGroups, contains('hydroxyl (OH)'));
      expect(clusters.single.polyatomicGroups.single.definition.charge, -1);
      expect(clusters.single.isValid, isTrue);
    });

    test(
      'polyatomic dictionary recognizes complete ions and their charges',
      () {
        final atoms = [
          atom('n', 'N', 500)..y = 500,
          atom('o1', 'O', 500)..y = 390,
          atom('o2', 'O', 595)..y = 555,
          atom('o3', 'O', 405)..y = 555,
        ];
        final reaction = const UniversalChemicalClusterEngine()
            .analyze(atoms)
            .single;

        final nitrate = reaction.polyatomicGroups.single;
        expect(nitrate.definition.id, 'nitrate');
        expect(nitrate.definition.formula, 'NO₃');
        expect(nitrate.definition.charge, -1);
        expect(nitrate.definition.valencyRoman, 'I');
        expect(reaction.message, contains('Gốc Nitrat NO₃⁻, hóa trị I'));
      },
    );

    test(
      'polyatomic packaging requires the complete central-peripheral graph',
      () {
        final atoms = [
          atom('c', 'C', 500)..y = 500,
          atom('o1', 'O', 500)..y = 390,
          atom('o2', 'O', 595)..y = 555,
        ];
        final reaction = const UniversalChemicalClusterEngine()
            .analyze(atoms)
            .single;

        expect(reaction.polyatomicGroups, isEmpty);
      },
    );

    test('tetrahedral-group geometry rules and charge are data driven', () {
      final sulfate = polyatomicGroupDictionary.singleWhere(
        (group) => group.id == 'sulfate',
      );
      final phosphate = polyatomicGroupDictionary.singleWhere(
        (group) => group.id == 'phosphate',
      );

      expect(sulfate.geometry, MolecularGeometry.tetrahedral);
      expect(sulfate.peripheralCount, 4);
      expect(sulfate.charge, -2);
      expect(phosphate.geometry, MolecularGeometry.tetrahedral);
      expect(phosphate.valency, 3);
    });

    test('recognizes sulfuric acid formula and sulfate structure', () {
      final atoms = [
        atom('s', 'S', 500)..y = 500,
        atom('o1', 'O', 390)..y = 500,
        atom('o2', 'O', 610)..y = 500,
        atom('o3', 'O', 500)..y = 390,
        atom('o4', 'O', 500)..y = 610,
        atom('h1', 'H', 280)..y = 500,
        atom('h2', 'H', 500)..y = 280,
      ];
      final engine = const UniversalChemicalClusterEngine();
      final clusters = engine.analyze(atoms);

      expect(clusters, hasLength(1));
      expect(clusters.single.product, 'H₂SO₄');
      expect(
        clusters.single.recognizedGroups,
        contains('sulfate skeleton (SO₄)'),
      );
      expect(clusters.single.isValid, isTrue);
    });

    group('chemical formula canonicalization', () {
      test('normalizes permuted metal carbonate signatures identically', () {
        final forward = <String, int>{'Cu': 1, 'C': 1, 'O': 3};
        final permuted = <String, int>{'O': 3, 'Cu': 1, 'C': 1};

        expect(ChemicalFormulaCanonicalizer.formula(forward), 'CuCO₃');
        expect(ChemicalFormulaCanonicalizer.formula(permuted), 'CuCO₃');
        expect(
          ChemicalFormulaCanonicalizer.signatureKey(forward),
          ChemicalFormulaCanonicalizer.signatureKey(permuted),
        );
      });

      test('keeps polyatomic formula ordering canonical', () {
        expect(ChemicalFormulaCanonicalizer.formula({'O': 1, 'H': 1}), 'OH');
        expect(ChemicalFormulaCanonicalizer.formula({'O': 1, 'S': 1}), 'SO');
        expect(
          ChemicalFormulaCanonicalizer.formula({'O': 4, 'S': 1, 'H': 2}),
          'H₂SO₄',
        );
        expect(
          ChemicalFormulaCanonicalizer.formula({'O': 2, 'H': 2, 'Ca': 1}),
          'Ca(OH)₂',
        );
      });

      test('orders unknown formulas by chemical priorities, not map order', () {
        expect(
          ChemicalFormulaCanonicalizer.formula({'O': 3, 'Cu': 1, 'C': 1}),
          'CuCO₃',
        );
        expect(
          ChemicalFormulaCanonicalizer.formula({'O': 2, 'Cu': 1, 'C': 1}),
          'CuCO₂',
        );
        expect(ChemicalFormulaCanonicalizer.formula({'O': 2, 'C': 1}), 'CO₂');
        expect(ChemicalFormulaCanonicalizer.formula({'O': 1, 'S': 1}), 'SO');
      });
    });

    test('recognizes a calcium carbonate cluster', () {
      final atoms = [
        atom('c', 'C', 500)..y = 500,
        atom('o1', 'O', 610)..y = 500,
        atom('o2', 'O', 445)..y = 405,
        atom('o3', 'O', 445)..y = 595,
        atom('ca', 'Ca', 730)..y = 500,
      ];
      final clusters = const UniversalChemicalClusterEngine().analyze(atoms);

      expect(clusters, hasLength(1));
      expect(clusters.single.product, 'CaCO₃');
      expect(
        clusters.single.recognizedGroups,
        contains('carbonate skeleton (CO₃)'),
      );
      expect(clusters.single.isValid, isTrue);
    });

    test('marks over-valent spatial clusters invalid without throwing', () {
      final atoms = [
        atom('c', 'C', 500)..y = 500,
        for (var index = 0; index < 5; index++)
          atom('h$index', 'H', 500 + 75 * (index.isEven ? 1 : -1))
            ..y =
                500 +
                75 *
                    (index < 2
                        ? 1
                        : index < 4
                        ? -1
                        : 0),
      ];
      final engine = const UniversalChemicalClusterEngine();
      final clusters = engine.analyze(atoms);

      expect(clusters, hasLength(1));
      expect(clusters.single.isValid, isFalse);
      expect(clusters.single.message, contains('hóa trị tối đa'));
      expect(clusters.single.signature, {'C': 1, 'H': 5});
    });

    test('keeps spatially independent clusters separate', () {
      final atoms = [
        atom('h1', 'H', 0),
        atom('h2', 'H', 50),
        atom('o1', 'O', 1000),
        atom('o2', 'O', 1050),
      ];
      final clusters = const UniversalChemicalClusterEngine().analyze(atoms);

      expect(clusters, hasLength(2));
      expect(clusters.map((cluster) => cluster.signature), [
        {'H': 2},
        {'O': 2},
      ]);
    });

    test('fails safely on malformed coordinates and connection thresholds', () {
      final atoms = [
        AtomNode(
          id: 'bad',
          element: elementBySymbol('C')!,
          x: double.nan,
          y: double.infinity,
        ),
        atom('h', 'H', 0),
      ];
      const engine = UniversalChemicalClusterEngine();

      expect(engine.analyze(atoms), isEmpty);
      expect(AtomicReactionLogic.findBonds(atoms, maxDistance: 0), isEmpty);
    });
  });

  testWidgets('atomic workspace recognizes the water quick-start cluster', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AtomicVirtualLabScreen(isVietnamese: true)),
    );
    await tester.tap(find.byKey(const Key('atomic-preset-0')));
    await tester.pump();

    expect(find.text('2H + O → H₂O'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('periodic table elements can be dragged into the canvas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AtomicVirtualLabScreen(isVietnamese: true)),
    );
    final hydrogen = find.text('H');
    final start = tester.getCenter(hydrogen);
    await tester.dragFrom(start, const Offset(450, 250));
    await tester.pump();

    expect(find.text('1 nguyên tử'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging a packaged polyatomic ion moves it as one unit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AtomicVirtualLabScreen(isVietnamese: true)),
    );
    final canvas = tester.state<AtomicCanvasState>(find.byType(AtomicCanvas));
    canvas.addPresetAtoms([
      ('C', const Offset(500, 500)),
      ('O', const Offset(500, 390)),
      ('O', const Offset(595, 555)),
      ('O', const Offset(405, 555)),
    ]);
    await tester.pump();

    Finder atomFinder(String id) => find.byWidgetPredicate(
      (widget) => widget is AtomWidget && widget.atom.id == id,
    );

    final atomCentersBefore = [
      for (var index = 0; index < 4; index++)
        tester.getCenter(atomFinder('atom-$index')),
    ];
    tester
        .widget<AtomWidget>(atomFinder('atom-0'))
        .onPanDelta(const Offset(35, 0));
    await tester.pump();
    final atomCentersAfter = [
      for (var index = 0; index < 4; index++)
        tester.getCenter(atomFinder('atom-$index')),
    ];

    for (var index = 0; index < atomCentersBefore.length; index++) {
      expect(
        atomCentersAfter[index].dx - atomCentersBefore[index].dx,
        closeTo(35, 1),
      );
      expect(
        atomCentersAfter[index].dy - atomCentersBefore[index].dy,
        closeTo(0, 1),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging a peripheral atom moves only that atom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AtomicVirtualLabScreen(isVietnamese: true)),
    );
    final canvas = tester.state<AtomicCanvasState>(find.byType(AtomicCanvas));
    canvas.addPresetAtoms([
      ('S', const Offset(500, 500)),
      ('O', const Offset(500, 390)),
      ('O', const Offset(595, 555)),
      ('O', const Offset(405, 555)),
      ('O', const Offset(500, 610)),
    ]);
    await tester.pump();

    Finder atomFinder(String id) => find.byWidgetPredicate(
      (widget) => widget is AtomWidget && widget.atom.id == id,
    );

    final centersBefore = [
      for (var index = 0; index < 5; index++)
        tester.getCenter(atomFinder('atom-$index')),
    ];
    tester
        .widget<AtomWidget>(atomFinder('atom-1'))
        .onPanDelta(const Offset(35, 0));
    await tester.pump();
    final centersAfter = [
      for (var index = 0; index < 5; index++)
        tester.getCenter(atomFinder('atom-$index')),
    ];

    for (var index = 0; index < centersBefore.length; index++) {
      expect(
        centersAfter[index].dx - centersBefore[index].dx,
        closeTo(index == 1 ? 35 : 0, 1),
      );
      expect(centersAfter[index].dy - centersBefore[index].dy, closeTo(0, 1));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid cluster shows a warning in the equation bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AtomicVirtualLabScreen(isVietnamese: true)),
    );
    final canvas = tester.state<AtomicCanvasState>(find.byType(AtomicCanvas));
    canvas.addPresetAtoms([
      ('C', const Offset(500, 500)),
      ('H', const Offset(580, 500)),
      ('H', const Offset(500, 580)),
      ('H', const Offset(420, 500)),
      ('H', const Offset(500, 420)),
      ('H', const Offset(556, 556)),
    ]);
    await tester.pump();

    expect(find.textContaining('hóa trị tối đa'), findsOneWidget);
    expect(find.text('5H + C → H₅C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
