import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/ui/glide_select.dart';

void main() {
  testWidgets('dropdown menu bounces open like the sidebar menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlideSelect<String>.dropdown(
            options: const [
              GlideSelectOption(value: 'physics', label: 'Physics'),
            ],
            placeholder: 'Choose a subject',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choose a subject'));
    await tester.pump();

    var transition = tester.widget<ScaleTransition>(
      find.byKey(const Key('glide-select-menu-scale')),
    );
    expect(transition.scale.value, closeTo(0.9, 0.001));

    await tester.pump(const Duration(milliseconds: 160));
    transition = tester.widget<ScaleTransition>(
      find.byKey(const Key('glide-select-menu-scale')),
    );
    expect(transition.scale.value, greaterThan(1));

    await tester.pumpAndSettle();
    transition = tester.widget<ScaleTransition>(
      find.byKey(const Key('glide-select-menu-scale')),
    );
    expect(transition.scale.value, closeTo(1, 0.001));
  });

  testWidgets('dropdown menu respects reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: GlideSelect<String>.dropdown(
              options: const [
                GlideSelectOption(value: 'physics', label: 'Physics'),
              ],
              placeholder: 'Choose a subject',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choose a subject'));
    await tester.pump();

    final transition = tester.widget<ScaleTransition>(
      find.byKey(const Key('glide-select-menu-scale')),
    );
    expect(transition.scale.value, 1);
  });

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
