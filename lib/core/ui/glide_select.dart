import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class GlideSelect extends StatefulWidget {
  const GlideSelect({super.key, required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  State<GlideSelect> createState() => _GlideSelectState();
}

class _GlideSelectState extends State<GlideSelect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 30,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _scale = _controller.drive(Tween<double>(begin: 1, end: 1.1));
  }

  @override
  void didUpdateWidget(covariant GlideSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected && widget.selected) {
      _playSelectionAnimation();
    }
  }

  void _playSelectionAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller
      ..stop()
      ..value = 0
      ..animateWith(SpringSimulation(_spring, 0, 1, 0)).then((_) {
        if (!mounted) return;
        // Return to rest position using current velocity for a natural bounce.
        _controller.animateWith(
          SpringSimulation(_spring, _controller.value, 0, _controller.velocity),
        );
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    key: const Key('glide-select-scale'),
    scale: _scale,
    alignment: Alignment.center,
    child: widget.child,
  );
}
