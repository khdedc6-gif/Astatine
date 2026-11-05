import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';

class BlueCursorOverlay extends StatefulWidget {
  final Widget child;

  const BlueCursorOverlay({super.key, required this.child});

  @override
  State<BlueCursorOverlay> createState() => _BlueCursorOverlayState();
}

class _BlueCursorOverlayState extends State<BlueCursorOverlay> {
  final ValueNotifier<Offset?> _position = ValueNotifier(null);
  final ValueNotifier<bool> _pressed = ValueNotifier(false);
  final ValueNotifier<bool> _visible = ValueNotifier(false);
  bool _suppressMouseHover = false;
  Timer? _touchHoverSuppressionTimer;

  void _suppressMouseHoverAfterTouch() {
    _suppressMouseHover = true;
    _touchHoverSuppressionTimer?.cancel();
    _touchHoverSuppressionTimer = Timer(const Duration(milliseconds: 600), () {
      _suppressMouseHover = false;
    });
  }

  @override
  void dispose() {
    _touchHoverSuppressionTimer?.cancel();
    _position.dispose();
    _pressed.dispose();
    _visible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: Listenable.merge([_visible, _position, _pressed]),
          builder: (context, _) {
            final position = _position.value;
            if (!_visible.value || position == null) {
              return const SizedBox.shrink();
            }
            return Positioned(
              left: position.dx - 14,
              top: position.dy - 14,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const Key('app-blue-cursor'),
                    size: const Size.square(28),
                    painter: _BlueCursorPainter(
                      pressed: _pressed.value,
                      accent: palette.accent,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned.fill(
          child: MouseRegion(
            cursor: SystemMouseCursors.none,
            hitTestBehavior: HitTestBehavior.translucent,
            onHover: (event) {
              if (event.kind != PointerDeviceKind.mouse ||
                  _suppressMouseHover) {
                return;
              }
              _visible.value = true;
              _position.value = event.localPosition;
            },
            onExit: (_) {
              _visible.value = false;
              _position.value = null;
              _pressed.value = false;
            },
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                if (event.kind == PointerDeviceKind.touch ||
                    event.kind == PointerDeviceKind.stylus ||
                    event.kind == PointerDeviceKind.invertedStylus) {
                  _suppressMouseHoverAfterTouch();
                  _visible.value = false;
                  _position.value = null;
                  _pressed.value = false;
                } else {
                  _pressed.value = true;
                }
              },
              onPointerUp: (event) {
                _pressed.value = false;
                if (event.kind == PointerDeviceKind.touch ||
                    event.kind == PointerDeviceKind.stylus ||
                    event.kind == PointerDeviceKind.invertedStylus) {
                  _visible.value = false;
                  _position.value = null;
                }
              },
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlueCursorPainter extends CustomPainter {
  _BlueCursorPainter({required this.pressed, required this.accent});

  final bool pressed;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final cursorPosition = size.center(Offset.zero);
    final radius = pressed ? 11.5 : 14.0;
    canvas.drawCircle(
      cursorPosition,
      radius,
      Paint()..color = accent.withValues(alpha: 0.09),
    );
    canvas.drawCircle(
      cursorPosition,
      radius - 0.75,
      Paint()
        ..color = accent.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(cursorPosition, 2.5, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _BlueCursorPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.pressed != pressed;
}

class HoverLift extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;

  const HoverLift({
    super.key,
    required this.child,
    this.scale = 1.025,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});

  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) {
      _setPressed(true);
      if (!kIsWeb && event.kind == PointerDeviceKind.touch) {
        unawaited(HapticFeedback.selectionClick());
      }
    },
    onPointerUp: (_) => _setPressed(false),
    onPointerCancel: (_) => _setPressed(false),
    child: AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: Duration(milliseconds: _pressed ? 100 : 240),
      curve: _pressed ? Curves.easeOut : Curves.elasticOut,
      child: widget.child,
    ),
  );
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (!mounted || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.none,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedScale(
        scale: _hovered ? widget.scale : 1,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
