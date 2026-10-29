export 'reaction_engine.dart';

import 'package:flutter/material.dart';

import 'chemical_models.dart';

class ChemicalReactionEngine {
  const ChemicalReactionEngine();

  ReactionResult? evaluate(
    List<ChemicalClass> contents, {
    bool isVietnamese = false,
  }) {
    final metalReaction = _findMetalWaterReaction(contents, isVietnamese);
    if (metalReaction != null) return metalReaction;

    final neutralization = _findNeutralization(contents, isVietnamese);
    if (neutralization != null) return neutralization;

    return _findPrecipitation(contents, isVietnamese);
  }

  ReactionResult? _findMetalWaterReaction(
    List<ChemicalClass> contents,
    bool isVietnamese,
  ) {
    for (final metal in contents) {
      if (metal.category != ChemicalCategory.metal ||
          !metal.isAlkaliMetal ||
          metal.cation?.charge != 1) {
        continue;
      }
      if (!contents.any((item) => item.category == ChemicalCategory.water)) {
        continue;
      }

      final hydroxide = ChemicalIon(
        symbol: 'OH',
        charge: -1,
        isPolyatomic: true,
      );
      final base = _ionicFormula(metal.cation!, hydroxide).formula;
      return ReactionResult(
        type: ReactionType.metalWater,
        equation: '2${metal.formula} + 2H2O → 2$base + H2↑',
        phenomenon: isVietnamese
            ? 'Kim loại phản ứng mạnh với nước, tạo dung dịch bazơ và khí hiđro.'
            : 'The metal reacts vigorously with water, forming a base and hydrogen gas.',
        liquidColor: const Color(0xFF4DA7D8),
        particles: const [
          ReactionParticle(
            kind: ParticleKind.bubble,
            color: Color(0xFFB5F3FF),
            count: 24,
          ),
        ],
      );
    }
    return null;
  }

  ReactionResult? _findNeutralization(
    List<ChemicalClass> contents,
    bool isVietnamese,
  ) {
    for (final acid in contents) {
      if (acid.category != ChemicalCategory.acid ||
          acid.acidProtons <= 0 ||
          acid.anion == null) {
        continue;
      }
      for (final base in contents) {
        if (base.category != ChemicalCategory.base ||
            base.baseHydroxides <= 0 ||
            base.cation == null) {
          continue;
        }

        final divisor = _gcd(acid.acidProtons, base.baseHydroxides);
        final acidCoefficient = base.baseHydroxides ~/ divisor;
        final baseCoefficient = acid.acidProtons ~/ divisor;
        final salt = _ionicFormula(base.cation!, acid.anion!);
        final acidAnions = acidCoefficient * acid.anionCount;
        final baseCations = baseCoefficient * base.cationCount;
        if (acidAnions % salt.anionCount != 0 ||
            baseCations % salt.cationCount != 0) {
          continue;
        }
        final saltFromAcid = acidAnions ~/ salt.anionCount;
        final saltFromBase = baseCations ~/ salt.cationCount;
        if (saltFromAcid != saltFromBase) continue;

        final waterCoefficient = acidCoefficient * acid.acidProtons;
        final equation = _formatEquation(
          [
            _EquationTerm(acidCoefficient, acid.formula),
            _EquationTerm(baseCoefficient, base.formula),
          ],
          [
            _EquationTerm(saltFromAcid, salt.formula),
            _EquationTerm(waterCoefficient, 'H2O'),
          ],
        );
        return ReactionResult(
          type: ReactionType.neutralization,
          equation: equation,
          phenomenon: isVietnamese
              ? 'Axit và bazơ trung hòa, tạo thành muối và nước.'
              : 'The acid and base neutralize, forming a salt and water.',
          liquidColor: const Color(0xFF56BFEA),
        );
      }
    }
    return null;
  }

  ReactionResult? _findPrecipitation(
    List<ChemicalClass> contents,
    bool isVietnamese,
  ) {
    for (var cationIndex = 0; cationIndex < contents.length; cationIndex++) {
      final cationSource = contents[cationIndex];
      final cation = cationSource.cation;
      final counterAnion = cationSource.anion;
      if (cation == null || counterAnion == null) continue;

      for (var anionIndex = 0; anionIndex < contents.length; anionIndex++) {
        if (cationIndex == anionIndex) continue;
        final anionSource = contents[anionIndex];
        final anion = anionSource.anion;
        final counterCation = anionSource.cation;
        if (anion == null ||
            counterCation == null ||
            !_isInsoluble(cation, anion)) {
          continue;
        }

        final precipitate = _ionicFormula(cation, anion);
        final spectator = _ionicFormula(counterCation, counterAnion);
        final coefficients = _balanceDoubleDisplacement(
          cationSource,
          anionSource,
          precipitate,
          spectator,
        );
        if (coefficients == null) continue;

        return ReactionResult(
          type: ReactionType.doubleDisplacement,
          equation: _formatEquation(
            [
              _EquationTerm(coefficients.first, cationSource.formula),
              _EquationTerm(coefficients.second, anionSource.formula),
            ],
            [
              _EquationTerm(coefficients.third, '${precipitate.formula}↓'),
              _EquationTerm(coefficients.fourth, spectator.formula),
            ],
          ),
          phenomenon: isVietnamese
              ? 'Hai dung dịch trao đổi ion, tạo thành chất rắn kết tủa.'
              : 'The solutions exchange ions and form an insoluble precipitate.',
          liquidColor: const Color(0xFFB7C7D9),
          particles: const [
            ReactionParticle(
              kind: ParticleKind.precipitate,
              color: Color(0xFFE8EDF2),
              count: 32,
            ),
          ],
        );
      }
    }
    return null;
  }

