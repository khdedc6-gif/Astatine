import 'package:flutter/material.dart';

import 'molecule_physics_types.dart';

bool get isAvailable => false;

PhysicsStepResult simulate({
  required List<PhysicsParticleState> particles,
  required Size size,
  required double deltaSeconds,
  required double temperature,
  required bool burnerLit,
  required int randomSeed,
}) {
  throw UnsupportedError('Native molecule physics is unavailable.');
}
