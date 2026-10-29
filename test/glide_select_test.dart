import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/ui/glide_select.dart';

void main() {
  testWidgets('selected label springs to about 110% then returns to normal', (
    tester,
  ) async {
    var selected = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                GlideSelect(selected: selected, child: const Text('Physics')),
                TextButton(
                  onPressed: () => setState(() => selected = true),
                  child: const Text('Select'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Select'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final transition = tester.widget<ScaleTransition>(
      find.byKey(const Key('glide-select-scale')),
    );
    expect(transition.scale.value, greaterThan(1));
    expect(transition.scale.value, lessThanOrEqualTo(1.11));

    await tester.pumpAndSettle();
    expect(transition.scale.value, closeTo(1, 0.000001));
  });

  testWidgets('selection respects reduced motion', (tester) async {
    var selected = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(
                children: [
                  GlideSelect(selected: selected, child: const Text('Physics')),
                  TextButton(
                    onPressed: () => setState(() => selected = true),
                    child: const Text('Select'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Select'));
    await tester.pump();

    final transition = tester.widget<ScaleTransition>(
      find.byKey(const Key('glide-select-scale')),
    );
    expect(transition.scale.value, 1);
  });
}