  bool _isInsoluble(ChemicalIon cation, ChemicalIon anion) {
    if (cation.charge <= 0 || anion.charge >= 0 || cation.isAlkaliMetal) {
      return false;
    }
    if (anion.symbol == 'NO3' || anion.symbol == 'CH3COO') return false;

    if (const {'Cl', 'Br', 'I'}.contains(anion.symbol)) {
      return const {'Ag', 'Pb', 'Hg'}.contains(cation.symbol);
    }
    if (anion.symbol == 'SO4') {
      return const {'Ba', 'Sr', 'Pb', 'Ca'}.contains(cation.symbol);
    }
    if (const {'CO3', 'PO4', 'OH', 'S'}.contains(anion.symbol)) {
      return true;
    }
    return false;
  }

  _DoubleDisplacementCoefficients? _balanceDoubleDisplacement(
    ChemicalClass cationSource,
    ChemicalClass anionSource,
    _IonicFormula precipitate,
    _IonicFormula spectator,
  ) {
    for (var first = 1; first <= 24; first++) {
      final precipitateFromCation = first * cationSource.cationCount;
      if (precipitateFromCation % precipitate.cationCount != 0) continue;
      final precipitateUnits = precipitateFromCation ~/ precipitate.cationCount;

      for (var second = 1; second <= 24; second++) {
        final precipitateFromAnion = second * anionSource.anionCount;
        if (precipitateFromAnion % precipitate.anionCount != 0 ||
            precipitateFromAnion ~/ precipitate.anionCount !=
                precipitateUnits) {
          continue;
        }

        final spectatorFromFirst = first * cationSource.anionCount;
        final spectatorFromSecond = second * anionSource.cationCount;
        if (spectatorFromFirst % spectator.anionCount != 0 ||
            spectatorFromSecond % spectator.cationCount != 0) {
          continue;
        }
        final spectatorFromFirstUnits =
            spectatorFromFirst ~/ spectator.anionCount;
        final spectatorFromSecondUnits =
            spectatorFromSecond ~/ spectator.cationCount;
        if (spectatorFromFirstUnits != spectatorFromSecondUnits) continue;

        return _DoubleDisplacementCoefficients(
          first,
          second,
          precipitateUnits,
          spectatorFromFirstUnits,
        );
      }
    }
    return null;
  }

  _IonicFormula _ionicFormula(ChemicalIon cation, ChemicalIon anion) {
    final divisor = _gcd(cation.charge.abs(), anion.charge.abs());
    final cationCount = anion.charge.abs() ~/ divisor;
    final anionCount = cation.charge.abs() ~/ divisor;
    return _IonicFormula(
      '${_ionPart(cation, cationCount)}${_ionPart(anion, anionCount)}',
      cationCount,
      anionCount,
    );
  }

  String _ionPart(ChemicalIon ion, int count) {
    if (count == 1) return ion.symbol;
    final symbol = ion.isPolyatomic ? '(${ion.symbol})' : ion.symbol;
    return '$symbol$count';
  }

  int _gcd(int first, int second) {
    var a = first;
    var b = second;
    while (b != 0) {
      final remainder = a % b;
      a = b;
      b = remainder;
    }
    return a;
  }

  String _formatEquation(
    List<_EquationTerm> reactants,
    List<_EquationTerm> products,
  ) {
    String format(_EquationTerm term) =>
        '${term.coefficient == 1 ? '' : term.coefficient}${term.formula}';
    return '${reactants.map(format).join(' + ')} → '
        '${products.map(format).join(' + ')}';
  }
}

class _IonicFormula {
  const _IonicFormula(this.formula, this.cationCount, this.anionCount);

  final String formula;
  final int cationCount;
  final int anionCount;
}

class _DoubleDisplacementCoefficients {
  const _DoubleDisplacementCoefficients(
    this.first,
    this.second,
    this.third,
    this.fourth,
  );

  final int first;
  final int second;
  final int third;
  final int fourth;
}

class _EquationTerm {
  const _EquationTerm(this.coefficient, this.formula);

  final int coefficient;
  final String formula;
}
