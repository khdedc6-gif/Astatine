import 'package:flutter/material.dart';

import 'chemical_models.dart';

class ReactionEngine {
  const ReactionEngine();

  List<ReactionResult> evaluateReactionSequence(
    List<Chemical> contents,
    Chemical addedChemical, {
    double temperature = 24,
    bool isVietnamese = false,
  }) {
    if (const {'K', 'Na', 'Ba', 'Ca'}.contains(addedChemical.formula) &&
        contents.any((item) => item.formula == 'H2O')) {
      final salt = contents.where(
        (item) => const {
          'CuSO4',
          'FeCl3',
          'AlCl3',
          'Al2(SO4)3',
          'ZnSO4',
          'ZnCl2',
          'FeSO4',
        }.contains(item.formula),
      );
      if (salt.isNotEmpty) {
        final hydroxide = switch (addedChemical.formula) {
          'K' => 'KOH',
          'Na' => 'NaOH',
          'Ba' => 'Ba(OH)2',
          _ => 'Ca(OH)2',
        };
        final base = ChemicalCatalog.reagents.firstWhere(
          (item) => item.formula == hydroxide,
        );
        final first = evaluateReaction(
          addedChemical,
          ChemicalCatalog.water,
          temperature: temperature,
          isVietnamese: isVietnamese,
        );
        final second = evaluateReaction(
          base,
          salt.first,
          temperature: temperature,
          isVietnamese: isVietnamese,
        );
        if (first != null && second != null) return [first, second];
      }
    }
    if (addedChemical.formula == 'NaOH' &&
        contents.any((item) => item.formula == 'AlCl3')) {
      final precipitation = evaluateReactionFormulas(
        'NaOH',
        'AlCl3',
        temperature: temperature,
        isVietnamese: isVietnamese,
      );
      final addedBefore = contents
          .where((item) => item.formula == 'NaOH')
          .length;
      final hasPrecipitate = contents.any((item) => item.formula == 'Al(OH)3');
      final dissolve = evaluateReactionFormulas(
        'Al(OH)3',
        'NaOH',
        temperature: temperature,
        isVietnamese: isVietnamese,
      );
      if (hasPrecipitate && dissolve != null) return [dissolve];
      if (addedBefore >= 1 && precipitation != null && dissolve != null) {
        return [precipitation, dissolve];
      }
      if (precipitation != null) return [precipitation];
    }

    if (addedChemical.formula == 'CO2' &&
        contents.any((item) => item.formula == 'CaCO3')) {
      final dissolve = evaluateReactionFormulas(
        'CO2',
        'CaCO3',
        temperature: temperature,
        isVietnamese: isVietnamese,
      );
      if (dissolve != null) return [dissolve];
    }

    if (addedChemical.formula == 'HCl' &&
        contents.any((item) => item.formula == 'NaAlO2')) {
      final dissolution = contents.any((item) => item.formula == 'Al(OH)3');
      final first = evaluateReactionFormulas(
        'HCl',
        dissolution ? 'Al(OH)3' : 'NaAlO2',
        temperature: temperature,
        isVietnamese: isVietnamese,
      );
      if (first != null) return [first];
    }

    for (final chemical in contents.reversed) {
      final result =
          evaluateReaction(
            addedChemical,
            chemical,
            temperature: temperature,
            isVietnamese: isVietnamese,
          ) ??
          evaluateReaction(
            chemical,
            addedChemical,
            temperature: temperature,
            isVietnamese: isVietnamese,
          );
      if (result != null) return [result];
    }
    return const [];
  }

  ReactionResult? evaluateReactionFormulas(
    String firstFormula,
    String secondFormula, {
    double temperature = 24,
    bool isVietnamese = false,
    bool burnerLit = false,
  }) {
    final temp = temperature.clamp(0.0, 400.0).toDouble();
    final thermal = burnerLit
        ? _thermalDecomposition(firstFormula, secondFormula, temp, isVietnamese)
        : null;
    if (thermal != null) return thermal;
    final custom = _specialFormulaReaction(
      firstFormula,
      secondFormula,
      temp,
      isVietnamese,
    );
    if (custom != null) return custom;
    final hydrolysis = _hydrolysisReaction(
      firstFormula,
      secondFormula,
      temp,
      isVietnamese,
    );
    if (hydrolysis != null) return hydrolysis;
    final first = ChemicalCatalog.reagents
        .where((chemical) => chemical.formula == firstFormula)
        .firstOrNull;
    final second = ChemicalCatalog.reagents
        .where((chemical) => chemical.formula == secondFormula)
        .firstOrNull;
    if (first == null || second == null) return null;
    return evaluateReaction(
          first,
          second,
          temperature: temp,
          isVietnamese: isVietnamese,
        ) ??
        evaluateReaction(
          second,
          first,
          temperature: temp,
          isVietnamese: isVietnamese,
        );
  }

