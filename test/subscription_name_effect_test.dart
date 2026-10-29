import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/features/profile/subscription_name_effect.dart';

void main() {
  testWidgets(
    'premium user names use their tier color and animated particles',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SubscriptionNameEffect(
                  name: 'Pro user',
                  tier: 'PRO',
                  defaultColor: Colors.white,
                ),
                SubscriptionNameEffect(
                  name: 'Ultra user',
                  tier: 'ULTRA',
                  defaultColor: Colors.white,
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.widget<Text>(find.text('Pro user')).style?.color,
        const Color(0xFFBB65E7),
      );
      expect(
        tester.widget<Text>(find.text('Ultra user')).style?.color,
        const Color(0xFFFFC400),
      );
      expect(
        find.byKey(const Key('subscription-glitter-particles')),
        findsNWidgets(2),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('free names keep their default color without particles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SubscriptionNameEffect(
            name: 'Free user',
            tier: 'FREE',
            defaultColor: Colors.white,
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Free user')).style?.color,
      Colors.white,
    );
    expect(
      find.byKey(const Key('subscription-glitter-particles')),
      findsNothing,
    );
  });
}
