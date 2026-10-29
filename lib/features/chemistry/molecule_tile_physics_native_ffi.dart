import 'dart:ffi' hide Size;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:molecule_tile_physics/molecule_tile_physics_bindings_generated.dart'
    as bindings;

import 'molecule_physics_types.dart';

bool get isAvailable => true;

PhysicsStepResult simulate({
  required List<PhysicsParticleState> particles,
  required Size size,
  required double deltaSeconds,
  required double temperature,
  required bool burnerLit,
  required int randomSeed,
}) {
  final input = calloc<bindings.MoleculePhysicsParticle>(particles.length);
  Pointer<bindings.MoleculePhysicsResult> result = nullptr;
  try {
    for (var index = 0; index < particles.length; index++) {
      final source = particles[index];
      final target = (input + index).ref;
      target
        ..id = source.id
        ..seed = source.seed
        ..x = source.x
        ..y = source.y
        ..velocity_x = source.velocityX
        ..velocity_y = source.velocityY
        ..scale = source.scale
        ..thermal_time = source.thermalTime
        ..reaction_cooldown = source.reactionCooldown
        ..remaining_life = source.remainingLife
        ..color = source.color
        ..created_at_milliseconds = source.createdAtMilliseconds
        ..motion = source.motion
        ..is_fluid = source.isFluid ? 1 : 0;
      _writeFormula(target.formula, source.formula);
    }

    result = bindings.molecule_physics_step(
      input,
      particles.length,
      size.width,
      size.height,
      deltaSeconds,
      temperature,
      burnerLit ? 1 : 0,
      randomSeed,
    );
    if (result == nullptr) {
      throw StateError('Native molecule physics could not allocate a result.');
    }
    final value = result.ref;
    if (value.status != 0) {
      throw StateError(
        'Native molecule physics failed with status ${value.status}.',
      );
    }

    final outputParticles = List<PhysicsParticleState>.generate(
      value.particle_count,
      (index) => _readParticle((value.particles + index).ref),
      growable: false,
    );
    final outputEvents = List<PhysicsReactionEvent>.generate(
      value.event_count,
      (index) => _readEvent((value.events + index).ref),
      growable: false,
    );
    return PhysicsStepResult(particles: outputParticles, events: outputEvents);
  } finally {
    if (result != nullptr) bindings.molecule_physics_result_free(result);
    calloc.free(input);
  }
}

void _writeFormula(Array<Uint8> target, String formula) {
  final bytes = formula.codeUnits;
  if (bytes.any((byte) => byte > 0x7f) || bytes.length >= 48) {
    throw ArgumentError.value(
      formula,
      'formula',
      'Must be ASCII and <48 bytes.',
    );
  }
  for (var index = 0; index < bytes.length; index++) {
    target[index] = bytes[index];
  }
  target[bytes.length] = 0;
}

String _readFormula(Array<Uint8> value) {
  final bytes = <int>[];
  for (var index = 0; index < 48; index++) {
    final byte = value[index];
    if (byte == 0) break;
    bytes.add(byte);
  }
  return String.fromCharCodes(bytes);
}

PhysicsParticleState _readParticle(bindings.MoleculePhysicsParticle value) =>
    PhysicsParticleState(
      id: value.id,
      formula: _readFormula(value.formula),
      seed: value.seed,
      x: value.x,
      y: value.y,
      velocityX: value.velocity_x,
      velocityY: value.velocity_y,
      scale: value.scale,
      thermalTime: value.thermal_time,
      reactionCooldown: value.reaction_cooldown,
      remainingLife: value.remaining_life,
      color: value.color,
      createdAtMilliseconds: value.created_at_milliseconds,
      motion: value.motion,
      isFluid: value.is_fluid != 0,
    );

PhysicsReactionEvent _readEvent(bindings.MoleculePhysicsEvent value) =>
    PhysicsReactionEvent(
      metalFormula: _readFormula(value.metal_formula),
      firstFormula: _readFormula(value.first_formula),
      secondFormula: _readFormula(value.second_formula),
      x: value.x,
      y: value.y,
    );
