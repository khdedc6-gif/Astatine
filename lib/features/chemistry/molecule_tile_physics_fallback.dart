import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chemical_models.dart';

class BeakerReactionEvent {
  const BeakerReactionEvent({
    required this.metalFormula,
    required this.x,
    required this.y,
    required this.firstFormula,
    required this.secondFormula,
  });

  final String metalFormula;
  final double x;
  final double y;
  final String firstFormula;
  final String secondFormula;
}

class MoleculeTilePhysicsFallback {
  MoleculeTilePhysicsFallback({math.Random? random})
    : _random = random ?? math.Random();

  static const double _liquidTop = 0.48;
  static const double _liquidBottom = 0.83;
  static const double _metalGravity = 1.8;
  static const double _thermalDuration = 1.8;
  static const double _shockwaveRadius = 0.22;
  static const double _maxJitterSpeed = 44.8;

  final math.Random _random;

  List<BeakerReactionEvent> update(
    List<MoleculeTile> particles, {
    required Size size,
    required double deltaSeconds,
    required double temperature,
    bool burnerLit = false,
  }) {
    if (size.isEmpty || deltaSeconds <= 0 || particles.isEmpty) {
      return const [];
    }

    final dt = deltaSeconds.clamp(0.0, 1 / 20);
    const minTemp = 0.0;
    const maxTemp = 100.0;
    final normalizedTemperature =
        (temperature.clamp(minTemp, maxTemp) - minTemp) / (maxTemp - minTemp);
    final jitterSpeed =
        _maxJitterSpeed * math.pow(normalizedTemperature, 2).toDouble();
    final removed = <MoleculeTile>{};
    final reactions = <BeakerReactionEvent>[];
    final originalParticles = List<MoleculeTile>.of(particles);
    final reactionCooldown = _magnesiumCooldown(temperature);

    for (final particle in originalParticles) {
      particle.thermalTime = math.max(0, particle.thermalTime - dt);
      particle.reactionCooldown = math.max(0, particle.reactionCooldown - dt);
      particle.remainingLife -= dt;

      if (particle.motion == SymbolicParticleMotion.gas) {
        _updateGas(particle, dt);
      } else if (particle.isFluid) {
        if (jitterSpeed == 0) {
          particle.velocityX = 0;
          particle.velocityY = 0;
        } else {
          _updateFluid(particle, dt, jitterSpeed);
        }
      } else if (particle.motion == SymbolicParticleMotion.solid ||
          particle.motion == SymbolicParticleMotion.precipitate) {
        _updateSolid(particle, dt);
      } else {
        _updateDissolvedProduct(particle, dt);
      }

      if (particle.remainingLife <= 0 ||
          (particle.motion == SymbolicParticleMotion.gas &&
              particle.y < 0.08)) {
        removed.add(particle);
      }
    }

    if (burnerLit && temperature > 300) {
      for (final reagent in originalParticles) {
        if (removed.contains(reagent) || reagent.reactionCooldown > 0) continue;
        final products = _thermalProducts(reagent.formula);
        if (products == null) continue;
        final event = _event(
          metalFormula: '',
          first: reagent,
          second: MoleculeTile(
            formula: 'HEAT',
            color: Colors.orange,
            motion: SymbolicParticleMotion.suspended,
            seed: reagent.seed,
            x: reagent.x,
            y: reagent.y,
          ),
        );
        reactions.add(event);
        removed.add(reagent);
        for (final product in products) {
          _spawnProduct(
            particles,
            formula: product.formula,
            motion: product.motion,
            source: reagent,
            position: Offset(event.x, event.y),
            isFluid: product.isFluid,
            velocityY: product.motion == SymbolicParticleMotion.gas ? -0.12 : 0,
          );
        }
      }
    }

    for (final metal in originalParticles) {
      if (!_isReactiveMetal(metal) ||
          removed.contains(metal) ||
          metal.scale <= 0.18 ||
          metal.reactionCooldown > 0) {
        continue;
      }

      for (final water in originalParticles) {
        if (water.formula != 'H2O' ||
            !water.isFluid ||
            removed.contains(water) ||
            !_reactsWithWater(metal.formula, temperature) ||
            !_overlaps(metal, water, size)) {
          continue;
        }

        removed.add(water);
        final event = _event(
          metalFormula: metal.formula,
          first: metal,
          second: water,
        );
        reactions.add(event);
        final hotWaterProduct = _hotWaterProduct(metal.formula);
        if (hotWaterProduct != null) {
          metal.reactionCooldown = reactionCooldown;
          metal.scale = math.max(0.18, metal.scale - 0.08);
          _spawnProduct(
            particles,
            formula: hotWaterProduct,
            motion: SymbolicParticleMotion.precipitate,
            source: metal,
            position: Offset(event.x, event.y),
          );
          _spawnGas(
            particles,
            source: metal,
            position: Offset(event.x, event.y),
          );
          if (const {'K', 'Na', 'Ca', 'Ba'}.contains(metal.formula)) {
            _applyShockwave(particles, metal, event, size);
          }
          if (metal.scale <= 0.18) removed.add(metal);
        } else {
          metal.reactionCooldown = 0.28;
          metal.scale = math.max(0.18, metal.scale - 0.12);
          _spawnProducts(particles, event, source: metal);
          _applyShockwave(particles, metal, event, size);
          if (metal.scale <= 0.18) removed.add(metal);
        }
        break;
      }
      if (removed.contains(metal) || metal.reactionCooldown > 0) continue;
      for (final acid in originalParticles) {
        if (removed.contains(acid) ||
            !_isReactiveAcidMetal(metal.formula) ||
            !const {'HCl', 'H2SO4'}.contains(acid.formula) ||
            !_overlaps(metal, acid, size)) {
          continue;
        }
        final saltFormula =
            metal.formula == 'Fe' && acid.formula == 'HCl' && temperature >= 80
            ? 'FeCl3'
            : _metalAcidSalt(metal.formula, acid.formula);
        if (saltFormula == null) continue;
        final event = _event(
          metalFormula: metal.formula,
          first: metal,
          second: acid,
        );
        reactions.add(event);
        removed.add(acid);
        metal.reactionCooldown = 0.3;
        metal.scale = math.max(0.18, metal.scale - 0.12);
        final saltIsPrecipitate =
            saltFormula == 'PbCl2' || saltFormula == 'PbSO4';
        _spawnProduct(
          particles,
          formula: saltFormula,
          motion: saltIsPrecipitate
              ? SymbolicParticleMotion.precipitate
              : SymbolicParticleMotion.suspended,
          source: metal,
          position: Offset(event.x, event.y),
          isFluid: !saltIsPrecipitate,
        );
        _spawnGas(particles, source: metal, position: Offset(event.x, event.y));
        if (metal.scale <= 0.18) removed.add(metal);
        break;
      }
    }

    final collisionBuckets = <(int, int), List<MoleculeTile>>{};
    final particleIndexes = <MoleculeTile, int>{};
    for (var index = 0; index < originalParticles.length; index++) {
      final particle = originalParticles[index];
      final cell = (
        (particle.x * size.width / 35).floor(),
        (particle.y * size.height / 25).floor(),
      );
      collisionBuckets.putIfAbsent(cell, () => []).add(particle);
      particleIndexes[particle] = index;
    }
    for (
      var firstIndex = 0;
      firstIndex < originalParticles.length;
      firstIndex++
    ) {
      final first = originalParticles[firstIndex];
      if (removed.contains(first) || first.reactionCooldown > 0) continue;
      final cellX = (first.x * size.width / 35).floor();
      final cellY = (first.y * size.height / 25).floor();
      var reacted = false;
      for (var offsetX = -1; offsetX <= 1 && !reacted; offsetX++) {
        for (var offsetY = -1; offsetY <= 1 && !reacted; offsetY++) {
          for (final second
              in collisionBuckets[(cellX + offsetX, cellY + offsetY)] ??
                  const <MoleculeTile>[]) {
            if (particleIndexes[second]! <= firstIndex ||
                removed.contains(second) ||
                second.reactionCooldown > 0 ||
                !_overlaps(first, second, size)) {
              continue;
            }
            final event = _reactDissolvedParticles(
              first,
              second,
              particles,
              removed,
              size: size,
              temperature: temperature,
            );
            if (event == null) continue;
            reactions.add(event);
            reacted = true;
            break;
          }
        }
      }
    }

    particles.removeWhere(removed.contains);
    return reactions;
  }

