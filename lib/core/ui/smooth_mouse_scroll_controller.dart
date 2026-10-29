import 'package:flutter/material.dart';

class SmoothMouseScrollController extends ScrollController {
  SmoothMouseScrollController();

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SmoothMouseScrollPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

class _SmoothMouseScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothMouseScrollPosition({
    required super.physics,
    required super.context,
    required super.initialPixels,
    required super.keepScrollOffset,
    required super.oldPosition,
    required super.debugLabel,
  });

  double? _wheelTarget;
  int _animationGeneration = 0;
  bool _isWheelAnimating = false;

  @override
  void pointerScroll(double delta) {
    if (delta == 0) {
      _animationGeneration++;
      _wheelTarget = null;
      _isWheelAnimating = false;
      super.pointerScroll(delta);
      return;
    }

    final target = ((_wheelTarget ?? pixels) + delta)
        .clamp(minScrollExtent, maxScrollExtent)
        .toDouble();
    if (target == (_wheelTarget ?? pixels)) return;

    _wheelTarget = target;
    final isRetargeting = _isWheelAnimating;
    _isWheelAnimating = true;
    final generation = ++_animationGeneration;
    animateTo(
      target,
      duration: isRetargeting
          ? const Duration(milliseconds: 48)
          : const Duration(milliseconds: 220),
      curve: isRetargeting ? Curves.easeOutCubic : Curves.decelerate,
    ).whenComplete(() {
      if (generation == _animationGeneration) {
        _wheelTarget = null;
        _isWheelAnimating = false;
      }
    });
  }
}
