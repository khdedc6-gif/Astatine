import 'package:flutter/foundation.dart';

import 'kiosk_mode_stub.dart'
    if (dart.library.js_interop) 'kiosk_mode_web.dart'
    as platform;

class KioskModeService {
  final platform.KioskModePlatform _platform = platform.KioskModePlatform();

  void start({
    required VoidCallback onUnauthorizedFullscreenExit,
    required ValueChanged<bool> onFullscreenShortcut,
  }) {
    _platform.start(
      onUnauthorizedFullscreenExit: onUnauthorizedFullscreenExit,
      onFullscreenShortcut: onFullscreenShortcut,
    );
  }

  Future<void> enterFullscreen() => _platform.enterFullscreen();

  Future<void> exitFullscreen() => _platform.exitFullscreen();

  void dispose() => _platform.dispose();
}
