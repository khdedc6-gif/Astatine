import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

@immutable
class GlideSelectOption<T> {
  const GlideSelectOption({required this.value, required this.label, this.tag});

  final T value;
  final String label;
  final String? tag;
}

enum GlideSelectSize { sm, md, lg }

class GlideSelect<T> extends StatefulWidget {
  const GlideSelect({super.key, required bool selected, required Widget child})
    : options = null,
      value = null,
      defaultValue = null,
      onChanged = null,
      placeholder = '',
      showTags = false,
      size = GlideSelectSize.md,
      radius = 10,
      menuWidth = null,
      placement = AxisDirection.down,
      align = Alignment.centerLeft,
      disabled = false,
      decoration = null,
      legacySelected = selected,
      legacyChild = child;

  const GlideSelect.dropdown({
    super.key,
    required List<GlideSelectOption<T>> this.options,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.placeholder = 'Select…',
    this.showTags = true,
    this.size = GlideSelectSize.md,
    this.radius = 10,
    this.menuWidth,
    this.placement = AxisDirection.down,
    this.align = Alignment.centerLeft,
    this.disabled = false,
    this.decoration,
  }) : legacySelected = null,
       legacyChild = null;

  final List<GlideSelectOption<T>>? options;
  final T? value;
  final T? defaultValue;
  final ValueChanged<T?>? onChanged;
  final String placeholder;
  final bool showTags;
  final GlideSelectSize size;
  final double radius;
  final double? menuWidth;
  final AxisDirection placement;
  final Alignment align;
  final bool disabled;
  final InputDecoration? decoration;

  final bool? legacySelected;
  final Widget? legacyChild;

  bool get isDropdown => options != null;

  @override
  State<GlideSelect<T>> createState() => _GlideSelectState<T>();
}

