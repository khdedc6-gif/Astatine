import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/branding/app_branding_assets.dart';
import 'package:astatine_dashboard/core/notifications/toast.dart';
import 'package:astatine_dashboard/features/admin/admin_terminal.dart';
import 'package:astatine_dashboard/features/dashboard/main_dashboard.dart';

void main() {
  testWidgets('F11 toggles desktop fullscreen from the application host', (
    tester,
  ) async {
    var fullscreenToggleCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ToastService.navigatorKey,
        home: AdminTerminalHost(
          isDevLoader: () async => false,
          sessionLoader: () async => false,
          maintenanceLoader: () async => {'maintenance_mode': false},
          fullscreenToggler: () async => fullscreenToggleCount++,
          onForceLogout: () async {},
          child: const Scaffold(body: Text('Application screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await tester.pumpAndSettle();

    expect(fullscreenToggleCount, 1);
    expect(find.text('Application screen'), findsOneWidget);
  });

  testWidgets('dashboard fullscreen button shares the F11 callback', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    var fullscreenToggleCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ToastService.navigatorKey,
        home: AdminTerminalHost(
          isDevLoader: () async => false,
          sessionLoader: () async => false,
          maintenanceLoader: () async => {'maintenance_mode': false},
          fullscreenToggler: () async => fullscreenToggleCount++,
          onForceLogout: () async {},
          child: const MainLayoutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard-fullscreen-toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('focus-mode-toggle')), findsNothing);
    expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard-fullscreen-toggle')));
    await tester.pumpAndSettle();

    expect(fullscreenToggleCount, 1);
  });

  testWidgets('admin shortcut authorizes and runs terminal commands', (
    tester,
  ) async {
    var cacheClearCount = 0;
    var logoutCount = 0;
    BrandingAssetSlot? selectedBrandingSlot;
    BrandingImageSetting? uploadedCrop;
    final rpcCalls = <({String name, Map<String, dynamic> params})>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ToastService.navigatorKey,
        home: AdminTerminalHost(
          isDevLoader: () async => true,
          sessionLoader: () async => true,
          maintenanceLoader: () async => {'maintenance_mode': false},
          cacheClearer: () async => cacheClearCount++,
          adminRpc: (name, params) async {
            rpcCalls.add((name: name, params: params));
            if (params['p_username'] == 'missing') {
              throw StateError('Username not found');
            }
            return switch (name) {
              'admin_ban_user' => {'username': params['p_username']},
              'admin_unban_user' => {'username': params['p_username']},
              'admin_give_resource' => {
                'username': params['p_username'],
                'quantity': params['p_quantity'],
                'balance': '120.5',
                'kind': params['p_kind'],
                'days': params['p_quantity'],
                'expires_at': '2026-10-25T00:00:00Z',
              },
              'admin_set_maintenance_mode' => {
                'maintenance_mode': params['p_enabled'],
              },
              _ => throw StateError('Unexpected RPC $name'),
            };
          },
          onForceLogout: () async => logoutCount++,
          brandingImagePicker: () async => BrandingImageFile(
            bytes: Uint8List.fromList(const [
              0x89,
              0x50,
              0x4e,
              0x47,
              0x0d,
              0x0a,
              0x1a,
              0x0a,
              0x00,
              0x00,
              0x00,
              0x0d,
              0x49,
              0x48,
              0x44,
              0x52,
              0x00,
              0x00,
              0x00,
              0x01,
              0x00,
              0x00,
              0x00,
              0x01,
              0x08,
              0x06,
              0x00,
              0x00,
              0x00,
              0x1f,
              0x15,
              0xc4,
              0x89,
              0x00,
              0x00,
              0x00,
              0x0b,
              0x49,
              0x44,
              0x41,
              0x54,
              0x78,
              0x9c,
              0x63,
              0x60,
              0x00,
              0x02,
              0x00,
              0x00,
              0x05,
              0x00,
              0x01,
              0xa5,
              0xf6,
              0x45,
              0x40,
              0x00,
              0x00,
              0x00,
              0x00,
              0x49,
              0x45,
              0x4e,
              0x44,
              0xae,
              0x42,
              0x60,
              0x82,
            ]),
            name: 'preview.png',
          ),
          brandingImageUploader: (slot, file, crop) async {
            selectedBrandingSlot = slot;
            uploadedCrop = crop;
            return 'https://assets.example.test/$slot';
          },
          child: const Scaffold(body: Text('Application screen')),
        ),
      ),
    );

    await _openTerminal(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Access Granted'), findsOneWidget);
    expect(find.text('PS C:\\Astatine>'), findsOneWidget);
    expect(find.text('Enter command'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
      isNull,
    );
    expect(find.byKey(const Key('admin-upload-visuals')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('admin-upload-visuals')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overview illustration'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('branding-image-publish')), findsOneWidget);
    expect(find.text('Preview overview illustration'), findsOneWidget);
    await tester.drag(find.byType(Slider).first, const Offset(80, 0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('branding-image-publish')));
    await tester.tap(find.byKey(const Key('branding-image-publish')));
    await tester.pumpAndSettle();
    expect(selectedBrandingSlot, BrandingAssetSlot.overviewIllustration);
    expect(uploadedCrop!.scale, greaterThan(1));
    expect(uploadedCrop?.x, 0);
    expect(uploadedCrop?.y, 0);
    expect(
      find.text('Overview illustration image uploaded and published.'),
      findsOneWidget,
    );

    await _submitCommand(tester, 'help');
    expect(
      find.textContaining('help  clear  clear-cache  upload-visuals  ban'),
      findsOneWidget,
    );

    await _submitCommand(tester, 'clear-cache');
    await tester.pumpAndSettle();
    expect(cacheClearCount, 1);
    expect(find.text('Local in-memory caches cleared.'), findsOneWidget);

    await _submitCommand(tester, 'ban Alice 7d repeated abuse');
    await tester.pumpAndSettle();
    expect(rpcCalls.last.name, 'admin_ban_user');
    expect(rpcCalls.last.params['p_username'], 'Alice');
    expect(rpcCalls.last.params['p_reason'], 'repeated abuse');
    expect(find.textContaining('Banned Alice until'), findsOneWidget);

    await _submitCommand(tester, 'ban Alice p severe abuse');
    await tester.pumpAndSettle();
    expect(rpcCalls.last.params['p_banned_until'], isNull);
    expect(find.textContaining('Banned Alice permanently'), findsOneWidget);

    await _submitCommand(tester, 'unban Alice');
    await tester.pumpAndSettle();
    expect(rpcCalls.last.name, 'admin_unban_user');
    expect(find.text('Unbanned Alice.'), findsOneWidget);

    await _submitCommand(tester, 'give ast Alice 25.5');
    await tester.pumpAndSettle();
    expect(rpcCalls.last.name, 'admin_give_resource');
    expect(rpcCalls.last.params['p_kind'], 'ast');
    expect(find.textContaining('Granted 25.5 AST'), findsOneWidget);

    await _submitCommand(tester, 'give pro Alice 14');
    await tester.pumpAndSettle();
    expect(rpcCalls.last.params['p_kind'], 'pro');
    expect(find.textContaining('Granted PRO for 14 days'), findsOneWidget);

    final callCountBeforeInvalidGrant = rpcCalls.length;
    await _submitCommand(tester, 'give ultra Alice 1.5');
    await tester.pumpAndSettle();
    expect(rpcCalls.length, callCountBeforeInvalidGrant);
    expect(
      find.text('Subscription quantity must be whole days (maximum 36500).'),
      findsOneWidget,
    );

    await _submitCommand(tester, 'ban missing 7d unknown account');
    await tester.pumpAndSettle();
    expect(find.textContaining('Ban failed:'), findsOneWidget);
    expect(find.textContaining('Username not found'), findsOneWidget);

    await _submitCommand(tester, 'shutdown database');
    await tester.pumpAndSettle();
    expect(rpcCalls.last.name, 'admin_set_maintenance_mode');
    expect(rpcCalls.last.params['p_enabled'], true);
    expect(
      find.textContaining('Global app maintenance enabled'),
      findsOneWidget,
    );

    await _submitCommand(tester, 'maintenance off');
    await tester.pumpAndSettle();
    expect(rpcCalls.last.params['p_enabled'], false);
    expect(
      find.textContaining('Global app maintenance disabled'),
      findsOneWidget,
    );

    await _submitCommand(tester, 'force-logout');
    await tester.pumpAndSettle();
    expect(logoutCount, 1);

    await _submitCommand(tester, 'exit');
    await tester.pumpAndSettle();
    expect(find.text('Application screen'), findsOneWidget);
  });

  testWidgets('three-finger touch opens the admin terminal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ToastService.navigatorKey,
        home: AdminTerminalHost(
          isDevLoader: () async => true,
          sessionLoader: () async => true,
          maintenanceLoader: () async => {'maintenance_mode': false},
          onForceLogout: () async {},
          child: const Scaffold(body: Text('Application screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final first = await tester.startGesture(
      const Offset(100, 100),
      pointer: 101,
    );
    final second = await tester.startGesture(
      const Offset(120, 100),
      pointer: 102,
    );
    final third = await tester.startGesture(
      const Offset(140, 100),
      pointer: 103,
    );
    await third.up();
    await second.up();
    await first.up();
    await tester.pumpAndSettle();

    expect(find.textContaining('Access Granted'), findsOneWidget);
  });

  testWidgets('five rapid taps on the app name open the terminal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ToastService.navigatorKey,
        home: AdminTerminalHost(
          isDevLoader: () async => true,
          sessionLoader: () async => true,
          maintenanceLoader: () async => {'maintenance_mode': false},
          onForceLogout: () async {},
          child: const Scaffold(
            body: Center(
              child: AdminTerminalTapTarget(child: Text('Astatine')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var tap = 0; tap < 5; tap++) {
      await tester.tap(find.text('Astatine'));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(find.textContaining('Access Granted'), findsOneWidget);
  });

  testWidgets('command input auto-focuses and keeps focus after Enter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ToastService.navigatorKey,
        home: AdminTerminalHost(
          isDevLoader: () async => true,
          sessionLoader: () async => true,
          maintenanceLoader: () async => {'maintenance_mode': false},
          onForceLogout: () async {},
          child: const Scaffold(body: Text('Application screen')),
        ),
      ),
    );

    await _openTerminal(tester);
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.focusNode?.hasFocus, isTrue);

    await _submitCommand(tester, 'help');
    await tester.pumpAndSettle();

    final submittedInput = tester.widget<TextField>(find.byType(TextField));
    expect(submittedInput.controller?.text, isEmpty);
    expect(submittedInput.focusNode?.hasFocus, isTrue);
  });

  testWidgets('terminal cannot be opened when is_dev is false', (tester) async {
    var verificationCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ToastService.navigatorKey,
        home: AdminTerminalHost(
          isDevLoader: () async {
            verificationCount++;
            return false;
          },
          sessionLoader: () async => true,
          maintenanceLoader: () async => {'maintenance_mode': false},
          cacheClearer: () async {},
          adminRpc: (name, params) async => {},
          onForceLogout: () async {},
          child: const Scaffold(
            body: Center(
              child: AdminTerminalTapTarget(child: Text('Astatine')),
            ),
          ),
        ),
      ),
    );

    await _openTerminal(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('ASTATINE ADMIN TERMINAL'), findsNothing);

    for (var tap = 0; tap < 5; tap++) {
      await tester.tap(find.text('Astatine'));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('ASTATINE ADMIN TERMINAL'), findsNothing);

    final first = await tester.startGesture(
      const Offset(100, 100),
      pointer: 201,
    );
    final second = await tester.startGesture(
      const Offset(120, 100),
      pointer: 202,
    );
    final third = await tester.startGesture(
      const Offset(140, 100),
      pointer: 203,
    );
    await third.up();
    await second.up();
    await first.up();
    await tester.pumpAndSettle();

    expect(find.textContaining('ASTATINE ADMIN TERMINAL'), findsNothing);
    expect(find.text('Enter command'), findsNothing);
    expect(verificationCount, greaterThanOrEqualTo(3));
  });

  testWidgets('initial system check does not replace the application screen', (
    tester,
  ) async {
    final sessionResult = Completer<bool>();
    final maintenanceResult = Completer<Map<String, dynamic>?>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ToastService.navigatorKey,
        home: AdminTerminalHost(
          isDevLoader: () async => false,
          sessionLoader: () => sessionResult.future,
          maintenanceLoader: () => maintenanceResult.future,
          onForceLogout: () async {},
          child: const Scaffold(body: Text('Application screen')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Application screen'), findsOneWidget);
    expect(find.text('Đang kiểm tra hệ thống'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    sessionResult.complete(true);
    maintenanceResult.complete({'maintenance_mode': false});
    await tester.pumpAndSettle();
    expect(find.text('Application screen'), findsOneWidget);
  });

  testWidgets('global maintenance blocks authenticated non-developer UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ToastService.navigatorKey,
        home: AdminTerminalHost(
          isDevLoader: () async => false,
          sessionLoader: () async => true,
          maintenanceLoader: () async => {
            'maintenance_mode': true,
            'maintenance_message': 'Hệ thống đang bảo trì khẩn cấp',
          },
          cacheClearer: () async {},
          adminRpc: (name, params) async => {},
          onForceLogout: () async {},
          child: const Scaffold(body: Text('Application screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hệ thống đang bảo trì khẩn cấp'), findsOneWidget);
    expect(find.text('Application screen'), findsNothing);
  });

  testWidgets('global maintenance leaves developers in the application', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ToastService.navigatorKey,
        home: AdminTerminalHost(
          isDevLoader: () async => true,
          sessionLoader: () async => true,
          maintenanceLoader: () async => {
            'maintenance_mode': true,
            'maintenance_message': 'Hệ thống đang bảo trì khẩn cấp',
          },
          cacheClearer: () async {},
          adminRpc: (name, params) async => {},
          onForceLogout: () async {},
          child: const Scaffold(body: Text('Application screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Application screen'), findsOneWidget);
    expect(find.text('Hệ thống đang bảo trì khẩn cấp'), findsNothing);
  });
}

Future<void> _openTerminal(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> _submitCommand(WidgetTester tester, String command) async {
  await tester.enterText(find.byType(TextField), command);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}
