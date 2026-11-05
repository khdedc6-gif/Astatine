import 'dart:async';

import 'package:flutter/material.dart';

enum ToastType { success, error, info, warning, astReward }

class ToastService {
  ToastService._();

  // Shared app-wide navigator used by async flows, background tasks, and
  // service-layer code that cannot access a widget context directly.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void showSuccess(String message, {String? title}) => _show(
    message: message,
    type: ToastType.success,
    title: title ?? 'Thành công',
  );

  static void showError(String message, {String? title}) => _show(
    message: message,
    type: ToastType.error,
    title: title ?? 'Đã có lỗi xảy ra',
  );

  static void showWarning(String message, {String? title}) => _show(
    message: message,
    type: ToastType.warning,
    title: title ?? 'Cảnh báo',
  );

  static void showInfo(String message, {String? title}) => _show(
    message: message,
    type: ToastType.info,
    title: title ?? 'Thông báo',
  );

  static void showAstReward(int amount, String message, {String? title}) =>
      _show(
        message: message,
        type: ToastType.astReward,
        title: title ?? 'AST Reward',
        amount: amount,
      );

  static void _show({
    required String message,
    required ToastType type,
    String? title,
    int? amount,
    BuildContext? context,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = context == null
        ? navigatorKey.currentState?.overlay
        : Overlay.maybeOf(context);
    if (overlay == null) {
      throw StateError(
        'ToastService requires a mounted app navigator or an overlay context.',
      );
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        message: message,
        title: title,
        type: type,
        amount: amount,
        duration: duration,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  static void showWithContext(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) => _show(
    context: context,
    message: message,
    type: type,
    title: title,
    duration: duration,
  );
}

@Deprecated('Use ToastService directly; context is no longer required.')
class DiscordToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) => ToastService.showWithContext(
    context,
    message: message,
    type: type,
    title: title,
    duration: duration,
  );

  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
  }) => ToastService.showWithContext(
    context,
    message: message,
    type: ToastType.success,
    title: title ?? 'Thành công',
  );

  static void showError(
    BuildContext context,
    String message, {
    String? title,
  }) => ToastService.showWithContext(
    context,
    message: message,
    type: ToastType.error,
    title: title ?? 'Đã có lỗi xảy ra',
  );

  static void showInfo(BuildContext context, String message, {String? title}) =>
      ToastService.showWithContext(
        context,
        message: message,
        type: ToastType.info,
        title: title ?? 'Thông báo',
      );

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
  }) => ToastService.showWithContext(
    context,
    message: message,
    type: ToastType.warning,
    title: title ?? 'Cảnh báo',
  );
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
    this.title,
    this.amount,
  });

  final String message;
  final String? title;
  final ToastType type;
  final int? amount;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.2, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color get _accentColor => switch (widget.type) {
    ToastType.success => const Color(0xFF10B981),
    ToastType.error => const Color(0xFFEF4444),
    ToastType.warning => const Color(0xFFF59E0B),
    ToastType.info => const Color(0xFF3B82F6),
    ToastType.astReward => const Color(0xFFFFB800),
  };

  IconData get _icon => switch (widget.type) {
    ToastType.success => Icons.check_circle_rounded,
    ToastType.error => Icons.error_rounded,
    ToastType.warning => Icons.warning_rounded,
    ToastType.info => Icons.info_rounded,
    ToastType.astReward => Icons.token_rounded,
  };

  @override
  Widget build(BuildContext context) => Positioned(
    top: 24,
    right: 24,
    child: SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380, minWidth: 280),
            decoration: BoxDecoration(
              color: const Color(0xFF181A22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _accentColor.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Container(width: 5, color: _accentColor),
                    const SizedBox(width: 12),
                    Icon(_icon, color: _accentColor, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.title != null) ...[
                              Text(
                                widget.title!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              widget.message,
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                            if (widget.amount != null) ...[
                              const SizedBox(height: 5),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '+${widget.amount} AST',
                                      style: TextStyle(
                                        color: _accentColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 16,
                      ),
                      onPressed: _dismiss,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