class _GlideSelectState<T> extends State<GlideSelect<T>>
    with TickerProviderStateMixin {
  late final AnimationController _legacyController;
  late final Animation<double> _legacyScale;
  late final AnimationController _menuAnimationController;
  late final Animation<double> _menuOpacityAnimation;
  late final Animation<double> _menuScaleAnimation;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Timer? _typeaheadTimer;
  String _typeahead = '';
  T? _innerValue;
  int? _activeIndex;
  bool _isOpen = false;

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 30,
  );

  @override
  void initState() {
    super.initState();
    _legacyController = AnimationController.unbounded(vsync: this);
    _legacyScale = _legacyController.drive(Tween<double>(begin: 1, end: 1.1));
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
    )..addStatusListener(_handleMenuAnimationStatus);
    _menuOpacityAnimation = CurvedAnimation(
      parent: _menuAnimationController,
      curve: Curves.easeOutCubic,
    );
    _menuScaleAnimation = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
        parent: _menuAnimationController,
        curve: const Cubic(0.34, 1.45, 0.64, 1),
      ),
    );
    _innerValue = widget.defaultValue;
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant GlideSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.legacySelected == true && oldWidget.legacySelected != true) {
      _playSelectionAnimation();
    }
    if (_isOpen) _overlayEntry?.markNeedsBuild();
  }

  T? get _currentValue => widget.value ?? _innerValue;

  GlideSelectOption<T>? get _selectedOption {
    final value = _currentValue;
    for (final option in widget.options ?? <GlideSelectOption<T>>[]) {
      if (option.value == value) return option;
    }
    return null;
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _isOpen) _close();
  }

  void _handleMenuAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || _isOpen) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _playSelectionAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _legacyController
      ..stop()
      ..value = 0
      ..animateWith(SpringSimulation(_spring, 0, 1, 0)).then((_) {
        if (!mounted) return;
        _legacyController.animateWith(
          SpringSimulation(
            _spring,
            _legacyController.value,
            0,
            _legacyController.velocity,
          ),
        );
      });
  }

  void _toggle() {
    if (widget.disabled) return;
    if (_isOpen) {
      _close();
    } else {
      _open(viaKeyboard: false);
    }
  }

  void _open({required bool viaKeyboard}) {
    if (widget.disabled || widget.options == null || widget.options!.isEmpty) {
      return;
    }
    final selected = widget.options!.indexWhere(
      (option) => option.value == _currentValue,
    );
    _activeIndex = selected >= 0 ? selected : (viaKeyboard ? 0 : null);
    _isOpen = true;
    _focusNode.requestFocus();
    if (_overlayEntry == null) {
      _menuAnimationController.value = 0;
      _overlayEntry = OverlayEntry(builder: _buildOverlay);
      Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _menuAnimationController.value = 1;
    } else {
      _menuAnimationController.forward();
    }
    setState(() {});
  }

  void _close({bool rebuild = true}) {
    if (!_isOpen) return;
    _isOpen = false;
    _activeIndex = null;
    _typeaheadTimer?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _menuAnimationController.value = 0;
      _overlayEntry?.remove();
      _overlayEntry = null;
    } else if (_overlayEntry != null) {
      _menuAnimationController.reverse();
    }
    if (rebuild && mounted) setState(() {});
  }

  void _select(int index) {
    final options = widget.options;
    if (options == null || index < 0 || index >= options.length) return;
    final selected = options[index].value;
    if (selected != _currentValue) {
      if (widget.value == null) _innerValue = selected;
      widget.onChanged?.call(selected);
    }
    _close();
    _focusNode.requestFocus();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent || widget.options == null) return;
    final options = widget.options!;
    if (!_isOpen) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _open(viaKeyboard: true);
      }
      return;
    }
    final current = _activeIndex ?? 0;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      _close();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _activeIndex = (current + 1).clamp(0, options.length - 1));
      _overlayEntry?.markNeedsBuild();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _activeIndex = (current - 1).clamp(0, options.length - 1));
      _overlayEntry?.markNeedsBuild();
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      setState(() => _activeIndex = 0);
      _overlayEntry?.markNeedsBuild();
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      setState(() => _activeIndex = options.length - 1);
      _overlayEntry?.markNeedsBuild();
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _select(current);
    } else if (event.character case final String character
        when character.length == 1) {
      _typeahead += character.toLowerCase();
      _typeaheadTimer?.cancel();
      _typeaheadTimer = Timer(const Duration(milliseconds: 500), () {
        _typeahead = '';
      });
      final index = options.indexWhere(
        (option) => option.label.toLowerCase().startsWith(_typeahead),
      );
      if (index >= 0) {
        setState(() => _activeIndex = index);
        _overlayEntry?.markNeedsBuild();
      }
    }
  }

  Widget _buildOverlay(BuildContext context) {
    final renderBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final width = widget.menuWidth ?? renderBox?.size.width ?? 176;
    final isAbove = widget.placement == AxisDirection.up;
    final selectedIndex = widget.options!.indexWhere(
      (option) => option.value == _currentValue,
    );
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: isAbove ? Alignment.topLeft : Alignment.bottomLeft,
            followerAnchor: isAbove ? Alignment.bottomLeft : Alignment.topLeft,
            offset: Offset(0, isAbove ? -6 : 6),
            child: Material(
              color: Colors.transparent,
              child: FadeTransition(
                key: const Key('glide-select-menu-fade'),
                opacity: _menuOpacityAnimation,
                child: ScaleTransition(
                  key: const Key('glide-select-menu-scale'),
                  scale: _menuScaleAnimation,
                  alignment: isAbove ? Alignment.bottomLeft : Alignment.topLeft,
                  child: _GlideMenu<T>(
                    width: width,
                    radius: widget.radius,
                    options: widget.options!,
                    selectedIndex: selectedIndex,
                    activeIndex: _activeIndex,
                    showTags: widget.showTags,
                    onHover: (index) {
                      _activeIndex = index;
                    },
                    onSelect: _select,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(BuildContext context) {
    final palette =
        Theme.of(context).extension<_GlidePalette>() ??
        _GlidePalette.fromTheme(Theme.of(context));
    final selected = _selectedOption;
    final horizontal = switch (widget.size) {
      GlideSelectSize.sm => 10.0,
      GlideSelectSize.md => 12.0,
      GlideSelectSize.lg => 14.0,
    };
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: palette.text,
      fontSize: switch (widget.size) {
        GlideSelectSize.sm => 12,
        GlideSelectSize.md => 13,
        GlideSelectSize.lg => 14,
      },
    );
    final decoration = widget.decoration;
    return CompositedTransformTarget(
      link: _layerLink,
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          key: _triggerKey,
          width: constraints.hasBoundedWidth
              ? double.infinity
              : widget.menuWidth ?? 176,
          child: Focus(
            focusNode: _focusNode,
            onKeyEvent: (_, event) {
              _handleKey(event);
              return KeyEventResult.handled;
            },
            child: Semantics(
              button: true,
              expanded: _isOpen,
              enabled: !widget.disabled,
              label: decoration?.labelText ?? widget.placeholder,
              child: InkWell(
                onTap: _toggle,
                borderRadius: BorderRadius.circular(widget.radius),
                child: InputDecorator(
                  isEmpty: selected == null,
                  decoration: (decoration ?? const InputDecoration()).copyWith(
                    enabled: !widget.disabled,
                    contentPadding:
                        decoration?.contentPadding ??
                        EdgeInsets.symmetric(
                          horizontal: horizontal,
                          vertical: widget.size == GlideSelectSize.lg ? 13 : 10,
                        ),
                    suffixIcon: Icon(
                      _isOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: palette.accent,
                    ),
                    border:
                        decoration?.border ??
                        OutlineInputBorder(
                          borderRadius: BorderRadius.circular(widget.radius),
                          borderSide: BorderSide(color: palette.border),
                        ),
                  ),
                  child: Text(
                    selected?.label ?? widget.placeholder,
                    overflow: TextOverflow.ellipsis,
                    style: selected == null
                        ? textStyle?.copyWith(color: palette.muted)
                        : textStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  @override
  @override
  @override
  Widget build(BuildContext context) {
    if (!widget.isDropdown) {
      return ScaleTransition(
        key: const Key('glide-select-scale'),
        scale: _legacyScale,
        alignment: Alignment.center,
        child: widget.legacyChild,
      );
    }
    return _buildDropdown(context);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
    _typeaheadTimer?.cancel();
    _focusNode.dispose();
    _menuAnimationController
      ..removeStatusListener(_handleMenuAnimationStatus)
      ..dispose();
    _legacyController.dispose();
    super.dispose();
  }
}

class _GlideMenu<T> extends StatefulWidget {
  const _GlideMenu({
    required this.width,
    required this.radius,
    required this.options,
    required this.selectedIndex,
    required this.activeIndex,
    required this.showTags,
    required this.onHover,
    required this.onSelect,
  });

  final double width;
  final double radius;
  final List<GlideSelectOption<T>> options;
  final int selectedIndex;
  final int? activeIndex;
  final bool showTags;
  final ValueChanged<int> onHover;
  final ValueChanged<int> onSelect;

  @override
  State<_GlideMenu<T>> createState() => _GlideMenuState<T>();
}

class _GlideMenuState<T> extends State<_GlideMenu<T>> {
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _hoveredIndex = widget.activeIndex;
  }

  @override
  void didUpdateWidget(covariant _GlideMenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndex != oldWidget.activeIndex) {
      _hoveredIndex = widget.activeIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _GlidePalette.fromTheme(Theme.of(context));
    return Container(
      width: widget.width,
      constraints: const BoxConstraints(maxHeight: 320),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: widget.options.length,
        itemBuilder: (context, index) {
          final option = widget.options[index];
          final highlighted = index == _hoveredIndex;
          return MouseRegion(
            opaque: true,
            onEnter: (_) {
              if (_hoveredIndex == index) return;
              setState(() => _hoveredIndex = index);
              widget.onHover(index);
            },
            child: InkWell(
              onTap: () => widget.onSelect(index),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              borderRadius: BorderRadius.circular(
                math.max(4, widget.radius - 4),
              ),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: highlighted ? palette.highlight : Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    math.max(4, widget.radius - 4),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.text, fontSize: 13),
                      ),
                    ),
                    if (widget.showTags && option.tag != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        option.tag!,
                        style: TextStyle(color: palette.muted, fontSize: 11),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: index == widget.selectedIndex
                          ? palette.accent
                          : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

@immutable
class _GlidePalette {
  const _GlidePalette({
    required this.surface,
    required this.highlight,
    required this.border,
    required this.accent,
    required this.text,
    required this.muted,
  });

  final Color surface;
  final Color highlight;
  final Color border;
  final Color accent;
  final Color text;
  final Color muted;

  factory _GlidePalette.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    return _GlidePalette(
      surface: scheme.surface,
      highlight: scheme.surfaceContainerHighest,
      border: scheme.outline,
      accent: scheme.primary,
      text: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
    );
  }
}