  List<_ThermalProduct>? _thermalProducts(String formula) => switch (formula) {
    'CaCO3' => [
      const _ThermalProduct('CaO', SymbolicParticleMotion.solid),
      const _ThermalProduct('CO2', SymbolicParticleMotion.gas),
    ],
    'KMnO4' => [
      const _ThermalProduct('K2MnO4', SymbolicParticleMotion.suspended, true),
      const _ThermalProduct('MnO2', SymbolicParticleMotion.precipitate),
      const _ThermalProduct('O2', SymbolicParticleMotion.gas),
    ],
    'Cu(OH)2' => [
      const _ThermalProduct('CuO', SymbolicParticleMotion.solid),
      const _ThermalProduct('H2O', SymbolicParticleMotion.suspended, true),
    ],
    _ => null,
  };

  String? _hotWaterProduct(String formula) {
    if (formula == 'Mg') return 'Mg(OH)2';
    if (formula == 'Al') return 'Al(OH)3';
    if (formula == 'Zn') return 'Zn(OH)2';
    if (formula == 'Fe') return 'Fe(OH)2';
    return null;
  }

  void _updateGas(MoleculeTile particle, double dt) {
    particle.velocityY -= 0.06 * dt;
    particle.velocityX += (_random.nextDouble() - 0.5) * 0.12 * dt;
    particle.velocityX *= math.pow(0.998, dt * 60).toDouble();
    particle.x += particle.velocityX * dt;
    particle.y += particle.velocityY * dt;
    final left = 0.22 + particle.y * 0.10 + 0.025;
    final right = 0.78 - particle.y * 0.10 - 0.025;
    if (particle.x < left) {
      particle.x = left;
      particle.velocityX = particle.velocityX.abs() * 0.52;
    } else if (particle.x > right) {
      particle.x = right;
      particle.velocityX = -particle.velocityX.abs() * 0.52;
    }
  }

