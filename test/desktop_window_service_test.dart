import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/platform/desktop_window_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mobile fullscreen toggles the system UI on Android and iOS', () async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      debugDefaultTargetPlatformOverride = null;
    });

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await DesktopWindowService.toggleFullscreen();
    await DesktopWindowService.toggleFullscreen();
    expect(calls[0].arguments, SystemUiMode.immersiveSticky.toString());
    expect(calls[1].arguments, SystemUiMode.edgeToEdge.toString());

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await DesktopWindowService.toggleFullscreen();
    await DesktopWindowService.toggleFullscreen();
    expect(calls[2].method, 'SystemChrome.setEnabledSystemUIOverlays');
    expect(calls[2].arguments, isEmpty);
    expect(calls[3].method, 'SystemChrome.setEnabledSystemUIOverlays');
    expect(calls[3].arguments, isNotEmpty);
  });
}
