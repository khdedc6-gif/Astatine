import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class KioskModePlatform {
  VoidCallback? _onUnauthorizedFullscreenExit;
  ValueChanged<bool>? _onFullscreenShortcut;
  bool _isActive = false;

  late final web.EventListener _keyDownListener = ((
    web.Event event,
  ) => _handleKeyDown(event)).toJS;
  late final web.EventListener _fullscreenChangeListener = ((
    web.Event event,
  ) => _handleFullscreenChange()).toJS;

  void start({
    required VoidCallback onUnauthorizedFullscreenExit,
    required ValueChanged<bool> onFullscreenShortcut,
  }) {
    if (_isActive) return;

    _isActive = true;
    _onUnauthorizedFullscreenExit = onUnauthorizedFullscreenExit;
    _onFullscreenShortcut = onFullscreenShortcut;
    web.window.addEventListener('keydown', _keyDownListener, true.toJS);
    web.document.addEventListener(
      'fullscreenchange',
      _fullscreenChangeListener,
    );
  }

  Future<void> enterFullscreen() async {
    final root = web.document.documentElement;
    if (root == null) {
      throw StateError('The browser document has no root element.');
    }
    await root.requestFullscreen().toDart;
  }

  Future<void> exitFullscreen() async {
    if (web.document.fullscreenElement != null) {
      await web.document.exitFullscreen().toDart;
    }
  }

  void _handleKeyDown(web.Event event) {
    final keyEvent = event as web.KeyboardEvent;
    if (keyEvent.key == 'F11' || keyEvent.keyCode == 122) {
      keyEvent
        ..preventDefault()
        ..stopPropagation()
        ..stopImmediatePropagation();
      _onFullscreenShortcut?.call(web.document.fullscreenElement != null);
    }
  }

  void _handleFullscreenChange() {
    if (_isActive && web.document.fullscreenElement == null) {
      _onUnauthorizedFullscreenExit?.call();
    }
  }

  void dispose() {
    if (!_isActive) return;

    _isActive = false;
    _onUnauthorizedFullscreenExit = null;
    _onFullscreenShortcut = null;
    web.window.removeEventListener('keydown', _keyDownListener, true.toJS);
    web.document.removeEventListener(
      'fullscreenchange',
      _fullscreenChangeListener,
    );
  }
}