  ReactionResult? _specialFormulaReaction(
    String first,
    String second,
    double temperature,
    bool vi,
  ) {
    final pair = {first, second};
    if (pair.contains('HCl') && pair.contains('NaAlO2')) {
      final equation = _balance(
        [const _Term('HCl'), const _Term('NaAlO2'), const _Term('H2O')],
        [const _Term('Al(OH)3', precipitate: true), const _Term('NaCl')],
      );
      if (equation == null) return null;
      return _result(
        type: ReactionType.doubleDisplacement,
        equation: _render(equation),
        phenomenon: vi
            ? 'Axit làm xuất hiện lại kết tủa keo nhôm hiđroxit từ dung dịch aluminat.'
            : 'Acid regenerates the gelatinous aluminium hydroxide precipitate from aluminate solution.',
        color: const Color(0xFFE2E8F0),
        temperature: temperature,
        heat: 8,
      );
    }
    if (pair.contains('HCl') && pair.contains('Al(OH)3')) {
      final equation = _balance(
        [const _Term('HCl'), const _Term('Al(OH)3')],
        [const _Term('AlCl3'), const _Term('H2O')],
      );
      if (equation == null) return null;
      return _result(
        type: ReactionType.neutralization,
        equation: _render(equation),
        phenomenon: vi
            ? 'Axit dư hòa tan kết tủa nhôm hiđroxit, tạo dung dịch nhôm clorua.'
            : 'Excess acid dissolves aluminium hydroxide precipitate, forming aluminium chloride solution.',
        color: const Color(0xFFE7B2B2),
        temperature: temperature,
        heat: 10,
      );
    }
    if (temperature >= 80 && pair.contains('Cu') && pair.contains('H2SO4')) {
      final equation = 'Cu + 2H2SO4 → CuSO4 + SO2↑ + 2H2O';
      return _result(
        type: ReactionType.gasEvolution,
        equation: equation,
        phenomenon: vi
            ? 'Đồng phản ứng với axit sunfuric đặc, nóng tạo đồng sunfat, khí lưu huỳnh đioxit và nước.'
            : 'Copper reacts with hot concentrated sulfuric acid to form copper sulfate, sulfur dioxide, and water.',
        color: const Color(0xFF268FC0),
        temperature: temperature,
        heat: 26,
        hasGas: true,
      );
    }
    if (pair.contains('Cu') && pair.contains('AgNO3')) {
      return _result(
        type: ReactionType.singleDisplacement,
        equation: 'Cu + 2AgNO3 → Cu(NO3)2 + 2Ag',
        phenomenon: vi
            ? 'Đồng đẩy bạc khỏi dung dịch bạc nitrat; bạc bám lên bề mặt đồng.'
            : 'Copper displaces silver from silver nitrate; silver deposits on the copper surface.',
        color: const Color(0xFF6FBFD6),
        temperature: temperature,
        heat: 8,
      );
    }
    if (pair.contains('Fe') && pair.contains('Cl2')) {
      return _result(
        type: ReactionType.singleDisplacement,
        equation: '2Fe + 3Cl2 → 2FeCl3',
        phenomenon: vi
            ? 'Sắt phản ứng với clo tạo sắt(III) clorua màu vàng nâu.'
            : 'Iron reacts with chlorine to form yellow-brown iron(III) chloride.',
        color: const Color(0xFFD97706),
        temperature: temperature,
        heat: 32,
      );
    }
    if (temperature >= 80 && pair.contains('Fe') && pair.contains('HCl')) {
      return _result(
        type: ReactionType.gasEvolution,
        equation: '2Fe + 6HCl → 2FeCl3 + 3H2↑',
        phenomenon: vi
            ? 'Sắt tác dụng với axit clohiđric khi đun nóng tạo sắt(III) clorua và khí hiđro.'
            : 'Heated iron reacts with hydrochloric acid to form iron(III) chloride and hydrogen gas.',
        color: const Color(0xFFD97706),
        temperature: temperature,
        heat: 18,
        hasGas: true,
      );
    }
    if (pair.contains('KOH') ||
        pair.contains('NaOH') ||
        pair.contains('Ba(OH)2') ||
        pair.contains('Ca(OH)2')) {
      final base = [
        'KOH',
        'NaOH',
        'Ba(OH)2',
        'Ca(OH)2',
      ].firstWhere(pair.contains, orElse: () => '');
      final metal = switch (base) {
        'KOH' => 'K',
        'NaOH' => 'Na',
        'Ba(OH)2' => 'Ba',
        'Ca(OH)2' => 'Ca',
        _ => '',
      };
      final salt = [
        'CuSO4',
        'FeCl3',
        'AlCl3',
        'Al2(SO4)3',
        'ZnSO4',
        'ZnCl2',
        'FeSO4',
      ].firstWhere(pair.contains, orElse: () => '');
      if (base.isNotEmpty && salt.isNotEmpty) {
        final hydroxide = switch (salt) {
          'CuSO4' => 'Cu(OH)2',
          'FeCl3' => 'Fe(OH)3',
          'FeSO4' || 'FeCl2' => 'Fe(OH)2',
          'AlCl3' || 'Al2(SO4)3' => 'Al(OH)3',
          'ZnSO4' || 'ZnCl2' => 'Zn(OH)2',
          _ => '',
        };
        final solubleSalt = switch (salt) {
          'CuSO4' || 'ZnSO4' || 'Al2(SO4)3' || 'FeSO4' =>
            const {'Ba', 'Ca'}.contains(metal) ? '${metal}SO4' : '${metal}2SO4',
          'FeCl3' || 'AlCl3' =>
            const {'Ba', 'Ca'}.contains(metal) ? '${metal}Cl2' : '${metal}Cl',
          _ => '',
        };
        if (hydroxide.isNotEmpty && solubleSalt.isNotEmpty) {
          final equation = _balance(
            [_Term(base), _Term(salt)],
            [_Term(hydroxide, precipitate: true), _Term(solubleSalt)],
          );
          if (equation != null) {
            final precipitateColor = switch (hydroxide) {
              'Cu(OH)2' => const Color(0xFF5AB8C7),
              'Fe(OH)3' => const Color(0xFFC8663A),
              'Fe(OH)2' => const Color(0xFF6A9B57),
              'Al(OH)3' || 'Zn(OH)2' => const Color(0xFFE6E0D3),
              _ => const Color(0xFF83CFC0),
            };
            return _result(
              type: ReactionType.doubleDisplacement,
              equation: _render(equation),
              phenomenon: vi
                  ? 'Bazơ phản ứng với dung dịch muối tạo kết tủa hiđroxit.'
                  : 'The base reacts with the salt solution to form a hydroxide precipitate.',
              color: precipitateColor,
              temperature: temperature,
              heat: 10,
              particles: [
                ReactionParticle(
                  kind: ParticleKind.precipitate,
                  color: const Color(0xFFE6E0D3),
                  count: 20,
                ),
              ],
            );
          }
        }
      }
    }
    if (pair.contains('NaOH') && pair.contains('AlCl3')) {
      final equation = _balance(
        [const _Term('NaOH'), const _Term('AlCl3')],
        [const _Term('Al(OH)3', precipitate: true), const _Term('NaCl')],
      );
      if (equation == null) return null;
      return _result(
        type: ReactionType.doubleDisplacement,
        equation: _render(equation),
        phenomenon: vi
            ? 'Bazơ và muối nhôm tạo kết tủa keo trắng nhôm hiđroxit.'
            : 'The base reacts with aluminium chloride to form a white aluminium hydroxide precipitate.',
        color: const Color(0xFFE2E8F0),
        temperature: temperature,
        heat: 8,
        particles: [
          ReactionParticle(
            kind: ParticleKind.precipitate,
            color: const Color(0xFFE6E0D3),
            count: 20,
          ),
        ],
      );
    }
    if (pair.contains('Al(OH)3') && pair.contains('NaOH')) {
      final equation = _balance(
        [const _Term('Al(OH)3'), const _Term('NaOH')],
        [const _Term('NaAlO2'), const _Term('H2O')],
      );
      if (equation == null) return null;
      return _result(
        type: ReactionType.doubleDisplacement,
        equation: _render(equation),
        phenomenon: vi
            ? 'Kết tủa nhôm hiđroxit tan trong lượng dư natri hiđroxit.'
            : 'Aluminium hydroxide precipitate dissolves in excess sodium hydroxide.',
        color: const Color(0xFF83CFC0),
        temperature: temperature,
        heat: 8,
      );
    }

    final bicarbonateCation = first == 'CO2' ? second : first;
    if (pair.contains('CO2') &&
        const {'CaCO3', 'BaCO3'}.contains(bicarbonateCation)) {
      final cation = bicarbonateCation.substring(0, 2) == 'Ba' ? 'Ba' : 'Ca';
      final equation = _balance(
        [_Term('CO2'), _Term(bicarbonateCation), const _Term('H2O')],
        [_Term('$cation(HCO3)2')],
      );
      if (equation == null) return null;
      return _result(
        type: ReactionType.doubleDisplacement,
        equation: _render(equation),
        phenomenon: vi
            ? 'Kết tủa cacbonat tan khi có khí CO2 dư, tạo muối hiđrocacbonat tan.'
            : 'Excess carbon dioxide dissolves the carbonate precipitate into soluble bicarbonate.',
        color: const Color(0xFF95D5E8),
        temperature: temperature,
        heat: 6,
      );
    }

    final sulfiteCation = first == 'SO2' ? second : first;
    if (pair.contains('SO2') &&
        const {'CaSO3', 'BaSO3'}.contains(sulfiteCation)) {
      final cation = sulfiteCation.substring(0, 2) == 'Ba' ? 'Ba' : 'Ca';
      final equation = _balance(
        [_Term('SO2'), _Term(sulfiteCation), const _Term('H2O')],
        [_Term('$cation(HSO3)2')],
      );
      if (equation == null) return null;
      return _result(
        type: ReactionType.doubleDisplacement,
        equation: _render(equation),
        phenomenon: vi
            ? 'Khí SO2 dư chuyển kết tủa sunfit thành hiđrosunfit tan.'
            : 'Excess sulfur dioxide converts the sulfite precipitate into soluble bisulfite.',
        color: const Color(0xFF95D5E8),
        temperature: temperature,
        heat: 6,
      );
    }
    return null;
  }

