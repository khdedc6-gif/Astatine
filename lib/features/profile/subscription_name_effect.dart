import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_profile_store.dart';

class SubscriptionTierCache {
  SubscriptionTierCache._();

  static final Map<String, Future<String>> _tiers = {};

  static Future<String> forUser(String userId) =>
      _tiers.putIfAbsent(userId, () async {
        try {
          final result = await Supabase.instance.client.rpc(
            'get_user_subscription_tier',
            params: {'p_user_id': userId},
          );
          final tier = result?.toString().toUpperCase();
          return const {'FREE', 'PRO', 'ULTRA'}.contains(tier) ? tier! : 'FREE';
        } catch (error) {
          debugPrint(
            'Unable to load a chat participant subscription tier: $error',
          );
          return 'FREE';
        }
      });

  static void invalidate(String userId) {
    _tiers.remove(userId);
  }

  static void clear() {
    _tiers.clear();
  }
}

class SubscriptionUserName extends StatelessWidget {
  const SubscriptionUserName({
    super.key,
    required this.userId,
    required this.fallbackName,
    required this.defaultColor,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w600,
  });

  final String? userId;
  final String fallbackName;
  final Color defaultColor;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    String? resolvedUserId = userId;
    if (resolvedUserId == null) {
      try {
        resolvedUserId = Supabase.instance.client.auth.currentUser?.id;
      } catch (error) {
        debugPrint('Unable to resolve current user subscription: $error');
      }
    }
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      return SubscriptionNameEffect(
        name: fallbackName,
        tier: 'FREE',
        defaultColor: defaultColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
      );
    }
    final resolvedId = resolvedUserId;

    return AnimatedBuilder(
      animation: UserProfileStore.instance,
      builder: (context, _) {
        final profile = UserProfileStore.instance.profileFor(resolvedId);
        final name = (profile?['full_name'] as String?)?.trim();
        final displayName = name?.isNotEmpty == true ? name! : fallbackName;
        return FutureBuilder<String>(
          future: SubscriptionTierCache.forUser(resolvedId),
          builder: (context, snapshot) => SubscriptionNameEffect(
            name: displayName,
            tier: snapshot.data ?? 'FREE',
            defaultColor: defaultColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        );
      },
    );
  }
}

class SubscriptionNameEffect extends StatefulWidget {
  const SubscriptionNameEffect({
    super.key,
    required this.name,
    required this.tier,
    required this.defaultColor,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w700,
  });

  final String name;
  final String tier;
  final Color defaultColor;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  State<SubscriptionNameEffect> createState() => _SubscriptionNameEffectState();
}

class _SubscriptionNameEffectState extends State<SubscriptionNameEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sparkleController;

  Color? get _tierColor => switch (widget.tier) {
    'PRO' => const Color(0xFFBB65E7),
    'ULTRA' => const Color(0xFFFFC400),
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (_tierColor != null) _sparkleController.repeat();
  }

  @override
  void didUpdateWidget(covariant SubscriptionNameEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tierColor != null && !_sparkleController.isAnimating) {
      _sparkleController.repeat();
    } else if (_tierColor == null && _sparkleController.isAnimating) {
      _sparkleController.stop();
      _sparkleController.value = 0;
    }
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _tierColor ?? widget.defaultColor;
    final label = Text(
      widget.name,
      key: const Key('subscription-styled-user-name'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontWeight: widget.fontWeight,
        fontSize: widget.fontSize,
      ),
    );

    if (_tierColor == null) return label;

    return AnimatedBuilder(
      animation: _sparkleController,
      builder: (context, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: label,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const Key('subscription-glitter-particles'),
                painter: _SubscriptionSparklePainter(
                  progress: _sparkleController.value,
                  tier: widget.tier,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionSparklePainter extends CustomPainter {
  const _SubscriptionSparklePainter({
    required this.progress,
    required this.tier,
  });

  final double progress;
  final String tier;

  static const _goldParticleColors = [
    Color(0xFFFFE57F),
    Color(0xFFFFFFFF),
    Color(0xFFFFD700),
  ];
  static const _proParticleColors = [
    Color(0xFFBB65E7),
    Color(0xFFE8C8FF),
    Color(0xFFFFFFFF),
    Color(0xFF8F45C5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final centerFade = _centerFade(progress);
    if (centerFade <= 0) return;

    final colors = tier == 'PRO' ? _proParticleColors : _goldParticleColors;
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);

    for (var index = 0; index < 22; index++) {
      final seed = _fraction(math.sin((index + 1) * 127.1) * 43758.5453);
      final phase = (progress + index / 22) % 1;
      final jitterX = (seed - 0.5) * 0.035;
      final jitterY =
          (_fraction(math.sin((index + 1) * 78.233) * 24634.6345) - 0.5) * 0.36;
      final position = Offset(
        size.width * (phase + jitterX),
        size.height * (0.82 - phase * 0.64 + jitterY),
      );

      final twinkle =
          (0.5 +
                  0.5 *
                      math.sin(
                        2 * math.pi * (progress * (5 + index % 7) + seed * 4),
                      ))
              .clamp(0.0, 1.0);
      final edgeFade = math.min(
        (phase / 0.08).clamp(0.0, 1.0),
        ((1 - phase) / 0.08).clamp(0.0, 1.0),
      );
      final opacity = (0.1 + twinkle * 0.9) * edgeFade * centerFade;
      if (opacity <= 0.01) continue;

      final diameter = 1.0 + seed * 1.5;
      final radius = diameter / 2;
      final color = colors[index % colors.length];
      particlePaint.color = color.withValues(alpha: opacity);
      glowPaint.color = color.withValues(alpha: opacity * 0.38);
      canvas.drawCircle(position, radius * 1.8, glowPaint);
      canvas.drawCircle(position, radius, particlePaint);
    }
  }

  double _centerFade(double value) {
    if (value < 0.40) return 1;
    if (value < 0.49) return 1 - ((value - 0.40) / 0.09);
    if (value < 0.52) return 0;
    if (value < 0.61) return (value - 0.52) / 0.09;
    return 1;
  }

  double _fraction(double value) => value - value.floorToDouble();

  @override
  bool shouldRepaint(covariant _SubscriptionSparklePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.tier != tier;
}
