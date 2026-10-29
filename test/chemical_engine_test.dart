import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/features/chemistry/chemical_models.dart';
import 'package:astatine_dashboard/features/chemistry/molecule_tile_physics.dart';
import 'package:astatine_dashboard/features/chemistry/pseudo_3d_beaker.dart';
import 'package:astatine_dashboard/features/chemistry/reaction_engine.dart';
import 'package:astatine_dashboard/features/chemistry/virtual_lab.dart';
import 'package:astatine_dashboard/features/chemistry/virtual_lab_chemistry.dart';

void main() {
  const engine = ReactionEngine();

  test('balances a polyprotic acid with a divalent base generically', () {
    const sulfate = ChemicalIon(symbol: 'SO4', charge: -2, isPolyatomic: true);
    const calcium = ChemicalIon(symbol: 'Ca', charge: 2);
    const acid = ChemicalClass(
      id: 'sulfuric-acid',
      name: 'Sulfuric acid',
      nameVietnamese: 'Axit sulfuric',
      formula: 'H2SO4',
      category: ChemicalCategory.acid,
      state: ChemicalState.aqueous,
      color: Color(0xFF55C7F3),
      anion: sulfate,
      acidProtons: 2,
    );
    const base = ChemicalClass(
      id: 'calcium-hydroxide',
      name: 'Calcium hydroxide',
      nameVietnamese: 'Canxi hiđroxit',
      formula: 'Ca(OH)2',
      category: ChemicalCategory.base,
      state: ChemicalState.aqueous,
      color: Color(0xFF70D6A6),
      cation: calcium,
      baseHydroxides: 2,
    );

    final result = engine.evaluate([acid, base], 24);

    expect(result?.equation, 'H2SO4 + Ca(OH)2 → CaSO4 + 2H2O');
    expect(result?.type, ReactionType.neutralization);
  });

  test('applies the alkali metal and water rule', () {
    final result = engine.evaluate([
      ChemicalCatalog.sodium,
      ChemicalCatalog.water,
    ], 24);

    expect(result?.equation, '2Na + 2H2O → 2NaOH + H2↑');
    expect(result?.particles.single.kind, ParticleKind.bubble);
    expect(result?.intensity, ReactionIntensity.explosive);
    expect(
      engine
          .evaluate([ChemicalCatalog.sodium, ChemicalCatalog.water], 100)
          ?.particles
          .single
          .count,
      greaterThan(result!.particles.single.count),
    );
  });

  test('fluid particles jitter and solid particles accelerate downward', () {
    final physics = MoleculeTilePhysics(random: math.Random(7));
    final water = MoleculeTile(
      formula: 'H2O',
      color: const Color(0xFF36BDF8),
      motion: SymbolicParticleMotion.suspended,
      seed: 0.2,
      x: 0.5,
      y: 0.65,
      isFluid: true,
    );
    final metal = MoleculeTile(
      formula: 'Mg',
      color: const Color(0xFF475569),
      motion: SymbolicParticleMotion.solid,
      seed: 0.4,
      x: 0.55,
      y: 0.2,
    );
    final initialWaterPosition = Offset(water.x, water.y);
    const canvasSize = Size(400, 500);

    physics.update(
      [water, metal],
      size: canvasSize,
      deltaSeconds: 1 / 30,
      temperature: 90,
    );

    expect(Offset(water.x, water.y), isNot(initialWaterPosition));
    expect(metal.y, greaterThan(0.2));
    expect(metal.velocityY, greaterThan(0));
  });

  test('higher temperatures produce substantially faster fluid motion', () {
    MoleculeTile createWater() => MoleculeTile(
      formula: 'H2O',
      color: const Color(0xFF36BDF8),
      motion: SymbolicParticleMotion.suspended,
      seed: 0.2,
      x: 0.5,
      y: 0.65,
      isFluid: true,
    );

    final coldWater = createWater();
    final hotWater = createWater();
    const initialPosition = Offset(0.5, 0.65);
    final coldPhysics = MoleculeTilePhysics(random: math.Random(15));
    final hotPhysics = MoleculeTilePhysics(random: math.Random(15));

    coldPhysics.update(
      [coldWater],
      size: const Size(400, 500),
      deltaSeconds: 1 / 30,
      temperature: 0,
    );
    hotPhysics.update(
      [hotWater],
      size: const Size(400, 500),
      deltaSeconds: 1 / 30,
      temperature: 100,
    );

    final coldDistance =
        (Offset(coldWater.x, coldWater.y) - initialPosition).distance;
    final hotDistance =
        (Offset(hotWater.x, hotWater.y) - initialPosition).distance;
    expect(hotDistance, greaterThan(coldDistance * 5));
  });

  test(
    'zero temperature freezes water and 24C jitter is about 5.76% of max',
    () {
      MoleculeTile createWater({double velocityX = 0, double velocityY = 0}) =>
          MoleculeTile(
            formula: 'H2O',
            color: const Color(0xFF36BDF8),
            motion: SymbolicParticleMotion.suspended,
            seed: 0.2,
            x: 0.5,
            y: 0.65,
            velocityX: velocityX,
            velocityY: velocityY,
            isFluid: true,
          );

      const initialPosition = Offset(0.5, 0.65);
      const canvasSize = Size(400, 500);
      final frozenWater = createWater(velocityX: 1, velocityY: -1);
      MoleculeTilePhysics(random: math.Random(27)).update(
        [frozenWater],
        size: canvasSize,
        deltaSeconds: 1 / 60,
        temperature: 0,
      );
      expect(Offset(frozenWater.x, frozenWater.y), initialPosition);
      expect(frozenWater.velocityX, 0);
      expect(frozenWater.velocityY, 0);

      final moderateWater = createWater();
      final maxTemperatureWater = createWater();
      const deltaSeconds = 1 / 6000;
      MoleculeTilePhysics(random: math.Random(27)).update(
        [moderateWater],
        size: canvasSize,
        deltaSeconds: deltaSeconds,
        temperature: 24,
      );
      MoleculeTilePhysics(random: math.Random(27)).update(
        [maxTemperatureWater],
        size: canvasSize,
        deltaSeconds: deltaSeconds,
        temperature: 100,
      );
      final moderateDistance =
          (Offset(moderateWater.x, moderateWater.y) - initialPosition).distance;
      final maxTemperatureDistance =
          (Offset(maxTemperatureWater.x, maxTemperatureWater.y) -
                  initialPosition)
              .distance;
      expect(
        moderateDistance / maxTemperatureDistance,
        closeTo(math.pow(0.24, 2), 0.0001),
      );
    },
  );

  test('molecule tiles use the requested formula color palette', () {
    final cases = <String, (Color, Color)>{
      'H2O': (const Color(0xFFE0F2FE), const Color(0xFF38BDF8)),
      'H2': (const Color(0xFFF8FAFC), const Color(0xFF94A3B8)),
      'K': (const Color(0xFFDDD6FE), const Color(0xFF8B5CF6)),
      'Na': (const Color(0xFFC7D2FE), const Color(0xFF6366F1)),
      'Cu': (const Color(0xFFEA580C), const Color(0xFF9A3412)),
      'NaOH': (const Color(0xFFDCFCE7), const Color(0xFF22C55E)),
      'Cu(OH)2': (const Color(0xFF0284C7), const Color(0xFF0369A1)),
      'Fe(OH)3': (const Color(0xFF9A3412), const Color(0xFF7C2D12)),
      'CuO': (const Color(0xFF1E293B), const Color(0xFF0F172A)),
      'HCl': (const Color(0xFFFEE2E2), const Color(0xFFEF4444)),
      'CuSO4': (const Color(0xFF0284C7), const Color(0xFF0369A1)),
      'AgCl': (Colors.white, const Color(0xFF94A3B8)),
    };

    for (final entry in cases.entries) {
      final tile = MoleculeTile(
        formula: entry.key,
        color: Colors.white,
        motion: SymbolicParticleMotion.suspended,
        seed: 0,
      );
      expect(tile.backgroundColor, entry.value.$1, reason: entry.key);
      expect(tile.borderColor, entry.value.$2, reason: entry.key);
      expect(
        tile.foregroundColor,
        MoleculeTile.reagentTextColor(entry.key),
        reason:
            'Selector and beaker text should share a color for ${entry.key}',
      );
    }
  });

  test('alkali metal consumes water on contact and emits heated products', () {
    final physics = MoleculeTilePhysics(random: math.Random(3));
    final sodium = MoleculeTile(
      formula: 'Na',
      color: const Color(0xFF64748B),
      motion: SymbolicParticleMotion.solid,
      seed: 0.2,
      x: 0.5,
      y: 0.65,
    );
    final water = MoleculeTile(
      formula: 'H2O',
      color: const Color(0xFF36BDF8),
      motion: SymbolicParticleMotion.suspended,
      seed: 0.4,
      x: 0.5,
      y: 0.65,
      isFluid: true,
    );
    final particles = [sodium, water];

    final events = physics.update(
      particles,
      size: const Size(400, 500),
      deltaSeconds: 1 / 60,
      temperature: 25,
    );

    expect(events, hasLength(1));
    expect(particles.any((particle) => particle.formula == 'H2O'), isFalse);
    expect(particles.any((particle) => particle.formula == 'NaOH'), isTrue);
    expect(particles.any((particle) => particle.formula == 'H2'), isTrue);
    expect(sodium.scale, lessThan(1));
    expect(sodium.thermalTime, greaterThan(0));
  });

  test('potassium in water creates visible KOH and hydrogen tiles', () {
    final result = engine.evaluateReaction(
      ChemicalCatalog.potassiumMetal,
      ChemicalCatalog.water,
    );

    expect(result?.equation, '2K + 2H2O → 2KOH + H2↑');
    expect(
      result?.textParticles.map((tile) => tile.formula),
      containsAll(['KOH', 'H2']),
    );
    final potassiumHydroxide = result!.textParticles.firstWhere(
      (tile) => tile.formula == 'KOH',
    );
    expect(potassiumHydroxide.backgroundColor, const Color(0xFFDCFCE7));
    expect(
      result.textParticles.every((tile) => tile.x != 0 && tile.y != 0),
      isTrue,
    );
  });

  test('supports alkaline-earth water, oxide-acid, and oxide-base rules', () {
    final calciumWater = engine.evaluateReaction(
      ChemicalCatalog.calciumMetal,
      ChemicalCatalog.water,
    );
    final copperOxide = ChemicalCatalog.reagents.firstWhere(
      (chemical) => chemical.formula == 'CuO',
    );
    final sulfuricAcid = ChemicalCatalog.reagents.firstWhere(
      (chemical) => chemical.formula == 'H2SO4',
    );
    final carbonDioxide = ChemicalCatalog.reagents.firstWhere(
      (chemical) => chemical.formula == 'CO2',
    );
    final calciumHydroxide = ChemicalCatalog.reagents.firstWhere(
      (chemical) => chemical.formula == 'Ca(OH)2',
    );

    expect(calciumWater?.equation, 'Ca + 2H2O → Ca(OH)2 + H2↑');
    expect(calciumWater?.textParticles, isNotEmpty);
    expect(
      calciumWater?.textParticles.any(
        (particle) =>
            particle.formula == 'H2' &&
            particle.motion == SymbolicParticleMotion.gas,
      ),
      isTrue,
    );
    expect(
      engine.evaluateReaction(copperOxide, sulfuricAcid)?.equation,
      'CuO + H2SO4 → CuSO4 + H2O',
    );
    final carbonatedLime = engine.evaluateReaction(
      carbonDioxide,
      calciumHydroxide,
    );
    expect(carbonatedLime?.equation, 'CO2 + Ca(OH)2 → CaCO3↓ + H2O');
    expect(
      carbonatedLime?.textParticles.map((particle) => particle.formula),
      contains('CaCO3'),
    );
    expect(
      carbonatedLime?.textParticles.map((particle) => particle.motion),
      contains(SymbolicParticleMotion.precipitate),
    );
  });

  test('queues sodium water reaction before copper sulfate precipitation', () {
    final copperSulfate = ChemicalCatalog.reagents.firstWhere(
      (chemical) => chemical.formula == 'CuSO4',
    );
    final stages = engine.evaluateReactionSequence([
      ChemicalCatalog.water,
      copperSulfate,
    ], ChemicalCatalog.sodiumMetal);
    final queue = ReactionQueue()..replaceWith(stages);

    expect(stages, hasLength(2));
    expect(queue.takeNext()?.equation, '2Na + 2H2O → 2NaOH + H2↑');
    final secondStage = queue.takeNext();
    expect(secondStage?.equation, '2NaOH + CuSO4 → Cu(OH)2↓ + Na2SO4');
    expect(
      secondStage?.textParticles
          .firstWhere((tile) => tile.formula == 'Cu(OH)2')
          .backgroundColor,
      const Color(0xFF0284C7),
    );
    expect(queue.isEmpty, isTrue);
  });

  test('hot magnesium reacts with water only at or above 70C', () {
    expect(
      engine.evaluateReactionFormulas('Mg', 'H2O', temperature: 69.9),
      isNull,
    );
    expect(
      engine.evaluateReactionFormulas('Mg', 'H2O', temperature: 70)?.equation,
      'Mg + 2H2O → Mg(OH)2↓ + H2↑',
    );
  });

  test(
    'queues alkali-water reactions before copper and iron salt reactions',
    () {
      for (final metal in [
        ChemicalCatalog.potassiumMetal,
        ChemicalCatalog.sodiumMetal,
      ]) {
        final expectedHydroxide = metal.formula == 'K' ? 'KOH' : 'NaOH';
        for (final saltFormula in ['CuSO4', 'FeCl3']) {
          final salt = ChemicalCatalog.reagents.firstWhere(
            (chemical) => chemical.formula == saltFormula,
          );
          final stages = engine.evaluateReactionSequence([
            ChemicalCatalog.water,
            salt,
          ], metal);
          expect(stages, hasLength(2));
          expect(stages.first.equation, contains(expectedHydroxide));
          expect(stages.last.equation, contains(saltFormula));
          expect(
            stages.last.equation,
            contains(
              saltFormula == 'CuSO4'
                  ? '${metal.formula}2SO4'
                  : '${metal.formula}Cl',
            ),
          );
        }
      }
    },
  );

  test(
    'recognizes aluminium hydroxide dissolving in excess sodium hydroxide',
    () {
      final aluminiumChloride = ChemicalCatalog.reagents.firstWhere(
        (chemical) => chemical.formula == 'AlCl3',
      );
      final firstAddition = engine.evaluateReactionSequence(
        [aluminiumChloride],
        ChemicalCatalog.reagents.firstWhere(
          (chemical) => chemical.formula == 'NaOH',
        ),
      );
      final excessAdditions = engine.evaluateReactionSequence([
        aluminiumChloride,
        ChemicalCatalog.sodiumHydroxide,
      ], ChemicalCatalog.sodiumHydroxide);
      final precipitation = engine.evaluateReactionFormulas('NaOH', 'AlCl3');
      final dissolution = engine.evaluateReactionFormulas('Al(OH)3', 'NaOH');

      expect(firstAddition.single.equation, '3NaOH + AlCl3 → Al(OH)3↓ + 3NaCl');
      expect(excessAdditions, hasLength(2));
      expect(excessAdditions.last.equation, 'Al(OH)3 + NaOH → NaAlO2 + 2H2O');
      expect(precipitation?.equation, '3NaOH + AlCl3 → Al(OH)3↓ + 3NaCl');
      expect(dissolution?.equation, 'Al(OH)3 + NaOH → NaAlO2 + 2H2O');
    },
  );

  test('evaluates salt and carbide hydrolysis with the heat threshold', () {
    expect(
      engine.evaluateReactionFormulas('AlCl3', 'H2O')?.equation,
      'AlCl3 + 3H2O → Al(OH)3↓ + 3HCl',
    );
    expect(
      engine.evaluateReactionFormulas('Al2(SO4)3', 'H2O')?.equation,
      'Al2(SO4)3 + 6H2O → 2Al(OH)3↓ + 3H2SO4',
    );
    expect(
      engine.evaluateReactionFormulas('Na2CO3', 'H2O')?.equation,
      'Na2CO3 + H2O → NaHCO3 + NaOH',
    );
    expect(
      engine.evaluateReactionFormulas('CaC2', 'H2O', temperature: 59),
      isNull,
    );
    expect(
      engine.evaluateReactionFormulas('CaC2', 'H2O', temperature: 60)?.equation,
      'CaC2 + 2H2O → Ca(OH)2↓ + C2H2↑',
    );
    expect(
      engine
          .evaluateReactionFormulas('Al4C3', 'H2O', temperature: 60)
          ?.equation,
      'Al4C3 + 12H2O → 4Al(OH)3↓ + 3CH4↑',
    );
    expect(
      engine.evaluateReactionFormulas('Ca3P2', 'H2O')?.equation,
      'Ca3P2 + 6H2O → 3Ca(OH)2↓ + 2PH3↑',
    );
    expect(
      engine.evaluateReactionFormulas('FeCl3', 'H2O')?.equation,
      'FeCl3 + 3H2O ⇌ Fe(OH)3↓ + 3HCl',
    );
    expect(
      engine.evaluateReactionFormulas('NH4Cl', 'H2O')?.equation,
      'NH4Cl + H2O ⇌ NH4OH + HCl',
    );
    expect(
      engine.evaluateReactionFormulas('CH3COONa', 'H2O')?.equation,
      'CH3COONa + H2O ⇌ CH3COOH + NaOH',
    );
  });

  test('evaluates metal displacement, hot acid, and burner decomposition', () {
    expect(
      engine.evaluateReactionFormulas('Cu', 'AgNO3')?.equation,
      'Cu + 2AgNO3 → Cu(NO3)2 + 2Ag',
    );
    expect(
      engine.evaluateReactionFormulas('Cu', 'H2SO4', temperature: 79),
      isNull,
    );
    expect(
      engine.evaluateReactionFormulas('Cu', 'H2SO4', temperature: 80)?.equation,
      'Cu + 2H2SO4 → CuSO4 + SO2↑ + 2H2O',
    );
    expect(
      engine.evaluateReactionFormulas('Fe', 'Cl2')?.equation,
      '2Fe + 3Cl2 → 2FeCl3',
    );
    expect(
      engine.evaluateReactionFormulas('Fe', 'HCl', temperature: 80)?.equation,
      '2Fe + 6HCl → 2FeCl3 + 3H2↑',
    );
    expect(
      engine.evaluateReactionFormulas('CaCO3', 'HEAT', temperature: 301),
      isNull,
    );
    expect(
      engine
          .evaluateReactionFormulas(
            'CaCO3',
            'HEAT',
            temperature: 301,
            burnerLit: true,
          )
          ?.equation,
      'CaCO3 → CaO + CO2↑',
    );
    expect(
      engine
          .evaluateReactionFormulas(
            'KMnO4',
            'HEAT',
            temperature: 301,
            burnerLit: true,
          )
          ?.equation,
      '2KMnO4 → K2MnO4 + MnO2 + O2↑',
    );
    expect(
      engine
          .evaluateReactionFormulas(
            'Cu(OH)2',
            'HEAT',
            temperature: 301,
            burnerLit: true,
          )
          ?.equation,
      'Cu(OH)2 → CuO + H2O',
    );
  });

  test('acid restores aluminium hydroxide from sodium aluminate', () {
    final stages = engine.evaluateReactionSequence([
      const Chemical(
        id: 'naalo2',
        name: 'Sodium aluminate',
        nameVietnamese: 'Natri aluminat',
        formula: 'NaAlO2',
        category: ChemicalCategory.salt,
        state: ChemicalState.aqueous,
        color: Color(0xFFE2E8F0),
      ),
    ], ChemicalCatalog.hydrochloricAcid);
    final restored = engine.evaluateReactionFormulas('HCl', 'NaAlO2');
    final dissolved = engine.evaluateReactionFormulas('HCl', 'Al(OH)3');

    expect(stages, hasLength(1));
    expect(restored?.equation, 'HCl + NaAlO2 + H2O → Al(OH)3↓ + NaCl');
    expect(dissolved?.equation, '3HCl + Al(OH)3 → AlCl3 + 3H2O');
  });

  test('models excess carbon dioxide dissolving limewater precipitate', () {
    final precipitation = engine.evaluateReactionFormulas('CO2', 'Ca(OH)2');
    final dissolution = engine.evaluateReactionFormulas('CO2', 'CaCO3');

    expect(precipitation?.equation, 'CO2 + Ca(OH)2 → CaCO3↓ + H2O');
    expect(dissolution?.equation, 'CO2 + CaCO3 + H2O → Ca(HCO3)2');
  });

  test(
    'magnesium collision waits for heat and emits carried-velocity products',
    () {
      MoleculeTile createTile({
        required String formula,
        required SymbolicParticleMotion motion,
        required double x,
        required double y,
        bool isFluid = false,
      }) => MoleculeTile(
        formula: formula,
        color: const Color(0xFF475569),
        motion: motion,
        seed: 0.2,
        x: x,
        y: y,
        velocityX: 0.12,
        velocityY: 0,
        isFluid: isFluid,
      );

      final coldMg = createTile(
        formula: 'Mg',
        motion: SymbolicParticleMotion.solid,
        x: 0.5,
        y: 0.7,
      );
      final coldWater = createTile(
        formula: 'H2O',
        motion: SymbolicParticleMotion.suspended,
        x: 0.5,
        y: 0.7,
        isFluid: true,
      );
      final coldParticles = [coldMg, coldWater];
      final physics = MoleculeTilePhysics(random: math.Random(31));

      expect(
        physics.update(
          coldParticles,
          size: const Size(400, 500),
          deltaSeconds: 1 / 60,
          temperature: 69,
        ),
        isEmpty,
      );
      expect(coldParticles.map((particle) => particle.formula), ['Mg', 'H2O']);

      final hotMg = createTile(
        formula: 'Mg',
        motion: SymbolicParticleMotion.solid,
        x: 0.5,
        y: 0.7,
      );
      final hotWater = createTile(
        formula: 'H2O',
        motion: SymbolicParticleMotion.suspended,
        x: 0.5,
        y: 0.7,
        isFluid: true,
      );
      final hotParticles = [hotMg, hotWater];
      final events = physics.update(
        hotParticles,
        size: const Size(400, 500),
        deltaSeconds: 1 / 60,
        temperature: 100,
      );

      expect(events.single.firstFormula, 'Mg');
      expect(events.single.secondFormula, 'H2O');
      expect(
        hotParticles.any((particle) => particle.formula == 'H2O'),
        isFalse,
      );
      final hydroxide = hotParticles.firstWhere(
        (particle) => particle.formula == 'Mg(OH)2',
      );
      expect(hydroxide.motion, SymbolicParticleMotion.precipitate);
      expect(hydroxide.x, closeTo(events.single.x, 0.0001));
      expect(hydroxide.velocityX, closeTo(hotMg.velocityX, 0.0001));
      expect(hotParticles.any((particle) => particle.formula == 'H2'), isTrue);
    },
  );

  test('salt hydrolysis occurs only after a collision with water', () {
    final aluminiumChloride = MoleculeTile(
      formula: 'AlCl3',
      color: Colors.amber,
      motion: SymbolicParticleMotion.solid,
      seed: 0,
      x: 0.5,
      y: 0.65,
    );
    final water = MoleculeTile(
      formula: 'H2O',
      color: Colors.blue,
      motion: SymbolicParticleMotion.suspended,
      seed: 0.1,
      x: 0.5,
      y: 0.65,
      isFluid: true,
    );
    final particles = [aluminiumChloride, water];

    final events = MoleculeTilePhysics(random: math.Random(51)).update(
      particles,
      size: const Size(400, 500),
      deltaSeconds: 1 / 60,
      temperature: 24,
    );

    expect(events.single.firstFormula, 'AlCl3');
    expect(particles.any((particle) => particle.formula == 'Al(OH)3'), isTrue);
    expect(particles.any((particle) => particle.formula == 'HCl'), isTrue);
    expect(particles.any((particle) => particle.formula == 'H2O'), isFalse);
  });

  test('hot carbide hydrolysis creates gases and a thermal shockwave', () {
    final carbide = MoleculeTile(
      formula: 'CaC2',
      color: Colors.grey,
      motion: SymbolicParticleMotion.solid,
      seed: 0,
      x: 0.5,
      y: 0.65,
    );
    final waters = List.generate(
      3,
      (index) => MoleculeTile(
        formula: 'H2O',
        color: Colors.blue,
        motion: SymbolicParticleMotion.suspended,
        seed: index.toDouble() / 10,
        x: 0.5 + index * 0.025,
        y: 0.65,
        isFluid: true,
      ),
    );
    final particles = [carbide, ...waters];

    final events = MoleculeTilePhysics(random: math.Random(52)).update(
      particles,
      size: const Size(400, 500),
      deltaSeconds: 1 / 60,
      temperature: 60,
    );

    expect(events.single.firstFormula, 'CaC2');
    expect(particles.any((particle) => particle.formula == 'Ca(OH)2'), isTrue);
    expect(particles.any((particle) => particle.formula == 'C2H2'), isTrue);
    expect(
      particles.where((particle) => particle.formula == 'H2O'),
      hasLength(1),
    );
    expect(particles.last.thermalTime, greaterThan(0));
  });

  test(
    'hot iron water reaction and basic oxide hydration are collision driven',
    () {
      MoleculeTile tile(
        String formula, {
        required SymbolicParticleMotion motion,
        bool isFluid = false,
        double x = 0.5,
      }) => MoleculeTile(
        formula: formula,
        color: Colors.blueGrey,
        motion: motion,
        seed: 0.1,
        x: x,
        y: 0.65,
        isFluid: isFluid,
      );

      final iron = tile('Fe', motion: SymbolicParticleMotion.solid);
      final water = tile(
        'H2O',
        motion: SymbolicParticleMotion.suspended,
        isFluid: true,
      );
      final hotIronTiles = [iron, water];
      final ironEvents = MoleculeTilePhysics(random: math.Random(53)).update(
        hotIronTiles,
        size: const Size(400, 500),
        deltaSeconds: 1 / 60,
        temperature: 100,
      );
      expect(ironEvents.single.firstFormula, 'Fe');
      expect(
        hotIronTiles.any((particle) => particle.formula == 'Fe(OH)2'),
        isTrue,
      );
      expect(hotIronTiles.any((particle) => particle.formula == 'H2'), isTrue);

      final oxide = tile('CaO', motion: SymbolicParticleMotion.solid);
      final oxideWater = tile(
        'H2O',
        motion: SymbolicParticleMotion.suspended,
        isFluid: true,
      );
      final oxideTiles = [oxide, oxideWater];
      final oxideEvents = MoleculeTilePhysics(random: math.Random(54)).update(
        oxideTiles,
        size: const Size(400, 500),
        deltaSeconds: 1 / 60,
        temperature: 24,
      );
      expect(oxideEvents.single.firstFormula, 'CaO');
      expect(
        oxideTiles.any((particle) => particle.formula == 'Ca(OH)2'),
        isTrue,
      );
    },
  );

  test('burner decomposes a hot solid into particle products', () {
    final carbonate = MoleculeTile(
      formula: 'CaCO3',
      color: Colors.white,
      motion: SymbolicParticleMotion.solid,
      seed: 0.2,
      x: 0.5,
      y: 0.65,
    );
    final tiles = [carbonate];
    final events = MoleculeTilePhysics(random: math.Random(55)).update(
      tiles,
      size: const Size(400, 500),
      deltaSeconds: 1 / 60,
      temperature: 301,
      burnerLit: true,
    );

    expect(events.single.secondFormula, 'HEAT');
    expect(tiles.any((particle) => particle.formula == 'CaCO3'), isFalse);
    expect(tiles.any((particle) => particle.formula == 'CaO'), isTrue);
    expect(tiles.any((particle) => particle.formula == 'CO2'), isTrue);
  });

  test(
    'collision products react with dissolved salts on a later physics frame',
    () {
      final sodium = MoleculeTile(
        formula: 'Na',
        color: Colors.grey,
        motion: SymbolicParticleMotion.solid,
        seed: 0,
        x: 0.5,
        y: 0.65,
      );
      final water = MoleculeTile(
        formula: 'H2O',
        color: Colors.blue,
        motion: SymbolicParticleMotion.suspended,
        seed: 0.1,
        x: 0.5,
        y: 0.65,
        isFluid: true,
      );
      final copperSulfate = MoleculeTile(
        formula: 'CuSO4',
        color: Colors.blue,
        motion: SymbolicParticleMotion.suspended,
        seed: 0.2,
        x: 0.5,
        y: 0.65,
        isFluid: true,
      );
      final particles = [sodium, water, copperSulfate];
      final physics = MoleculeTilePhysics(random: math.Random(41));

      final firstFrame = physics.update(
        particles,
        size: const Size(400, 500),
        deltaSeconds: 1 / 60,
        temperature: 0,
      );
      expect(firstFrame.single.firstFormula, 'Na');
      expect(particles.any((particle) => particle.formula == 'NaOH'), isTrue);
      expect(particles.any((particle) => particle.formula == 'CuSO4'), isTrue);

      final secondFrame = physics.update(
        particles,
        size: const Size(400, 500),
        deltaSeconds: 1 / 60,
        temperature: 0,
      );
      expect(
        secondFrame.any(
          (event) =>
              event.firstFormula == 'NaOH' && event.secondFormula == 'CuSO4',
        ),
        isTrue,
      );
      expect(particles.any((particle) => particle.formula == 'CuSO4'), isFalse);
      expect(
        particles.any((particle) => particle.formula == 'Cu(OH)2'),
        isTrue,
      );
      expect(particles.any((particle) => particle.formula == 'Na2SO4'), isTrue);
    },
  );

  test('potassium stays in the beaker and falls when no water is present', () {
    final potassium = MoleculeTile(
      formula: 'K',
      color: Colors.purple,
      motion: SymbolicParticleMotion.solid,
      seed: 0.1,
      x: 0.5,
      y: 0.2,
    );
    final particles = [potassium];

    MoleculeTilePhysics(random: math.Random(43)).update(
      particles,
      size: const Size(400, 500),
      deltaSeconds: 1 / 30,
      temperature: 24,
    );

    expect(particles, contains(potassium));
    expect(potassium.y, greaterThan(0.2));
  });

  test('iron reacts with hydrochloric acid only after tile collision', () {
    final iron = MoleculeTile(
      formula: 'Fe',
      color: Colors.grey,
      motion: SymbolicParticleMotion.solid,
      seed: 0.1,
      x: 0.5,
      y: 0.7,
    );
    final acid = MoleculeTile(
      formula: 'HCl',
      color: Colors.red,
      motion: SymbolicParticleMotion.suspended,
      seed: 0.2,
      x: 0.5,
      y: 0.7,
      isFluid: true,
    );
    final particles = [iron, acid];
    final reactions = MoleculeTilePhysics(random: math.Random(46)).update(
      particles,
      size: const Size(400, 500),
      deltaSeconds: 1 / 60,
      temperature: 0,
    );

    expect(reactions.single.firstFormula, 'Fe');
    expect(reactions.single.secondFormula, 'HCl');
    expect(particles.any((particle) => particle.formula == 'HCl'), isFalse);
    expect(particles.any((particle) => particle.formula == 'FeCl2'), isTrue);
    expect(particles.any((particle) => particle.formula == 'H2'), isTrue);
  });

  test('excess sodium hydroxide dissolves an aluminium hydroxide tile', () {
    final precipitate = MoleculeTile(
      formula: 'Al(OH)3',
      color: Colors.white,
      motion: SymbolicParticleMotion.precipitate,
      seed: 0,
      x: 0.5,
      y: 0.65,
    );
    final excessBase = MoleculeTile(
      formula: 'NaOH',
      color: Colors.green,
      motion: SymbolicParticleMotion.suspended,
      seed: 0.1,
      x: 0.5,
      y: 0.65,
      isFluid: true,
    );
    final particles = [precipitate, excessBase];

    final events = MoleculeTilePhysics(random: math.Random(44)).update(
      particles,
      size: const Size(400, 500),
      deltaSeconds: 1 / 60,
      temperature: 0,
    );

    expect(events.single.firstFormula, 'Al(OH)3');
    expect(particles.any((particle) => particle.formula == 'Al(OH)3'), isFalse);
    expect(particles.any((particle) => particle.formula == 'NaAlO2'), isTrue);
    expect(particles.any((particle) => particle.formula == 'H2O'), isTrue);
  });

  test('excess carbon dioxide clears the carbonate precipitate', () {
    final carbonDioxide = MoleculeTile(
      formula: 'CO2',
      color: Colors.grey,
      motion: SymbolicParticleMotion.gas,
      seed: 0,
      x: 0.5,
      y: 0.65,
      velocityY: 0,
      remainingLife: 5,
    );
    final carbonate = MoleculeTile(
      formula: 'CaCO3',
      color: Colors.white,
      motion: SymbolicParticleMotion.precipitate,
      seed: 0.1,
      x: 0.5,
      y: 0.65,
    );
    final water = MoleculeTile(
      formula: 'H2O',
      color: Colors.blue,
      motion: SymbolicParticleMotion.suspended,
      seed: 0.2,
      x: 0.51,
      y: 0.65,
      isFluid: true,
    );
    final particles = [carbonDioxide, carbonate, water];

    final events = MoleculeTilePhysics(random: math.Random(45)).update(
      particles,
      size: const Size(400, 500),
      deltaSeconds: 1 / 60,
      temperature: 0,
    );

    expect(events.any((event) => event.firstFormula == 'CO2'), isTrue);
    expect(particles.any((particle) => particle.formula == 'CaCO3'), isFalse);
    expect(
      particles.any((particle) => particle.formula == 'Ca(HCO3)2'),
      isTrue,
    );
  });

  test('uses activity rank to decide single displacement', () {
    const zincIon = ChemicalIon(symbol: 'Zn', charge: 2, activityRank: 7);
    const copperIon = ChemicalIon(symbol: 'Cu', charge: 2, activityRank: 10);
    const zinc = Chemical(
      id: 'custom-zinc',
      name: 'Custom zinc sample',
      nameVietnamese: 'Mẫu kẽm tự tạo',
      formula: 'Zn',
      category: ChemicalCategory.metal,
      state: ChemicalState.solid,
      solubility: Solubility.reactive,
      activityRank: 7,
      color: Color(0xFFC5D3E5),
      cation: zincIon,
    );
    const copperSulfate = Chemical(
      id: 'custom-copper-solution',
      name: 'Custom copper solution',
      nameVietnamese: 'Dung dịch đồng tự tạo',
      formula: 'CuSO4',
      category: ChemicalCategory.salt,
      state: ChemicalState.aqueous,
      color: Color(0xFF91A8F4),
      cation: copperIon,
      anion: ChemicalCatalog.sulfate,
    );
    const copper = Chemical(
      id: 'custom-copper-metal',
      name: 'Custom copper sample',
      nameVietnamese: 'Mẫu đồng tự tạo',
      formula: 'Cu',
      category: ChemicalCategory.metal,
      state: ChemicalState.solid,
      solubility: Solubility.reactive,
      activityRank: 10,
      color: Color(0xFFC5D3E5),
      cation: copperIon,
    );
    const zincSulfate = Chemical(
      id: 'custom-zinc-solution',
      name: 'Custom zinc solution',
      nameVietnamese: 'Dung dịch kẽm tự tạo',
      formula: 'ZnSO4',
      category: ChemicalCategory.salt,
      state: ChemicalState.aqueous,
      color: Color(0xFF91A8F4),
      cation: zincIon,
      anion: ChemicalCatalog.sulfate,
    );

    expect(
      engine.evaluate([zinc, copperSulfate], 24)?.equation,
      'Zn + CuSO4 → ZnSO4 + Cu',
    );
    expect(engine.evaluate([copper, zincSulfate], 24), isNull);
    expect(
      engine.evaluate([
        ChemicalCatalog.ironMetal,
        ChemicalCatalog.hydrochloricAcid,
      ], 24)?.equation,
      'Fe + 2HCl → FeCl2 + H2↑',
    );
    expect(
      engine.evaluate([
        ChemicalCatalog.copperMetal,
        ChemicalCatalog.hydrochloricAcid,
      ], 24),
      isNull,
    );
  });

  test('active oxide and acid-salt gas rules use reagent properties', () {
    final sodiumOxide = ChemicalCatalog.reagents.firstWhere(
      (chemical) => chemical.formula == 'Na2O',
    );
    final oxideReaction = engine.evaluate([
      sodiumOxide,
      ChemicalCatalog.water,
    ], 24);
    expect(oxideReaction?.equation, 'Na2O + H2O → 2NaOH');

    final carbonate = ChemicalCatalog.reagents.firstWhere(
      (chemical) => chemical.formula == 'Na2CO3',
    );
    final gasReaction = engine.evaluate([
      ChemicalCatalog.hydrochloricAcid,
      carbonate,
    ], 24);
    expect(gasReaction?.equation, '2HCl + Na2CO3 → 2NaCl + CO2↑ + H2O');
    expect(gasReaction?.particles.single.kind, ParticleKind.bubble);
  });

  test('catalog contains the requested categories and solvent palette', () {
    expect(
      ChemicalCatalog.reagents.where(
        (item) => item.paletteGroup == PaletteCategory.metals,
      ),
      hasLength(11),
    );
    expect(
      ChemicalCatalog.reagents.where(
        (item) => item.paletteGroup == PaletteCategory.oxides,
      ),
      hasLength(11),
    );
    expect(
      ChemicalCatalog.reagents.where(
        (item) => item.paletteGroup == PaletteCategory.acids,
      ),
      hasLength(7),
    );
    expect(
      ChemicalCatalog.reagents.where(
        (item) => item.paletteGroup == PaletteCategory.bases,
      ),
      hasLength(9),
    );
    expect(
      ChemicalCatalog.reagents.where(
        (item) => item.paletteGroup == PaletteCategory.salts,
      ),
      hasLength(20),
    );
    expect(
      ChemicalCatalog.reagents.where(
        (item) => item.paletteGroup == PaletteCategory.solvents,
      ),
      hasLength(4),
    );
  });

  test('detects precipitation from ions instead of reagent pair entries', () {
    final result = engine.evaluate([
      ChemicalCatalog.silverNitrate,
      ChemicalCatalog.hydrochloricAcid,
    ], 24);

    expect(result?.equation, 'AgNO3 + HCl → AgCl↓ + HNO3');
    expect(result?.type, ReactionType.doubleDisplacement);
    expect(result?.particles.single.kind, ParticleKind.precipitate);
  });

  test('uses realistic precipitate colours for common products', () {
    final silverChloride = engine.evaluate([
      ChemicalCatalog.silverNitrate,
      ChemicalCatalog.hydrochloricAcid,
    ], 24);
    final copperHydroxide = engine.evaluate([
      ChemicalCatalog.reagents.firstWhere(
        (chemical) => chemical.formula == 'CuSO4',
      ),
      ChemicalCatalog.reagents.firstWhere(
        (chemical) => chemical.formula == 'NaOH',
      ),
    ], 24);

    expect(silverChloride?.liquidColor, const Color(0xFFF5F2EE));
    expect(copperHydroxide?.liquidColor, const Color(0xFF5AB8C7));
  });

  test('returns no reaction when no rule matches', () {
    expect(engine.evaluate([ChemicalCatalog.water], 24), isNull);
  });

  testWidgets('chemistry lab shows live results and flushes the beaker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: VirtualChemistryLabScreen(
          key: ValueKey('chemistry-screen'),
          isVietnamese: true,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('palette-filter-acids')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reagent-hcl')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('palette-filter-bases')));
    await tester.tap(find.byKey(const Key('palette-filter-bases')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reagent-naoh')));
    await tester.pump();
    expect(find.text('HCl + NaOH → NaCl + H2O'), findsOneWidget);
    expect(
      find.text('Axit và bazơ trung hòa, tạo thành muối và nước.'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: VirtualChemistryLabScreen(
          key: ValueKey('chemistry-screen'),
          isVietnamese: false,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('The acid and base neutralize, forming a salt and water.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('flush-beaker')));
    await tester.pump();
    expect(find.byKey(const Key('reaction-empty-state')), findsOneWidget);
    expect(find.text('HCl + NaOH → NaCl + H2O'), findsNothing);
  });

  testWidgets('3D bottle table defaults to Flask_05 and adds its reagents', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: VirtualChemistryLabScreen(isVietnamese: true)),
    );

    expect(find.byKey(const Key('chemistry-bottle-table')), findsNothing);
    await tester.tap(find.text('Dụng cụ'));
    await tester.pump();
    expect(find.byKey(const Key('chemistry-bottle-table')), findsOneWidget);
    expect(find.text('Flask_05'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-bottle-flask-01')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-bottle-flask-05')));
    await tester.pump();

    expect(find.text('HCl + NaOH → NaCl + H2O'), findsOneWidget);
  });

  testWidgets('lab shows sodium and collision-driven copper sulfate stages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: VirtualChemistryLabScreen(isVietnamese: true)),
    );

    await tester.ensureVisible(find.byKey(const Key('palette-filter-salts')));
    await tester.tap(find.byKey(const Key('palette-filter-salts')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reagent-cuso4')));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const Key('palette-filter-solvents')),
    );
    await tester.tap(find.byKey(const Key('palette-filter-solvents')));
    await tester.pump();
    final beakerCanvas = find.byType(MoleculeTileCanvas);
    final waterCard = find.byKey(const Key('reagent-h2o'));
    await tester.drag(
      waterCard,
      tester.getCenter(beakerCanvas) - tester.getCenter(waterCard),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final initialWaterTiles =
        (tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: beakerCanvas,
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as MoleculeTilePainter)
            .tiles
            .where((tile) => tile.formula == 'H2O')
            .toList();
    expect(initialWaterTiles, hasLength(greaterThan(20)));
    expect(
      initialWaterTiles.map((tile) => tile.y).reduce(math.min),
      lessThan(0.55),
    );
    expect(
      initialWaterTiles.map((tile) => tile.y).reduce(math.max),
      greaterThan(0.75),
    );

    await tester.ensureVisible(find.byKey(const Key('palette-filter-metals')));
    await tester.tap(find.byKey(const Key('palette-filter-metals')));
    await tester.pump();
    final canvasPainter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: beakerCanvas,
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as MoleculeTilePainter;
    final waterTile = canvasPainter.tiles.firstWhere(
      (tile) => tile.formula == 'H2O',
    );
    expect(
      canvasPainter.tiles.where((tile) => tile.formula == 'H2O'),
      hasLength(100),
    );
    for (final tile in canvasPainter.tiles.where(
      (tile) => tile.formula == 'CuSO4',
    )) {
      tile
        ..x = waterTile.x
        ..y = waterTile.y;
    }
    final canvasSize = tester.getSize(beakerCanvas);
    final target =
        tester.getTopLeft(beakerCanvas) +
        Offset(waterTile.x * canvasSize.width, waterTile.y * canvasSize.height);
    final sodiumCard = find.byKey(const Key('reagent-na'));
    await tester.drag(sodiumCard, target - tester.getCenter(sodiumCard));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2Na + 2H2O → 2NaOH + H2↑'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 950));
    expect(find.text('2NaOH + CuSO4 → Cu(OH)2↓ + Na2SO4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('potassium and water render molecule tiles in the beaker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: VirtualChemistryLabScreen(isVietnamese: true)),
    );

    await tester.ensureVisible(
      find.byKey(const Key('palette-filter-solvents')),
    );
    await tester.tap(find.byKey(const Key('palette-filter-solvents')));
    await tester.pump();
    final beakerCanvas = find.byType(MoleculeTileCanvas);
    final waterCard = find.byKey(const Key('reagent-h2o'));
    await tester.drag(
      waterCard,
      tester.getCenter(beakerCanvas) - tester.getCenter(waterCard),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final firstSpawnPainter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: beakerCanvas,
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as MoleculeTilePainter;
    expect(
      firstSpawnPainter.tiles.where((tile) => tile.formula == 'H2O'),
      hasLength(100),
    );
    await tester.drag(
      waterCard,
      tester.getCenter(beakerCanvas) - tester.getCenter(waterCard),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final secondSpawnPainter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: beakerCanvas,
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as MoleculeTilePainter;
    expect(
      secondSpawnPainter.tiles.where((tile) => tile.formula == 'H2O'),
      hasLength(200),
    );

    await tester.ensureVisible(find.byKey(const Key('palette-filter-metals')));
    await tester.tap(find.byKey(const Key('palette-filter-metals')));
    await tester.pump();
    final canvasPainter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: beakerCanvas,
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as MoleculeTilePainter;
    final waterTile = canvasPainter.tiles.firstWhere(
      (tile) => tile.formula == 'H2O',
    );
    final canvasSize = tester.getSize(beakerCanvas);
    final target =
        tester.getTopLeft(beakerCanvas) +
        Offset(waterTile.x * canvasSize.width, waterTile.y * canvasSize.height);
    final potassiumCard = find.byKey(const Key('reagent-k'));
    await tester.drag(potassiumCard, target - tester.getCenter(potassiumCard));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('2K + 2H2O → 2KOH + H2↑'), findsOneWidget);
    final canvasFinder = find.descendant(
      of: find.byType(MoleculeTileCanvas),
      matching: find.byType(CustomPaint),
    );
    final painter =
        tester.widget<CustomPaint>(canvasFinder).painter!
            as MoleculeTilePainter;
    final painterSize = tester.getSize(canvasFinder);
    expect(painterSize.width, greaterThan(0));
    expect(painterSize.height, greaterThan(0));
    final remainingWaterTiles = painter.tiles
        .where((tile) => tile.formula == 'H2O')
        .length;
    expect(remainingWaterTiles, 199);
    expect(painter.tiles.any((tile) => tile.formula == 'K'), isTrue);
    expect(painter.tiles.any((tile) => tile.formula == 'H2O'), isTrue);
    expect(painter.tiles.any((tile) => tile.formula == 'KOH'), isTrue);
    expect(painter.tiles.any((tile) => tile.formula == 'H2'), isTrue);
    expect(
      painter.tiles.every(
        (tile) =>
            tile.x >= 0.22 &&
            tile.x <= 0.78 &&
            tile.y >= 0.08 &&
            tile.y <= 0.89,
      ),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragged solid starts at its release point in the beaker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: VirtualChemistryLabScreen(isVietnamese: true)),
    );

    final canvas = find.byType(MoleculeTileCanvas);
    final canvasSize = tester.getSize(canvas);
    final releasePoint =
        tester.getTopLeft(canvas) +
        Offset(canvasSize.width * 0.5, canvasSize.height * 0.4);
    final magnesium = find.byKey(const Key('reagent-mg'));
    await tester.drag(magnesium, releasePoint - tester.getCenter(magnesium));
    await tester.pump(const Duration(milliseconds: 16));

    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: canvas,
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as MoleculeTilePainter;
    final particle = painter.tiles.firstWhere((tile) => tile.formula == 'Mg');
    expect(particle.x, closeTo(0.5, 0.02));
    expect(particle.y, closeTo(0.4, 0.02));
    expect(particle.velocityY, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('chemistry room opens the 3D chemistry lab screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VirtualLabScreen(isVietnamese: true)),
    );

    await tester.tap(find.byKey(const Key('open-laboratory')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('laboratory-room-1')));
    await tester.pump();
    expect(find.text('Phòng thí nghiệm Hóa học 3D'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chemistry-lab-back')));
    await tester.pump();
    expect(find.byKey(const Key('laboratory-room-1')), findsOneWidget);
  });

  testWidgets('atomic model room opens its interactive virtual lab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: VirtualLabScreen(isVietnamese: true)),
    );

    await tester.tap(find.byKey(const Key('open-laboratory')));
    await tester.pumpAndSettle();
    expect(find.text('Mô hình nguyên tử'), findsOneWidget);

    await tester.tap(find.byKey(const Key('laboratory-room-3')));
    await tester.pump();
    expect(find.text('Mô hình nguyên tử'), findsOneWidget);
    expect(find.byKey(const Key('atomic-preset-0')), findsOneWidget);

    final skinPicker = tester.widget<PopupMenuButton<int>>(
      find.byKey(const Key('atomic-skin-picker')),
    );
    skinPicker.onSelected!(1);
    await tester.pump();
    expect(find.text('Cực quang'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
      const Color(0xFF101A19),
    );

    await tester.tap(find.byKey(const Key('atomic-preset-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('fire-neutron')));
    await tester.pump();
    expect(find.text('1'), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const Key('atomic-lab-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('laboratory-room-3')), findsOneWidget);
  });

  testWidgets('palette category filters reagents and search narrows results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: VirtualChemistryLabScreen(isVietnamese: true)),
    );

    expect(find.byKey(const Key('palette-category-scrollbar')), findsOneWidget);
    expect(find.byKey(const Key('reagent-k')), findsOneWidget);
    expect(find.byKey(const Key('reagent-hcl')), findsNothing);
    final potassiumFormula = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('reagent-k')),
        matching: find.text('K'),
      ),
    );
    expect(potassiumFormula.style?.color, MoleculeTile.reagentTextColor('K'));
    await tester.ensureVisible(find.byKey(const Key('palette-filter-salts')));
    await tester.tap(find.byKey(const Key('palette-filter-salts')));
    await tester.pump();
    expect(find.byKey(const Key('reagent-agno3')), findsOneWidget);
    expect(find.byKey(const Key('reagent-k')), findsNothing);

    await tester.enterText(find.byKey(const Key('reagent-search')), 'AgNO3');
    await tester.pump();
    expect(find.byKey(const Key('reagent-agno3')), findsOneWidget);
    expect(find.byKey(const Key('reagent-nacl')), findsNothing);
  });

  testWidgets('beaker controls pause simulation and toggle half speed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: VirtualChemistryLabScreen(isVietnamese: true)),
    );

    final pause = find.byKey(const Key('simulation-pause'));
    final slowMotion = find.byKey(const Key('simulation-slow-motion'));
    expect(find.text('Tạm dừng'), findsOneWidget);
    expect(find.text('1×'), findsOneWidget);

    await tester.tap(pause);
    await tester.pump();
    expect(find.text('Tiếp tục'), findsOneWidget);

    await tester.tap(slowMotion);
    await tester.pump();
    expect(find.text('0.5×'), findsOneWidget);

    await tester.tap(pause);
    await tester.pump();
    expect(find.text('Tạm dừng'), findsOneWidget);
  });
}
