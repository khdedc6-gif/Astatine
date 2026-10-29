import 'package:flutter/foundation.dart';

class KioskModePlatform {
  void start({
    required VoidCallback onUnauthorizedFullscreenExit,
    required ValueChanged<bool> onFullscreenShortcut,
  }) {}

  Future<void> enterFullscreen() async {}

  Future<void> exitFullscreen() async {}

  void dispose() {}
}
