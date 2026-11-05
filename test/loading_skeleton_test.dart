import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/core/ui/loading_skeleton.dart';

void main() {
  testWidgets(
    'skeleton reports loading accessibly and respects reduced motion',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AstatinePalette.themeData('Campus'),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(body: ClassroomListSkeleton()),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Loading classrooms'), findsOneWidget);
      expect(find.byType(SkeletonBlock), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('classroom chat and assignment skeletons fit compact layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AstatinePalette.themeData('Dark'),
        home: const Scaffold(
          body: Column(
            children: [
              Expanded(child: ClassroomChatSkeleton()),
              Expanded(child: AssignmentCardsSkeleton()),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.bySemanticsLabel('Đang tải lớp học và kênh chat'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Đang tải bài tập'), findsOneWidget);
    expect(find.byType(SkeletonBlock), findsWidgets);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('page skeleton layouts adapt to narrow and wide screens', (
    tester,
  ) async {
    for (final size in [const Size(360, 800), const Size(1280, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AstatinePalette.themeData('Neon'),
          home: const Scaffold(
            body: Column(
              children: [
                Expanded(child: SeatingChartSkeleton()),
                Expanded(child: AnalyticsSkeleton()),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('flashcard skeleton lays out in a scroll view', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AstatinePalette.themeData('Dark'),
        home: const Scaffold(
          body: CustomScrollView(
            slivers: [SliverToBoxAdapter(child: FlashcardGridSkeleton())],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Loading flashcard decks'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('subject rate skeleton fits a compact details panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AstatinePalette.themeData('Matcha Latte'),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SubjectRatePanelSkeleton(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Đang tải điểm môn học'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
