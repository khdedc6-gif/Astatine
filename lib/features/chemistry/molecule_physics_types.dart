class PhysicsParticleState {
  const PhysicsParticleState({
    required this.id,
    required this.formula,
    required this.seed,
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    required this.scale,
    required this.thermalTime,
    required this.reactionCooldown,
    required this.remainingLife,
    required this.color,
    required this.createdAtMilliseconds,
    required this.motion,
    required this.isFluid,
  });

  final int id;
  final String formula;
  final double seed;
  final double x;
  final double y;
  final double velocityX;
  final double velocityY;
  final double scale;
  final double thermalTime;
  final double reactionCooldown;
  final double remainingLife;
  final int color;
  final int createdAtMilliseconds;
  final int motion;
  final bool isFluid;
}

class PhysicsReactionEvent {
  const PhysicsReactionEvent({
    required this.metalFormula,
    required this.firstFormula,
    required this.secondFormula,
    required this.x,
    required this.y,
  });

  final String metalFormula;
  final String firstFormula;
  final String secondFormula;
  final double x;
  final double y;
}

class PhysicsStepResult {
  const PhysicsStepResult({required this.particles, required this.events});

  final List<PhysicsParticleState> particles;
  final List<PhysicsReactionEvent> events;
}
