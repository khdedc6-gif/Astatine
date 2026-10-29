import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class HoverRipple extends StatefulWidget {
  const HoverRipple({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.color,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color? color;

  @override
  State<HoverRipple> createState() => _HoverRippleState();
}

class _HoverRippleState extends State<HoverRipple>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Offset?> _pointerPosition = ValueNotifier(null);
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 220),
      )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && mounted) {
          _pointerPosition.value = null;
        }
      });

  @override
  void dispose() {
    _pointerPosition.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: MouseRegion(
        onEnter: (event) {
          _pointerPosition.value = event.localPosition;
          _controller.forward(from: 0);
        },
        onHover: (event) {
          _pointerPosition.value = event.localPosition;
        },
        onExit: (_) {
          _controller.reverse();
        },
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _HoverRipplePainter(
                      position: _pointerPosition,
                      progress: _controller,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverRipplePainter extends CustomPainter {
  _HoverRipplePainter({
    required this.position,
    required this.progress,
    required this.color,
  }) : super(repaint: Listenable.merge([position, progress]));

  final ValueListenable<Offset?> position;
  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = position.value;
    if (center == null) return;
    final progressValue = Curves.easeOut.transform(progress.value);
    // Nothing to paint when the animation hasn't started yet.
    if (progressValue <= 0) return;
    final radius = size.longestSide * (0.12 + progressValue * 0.75);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.13 * progressValue),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _HoverRipplePainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.progress != progress ||
      oldDelegate.color != color;
}