  ReactionResult? _hydrolysisReaction(
    String first,
    String second,
    double temperature,
    bool vi,
  ) {
    final pair = {first, second};
    String? equation;
    String? phenomenon;
    Color? color;
    var hasGas = false;
    var heat = 5.0;
    if (pair.contains('AlCl3') && pair.contains('H2O')) {
      equation = 'AlCl3 + 3H2O → Al(OH)3↓ + 3HCl';
      phenomenon = vi
          ? 'Muối nhôm thủy phân nhẹ, tạo môi trường axit và một ít kết tủa keo.'
          : 'Aluminium chloride hydrolyses slightly, making the solution acidic and forming a small amount of gelatinous precipitate.';
      color = const Color(0xFFE9A6A6);
    } else if (pair.contains('FeCl3') && pair.contains('H2O')) {
      equation = 'FeCl3 + 3H2O ⇌ Fe(OH)3↓ + 3HCl';
      phenomenon = vi
          ? 'Sắt(III) clorua thủy phân tạo môi trường axit và một ít kết tủa keo; quỳ tím hóa đỏ.'
          : 'Iron(III) chloride hydrolyses to an acidic solution with a small amount of gelatinous precipitate; litmus turns red.';
      color = const Color(0xFFE9A6A6);
    } else if (pair.contains('Al2(SO4)3') && pair.contains('H2O')) {
      equation = 'Al2(SO4)3 + 6H2O → 2Al(OH)3↓ + 3H2SO4';
      phenomenon = vi
          ? 'Nhôm sunfat thủy phân nhẹ, làm dung dịch có tính axit.'
          : 'Aluminium sulfate hydrolyses slightly, making the solution acidic.';
      color = const Color(0xFFE9A6A6);
    } else if (pair.contains('Na2CO3') && pair.contains('H2O')) {
      equation = 'Na2CO3 + H2O → NaHCO3 + NaOH';
      phenomenon = vi
          ? 'Ion cacbonat thủy phân tạo môi trường bazơ (pH > 7).'
          : 'Carbonate ions hydrolyse to produce a basic solution (pH > 7).';
      color = const Color(0xFF9AD6B3);
    } else if (pair.contains('CH3COONa') && pair.contains('H2O')) {
      equation = 'CH3COONa + H2O ⇌ CH3COOH + NaOH';
      phenomenon = vi
          ? 'Natri axetat thủy phân tạo môi trường bazơ, làm quỳ tím hóa xanh.'
          : 'Sodium acetate hydrolyses to a basic solution, turning litmus blue.';
      color = const Color(0xFF9AD6B3);
    } else if (pair.contains('NH4Cl') && pair.contains('H2O')) {
      equation = 'NH4Cl + H2O ⇌ NH4OH + HCl';
      phenomenon = vi
          ? 'Amoni clorua thủy phân tạo môi trường axit; quỳ tím hóa đỏ.'
          : 'Ammonium chloride hydrolyses to an acidic solution; litmus turns red.';
      color = const Color(0xFFE9A6A6);
    } else if (temperature >= 60 &&
        pair.contains('CaC2') &&
        pair.contains('H2O')) {
      equation = 'CaC2 + 2H2O → Ca(OH)2↓ + C2H2↑';
      phenomenon = vi
          ? 'Canxi cacbua thủy phân tỏa nhiệt, tạo kết tủa và khí axetilen.'
          : 'Calcium carbide hydrolyses exothermically, forming a precipitate and acetylene gas.';
      color = const Color(0xFFB6D8C5);
      hasGas = true;
      heat = 42;
    } else if (temperature >= 60 &&
        pair.contains('Al4C3') &&
        pair.contains('H2O')) {
      equation = 'Al4C3 + 12H2O → 4Al(OH)3↓ + 3CH4↑';
      phenomenon = vi
          ? 'Nhôm cacbua thủy phân tỏa nhiệt, tạo kết tủa keo và khí metan.'
          : 'Aluminium carbide hydrolyses exothermically, forming gelatinous precipitate and methane gas.';
      color = const Color(0xFFB6D8C5);
      hasGas = true;
      heat = 48;
    } else if (pair.contains('Ca3P2') && pair.contains('H2O')) {
      equation = 'Ca3P2 + 6H2O → 3Ca(OH)2↓ + 2PH3↑';
      phenomenon = vi
          ? 'Canxi photphua thủy phân tỏa nhiệt, tạo canxi hiđroxit và khí photphin.'
          : 'Calcium phosphide hydrolyses exothermically, forming calcium hydroxide and phosphine gas.';
      color = const Color(0xFFB6D8C5);
      hasGas = true;
      heat = 48;
    } else if (temperature >= 60 &&
        pair.contains('Ca3P2') &&
        pair.contains('H2O')) {
      equation = 'Ca3P2 + 6H2O → 3Ca(OH)2↓ + 2PH3↑';
      phenomenon = vi
          ? 'Canxi photphua thủy phân tỏa nhiệt, tạo canxi hiđroxit và khí photphin.'
          : 'Calcium phosphide hydrolyses exothermically, forming calcium hydroxide and phosphine gas.';
      color = const Color(0xFFB6D8C5);
      hasGas = true;
      heat = 48;
    }
    if (equation == null || phenomenon == null || color == null) return null;
    return _result(
      type: ReactionType.hydrolysis,
      equation: equation,
      phenomenon: phenomenon,
      color: color,
      temperature: temperature,
      heat: heat,
      hasGas: hasGas,
      particles: hasGas
          ? [
              ReactionParticle(
                kind: ParticleKind.bubble,
                color: const Color(0xFFF1F5F9),
                count: _bubbleCount(temperature, heat),
                speed: _bubbleSpeed(temperature, heat) * 0.65,
              ),
              ReactionParticle(
                kind: ParticleKind.precipitate,
                color: const Color(0xFFE6E0D3),
                count: 24,
              ),
            ]
          : const [
              ReactionParticle(
                kind: ParticleKind.precipitate,
                color: Color(0xFFE6E0D3),
                count: 8,
              ),
            ],
    );
  }

