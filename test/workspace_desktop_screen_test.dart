import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/features/dashboard/main_dashboard.dart';
import 'package:astatine_dashboard/features/dashboard/workspace_desktop_screen.dart';

void main() {
  testWidgets('F11 toggles fullscreen while the EduPad workspace is open', (
    tester,
  ) async {
    var toggleCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceDesktopScreen(
            strings: AppStrings.vi,
            fullscreenWasLost: false,
            onRetryFullscreen: _noop,
            onToggleFullscreen: () => toggleCount++,
            onExitWorkspace: _noop,
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);

    expect(toggleCount, 1);
  });

  testWidgets('Other apps opens the isolated EduPad desktop', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.vi.otherAppsTitle));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace-app-flashcard')), findsOneWidget);
    expect(find.byKey(const Key('workspace-app-code')), findsOneWidget);
    expect(find.byKey(const Key('workspace-app-browser')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-content-scroll')), findsNothing);
    expect(find.byKey(const Key('workspace-start-button')), findsOneWidget);
  });

  testWidgets('Start Menu is the exit route back to the Astatine dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.vi.otherAppsTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-start-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace-exit-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('workspace-exit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-content-scroll')), findsOneWidget);
    expect(find.byKey(const Key('workspace-start-button')), findsNothing);
  });

  testWidgets('workspace taskbar remains usable on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceDesktopScreen(
            strings: AppStrings.vi,
            fullscreenWasLost: false,
            onRetryFullscreen: _noop,
            onToggleFullscreen: _noop,
            onExitWorkspace: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('workspace-start-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('workspace-app-flashcard')));
    await tester.pumpAndSettle();
    expect(find.text('What is a hypothesis?'), findsOneWidget);
    final layoutError = tester.takeException();
    expect(layoutError, isNull, reason: layoutError?.toString());
  });

  testWidgets('desktop apps open as manageable windows', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceDesktopScreen(
            strings: AppStrings.vi,
            fullscreenWasLost: false,
            onRetryFullscreen: _noop,
            onToggleFullscreen: _noop,
            onExitWorkspace: _noop,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('workspace-app-flashcard')));
    await tester.pumpAndSettle();

    expect(find.text('What is a hypothesis?'), findsOneWidget);
    await tester.tap(find.byTooltip('Minimize'));
    await tester.pumpAndSettle();
    expect(find.text('What is a hypothesis?'), findsNothing);

    await tester.tap(find.byKey(const Key('workspace-app-flashcard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('What is a hypothesis?'), findsNothing);
  });

  testWidgets('control center exposes labeled workspace settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceDesktopScreen(
            strings: AppStrings.vi,
            fullscreenWasLost: false,
            onRetryFullscreen: _noop,
            onToggleFullscreen: _noop,
            onExitWorkspace: _noop,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('workspace-control-center-button')));
    await tester.pumpAndSettle();

    expect(find.text('Chế độ tập trung'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
  });

  testWidgets('fullscreen exit notice offers a re-entry action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceDesktopScreen(
            strings: AppStrings.vi,
            fullscreenWasLost: true,
            onRetryFullscreen: _noop,
            onToggleFullscreen: _noop,
            onExitWorkspace: _noop,
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.vi.workspaceFullscreenNotice), findsOneWidget);
    expect(
      find.byKey(const Key('workspace-reenter-fullscreen')),
      findsOneWidget,
    );
  });
}

void _noop() {}