  void _updateFluid(MoleculeTile particle, double dt, double jitterSpeed) {
    final brownianImpulse = math.sqrt(dt);
    particle.velocityX +=
        (_random.nextDouble() - 0.5) * jitterSpeed * brownianImpulse;
    particle.velocityY +=
        (_random.nextDouble() - 0.5) * jitterSpeed * brownianImpulse;
    particle.velocityX = particle.velocityX.clamp(-1.3, 1.3);
    particle.velocityY = particle.velocityY.clamp(-0.8, 0.8);
    final damping = math.pow(0.965, dt * 60).toDouble();
    particle.velocityX *= damping;
    particle.velocityY *= damping;
    particle.x += particle.velocityX * dt;
    particle.y += particle.velocityY * dt;
    _keepInside(particle, fluid: true);
  }

  void _updateSolid(MoleculeTile particle, double dt) {
    if (particle.formula == 'K' || particle.formula == 'Na') {
      particle.velocityY += _metalGravity * dt;
      particle.velocityX += (_random.nextDouble() - 0.5) * 0.18 * dt;
      particle.velocityX *= math.pow(0.992, dt * 60).toDouble();
    } else {
      if (particle.y >= 0.84) {
        particle.y = 0.84;
        particle.velocityX = 0;
        particle.velocityY = 0;
        return;
      }
      particle.velocityY += 1.2 * dt;
    }
    particle.x += particle.velocityX * dt;
    particle.y += particle.velocityY * dt;
    _keepInside(particle, fluid: false);
  }

  void _updateDissolvedProduct(MoleculeTile particle, double dt) {
    particle.velocityY += 0.12 * dt;
    particle.velocityX *= math.pow(0.98, dt * 60).toDouble();
    particle.x += particle.velocityX * dt;
    particle.y += particle.velocityY * dt;
    _keepInside(particle, fluid: true);
  }

  void _keepInside(MoleculeTile particle, {bool fluid = false}) {
    final left = 0.22 + particle.y * 0.10 + 0.025;
    final right = 0.78 - particle.y * 0.10 - 0.025;
    if (particle.x < left) {
      particle.x = left;
      particle.velocityX = particle.velocityX.abs() * 0.52;
    } else if (particle.x > right) {
      particle.x = right;
      particle.velocityX = -particle.velocityX.abs() * 0.52;
    }

    final floor = fluid ? _liquidBottom : 0.84;
    final ceiling = fluid ? _liquidTop : 0.14;
    if (particle.y > floor) {
      particle.y = floor;
      if (particle.motion == SymbolicParticleMotion.solid ||
          particle.motion == SymbolicParticleMotion.precipitate) {
        particle.velocityY = 0;
      } else {
        particle.velocityY = -particle.velocityY.abs() * 0.28;
      }
    } else if (particle.y < ceiling) {
      particle.y = ceiling;
      particle.velocityY = particle.velocityY.abs() * 0.28;
    }
  }

  bool _overlaps(MoleculeTile first, MoleculeTile second, Size size) {
    final dx = (first.x - second.x).abs() * size.width;
    final dy = (first.y - second.y).abs() * size.height;
    return dx <= 35 && dy <= 25;
  }

  void _spawnProducts(
    List<MoleculeTile> particles,
    BeakerReactionEvent event, {
    required MoleculeTile source,
  }) {
    final hydroxide = switch (event.metalFormula) {
      'K' => 'KOH',
      'Ba' => 'Ba(OH)2',
      'Ca' => 'Ca(OH)2',
      _ => 'NaOH',
    };
    final now = DateTime.now();
    _spawnProduct(
      particles,
      formula: hydroxide,
      motion: SymbolicParticleMotion.suspended,
      source: source,
      position: Offset(event.x, event.y),
      isFluid: true,
      velocityY: 0.16,
      createdAt: now,
    );
    _spawnGas(particles, source: source, position: Offset(event.x, event.y));
  }