  ReactionResult? evaluateReaction(
    Chemical first,
    Chemical second, {
    double temperature = 24,
    bool isVietnamese = false,
    bool burnerLit = false,
  }) => evaluateLocalized(
    [first, second],
    temperature,
    isVietnamese: isVietnamese,
    burnerLit: burnerLit,
  );

  ReactionResult? evaluate(List<Chemical> contents, double temperature) =>
      evaluateLocalized(contents, temperature);

  ReactionResult? evaluateLocalized(
    List<Chemical> contents,
    double temperature, {
    bool isVietnamese = false,
    bool burnerLit = false,
  }) {
    final temp = temperature.clamp(0.0, 400.0).toDouble();
    if (burnerLit && temp > 300) {
      for (final reagent in contents.reversed) {
        final result = _thermalDecomposition(
          reagent.formula,
          'HEAT',
          temp,
          isVietnamese,
        );
        if (result != null) return result;
      }
    }
    if (contents.length < 2) return null;
    final directPair = _localizedSpecialPair(contents, temp, isVietnamese);
    return directPair ??
        _hydrolysis(contents, temp, isVietnamese) ??
        _metalWater(contents, temp, isVietnamese) ??
        _oxideWater(contents, temp, isVietnamese) ??
        _oxideAcid(contents, temp, isVietnamese) ??
        _amphotericOxideBase(contents, temp, isVietnamese) ??
        _acidicOxideBase(contents, temp, isVietnamese) ??
        _oxideCombination(contents, temp, isVietnamese) ??
        _acidGas(contents, temp, isVietnamese) ??
        _neutralization(contents, temp, isVietnamese) ??
        _singleDisplacement(contents, temp, isVietnamese) ??
        _doubleDisplacement(contents, temp, isVietnamese);
  }

  ReactionResult? _localizedSpecialPair(
    List<Chemical> contents,
    double temperature,
    bool vi,
  ) {
    for (var first = 0; first < contents.length; first++) {
      for (var second = first + 1; second < contents.length; second++) {
        final result = _specialFormulaReaction(
          contents[first].formula,
          contents[second].formula,
          temperature,
          vi,
        );
        if (result != null) return result;
      }
    }
    return null;
  }

  ReactionResult? _thermalDecomposition(
    String formula,
    String trigger,
    double temperature,
    bool vi,
  ) {
    if (trigger != 'HEAT' || temperature <= 300) return null;
    final reaction = switch (formula) {
      'CaCO3' => (
        'CaCO3 → CaO + CO2↑',
        vi
            ? 'Canxi cacbonat bị nhiệt phân thành canxi oxit và khí cacbon đioxit.'
            : 'Calcium carbonate thermally decomposes into calcium oxide and carbon dioxide.',
      ),
      'KMnO4' => (
        '2KMnO4 → K2MnO4 + MnO2 + O2↑',
        vi
            ? 'Kali pemanganat bị nhiệt phân, giải phóng khí oxi.'
            : 'Potassium permanganate thermally decomposes, releasing oxygen.',
      ),
      'Cu(OH)2' => (
        'Cu(OH)2 → CuO + H2O',
        vi
            ? 'Đồng(II) hiđroxit bị nhiệt phân thành đồng(II) oxit màu đen và nước.'
            : 'Copper(II) hydroxide thermally decomposes into black copper(II) oxide and water.',
      ),
      _ => null,
    };
    if (reaction == null) return null;
    return _result(
      type: ReactionType.thermalDecomposition,
      equation: reaction.$1,
      phenomenon: reaction.$2,
      color: const Color(0xFFDF8C51),
      temperature: temperature,
      heat: 14,
      hasGas: formula == 'CaCO3' || formula == 'KMnO4',
    );
  }

  ReactionResult? _hydrolysis(List<Chemical> contents, double temp, bool vi) {
    for (final reagent in contents) {
      if (!const {
        'AlCl3',
        'FeCl3',
        'Al2(SO4)3',
        'Na2CO3',
        'CH3COONa',
        'NH4Cl',
        'CaC2',
        'Al4C3',
        'Ca3P2',
      }.contains(reagent.formula)) {
        continue;
      }
      if (!contents.any((item) => item.formula == 'H2O')) continue;
      final result = _hydrolysisReaction(reagent.formula, 'H2O', temp, vi);
      if (result != null) return result;
    }
    return null;
  }

  ReactionResult? _metalWater(List<Chemical> contents, double temp, bool vi) {
    if (!contents.any((item) => item.category == ChemicalCategory.water)) {
      return null;
    }
    for (final metal in contents.where(
      (item) => item.category == ChemicalCategory.metal,
    )) {
      final ion = metal.cation;
      final hotMetal =
          temp >= 70 && const {'Mg', 'Al', 'Zn', 'Fe'}.contains(metal.formula);
      if ((!metal.reactsWithWater && !hotMetal) || ion == null) continue;
      final base = _ionicFormula(ion, ChemicalCatalog.hydroxide);
      final equation = _balance(
        [_Term(metal.formula), const _Term('H2O')],
        [_Term(base, precipitate: hotMetal), const _Term('H2', gas: true)],
      );
      if (equation == null) continue;
      return _result(
        type: ReactionType.metalWater,
        equation: _render(equation),
        phenomenon: hotMetal
            ? vi
                  ? 'Magiê phản ứng chậm với nước nóng, tạo kết tủa magiê hiđroxit và khí hiđro.'
                  : 'Magnesium reacts gradually with hot water, forming magnesium hydroxide precipitate and hydrogen gas.'
            : vi
            ? 'Kim loại kiềm phản ứng mãnh liệt với nước, tạo bazơ và khí hiđro.'
            : 'The alkali metal reacts vigorously with water, producing a base and hydrogen gas.',
        color: const Color(0xFF3F9BCB),
        temperature: temp,
        heat: hotMetal ? 18 : 48,
        hasGas: true,
        explosive: metal.isAlkaliMetal,
        particles: [
          ReactionParticle(
            kind: ParticleKind.bubble,
            color: const Color(0xFFD1F8FF),
            count: _bubbleCount(temp, hotMetal ? 18 : 48),
            speed: hotMetal
                ? _bubbleSpeed(temp, 18) * 0.55
                : _bubbleSpeed(temp, 48),
          ),
        ],
      );
    }
    return null;
  }

