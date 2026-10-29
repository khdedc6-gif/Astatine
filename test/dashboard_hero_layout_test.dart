import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/features/dashboard/main_dashboard.dart';

void main() {
  testWidgets('dashboard hero and Bento cards fit common viewport sizes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final viewport in [
      const Size(375, 812),
      const Size(844, 390),
      const Size(1440, 900),
    ]) {
      tester.view.physicalSize = viewport;
      await tester.pumpWidget(
        MaterialApp(
          theme: AstatinePalette.themeData('Campus'),
          home: Scaffold(
            body: DashboardContent(
              strings: AppStrings.vi,
              userName: 'Người học',
              isVietnamese: true,
              onOpenVirtualLab: _noop,
              onOpenAssignments: _noop,
              onOpenProjectHub: _noop,
              onOpenAppHub: _noop,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'Dashboard layout should fit $viewport without render errors.',
      );
      expect(find.byType(BentoCard), findsNWidgets(4));
      expect(
        find.byKey(const Key('welcome-note-illustration')),
        findsOneWidget,
      );

      final greeting = find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data?.startsWith('Chào ') ?? false),
      );
      final userName = find.text('Người học!');
      expect(greeting, findsOneWidget);
      expect(userName, findsOneWidget);
      expect(
        tester.getTopLeft(greeting).dy,
        lessThan(tester.getTopLeft(userName).dy),
      );
    }
  });
}

void _noop() {}
