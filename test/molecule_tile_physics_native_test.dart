import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/features/chemistry/molecule_physics_types.dart';
import 'package:astatine_dashboard/features/chemistry/molecule_tile_physics_native_ffi.dart'
    as native;

void main() {
  test('native C++ physics updates a particle state', () {
    expect(native.isAvailable, isTrue);

    final result = native.simulate(
      particles: [
        const PhysicsParticleState(
          id: 1,
          formula: 'Mg',
          seed: 0.4,
          x: 0.55,
          y: 0.2,
          velocityX: 0,
          velocityY: 0,
          scale: 1,
          thermalTime: 0,
          reactionCooldown: 0,
          remainingLife: 10,
          color: 0xFF475569,
          createdAtMilliseconds: -1,
          motion: 1,
          isFluid: false,
        ),
      ],
      size: const Size(400, 500),
      deltaSeconds: 1 / 30,
      temperature: 24,
      burnerLit: false,
      randomSeed: 7,
    );

    expect(result.particles, hasLength(1));
    expect(result.particles.single.id, 1);
    expect(result.particles.single.y, greaterThan(0.2));
  });
}