  ReactionResult? _oxideWater(List<Chemical> contents, double temp, bool vi) {
    if (!contents.any((item) => item.category == ChemicalCategory.water)) {
      return null;
    }
    for (final oxide in contents.where(
      (item) => item.category == ChemicalCategory.oxide,
    )) {
      if (!oxide.reactsWithWater) continue;
      final product = oxide.oxideKind == OxideKind.acidic
          ? oxide.waterProductFormula
          : oxide.cation == null
          ? null
          : _ionicFormula(oxide.cation!, ChemicalCatalog.hydroxide);
      if (product == null) continue;
      final equation = _balance(
        [_Term(oxide.formula), const _Term('H2O')],
        [_Term(product)],
      );
      if (equation == null) continue;
      final acidic = oxide.oxideKind == OxideKind.acidic;
      return _result(
        type: ReactionType.oxideWater,
        equation: _render(equation),
        phenomenon: vi
            ? acidic
                  ? 'Oxit axit tan trong nước tạo thành dung dịch axit.'
                  : 'Oxit bazơ hoạt động phản ứng với nước tạo thành bazơ.'
            : acidic
            ? 'The acidic oxide forms an acid when dissolved in water.'
            : 'The active basic oxide reacts with water to form a base.',
        color: const Color(0xFF429AC1),
        temperature: temp,
        heat: 12,
      );
    }
    return null;
  }

  ReactionResult? _oxideAcid(List<Chemical> contents, double temp, bool vi) {
    for (final oxide in contents.where(
      (item) =>
          item.category == ChemicalCategory.oxide &&
          item.oxideKind != OxideKind.acidic,
    )) {
      final cation = oxide.cation;
      if (cation == null) continue;
      for (final acid in contents.where(
        (item) => item.category == ChemicalCategory.acid,
      )) {
        final anion = acid.anion;
        if (anion == null) continue;
        final salt = _ionicFormula(cation, anion);
        final insoluble = !_isSoluble(cation, anion);
        final equation = _balance(
          [_Term(oxide.formula), _Term(acid.formula)],
          [_Term(salt, precipitate: insoluble), const _Term('H2O')],
        );
        if (equation == null) continue;
        final color = insoluble
            ? _precipitateColor(cation, anion)
            : const Color(0xFF50A8D4);
        return _result(
          type: ReactionType.doubleDisplacement,
          equation: _render(equation),
          phenomenon: vi
              ? oxide.oxideKind == OxideKind.amphoteric
                    ? 'Oxit lưỡng tính phản ứng với axit tạo muối và nước.'
                    : 'Oxit bazơ phản ứng với axit tạo muối và nước.'
              : oxide.oxideKind == OxideKind.amphoteric
              ? 'The amphoteric oxide reacts with the acid to form a salt and water.'
              : 'The basic oxide reacts with the acid to form a salt and water.',
          color: color,
          temperature: temp,
          heat: 14,
          particles: insoluble
              ? [
                  ReactionParticle(
                    kind: ParticleKind.precipitate,
                    color: color,
                    count: 24,
                  ),
                ]
              : const [],
        );
      }
    }
    return null;
  }

  ReactionResult? _amphotericOxideBase(
    List<Chemical> contents,
    double temp,
    bool vi,
  ) {
    if (temp < 300) return null;
    for (final oxide in contents.where(
      (item) =>
          item.category == ChemicalCategory.oxide &&
          item.oxideKind == OxideKind.amphoteric &&
          item.formula == 'Al2O3',
    )) {
      for (final base in contents.where(
        (item) =>
            item.category == ChemicalCategory.base &&
            const {'NaOH', 'KOH'}.contains(item.formula),
      )) {
        final cation = base.cation;
        if (cation == null) continue;
        final aluminate = '${cation.symbol}AlO2';
        final equation = _balance(
          [_Term(oxide.formula), _Term(base.formula)],
          [_Term(aluminate), const _Term('H2O')],
        );
        if (equation == null) continue;
        return _result(
          type: ReactionType.doubleDisplacement,
          equation: _render(equation),
          phenomenon: vi
              ? 'Nhôm oxit phản ứng với kiềm nóng chảy, tạo muối aluminat và nước.'
              : 'Aluminium oxide reacts with molten alkali to form an aluminate salt and water.',
          color: const Color(0xFF52A6CF),
          temperature: temp,
          heat: 16,
        );
      }
    }
    return null;
  }

  ReactionResult? _acidicOxideBase(
    List<Chemical> contents,
    double temp,
    bool vi,
  ) {
    for (final oxide in contents.where(
      (item) =>
          item.category == ChemicalCategory.oxide &&
          item.oxideKind == OxideKind.acidic,
    )) {
      Chemical? acid;
      for (final reagent in ChemicalCatalog.reagents) {
        if (reagent.category == ChemicalCategory.acid &&
            reagent.formula == oxide.waterProductFormula) {
          acid = reagent;
          break;
        }
      }
      final anion = acid?.anion;
      if (anion == null) continue;
      for (final base in contents.where(
        (item) => item.category == ChemicalCategory.base,
      )) {
        final cation = base.cation;
        if (cation == null) continue;
        final salt = _ionicFormula(cation, anion);
        final insoluble = !_isSoluble(cation, anion);
        final equation = _balance(
          [_Term(oxide.formula), _Term(base.formula)],
          [_Term(salt, precipitate: insoluble), const _Term('H2O')],
        );
        if (equation == null) continue;
        final color = insoluble
            ? _precipitateColor(cation, anion)
            : const Color(0xFF52A6CF);
        return _result(
          type: ReactionType.doubleDisplacement,
          equation: _render(equation),
          phenomenon: vi ? 'Oxit axit phản ứng với bazơ tạo muối và nước.' : 'The acidic oxide reacts with the base to form a salt and water.',
          color: color,
          temperature: temp,
          heat: 12,
          particles: insoluble
              ? [
                  ReactionParticle(
                    kind: ParticleKind.precipitate,
                    color: color,
                    count: 26,
                  ),
                ]
              : const [],
        );
      }
    }
    return null;
  }

