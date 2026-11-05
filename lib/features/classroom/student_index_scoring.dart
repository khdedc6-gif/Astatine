enum StudentIndexChangeType { positive, negative }

/// Calculates classroom participation index changes on a 0-10 scale.
class StudentIndexScoring {
  const StudentIndexScoring._();

  static const double minimumScore = 0;
  static const double maximumScore = 10;

  static double calculateChange({
    required double currentScore,
    required double baseImpact,
    required StudentIndexChangeType type,
  }) {
    _validateImpact(baseImpact);
    final score = clampScore(currentScore);
    if (score == minimumScore && type == StudentIndexChangeType.negative ||
        score == maximumScore && type == StudentIndexChangeType.positive) {
      return 0;
    }

    final multiplier = type == StudentIndexChangeType.positive
        ? _positiveMultiplier(score)
        : _negativeMultiplier(score);
    final change = baseImpact * multiplier;
    return type == StudentIndexChangeType.positive ? change : -change;
  }

  static double calculateNewScore({
    required double currentScore,
    required double baseImpact,
    required StudentIndexChangeType type,
  }) {
    final score = clampScore(currentScore);
    final change = calculateChange(
      currentScore: score,
      baseImpact: baseImpact,
      type: type,
    );
    return clampScore(score + change);
  }

  static double clampScore(double score) =>
      score.clamp(minimumScore, maximumScore).toDouble();

  static double _positiveMultiplier(double score) {
    if (score >= 8.5) return 0.1;
    if (score >= 7) return 0.25;
    if (score >= 5) return 0.5;
    if (score >= 3) return 0.75;
    return 1;
  }

  static double _negativeMultiplier(double score) {
    if (score < 1.5) return 0.1;
    if (score < 3) return 0.25;
    if (score < 5) return 0.5;
    if (score < 7) return 0.75;
    return 1;
  }

  static void _validateImpact(double baseImpact) {
    if (!baseImpact.isFinite || baseImpact <= 0) {
      throw ArgumentError.value(
        baseImpact,
        'baseImpact',
        'must be a positive finite number',
      );
    }
  }
}
