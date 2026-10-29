import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chemical_models.dart';
import 'molecule_physics_types.dart';
import 'molecule_tile_physics_fallback.dart' as fallback;
import 'molecule_tile_physics_native_stub.dart'
    if (dart.library.ffi) 'molecule_tile_physics_native_ffi.dart'
    as native;

export 'molecule_tile_physics_fallback.dart' show BeakerReactionEvent;

class MoleculeTilePhysics {
  MoleculeTilePhysics({math.Random? random})
    : _random = random ?? math.Random(),
      _fallback = fallback.MoleculeTilePhysicsFallback(random: random);

  final math.Random _random;
  final fallback.MoleculeTilePhysicsFallback _fallback;

  List<fallback.BeakerReactionEvent> update(
    List<MoleculeTile> particles, {
    required Size size,
    required double deltaSeconds,
    required double temperature,
    bool burnerLit = false,
  }) {
    if (!native.isAvailable ||
        size.isEmpty ||
        deltaSeconds <= 0 ||
        particles.isEmpty) {
      return _fallback.update(
        particles,
        size: size,
        deltaSeconds: deltaSeconds,
        temperature: temperature,
        burnerLit: burnerLit,
      );
    }

    final original = List<MoleculeTile>.of(particles);
    final result = native.simulate(
      particles: [
        for (var index = 0; index < original.length; index++)
          _toPhysicsState(original[index], index + 1),
      ],
      size: size,
      deltaSeconds: deltaSeconds,
      temperature: temperature,
      burnerLit: burnerLit,
      randomSeed: _random.nextInt(0x7fffffff),
    );

    particles
      ..clear()
      ..addAll(
        result.particles.map((state) {
          final tile = state.id > 0 && state.id <= original.length
              ? original[state.id - 1]
              : _newTile(state);
          tile
            ..x = state.x
            ..y = state.y
            ..velocityX = state.velocityX
            ..velocityY = state.velocityY
            ..scale = state.scale
            ..thermalTime = state.thermalTime
            ..reactionCooldown = state.reactionCooldown
            ..remainingLife = state.remainingLife
            ..isFluid = state.isFluid
            ..motion = _motion(state.motion);
          return tile;
        }),
      );
    return result.events
        .map(
          (event) => fallback.BeakerReactionEvent(
            metalFormula: event.metalFormula,
            x: event.x,
            y: event.y,
            firstFormula: event.firstFormula,
            secondFormula: event.secondFormula,
          ),
        )
        .toList(growable: false);
  }

  PhysicsParticleState _toPhysicsState(MoleculeTile tile, int id) =>
      PhysicsParticleState(
        id: id,
        formula: tile.formula,
        seed: tile.seed,
        x: tile.x,
        y: tile.y,
        velocityX: tile.velocityX,
        velocityY: tile.velocityY,
        scale: tile.scale,
        thermalTime: tile.thermalTime,
        reactionCooldown: tile.reactionCooldown,
        remainingLife: tile.remainingLife,
        color: tile.color.toARGB32(),
        createdAtMilliseconds: tile.createdAt?.millisecondsSinceEpoch ?? -1,
        motion: tile.motion.index,
        isFluid: tile.isFluid,
      );

  MoleculeTile _newTile(PhysicsParticleState state) => MoleculeTile(
    formula: state.formula,
    color: Color(state.color),
    motion: _motion(state.motion),
    seed: state.seed,
    createdAt: DateTime.fromMillisecondsSinceEpoch(state.createdAtMilliseconds),
    x: state.x,
    y: state.y,
    velocityX: state.velocityX,
    velocityY: state.velocityY,
    scale: state.scale,
    thermalTime: state.thermalTime,
    reactionCooldown: state.reactionCooldown,
    remainingLife: state.remainingLife,
    isFluid: state.isFluid,
  );

  SymbolicParticleMotion _motion(int value) =>
      SymbolicParticleMotion.values[value];
}