  ReactionResult? _oxideCombination(
    List<Chemical> contents,
    double temp,
    bool vi,
  ) {
    for (final acidicOxide in contents.where(
      (item) =>
          item.category == ChemicalCategory.oxide &&
          item.oxideKind == OxideKind.acidic,
    )) {
      final acid = ChemicalCatalog.reagents
          .where(
            (item) =>
                item.category == ChemicalCategory.acid &&
                item.formula == acidicOxide.waterProductFormula,
          )
          .firstOrNull;
      final anion = acid?.anion;
      if (anion == null) continue;
      for (final basicOxide in contents.where(
        (item) =>
            item.category == ChemicalCategory.oxide &&
            item.oxideKind == OxideKind.basic,
      )) {
        final cation = basicOxide.cation;
        if (cation == null) continue;
        final salt = _ionicFormula(cation, anion);
        final insoluble = !_isSoluble(cation, anion);
        final equation = _balance(
          [_Term(acidicOxide.formula), _Term(basicOxide.formula)],
          [_Term(salt, precipitate: insoluble)],
        );
        if (equation == null) continue;
        final color = insoluble
            ? _precipitateColor(cation, anion)
            : const Color(0xFF50A8D4);
        return _result(
          type: ReactionType.doubleDisplacement,
          equation: _render(equation),
          phenomenon: vi
              ? 'Oxit axit phản ứng với oxit bazơ tạo thành muối.'
              : 'The acidic oxide reacts with the basic oxide to form a salt.',
          color: color,
          temperature: temp,
          heat: 14,
          particles: insoluble
              ? [
                  ReactionParticle(
                    kind: ParticleKind.precipitate,
                    color: color,
                    count: 24,
                  ),
                ]
              : const [],
        );
      }
    }
    return null;
  }

  ReactionResult? _acidGas(List<Chemical> contents, double temp, bool vi) {
    for (final acid in contents.where(
      (item) => item.category == ChemicalCategory.acid,
    )) {
      final acidAnion = acid.anion;
      if (acidAnion == null) continue;
      for (final salt in contents.where(
        (item) => item.category == ChemicalCategory.salt,
      )) {
        final gasFormula = salt.anion?.gasWithAcid;
        final cation = salt.cation;
        if (gasFormula == null || cation == null) continue;
        final saltProduct = _ionicFormula(cation, acidAnion);
        final insoluble = !_isSoluble(cation, acidAnion);
        final products = <_Term>[
          _Term(saltProduct, precipitate: insoluble),
          _Term(gasFormula, gas: true),
          if (gasFormula != 'H2S') const _Term('H2O'),
        ];
        final equation = _balance([
          _Term(acid.formula),
          _Term(salt.formula),
        ], products);
        if (equation == null) continue;
        return _result(
          type: ReactionType.gasEvolution,
          equation: _render(equation),
          phenomenon: vi
              ? 'Khí $gasFormula thoát ra khi axit phản ứng với muối.'
              : '$gasFormula gas is released as the acid reacts with the salt.',
          color: const Color(0xFF58AFCB),
          temperature: temp,
          heat: 16,
          hasGas: true,
          particles: [
            ReactionParticle(
              kind: ParticleKind.bubble,
              color: const Color(0xFFD4FAFF),
              count: _bubbleCount(temp, 16),
              speed: _bubbleSpeed(temp, 16),
            ),
            if (insoluble)
              ReactionParticle(
                kind: ParticleKind.precipitate,
                color: _precipitateColor(cation, acidAnion),
                count: 24,
              ),
          ],
        );
      }
    }
    return null;
  }

  ReactionResult? _neutralization(
    List<Chemical> contents,
    double temp,
    bool vi,
  ) {
    for (final acid in contents.where(
      (item) => item.category == ChemicalCategory.acid,
    )) {
      if (acid.anion == null || acid.acidProtons == 0) continue;
      for (final base in contents.where(
        (item) => item.category == ChemicalCategory.base,
      )) {
        if (base.cation == null || base.baseHydroxides == 0) continue;
        final insoluble = !_isSoluble(base.cation!, acid.anion!);
        final salt = _ionicFormula(base.cation!, acid.anion!);
        final equation = _balance(
          [_Term(acid.formula), _Term(base.formula)],
          [_Term(salt, precipitate: insoluble), const _Term('H2O')],
        );
        if (equation == null) continue;
        return _result(
          type: ReactionType.neutralization,
          equation: _render(equation),
          phenomenon: vi
              ? insoluble
                    ? 'Phản ứng trung hòa tỏa nhiệt, đồng thời xuất hiện kết tủa muối.'
                    : 'Axit và bazơ trung hòa, tạo thành muối và nước.'
              : insoluble
              ? 'Neutralization releases heat and forms an insoluble salt precipitate.'
              : 'The acid and base neutralize, forming a salt and water.',
          color: const Color(0xFF53B9D6),
          temperature: temp,
          heat: 20,
          particles: insoluble
              ? [
                  ReactionParticle(
                    kind: ParticleKind.precipitate,
                    color: _precipitateColor(base.cation!, acid.anion!),
                    count: 28,
                  ),
                ]
              : const [],
        );
      }
    }
    return null;
  }

  ReactionResult? _singleDisplacement(
    List<Chemical> contents,
    double temp,
    bool vi,
  ) {
    for (final metal in contents.where(
      (item) => item.category == ChemicalCategory.metal,
    )) {
      final metalIon = metal.cation;
      if (metalIon == null) continue;
      for (final solution in contents.where(
        (item) =>
            item.category == ChemicalCategory.salt ||
            item.category == ChemicalCategory.acid &&
                const {'HCl', 'H2SO4'}.contains(item.formula),
      )) {
        final displacedIon = solution.cation;
        final anion = solution.anion;
        if (displacedIon == null ||
            anion == null ||
            (solution.category == ChemicalCategory.salt &&
                solution.cation?.isAlkaliMetal == true) ||
            (solution.category == ChemicalCategory.salt &&
                const {'K', 'Na', 'Ba', 'Ca'}.contains(metalIon.symbol)) ||
            metal.activityRank >= displacedIon.activityRank ||
            metalIon.symbol == displacedIon.symbol) {
          continue;
        }
        final newSalt = _ionicFormula(metalIon, anion);
        final acid = solution.category == ChemicalCategory.acid;
        final insoluble = !_isSoluble(metalIon, anion);
        final equation = _balance(
          [_Term(metal.formula), _Term(solution.formula)],
          [
            _Term(newSalt, precipitate: insoluble),
            _Term(acid ? 'H2' : displacedIon.symbol, gas: acid),
          ],
        );
        if (equation == null) continue;
        return _result(
          type: ReactionType.singleDisplacement,
          equation: _render(equation),
          phenomenon: vi
              ? 'Kim loại hoạt động mạnh hơn đẩy ion kim loại yếu hơn khỏi dung dịch.'
              : 'The more active metal displaces the less active metal from solution.',
          color: const Color(0xFF579DC4),
          temperature: temp,
          heat: 14,
          hasGas: acid,
          particles: [
            if (acid)
              ReactionParticle(
                kind: ParticleKind.bubble,
                color: const Color(0xFFD4FAFF),
                count: _bubbleCount(temp, 14),
                speed: _bubbleSpeed(temp, 14),
              ),
            if (insoluble)
              ReactionParticle(
                kind: ParticleKind.precipitate,
                color: _precipitateColor(metalIon, anion),
                count: 26,
              ),
          ],
        );
      }
    }
    return null;
  }

