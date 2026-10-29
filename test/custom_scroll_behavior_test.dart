import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/ui/custom_scroll_behavior.dart';
import 'package:astatine_dashboard/core/ui/hover_ripple.dart';
import 'package:astatine_dashboard/core/ui/smooth_mouse_scroll_controller.dart';

void main() {
  test('allows touch, mouse, and trackpad drag input', () {
    const behavior = CustomScrollBehavior();

    expect(
      behavior.dragDevices,
      containsAll({
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      }),
    );
  });

  testWidgets('uses bouncing physics with always-scrollable parent', (
    tester,
  ) async {
    ScrollPhysics? physics;

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const CustomScrollBehavior(),
        home: Builder(
          builder: (context) {
            physics = ScrollConfiguration.of(context).getScrollPhysics(context);
            return ListView(children: const [Text('Scrollable content')]);
          },
        ),
      ),
    );

    expect(physics, isA<BouncingScrollPhysics>());
    expect(physics!.parent, isA<AlwaysScrollableScrollPhysics>());
  });

  testWidgets('animates mouse wheel input instead of jumping immediately', (
    tester,
  ) async {
    final controller = SmoothMouseScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const CustomScrollBehavior(),
        home: ListView(
          controller: controller,
          children: List.generate(
            30,
            (index) => SizedBox(height: 80, child: Text('Row $index')),
          ),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable).first;
    final position = tester.getCenter(scrollable);
    await tester.sendEventToBinding(
      PointerScrollEvent(position: position, scrollDelta: const Offset(0, 160)),
    );
    await tester.pump();

    expect(controller.offset, lessThan(160));
    await tester.pump(const Duration(milliseconds: 240));
    expect(controller.offset, greaterThan(100));
  });

  testWidgets('keeps wheel bursts moving toward their accumulated target', (
    tester,
  ) async {
    final controller = SmoothMouseScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const CustomScrollBehavior(),
        home: ListView(
          controller: controller,
          children: List.generate(
            40,
            (index) => SizedBox(height: 80, child: Text('Row $index')),
          ),
        ),
      ),
    );

    final position = tester.getCenter(find.byType(Scrollable).first);
    for (var index = 0; index < 4; index++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: const Offset(0, 100),
        ),
      );
    }

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.offset, greaterThan(100));
    expect(controller.offset, lessThan(400));
    await tester.pump(const Duration(milliseconds: 240));
    expect(controller.offset, closeTo(400, 1));
  });

  testWidgets('hover ripple follows the pointer over a card', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 100,
              child: HoverRipple(child: ColoredBox(color: Colors.black)),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.byType(HoverRipple)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    expect(tester.takeException(), isNull);
    await gesture.removePointer();
  });
}
