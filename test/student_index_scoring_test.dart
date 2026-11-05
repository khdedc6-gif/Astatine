import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/features/classroom/student_index_scoring.dart';

void main() {
  group('StudentIndexScoring', () {
    test('reduces positive rewards by score tier', () {
      const impact = 1.0;

      expect(
        StudentIndexScoring.calculateChange(
          currentScore: 2.9,
          baseImpact: impact,
          type: StudentIndexChangeType.positive,
        ),
        1.0,
      );
      expect(
        StudentIndexScoring.calculateChange(
          currentScore: 3,
          baseImpact: impact,
          type: StudentIndexChangeType.positive,
        ),
        0.75,
      );
      expect(
        StudentIndexScoring.calculateChange(
          currentScore: 5,
          baseImpact: impact,
          type: StudentIndexChangeType.positive,
        ),
        0.5,
      );
      expect(
        StudentIndexScoring.calculateChange(
          currentScore: 7,
          baseImpact: impact,
          type: StudentIndexChangeType.positive,
        ),
        0.25,
      );
      expect(
        StudentIndexScoring.calculateChange(
          currentScore: 8.5,
          baseImpact: impact,
          type: StudentIndexChangeType.positive,
        ),
        0.1,
      );
      expect(
        StudentIndexScoring.calculateChange(
          currentScore: 10,
          baseImpact: impact,
          type: StudentIndexChangeType.positive,
        ),
        0,
      );
    });

    test('increases negative penalties by score tier', () {
      const impact = 1.0;

      expect(
        StudentIndexScoring.calculateChange(
          currentScore: 1,
          baseImpact: impact,
          type: StudentIndexChangeType.negative,
        ),
        -0.1,
      );
      expect(
        StudentIndexScoring.calculateChange(
          currentScore: 1.5,
          baseImpact: impact,
          type: StudentIndexChangeType.negative,
        ),
        -0.25,
      );
      expect(
        StudentIndexScoring.calculateChange(
          currentScore: 3,
          baseImpact: impact,
          type: StudentIndexChangeType.negative,
        ),
        -0.5,
      );
      expect(
        StudentIndexScoring.calculateChange(
          currentScore: 5,
          baseImpact: impact,
          type: StudentIndexChangeType.negative,
        ),
        -0.75,
      );
      expect(
        StudentIndexScoring.calculateChange(
          currentScore: 7,
          baseImpact: impact,
          type: StudentIndexChangeType.negative,
        ),
        -1.0,
      );
      expect(
        StudentIndexScoring.calculateChange(
          currentScore: 0,
          baseImpact: impact,
          type: StudentIndexChangeType.negative,
        ),
        0,
      );
    });

    test('clamps the resulting score to the 0-10 range', () {
      expect(
        StudentIndexScoring.calculateNewScore(
          currentScore: 9.95,
          baseImpact: 2,
          type: StudentIndexChangeType.positive,
        ),
        10,
      );
      expect(
        StudentIndexScoring.calculateNewScore(
          currentScore: 0.05,
          baseImpact: 2,
          type: StudentIndexChangeType.negative,
        ),
        0,
      );
      expect(StudentIndexScoring.clampScore(-2), 0);
      expect(StudentIndexScoring.clampScore(12), 10);
    });

    test('rejects invalid impact values', () {
      expect(
        () => StudentIndexScoring.calculateChange(
          currentScore: 5,
          baseImpact: 0,
          type: StudentIndexChangeType.positive,
        ),
        throwsArgumentError,
      );
      expect(
        () => StudentIndexScoring.calculateChange(
          currentScore: 5,
          baseImpact: double.infinity,
          type: StudentIndexChangeType.positive,
        ),
        throwsArgumentError,
      );
    });
  });
}
