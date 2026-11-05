import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';
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
    expect(find.byKey(const Key('workspace-app-files')), findsOneWidget);
    expect(find.byKey(const Key('workspace-app-settings')), findsOneWidget);
    expect(find.byKey(const Key('workspace-app-panel')), findsOneWidget);
    expect(find.byKey(const Key('workspace-app-astatine')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-content-scroll')), findsNothing);
    expect(find.byKey(const Key('workspace-start-button')), findsOneWidget);
  });

  testWidgets('system app shortcuts open their workspace previews', (
    tester,
  ) async {
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
    await tester.tap(find.byKey(const Key('workspace-app-files')));
    await tester.pumpAndSettle();
    expect(find.text('Tệp của bạn sẽ ở đây'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-app-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Không gian của bạn'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-app-panel')));
    await tester.pumpAndSettle();
    expect(find.text('Trung tâm điều khiển'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    tester.view.physicalSize = const Size(375, 740);
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
    expect(find.byKey(const Key('workspace-app-dock')), findsOneWidget);
    expect(
      find.byKey(const Key('workspace-dock-start-divider')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('workspace-status-bar')), findsOneWidget);
    expect(find.text('ASTATINE'), findsNothing);
    expect(find.byKey(const Key('workspace-dock-files')), findsOneWidget);
    expect(find.byKey(const Key('workspace-dock-flashcard')), findsOneWidget);
    await tester.tap(find.byKey(const Key('workspace-dock-flashcard')));
    await tester.pumpAndSettle();
    expect(find.text('What is a hypothesis?'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-app-flashcard')));
    await tester.pumpAndSettle();
    expect(find.text('What is a hypothesis?'), findsOneWidget);
    final layoutError = tester.takeException();
    expect(layoutError, isNull, reason: layoutError?.toString());
  });

  testWidgets('dock magnifies the hovered icon and settles on pointer exit', (
    tester,
  ) async {
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
    await tester.pumpAndSettle();

    final files = find.byKey(const Key('workspace-dock-files'));
    final baseSize = tester.getSize(files).width;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(files));
    await mouse.moveTo(tester.getCenter(files));
    await tester.pumpAndSettle();
    expect(tester.getSize(files).width, greaterThan(baseSize));

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.getSize(files).width, closeTo(baseSize, 0.2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dock renders with the dark Astatine palette', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const <ThemeExtension<dynamic>>[AstatinePalette.dark],
        ),
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

    expect(find.byKey(const Key('workspace-app-dock')), findsOneWidget);
    expect(find.byKey(const Key('workspace-dock-files')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dock supports keyboard launch with reduced motion enabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const <ThemeExtension<dynamic>>[AstatinePalette.campus],
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
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

    final dockTooltip = find.byKey(const Key('workspace-app-dock-tooltip'));
    bool dockButtonHasFocus() {
      final focusContext = tester.binding.focusManager.primaryFocus?.context;
      final focusedButton = focusContext
          ?.findAncestorWidgetOfExactType<InkWell>();
      return focusedButton?.key is ValueKey<String> &&
          (focusedButton!.key as ValueKey<String>).value.startsWith(
            'workspace-dock-',
          );
    }

    for (var attempt = 0; attempt < 40 && !dockButtonHasFocus(); attempt++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }

    expect(dockButtonHasFocus(), isTrue);
    expect(dockTooltip, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('workspace supports multiple draggable, resizable app windows', (
    tester,
  ) async {
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
    await tester.tap(find.byKey(const Key('workspace-app-files')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-app-settings')));
    await tester.pumpAndSettle();

    final filesWindow = find.byKey(const Key('workspace-window-files'));
    final settingsWindow = find.byKey(const Key('workspace-window-settings'));
    expect(filesWindow, findsOneWidget);
    expect(settingsWindow, findsOneWidget);
    expect(find.text('Truy cập nhanh'), findsOneWidget);
    expect(find.text('Không gian của bạn'), findsOneWidget);

    final initialRect = tester.getRect(settingsWindow);
    await tester.drag(
      find.byKey(const Key('workspace-window-titlebar-settings')),
      const Offset(100, 70),
    );
    await tester.pumpAndSettle();
    final movedRect = tester.getRect(settingsWindow);
    expect(movedRect.left, greaterThan(initialRect.left + 50));
    expect(movedRect.top, greaterThan(initialRect.top + 30));

    await tester.drag(
      find.byKey(const Key('workspace-window-resize-settings')),
      const Offset(120, 80),
    );
    await tester.pumpAndSettle();
    final resizedRect = tester.getRect(settingsWindow);
    expect(resizedRect.width, greaterThan(movedRect.width + 20));
    expect(resizedRect.height, greaterThan(movedRect.height + 20));

    await tester.tap(
      find.byKey(const Key('workspace-window-maximize-settings')),
    );
    await tester.pumpAndSettle();
    final maximizedRect = tester.getRect(settingsWindow);
    final workspaceArea = tester.getRect(
      find.byKey(const Key('workspace-window-area')),
    );
    expect(maximizedRect.size, workspaceArea.size);
    expect(maximizedRect.topLeft, workspaceArea.topLeft);

    await tester.tap(
      find.byKey(const Key('workspace-window-maximize-settings')),
    );
    await tester.pumpAndSettle();
    final restoredRect = tester.getRect(settingsWindow);
    expect(restoredRect.width, closeTo(resizedRect.width, 0.1));
    expect(restoredRect.height, closeTo(resizedRect.height, 0.1));

    await tester.tap(
      find.byKey(const Key('workspace-window-minimize-settings')),
    );
    await tester.pumpAndSettle();
    expect(settingsWindow, findsNothing);
    expect(filesWindow, findsOneWidget);
    expect(find.byKey(const Key('workspace-dock-settings')), findsOneWidget);

    await tester.tap(find.byKey(const Key('workspace-dock-settings')));
    await tester.pumpAndSettle();
    expect(settingsWindow, findsOneWidget);
    expect(find.text('Không gian của bạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
