import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chemical_models.dart';

class MoleculeTileCanvas extends StatelessWidget {
  const MoleculeTileCanvas({
    super.key,
    required this.animation,
    required this.reactionAnimation,
    required this.temperature,
    required this.tiles,
    this.accentColor = const Color(0xFF35D9E8),
  });

  final Animation<double> animation;
  final Animation<double> reactionAnimation;
  final double temperature;
  final List<MoleculeTile> tiles;
  final Color accentColor;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: MoleculeTilePainter(
      animation: animation,
      reactionAnimation: reactionAnimation,
      temperature: temperature,
      tiles: tiles,
      accentColor: accentColor,
    ),
    child: const SizedBox.expand(),
  );
}

class MoleculeTilePainter extends CustomPainter {
  MoleculeTilePainter({
    required this.animation,
    required this.reactionAnimation,
    required this.temperature,
    required this.tiles,
    required this.accentColor,
  }) : super(repaint: Listenable.merge([animation, reactionAnimation]));

  final Animation<double> animation;
  final Animation<double> reactionAnimation;
  final double temperature;
  final List<MoleculeTile> tiles;
  final Color accentColor;

  static final Map<String, TextPainter> _labelCache = {};

  static void clearLabelCache() => _labelCache.clear();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final vessel = Path()
      ..moveTo(size.width * 0.22, size.height * 0.12)
      ..lineTo(size.width * 0.29, size.height * 0.80)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.88,
        size.width * 0.41,
        size.height * 0.89,
      )
      ..lineTo(size.width * 0.59, size.height * 0.89)
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.88,
        size.width * 0.71,
        size.height * 0.80,
      )
      ..lineTo(size.width * 0.78, size.height * 0.12);

    canvas.drawPath(
      vessel,
      Paint()
        ..color = accentColor.withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.12),
      Offset(size.width * 0.82, size.height * 0.12),
      Paint()
        ..color = accentColor.withValues(alpha: 0.72)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    final interior = Path()
      ..moveTo(size.width * 0.23, size.height * 0.13)
      ..lineTo(size.width * 0.30, size.height * 0.80)
      ..quadraticBezierTo(
        size.width * 0.31,
        size.height * 0.86,
        size.width * 0.42,
        size.height * 0.87,
      )
      ..lineTo(size.width * 0.58, size.height * 0.87)
      ..quadraticBezierTo(
        size.width * 0.69,
        size.height * 0.86,
        size.width * 0.70,
        size.height * 0.80,
      )
      ..lineTo(size.width * 0.77, size.height * 0.13)
      ..close();

    final tileWidth = (size.width * 0.07).clamp(36.0, 48.0);
    final tileHeight = (size.height * 0.05).clamp(24.0, 32.0);
    final cornerRadius = Radius.circular(math.min(tileHeight * 0.24, 6));
    final paint = Paint();

    canvas.save();
    canvas.clipPath(interior);
    for (final tile in tiles) {
      final opacity = tile.motion == SymbolicParticleMotion.consumed
          ? 1 - reactionAnimation.value
          : tile.motion == SymbolicParticleMotion.gas
          ? (tile.remainingLife / 5.5).clamp(0.0, 1.0)
          : 1.0;
      if (opacity <= 0) continue;
      final rect = Rect.fromCenter(
        center: Offset(tile.x * size.width, tile.y * size.height),
        width: tileWidth * tile.scale,
        height: tileHeight * tile.scale,
      );
      final roundedRect = RRect.fromRectAndRadius(rect, cornerRadius);
      if (tile.thermalTime > 0) {
        canvas.drawRRect(
          roundedRect.inflate(2.5),
          Paint()
            ..color = const Color(0xFFFF9F43)
                .withValues(alpha: (tile.thermalTime / 1.8).clamp(0.0, 0.7))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas.drawRRect(
        roundedRect,
        paint..color = tile.backgroundColor.withValues(alpha: opacity * 0.98),
      );
      canvas.drawRRect(
        roundedRect,
        Paint()
          ..color = tile.borderColor.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      final label = _labelFor(tile, tileWidth, opacity);
      label.paint(
        canvas,
        Offset(
          rect.center.dx - label.width / 2,
          rect.center.dy - label.height / 2,
        ),
      );
    }
    canvas.restore();
  }

  TextPainter _labelFor(MoleculeTile tile, double tileWidth, double opacity) {
    final fontSize = tile.formula.length > 6
        ? 8.0
        : tile.formula.length > 4
        ? 9.0
        : 11.0;
    final color = tile.foregroundColor.withValues(alpha: opacity);
    final key =
        '${tile.formula}:${color.toARGB32()}:${fontSize.toStringAsFixed(1)}';
    return _labelCache.putIfAbsent(key, () {
      if (_labelCache.length >= 512) {
        _labelCache.remove(_labelCache.keys.first);
      }
      return TextPainter(
        text: TextSpan(
          text: tile.formula,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: tileWidth - 4);
    });
  }

  @override
  bool shouldRepaint(covariant MoleculeTilePainter oldDelegate) => true;
}