  BeakerReactionEvent? _reactDissolvedParticles(
    MoleculeTile first,
    MoleculeTile second,
    List<MoleculeTile> particles,
    Set<MoleculeTile> removed, {
    required Size size,
    required double temperature,
  }) {
    final specialMetalReaction = _reactSpecialMetalPair(
      first,
      second,
      particles,
      removed,
      temperature: temperature,
    );
    if (specialMetalReaction != null) return specialMetalReaction;

    final oxideReaction = _reactBasicOxideWater(
      first,
      second,
      particles,
      removed,
      size: size,
    );
    if (oxideReaction != null) return oxideReaction;

    final hydrolysis = _reactHydrolysis(
      first,
      second,
      particles,
      removed,
      size: size,
      temperature: temperature,
    );
    if (hydrolysis != null) return hydrolysis;

    final acid = first.formula == 'HCl'
        ? first
        : second.formula == 'HCl'
        ? second
        : null;
    final aluminate = first.formula == 'NaAlO2'
        ? first
        : second.formula == 'NaAlO2'
        ? second
        : null;
    final aluminiumHydroxide = first.formula == 'Al(OH)3'
        ? first
        : second.formula == 'Al(OH)3'
        ? second
        : null;
    if (acid != null && aluminate != null) {
      final event = _event(metalFormula: '', first: acid, second: aluminate);
      _consume(acid, aluminate, removed);
      _spawnProduct(
        particles,
        formula: 'Al(OH)3',
        motion: SymbolicParticleMotion.precipitate,
        source: aluminate,
        position: Offset(event.x, event.y),
      );
      _spawnProduct(
        particles,
        formula: 'NaCl',
        motion: SymbolicParticleMotion.suspended,
        source: acid,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      return event;
    }
    if (acid != null && aluminiumHydroxide != null) {
      final event = _event(
        metalFormula: '',
        first: acid,
        second: aluminiumHydroxide,
      );
      _consume(acid, aluminiumHydroxide, removed);
      _spawnProduct(
        particles,
        formula: 'AlCl3',
        motion: SymbolicParticleMotion.suspended,
        source: aluminiumHydroxide,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      _spawnProduct(
        particles,
        formula: 'H2O',
        motion: SymbolicParticleMotion.suspended,
        source: acid,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      return event;
    }

    MoleculeTile? hydroxide;
    MoleculeTile? salt;
    if (_isHydroxide(first.formula) && _isReactionSalt(second.formula)) {
      hydroxide = first;
      salt = second;
    } else if (_isHydroxide(second.formula) && _isReactionSalt(first.formula)) {
      hydroxide = second;
      salt = first;
    }
    if (hydroxide != null && salt != null) {
      final metal = _baseCation(hydroxide.formula);
      final precipitate = switch (salt.formula) {
        'CuSO4' => 'Cu(OH)2',
        'FeCl3' => 'Fe(OH)3',
        'FeSO4' || 'FeCl2' => 'Fe(OH)2',
        'AlCl3' || 'Al2(SO4)3' when metal != null => 'Al(OH)3',
        'ZnSO4' || 'ZnCl2' => 'Zn(OH)2',
        _ => null,
      };
      if (precipitate == null || metal == null) return null;
      final byproduct = _byproductSalt(metal, salt.formula);
      if (byproduct == null) return null;
      final event = _event(metalFormula: '', first: hydroxide, second: salt);
      _consume(first, second, removed);
      _spawnProduct(
        particles,
        formula: precipitate,
        motion: SymbolicParticleMotion.precipitate,
        source: hydroxide,
        position: Offset(event.x, event.y),
      );
      _spawnProduct(
        particles,
        formula: byproduct,
        motion: SymbolicParticleMotion.suspended,
        source: salt,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      return event;
    }

    final aluminateReaction =
        (first.formula == 'Al(OH)3' && second.formula == 'NaOH') ||
        (second.formula == 'Al(OH)3' && first.formula == 'NaOH');
    if (aluminateReaction) {
      final aluminate = first.formula == 'Al(OH)3' ? first : second;
      final sodiumHydroxide = identical(aluminate, first) ? second : first;
      final event = _event(
        metalFormula: '',
        first: aluminate,
        second: sodiumHydroxide,
      );
      _consume(aluminate, sodiumHydroxide, removed);
      _spawnProduct(
        particles,
        formula: 'NaAlO2',
        motion: SymbolicParticleMotion.suspended,
        source: aluminate,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      _spawnProduct(
        particles,
        formula: 'H2O',
        motion: SymbolicParticleMotion.suspended,
        source: sodiumHydroxide,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      return event;
    }

    final gas = const {'CO2', 'SO2'}.contains(first.formula)
        ? first
        : const {'CO2', 'SO2'}.contains(second.formula)
        ? second
        : null;
    final other = identical(gas, first) ? second : first;
    if (gas == null) return null;
    final base = const {'Ca(OH)2', 'Ba(OH)2'}.contains(other.formula);
    final precipitate = const {
      'CaCO3',
      'BaCO3',
      'CaSO3',
      'BaSO3',
    }.contains(other.formula);
    if (base) {
      final cation = other.formula.startsWith('Ba') ? 'Ba' : 'Ca';
      final product = gas.formula == 'CO2' ? '${cation}CO3' : '${cation}SO3';
      final event = _event(metalFormula: '', first: gas, second: other);
      _consume(gas, other, removed);
      _spawnProduct(
        particles,
        formula: product,
        motion: SymbolicParticleMotion.precipitate,
        source: other,
        position: Offset(event.x, event.y),
      );
      _spawnProduct(
        particles,
        formula: 'H2O',
        motion: SymbolicParticleMotion.suspended,
        source: other,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      return event;
    }
    if (precipitate &&
        (gas.formula == 'CO2' && other.formula.endsWith('CO3') ||
            gas.formula == 'SO2' && other.formula.endsWith('SO3')) &&
        particles.any((particle) => particle.formula == 'H2O')) {
      final cation = other.formula.startsWith('Ba') ? 'Ba' : 'Ca';
      final product = gas.formula == 'CO2'
          ? '$cation(HCO3)2'
          : '$cation(HSO3)2';
      final event = _event(metalFormula: '', first: gas, second: other);
      _consume(gas, other, removed);
      _spawnProduct(
        particles,
        formula: product,
        motion: SymbolicParticleMotion.suspended,
        source: other,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      return event;
    }
    return null;
  }

  BeakerReactionEvent? _reactSpecialMetalPair(
    MoleculeTile first,
    MoleculeTile second,
    List<MoleculeTile> particles,
    Set<MoleculeTile> removed, {
    required double temperature,
  }) {
    final iron = first.formula == 'Fe'
        ? first
        : second.formula == 'Fe'
        ? second
        : null;
    final chlorine = first.formula == 'Cl2'
        ? first
        : second.formula == 'Cl2'
        ? second
        : null;
    if (iron != null && chlorine != null) {
      final event = _event(metalFormula: 'Fe', first: iron, second: chlorine);
      _consume(iron, chlorine, removed);
      _spawnProduct(
        particles,
        formula: 'FeCl3',
        motion: SymbolicParticleMotion.suspended,
        source: iron,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      return event;
    }

    final acid = first.formula == 'HCl'
        ? first
        : second.formula == 'HCl'
        ? second
        : null;
    if (iron != null && acid != null && temperature >= 80) {
      final event = _event(metalFormula: 'Fe', first: iron, second: acid);
      removed.add(acid);
      _spawnProduct(
        particles,
        formula: 'FeCl3',
        motion: SymbolicParticleMotion.suspended,
        source: iron,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      for (var index = 0; index < 3; index++) {
        _spawnGas(particles, source: iron, position: Offset(event.x, event.y));
      }
      return event;
    }

    final copper = first.formula == 'Cu'
        ? first
        : second.formula == 'Cu'
        ? second
        : null;
    final silverNitrate = first.formula == 'AgNO3'
        ? first
        : second.formula == 'AgNO3'
        ? second
        : null;
    if (copper != null && silverNitrate != null) {
      final event = _event(
        metalFormula: 'Cu',
        first: copper,
        second: silverNitrate,
      );
      removed.add(silverNitrate);
      _spawnProduct(
        particles,
        formula: 'Cu(NO3)2',
        motion: SymbolicParticleMotion.suspended,
        source: silverNitrate,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      for (var index = 0; index < 2; index++) {
        _spawnProduct(
          particles,
          formula: 'Ag',
          motion: SymbolicParticleMotion.suspended,
          source: copper,
          position: Offset(copper.x + (index == 0 ? -0.012 : 0.012), copper.y),
        );
      }
      return event;
    }

    final sulfuricAcid = first.formula == 'H2SO4'
        ? first
        : second.formula == 'H2SO4'
        ? second
        : null;
    if (copper == null || sulfuricAcid == null || temperature < 80) {
      return null;
    }
    final event = _event(
      metalFormula: 'Cu',
      first: copper,
      second: sulfuricAcid,
    );
    removed.add(sulfuricAcid);
    _spawnProduct(
      particles,
      formula: 'CuSO4',
      motion: SymbolicParticleMotion.suspended,
      source: sulfuricAcid,
      position: Offset(event.x, event.y),
      isFluid: true,
    );
    _spawnGas(
      particles,
      source: copper,
      position: Offset(event.x, event.y),
      formula: 'SO2',
      velocityY: -0.10,
    );
    _spawnProduct(
      particles,
      formula: 'H2O',
      motion: SymbolicParticleMotion.suspended,
      source: sulfuricAcid,
      position: Offset(event.x, event.y),
      isFluid: true,
    );
    return event;
  }

  BeakerReactionEvent? _reactHydrolysis(
    MoleculeTile first,
    MoleculeTile second,
    List<MoleculeTile> particles,
    Set<MoleculeTile> removed, {
    required Size size,
    required double temperature,
  }) {
    final water = first.formula == 'H2O'
        ? first
        : second.formula == 'H2O'
        ? second
        : null;
    if (water == null) return null;
    final reagent = identical(water, first) ? second : first;
    if (reagent.formula == 'Mg' || !_isHydrolysisReagent(reagent.formula)) {
      return null;
    }
    if (const {'CaC2', 'Al4C3'}.contains(reagent.formula) && temperature < 60) {
      return null;
    }
    final waterStoichiometry = switch (reagent.formula) {
      'CaC2' => 2,
      'Al4C3' => 12,
      'Ca3P2' => 6,
      _ => 1,
    };
    final waterCandidates =
        particles.where((particle) {
          if (particle.formula != 'H2O' ||
              !particle.isFluid ||
              removed.contains(particle)) {
            return false;
          }
          final dx = (particle.x - reagent.x) * size.width;
          final dy = (particle.y - reagent.y) * size.height;
          return math.sqrt(dx * dx + dy * dy) <=
              _shockwaveRadius * math.min(size.width, size.height) * 1.5;
        }).toList()..sort((a, b) {
          final distanceA =
              math.pow(a.x - reagent.x, 2) + math.pow(a.y - reagent.y, 2);
          final distanceB =
              math.pow(b.x - reagent.x, 2) + math.pow(b.y - reagent.y, 2);
          return distanceA.compareTo(distanceB);
        });
    if (waterCandidates.length < waterStoichiometry) return null;
    final event = _event(metalFormula: '', first: reagent, second: water);
    _consume(reagent, waterCandidates.first, removed);
    for (final consumedWater
        in waterCandidates.skip(1).take(waterStoichiometry - 1)) {
      removed.add(consumedWater);
    }
    if (reagent.formula == 'CaC2') {
      _spawnProduct(
        particles,
        formula: 'Ca(OH)2',
        motion: SymbolicParticleMotion.precipitate,
        source: reagent,
        position: Offset(event.x, event.y),
      );
      _spawnGas(
        particles,
        source: reagent,
        position: Offset(event.x, event.y),
        formula: 'C2H2',
        velocityY: -0.12,
      );
    } else if (reagent.formula == 'Al4C3') {
      for (var index = 0; index < 4; index++) {
        _spawnProduct(
          particles,
          formula: 'Al(OH)3',
          motion: SymbolicParticleMotion.precipitate,
          source: reagent,
          position: Offset(event.x, event.y),
        );
      }
      for (var index = 0; index < 3; index++) {
        _spawnGas(
          particles,
          source: reagent,
          position: Offset(event.x, event.y),
          formula: 'CH4',
          velocityY: -0.12,
        );
      }
    } else if (reagent.formula == 'Ca3P2') {
      for (var index = 0; index < 3; index++) {
        _spawnProduct(
          particles,
          formula: 'Ca(OH)2',
          motion: SymbolicParticleMotion.precipitate,
          source: reagent,
          position: Offset(event.x, event.y),
        );
      }
      for (var index = 0; index < 2; index++) {
        _spawnGas(
          particles,
          source: reagent,
          position: Offset(event.x, event.y),
          formula: 'PH3',
          velocityY: -0.12,
        );
      }
    } else if (reagent.formula == 'Na2CO3') {
      _spawnProduct(
        particles,
        formula: 'NaHCO3',
        motion: SymbolicParticleMotion.suspended,
        source: reagent,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      _spawnProduct(
        particles,
        formula: 'NaOH',
        motion: SymbolicParticleMotion.suspended,
        source: reagent,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
    } else if (reagent.formula == 'CH3COONa') {
      _spawnProduct(
        particles,
        formula: 'CH3COOH',
        motion: SymbolicParticleMotion.suspended,
        source: reagent,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      _spawnProduct(
        particles,
        formula: 'NaOH',
        motion: SymbolicParticleMotion.suspended,
        source: reagent,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
    } else if (reagent.formula == 'NH4Cl') {
      _spawnProduct(
        particles,
        formula: 'NH4OH',
        motion: SymbolicParticleMotion.suspended,
        source: reagent,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
      _spawnProduct(
        particles,
        formula: 'HCl',
        motion: SymbolicParticleMotion.suspended,
        source: reagent,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
    } else {
      final metalHydroxide = reagent.formula == 'FeCl3' ? 'Fe(OH)3' : 'Al(OH)3';
      final acidByproduct = reagent.formula == 'Al2(SO4)3' ? 'H2SO4' : 'HCl';
      _spawnProduct(
        particles,
        formula: metalHydroxide,
        motion: SymbolicParticleMotion.precipitate,
        source: reagent,
        position: Offset(event.x, event.y),
      );
      _spawnProduct(
        particles,
        formula: acidByproduct,
        motion: SymbolicParticleMotion.suspended,
        source: reagent,
        position: Offset(event.x, event.y),
        isFluid: true,
      );
    }
    if (const {'CaC2', 'Al4C3', 'Ca3P2'}.contains(reagent.formula)) {
      final temperatureScale =
          0.75 + ((temperature.clamp(60.0, 100.0) - 60) / 40) * 0.8;
      _applyShockwave(
        particles,
        reagent,
        event,
        size,
        impulseScale: temperatureScale,
      );
      reagent.thermalTime = _thermalDuration;
    }
    return event;
  }

  BeakerReactionEvent? _reactBasicOxideWater(
    MoleculeTile first,
    MoleculeTile second,
    List<MoleculeTile> particles,
    Set<MoleculeTile> removed, {
    required Size size,
  }) {
    final oxide = first.formula == 'H2O'
        ? second
        : second.formula == 'H2O'
        ? first
        : null;
    if (oxide == null ||
        !const {'Na2O', 'K2O', 'CaO', 'BaO'}.contains(oxide.formula)) {
      return null;
    }
    final water = identical(oxide, first) ? second : first;
    if (!water.isFluid) return null;
    final product = switch (oxide.formula) {
      'Na2O' => 'NaOH',
      'K2O' => 'KOH',
      'CaO' => 'Ca(OH)2',
      _ => 'Ba(OH)2',
    };
    final event = _event(metalFormula: '', first: oxide, second: water);
    _consume(oxide, water, removed);
    _spawnProduct(
      particles,
      formula: product,
      motion: SymbolicParticleMotion.suspended,
      source: oxide,
      position: Offset(event.x, event.y),
      isFluid: true,
    );
    _applyShockwave(particles, oxide, event, size, impulseScale: 0.55);
    return event;
  }

  bool _isHydrolysisReagent(String formula) => const {
    'AlCl3',
    'FeCl3',
    'Al2(SO4)3',
    'Na2CO3',
    'CH3COONa',
    'NH4Cl',
    'CaC2',
    'Al4C3',
    'Ca3P2',
  }.contains(formula);

  bool _isHydroxide(String formula) =>
      const {'NaOH', 'KOH', 'Ba(OH)2', 'Ca(OH)2'}.contains(formula);

  String? _baseCation(String formula) => switch (formula) {
    'NaOH' => 'Na',
    'KOH' => 'K',
    'Ba(OH)2' => 'Ba',
    'Ca(OH)2' => 'Ca',
    _ => null,
  };

  String? _byproductSalt(String cation, String saltFormula) {
    final divalent = const {'Ba', 'Ca'}.contains(cation);
    if (saltFormula.contains('SO4')) {
      return divalent ? '${cation}SO4' : '${cation}2SO4';
    }
    if (saltFormula.contains('Cl')) {
      return divalent ? '${cation}Cl2' : '${cation}Cl';
    }
    return null;
  }

  bool _isReactiveAcidMetal(String formula) => const {
    'K',
    'Na',
    'Mg',
    'Al',
    'Zn',
    'Fe',
    'Pb',
    'Ca',
    'Ba',
  }.contains(formula);

  bool _reactsWithWater(String formula, double temperature) =>
      const {'K', 'Na', 'Ca', 'Ba'}.contains(formula) ||
      temperature >= 70 && const {'Mg', 'Al', 'Zn', 'Fe'}.contains(formula);

  String? _metalAcidSalt(String metal, String acid) {
    if (acid == 'HCl') {
      return switch (metal) {
        'K' => 'KCl',
        'Na' => 'NaCl',
        'Mg' => 'MgCl2',
        'Al' => 'AlCl3',
        'Zn' => 'ZnCl2',
        'Fe' => 'FeCl2',
        'Pb' => 'PbCl2',
        'Ca' => 'CaCl2',
        'Ba' => 'BaCl2',
        _ => null,
      };
    }
    return switch (metal) {
      'K' => 'K2SO4',
      'Na' => 'Na2SO4',
      'Mg' => 'MgSO4',
      'Al' => 'Al2(SO4)3',
      'Zn' => 'ZnSO4',
      'Fe' => 'FeSO4',
      'Pb' => 'PbSO4',
      'Ca' => 'CaSO4',
      'Ba' => 'BaSO4',
      _ => null,
    };
  }

  bool _isReactionSalt(String formula) => const {
    'CuSO4',
    'FeCl3',
    'FeSO4',
    'FeCl2',
    'AlCl3',
    'Al2(SO4)3',
    'ZnSO4',
    'ZnCl2',
  }.contains(formula);

  void _consume(
    MoleculeTile first,
    MoleculeTile second,
    Set<MoleculeTile> removed,
  ) {
    removed
      ..add(first)
      ..add(second);
    first.reactionCooldown = 0.35;
    second.reactionCooldown = 0.35;
  }

  BeakerReactionEvent _event({
    required String metalFormula,
    required MoleculeTile first,
    required MoleculeTile second,
  }) => BeakerReactionEvent(
    metalFormula: metalFormula,
    x: (first.x + second.x) / 2,
    y: (first.y + second.y) / 2,
    firstFormula: first.formula,
    secondFormula: second.formula,
  );

  void _spawnGas(
    List<MoleculeTile> particles, {
    required MoleculeTile source,
    required Offset position,
    String formula = 'H2',
    double velocityY = -0.18,
  }) {
    _spawnProduct(
      particles,
      formula: formula,
      motion: SymbolicParticleMotion.gas,
      source: source,
      position: position,
      velocityY: velocityY,
      remainingLife: 5.5,
    );
  }

  void _spawnProduct(
    List<MoleculeTile> particles, {
    required String formula,
    required SymbolicParticleMotion motion,
    required MoleculeTile source,
    required Offset position,
    bool isFluid = false,
    double velocityY = 0,
    double remainingLife = double.infinity,
    DateTime? createdAt,
  }) {
    particles.add(
      MoleculeTile(
        formula: formula,
        color: source.color,
        motion: motion,
        seed: _random.nextDouble(),
        createdAt: createdAt ?? DateTime.now(),
        x: position.dx,
        y: position.dy,
        velocityX: source.velocityX,
        velocityY: motion == SymbolicParticleMotion.gas
            ? velocityY
            : source.velocityY,
        isFluid: isFluid,
        remainingLife: remainingLife,
      ),
    );
  }

  double _magnesiumCooldown(double temperature) =>
      0.55 - ((temperature.clamp(70.0, 100.0) - 70) / 30) * 0.45;

  void _applyShockwave(
    List<MoleculeTile> particles,
    MoleculeTile metal,
    BeakerReactionEvent event,
    Size size, {
    double impulseScale = 1,
  }) {
    for (final particle in particles) {
      final dx = (particle.x - event.x) * size.width;
      final dy = (particle.y - event.y) * size.height;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance > _shockwaveRadius * math.min(size.width, size.height)) {
        continue;
      }
      final directionX = distance == 0 ? 0.0 : dx / distance;
      final directionY = distance == 0 ? -0.35 : dy / distance;
      particle.velocityX += directionX * 0.65 * impulseScale;
      particle.velocityY += directionY * 0.65 * impulseScale;
      particle.thermalTime = _thermalDuration;
    }

    final dx = metal.x - event.x;
    final dy = metal.y - event.y;
    final magnitude = math.sqrt(dx * dx + dy * dy);
    final directionX = magnitude == 0
        ? (_random.nextBool() ? 1.0 : -1.0)
        : dx / magnitude;
    final directionY = magnitude == 0 ? -0.4 : dy / magnitude;
    metal.velocityX +=
        directionX * (0.55 + _random.nextDouble() * 0.35) * impulseScale;
    metal.velocityY +=
        (directionY * (0.45 + _random.nextDouble() * 0.3) - 0.45) *
        impulseScale;
    metal.thermalTime = _thermalDuration;
  }

  bool _isReactiveMetal(MoleculeTile particle) =>
      _isReactiveAcidMetal(particle.formula) ||
      particle.formula == 'Ca' ||
      particle.formula == 'Ba';
}

class _ThermalProduct {
  const _ThermalProduct(this.formula, this.motion, [this.isFluid = false]);

  final String formula;
  final SymbolicParticleMotion motion;
  final bool isFluid;
}
