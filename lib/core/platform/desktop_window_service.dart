import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowService {
  static const _mobilePlatforms = {TargetPlatform.android, TargetPlatform.iOS};
  static bool _mobileFullscreen = false;

  static bool get isSupported =>
      !kIsWeb &&
      const {
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform);

  static Future<void> initialize() async {
    if (isSupported) await windowManager.ensureInitialized();
  }

  static Future<void> toggleFullscreen() async {
    if (isSupported) {
      final isFullscreen = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFullscreen);
      return;
    }
    if (kIsWeb || !_mobilePlatforms.contains(defaultTargetPlatform)) return;

    final shouldEnterFullscreen = !_mobileFullscreen;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await SystemChrome.setEnabledSystemUIMode(
        shouldEnterFullscreen
            ? SystemUiMode.immersiveSticky
            : SystemUiMode.edgeToEdge,
      );
    } else {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: shouldEnterFullscreen ? [] : SystemUiOverlay.values,
      );
    }
    _mobileFullscreen = shouldEnterFullscreen;
  }
}