  ReactionResult? _doubleDisplacement(
    List<Chemical> contents,
    double temp,
    bool vi,
  ) {
    const ionic = {
      ChemicalCategory.salt,
      ChemicalCategory.acid,
      ChemicalCategory.base,
    };
    for (var i = 0; i < contents.length; i++) {
      final first = contents[i];
      if (!ionic.contains(first.category) ||
          first.cation == null ||
          first.anion == null) {
        continue;
      }
      for (var j = i + 1; j < contents.length; j++) {
        final second = contents[j];
        if (!ionic.contains(second.category) ||
            second.cation == null ||
            second.anion == null) {
          continue;
        }
        final firstProduct = _ionicFormula(first.cation!, second.anion!);
        final secondProduct = _ionicFormula(second.cation!, first.anion!);
        final firstFalls = !_isSoluble(first.cation!, second.anion!);
        final secondFalls = !_isSoluble(second.cation!, first.anion!);
        if (!firstFalls && !secondFalls) continue;
        final products =
            [
              _Term(firstProduct, precipitate: firstFalls),
              _Term(secondProduct, precipitate: secondFalls),
            ]..sort(
              (first, second) => (first.precipitate ? 0 : 1).compareTo(
                second.precipitate ? 0 : 1,
              ),
            );
        final equation = _balance([
          _Term(first.formula),
          _Term(second.formula),
        ], products);
        if (equation == null) continue;
        final cat = firstFalls ? first.cation! : second.cation!;
        final an = firstFalls ? second.anion! : first.anion!;
        final color = _precipitateColor(cat, an);
        return _result(
          type: ReactionType.doubleDisplacement,
          equation: _render(equation),
          phenomenon: vi
              ? 'Các ion đổi vị trí; chất không tan tách khỏi dung dịch thành kết tủa.'
              : 'The ions exchange partners; an insoluble product separates as a precipitate.',
          color: color,
          temperature: temp,
          heat: 10,
          particles: [
            ReactionParticle(
              kind: ParticleKind.precipitate,
              color: color,
              count: 32,
            ),
          ],
        );
      }
    }
    return null;
  }

  ReactionResult _result({
    required ReactionType type,
    required String equation,
    required String phenomenon,
    required Color color,
    required double temperature,
    required double heat,
    bool hasGas = false,
    bool explosive = false,
    List<ReactionParticle> particles = const [],
  }) {
    final heatRelease = (heat * (1 + temperature / 500)).clamp(0.0, 100.0);
    final intensity = explosive || (hasGas && temperature >= 82)
        ? ReactionIntensity.explosive
        : heatRelease >= 30 || (hasGas && temperature >= 58)
        ? ReactionIntensity.vigorous
        : ReactionIntensity.normal;
    return ReactionResult(
      type: type,
      equation: equation,
      phenomenon: phenomenon,
      liquidColor: color,
      heatRelease: heatRelease,
      intensity: intensity,
      particles: particles,
      textParticles: _textParticlesFromEquation(equation),
    );
  }

  List<MoleculeTile> _textParticlesFromEquation(String equation) {
    final separator = equation.indexOf('→');
    if (separator < 0) return const [];
    final products = equation.substring(separator + 1).split(' + ');
    final particles = <MoleculeTile>[];
    for (final rawProduct in products) {
      final product = rawProduct.trim();
      final gas = product.endsWith('↑');
      final precipitate = product.endsWith('↓');
      final formula = product
          .replaceAll(RegExp(r'^\d+'), '')
          .replaceAll(RegExp('[↑↓]'), '');
      final coefficient =
          int.tryParse(RegExp(r'^\d+').firstMatch(product)?.group(0) ?? '') ??
          1;
      final motion = gas
          ? SymbolicParticleMotion.gas
          : precipitate
          ? SymbolicParticleMotion.precipitate
          : SymbolicParticleMotion.suspended;
      final color = switch (formula) {
        'H2' || 'CO2' || 'SO2' || 'Cl2' || 'O2' => const Color(0xFFF4FAFF),
        'Cu' => const Color(0xFFD97943),
        'Ag' => const Color(0xFFD6E0EA),
        'AgCl' || 'BaSO4' || 'CaCO3' || 'BaCO3' => const Color(0xFFF2F0EB),
        'Cu(OH)2' => const Color(0xFF42AFC5),
        'Fe(OH)3' => const Color(0xFFC8663A),
        'Fe(OH)2' => const Color(0xFF6A9B57),
        'CuS' => const Color(0xFF252A2E),
        _ =>
          ChemicalCatalog.reagents
                  .where((item) => item.formula == formula)
                  .firstOrNull
                  ?.color ??
              const Color(0xFFD9E2EE),
      };
      final copies = coefficient.clamp(1, 6);
      for (var index = 0; index < copies; index++) {
        final particleIndex = particles.length;
        particles.add(
          MoleculeTile(
            formula: formula,
            color: color,
            motion: motion,
            seed: ((particleIndex * 37 + formula.length * 13) % 100) / 100,
            x: 0.34 + ((particleIndex * 17) % 32) / 100,
            y: precipitate ? 0.48 : 0.62,
          ),
        );
      }
    }
    return particles;
  }

  bool _isSoluble(ChemicalIon cation, ChemicalIon anion) {
    final c = cation.symbol;
    final a = anion.symbol;
    if (cation.isAlkaliMetal || c == 'NH4' || a == 'NO3' || a == 'CH3COO') {
      return true;
    }
    if (const {'Cl', 'Br', 'I'}.contains(a)) {
      return !const {'Ag', 'Pb', 'Hg'}.contains(c);
    }
    if (a == 'SO4') return !const {'Ba', 'Pb', 'Sr'}.contains(c);
    if (const {'CO3', 'PO4', 'S', 'SO3'}.contains(a)) return false;
    if (a == 'OH') return const {'Ba', 'Ca'}.contains(c);
    return true;
  }

  Color _precipitateColor(ChemicalIon cation, ChemicalIon anion) {
    final c = cation.symbol;
    final a = anion.symbol;

    if (c == 'Ag' && a == 'Cl') return const Color(0xFFF5F2EE);
    if (c == 'Ba' && a == 'SO4') return const Color(0xFFF8F5F1);
    if (c == 'Ca' && a == 'CO3') return const Color(0xFFF1EEE8);
    if (c == 'Cu' && a == 'OH') return const Color(0xFF5AB8C7);
    if (c == 'Fe' && a == 'OH' && cation.charge == 2) {
      return const Color(0xFF58A76C);
    }
    if (c == 'Fe' && a == 'OH' && cation.charge == 3) {
      return const Color(0xFFCB6D3A);
    }
    if (c == 'Al' && a == 'OH') return const Color(0xFFE6E0D3);
    if (c == 'Mg' && a == 'OH') return const Color(0xFFEFE5D8);
    if (c == 'Zn' && a == 'OH') return const Color(0xFFE6E7EA);
    if (a == 'S') return const Color(0xFF1E2731);
    if (a == 'CO3') return const Color(0xFFF3F0EA);
    if (a == 'OH') return const Color(0xFF8CCFC0);
    if (a == 'SO4') return const Color(0xFFF3F3F0);
    if (a == 'Cl') return const Color(0xFFF5F2EE);
    return const Color(0xFFE9EEF5);
  }

  int _bubbleCount(double temp, double heat) =>
      (4 + temp * 0.25 + heat * 0.3).round().clamp(4, 48);

  double _bubbleSpeed(double temp, double heat) => 0.6 + temp / 35 + heat / 30;

  String _ionicFormula(ChemicalIon cation, ChemicalIon anion) {
    final divisor = _gcd(cation.charge.abs(), anion.charge.abs());
    final positive = anion.charge.abs() ~/ divisor;
    final negative = cation.charge.abs() ~/ divisor;
    String part(ChemicalIon ion, int count) => count == 1
        ? ion.symbol
        : '${ion.isPolyatomic ? '(${ion.symbol})' : ion.symbol}$count';
    return '${part(cation, positive)}${part(anion, negative)}';
  }

  _BalancedEquation? _balance(List<_Term> reactants, List<_Term> products) {
    final terms = [...reactants, ...products];
    final atoms = terms.map((term) => _parseFormula(term.formula)).toList();
    if (atoms.any((map) => map.isEmpty)) return null;
    final coefficients = List<int>.filled(terms.length, 1);
    List<int>? best;
    var minimum = 1 << 30;
    void search(int index, int sum) {
      if (sum >= minimum) return;
      if (index == terms.length) {
        final totals = <String, int>{};
        for (var i = 0; i < terms.length; i++) {
          final sign = i < reactants.length ? 1 : -1;
          atoms[i].forEach(
            (element, count) => totals.update(
              element,
              (value) => value + sign * count * coefficients[i],
              ifAbsent: () => sign * count * coefficients[i],
            ),
          );
        }
        if (totals.values.every((value) => value == 0)) {
          best = List<int>.of(coefficients);
          minimum = sum;
        }
        return;
      }
      for (var value = 1; value <= 8; value++) {
        coefficients[index] = value;
        search(index + 1, sum + value);
      }
    }

    search(0, 0);
    final values = best;
    if (values == null) return null;
    return _BalancedEquation(
      [
        for (var i = 0; i < reactants.length; i++)
          reactants[i].withCoefficient(values[i]),
      ],
      [
        for (var i = 0; i < products.length; i++)
          products[i].withCoefficient(values[reactants.length + i]),
      ],
    );
  }

  Map<String, int> _parseFormula(String formula) {
    final source = formula.replaceAll(RegExp('[↑↓]'), '');
    var cursor = 0;
    int readNumber() {
      final start = cursor;
      while (cursor < source.length && RegExp(r'\d').hasMatch(source[cursor])) {
        cursor++;
      }
      return start == cursor ? 1 : int.parse(source.substring(start, cursor));
    }

    Map<String, int> readGroup() {
      final result = <String, int>{};
      while (cursor < source.length && source[cursor] != ')') {
        if (source[cursor] == '(') {
          cursor++;
          final inner = readGroup();
          if (cursor < source.length && source[cursor] == ')') cursor++;
          final multiplier = readNumber();
          inner.forEach(
            (element, count) => result.update(
              element,
              (value) => value + count * multiplier,
              ifAbsent: () => count * multiplier,
            ),
          );
        } else if (RegExp(r'[A-Z]').hasMatch(source[cursor])) {
          final start = cursor++;
          if (cursor < source.length &&
              RegExp(r'[a-z]').hasMatch(source[cursor])) {
            cursor++;
          }
          final element = source.substring(start, cursor);
          final count = readNumber();
          result.update(
            element,
            (value) => value + count,
            ifAbsent: () => count,
          );
        } else {
          return {};
        }
      }
      return result;
    }

    return readGroup();
  }

  String _render(_BalancedEquation equation) {
    String term(_Term item) {
      final number = item.coefficient == 1 ? '' : '${item.coefficient}';
      final mark = item.precipitate
          ? '↓'
          : item.gas
          ? '↑'
          : '';
      return '$number${item.formula}$mark';
    }

    return '${equation.reactants.map(term).join(' + ')} → ${equation.products.map(term).join(' + ')}';
  }

  int _gcd(int a, int b) {
    while (b != 0) {
      final remainder = a % b;
      a = b;
      b = remainder;
    }
    return a;
  }
}

class ReactionQueue {
  final List<ReactionResult> _stages = [];

  bool get isEmpty => _stages.isEmpty;
  int get length => _stages.length;

  void enqueue(ReactionResult stage) {
    _stages.add(stage);
  }

  void enqueueAll(Iterable<ReactionResult> stages) {
    _stages.addAll(stages);
  }

  void replaceWith(Iterable<ReactionResult> stages) {
    _stages.clear();
    enqueueAll(stages);
  }

  ReactionResult? takeNext() => _stages.isEmpty ? null : _stages.removeAt(0);

  void clear() => _stages.clear();
}

class _Term {
  const _Term(
    this.formula, {
    this.coefficient = 1,
    this.gas = false,
    this.precipitate = false,
  });
  final String formula;
  final int coefficient;
  final bool gas;
  final bool precipitate;
  _Term withCoefficient(int value) =>
      _Term(formula, coefficient: value, gas: gas, precipitate: precipitate);
}

class _BalancedEquation {
  const _BalancedEquation(this.reactants, this.products);
  final List<_Term> reactants;
  final List<_Term> products;
}
