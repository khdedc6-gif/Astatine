// Lucian UX/UI Prompt #208 · MIT License (c) 2026 Seokwoooo · https://lucianlabs.dev/uxui-prompt/#208
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';

class WorkspaceAppDock extends StatefulWidget {
  const WorkspaceAppDock({
    super.key,
    required this.strings,
    required this.openApps,
    required this.activeApp,
    required this.isStartMenuOpen,
    required this.onToggleStartMenu,
    required this.onOpenApp,
  });

  final AppStrings strings;
  final Set<String> openApps;
  final String? activeApp;
  final bool isStartMenuOpen;
  final VoidCallback onToggleStartMenu;
  final ValueChanged<String> onOpenApp;

  @override
  State<WorkspaceAppDock> createState() => _WorkspaceAppDockState();
}

class _WorkspaceAppDockState extends State<WorkspaceAppDock>
    with TickerProviderStateMixin {
  static const _baseSize = 34.0;
  static const _maxSize = 62.0;
  static const _spread = 68.0;
  static const _gap = 3.0;
  static const _startAreaWidth = 64.0;
  static const _apps = <_DockApp>[
    _DockApp(
      id: 'files',
      icon: Icons.folder_rounded,
      colors: [Color(0xFF74C0FC), Color(0xFF1C7ED6)],
    ),
    _DockApp(
      id: 'settings',
      icon: Icons.settings_rounded,
      colors: [Color(0xFFFFF3BF), Color(0xFFFCC419)],
    ),
    _DockApp(
      id: 'flashcard',
      icon: Icons.style_rounded,
      colors: [Color(0xFFA5D8FF), Color(0xFF339AF0)],
    ),
    _DockApp(
      id: 'code',
      icon: Icons.code_rounded,
      colors: [Color(0xFFFF8787), Color(0xFFE03131)],
    ),
    _DockApp(
      id: 'browser',
      icon: Icons.language_rounded,
      colors: [Color(0xFFC3FAE8), Color(0xFF20C997)],
    ),
  ];

  late final Ticker _ticker = createTicker(_tick);
  late final AnimationController _hopController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addStatusListener(_handleHopStatus);
  final List<double> _sizes = List.filled(_apps.length, _baseSize);
  double? _mouseX;
  int _focusedIndex = -1;
  int _hoppingIndex = -1;
  int _visibleCount = _apps.length;

  String _label(_DockApp app) =>
      switch ((widget.strings.languageCode, app.id)) {
        ('vi', 'files') => 'Tệp',
        ('vi', 'settings') => 'Cài đặt',
        ('vi', 'flashcard') => 'Flashcards',
        ('vi', 'code') => 'Code Studio',
        ('vi', 'browser') => 'Trình duyệt',
        ('zh', 'files') => '文件',
        ('zh', 'settings') => '设置',
        ('zh', 'flashcard') => '卡片',
        ('zh', 'code') => '代码工作室',
        ('zh', 'browser') => '浏览器',
        (_, 'files') => 'Files',
        (_, 'settings') => 'Settings',
        (_, 'flashcard') => 'Flashcards',
        (_, 'code') => 'Code Studio',
        (_, 'browser') => 'Browser',
        _ => app.id,
      };

  void _handleHopStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _hoppingIndex = -1);
    }
  }

  void _handleHover(PointerEvent event, double width, int appCount) {
    _visibleCount = appCount;
    final y = event.localPosition.dy - 78;
    _mouseX = y > -130 && y < 10 ? event.localPosition.dx - width / 2 : null;
    _runTicker();
  }

  void _runTicker() {
    if (MediaQuery.disableAnimationsOf(context)) {
      for (var index = 0; index < _sizes.length; index++) {
        _sizes[index] = _targetSize(index, _visibleCount);
      }
      if (mounted) setState(() {});
      return;
    }
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration _) {
    final count = _visibleCount;
    var changed = false;
    var busy = false;
    for (var index = 0; index < _sizes.length; index++) {
      final target = _targetSize(index, count);

      final next = _sizes[index] + (target - _sizes[index]) * 0.28;
      if ((target - next).abs() > 0.1) {
        busy = true;
      } else {
        _sizes[index] = target;
      }
      if ((next - _sizes[index]).abs() > 0.01) {
        _sizes[index] = next;
        changed = true;
      }
    }

    if (changed && mounted) setState(() {});
    if (!busy) _ticker.stop();
  }

  double _targetSize(int index, int count) {
    if (index >= count) return _baseSize;
    if (_mouseX != null) {
      final center = (index - (count - 1) / 2) * (_baseSize + _gap);
      final distance = (_mouseX! - center) / _spread;
      return _baseSize +
          (_maxSize - _baseSize) * math.exp(-distance * distance * 1.6);
    }
    return index == _focusedIndex ? _maxSize * 0.8 : _baseSize;
  }

  int _visibleAppCount(double width) {
    if (width <= 0) return _apps.length;
    return ((width - 16 - _startAreaWidth + _gap) / (_baseSize + _gap))
        .floor()
        .clamp(0, _apps.length);
  }

  void _handleTap(int index, String appId) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    setState(() => _hoppingIndex = reducedMotion ? -1 : index);
    if (!reducedMotion) _hopController.repeat(count: 2);
    widget.onOpenApp(appId);
  }

  double _hopOffset(double progress) {
    final eased = const Cubic(0.3, 0.6, 0.4, 1).transform(progress);
    if (eased < 0.3) return -22 * (eased / 0.3);
    if (eased < 0.55) return -22 * (1 - (eased - 0.3) / 0.25);
    if (eased < 0.72) return -6 * ((eased - 0.55) / 0.17);
    return -6 * (1 - (eased - 0.72) / 0.28);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _hopController
      ..removeStatusListener(_handleHopStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = _visibleAppCount(width);
        _visibleCount = count;
        final apps = _apps.take(count).toList(growable: false);
        final dockWidth =
            apps.fold<double>(
              16 + _startAreaWidth,
              (sum, app) => sum + _sizes[_apps.indexOf(app)],
            ) +
            math.max(0, apps.length - 1) * _gap;
        final dockLeft = (width - dockWidth) / 2;
        final highlightedIndex = _highlightedIndex(count);
        var highlightCenter = dockLeft + 8 + _startAreaWidth;
        if (highlightedIndex >= 0) {
          for (var index = 0; index < highlightedIndex; index++) {
            highlightCenter += _sizes[index] + _gap;
          }
          highlightCenter += _sizes[highlightedIndex] / 2;
        }

        return SizedBox(
          key: const Key('workspace-app-dock'),
          height: 78,
          child: MouseRegion(
            onHover: (event) => _handleHover(event, width, count),
            onExit: (_) {
              _mouseX = null;
              _runTicker();
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (highlightedIndex >= 0)
                  Positioned(
                    left: highlightCenter - 60,
                    top:
                        72 -
                        28 -
                        _sizes[highlightedIndex] -
                        (_sizes[highlightedIndex] - _baseSize) * 0.25,
                    width: 120,
                    child: IgnorePointer(
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xD928203C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: Text(
                              key: const Key('workspace-app-dock-tooltip'),
                              _label(_apps[highlightedIndex]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: dockLeft,
                  bottom: 0,
                  width: dockWidth,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.card.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: dockLeft + 8,
                  bottom: 6,
                  width: 44,
                  height: 44,
                  child: Tooltip(
                    message: widget.strings.workspaceStartMenu,
                    child: InkWell(
                      key: const Key('workspace-start-button'),
                      onTap: widget.onToggleStartMenu,
                      borderRadius: BorderRadius.circular(15),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.isStartMenuOpen
                              ? palette.accent.withValues(alpha: 0.16)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 25,
                          color: palette.accent,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  key: const Key('workspace-dock-start-divider'),
                  left: dockLeft + 60,
                  bottom: 14,
                  width: 1,
                  height: 28,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.primaryText.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                Positioned(
                  left: dockLeft + 8 + _startAreaWidth,
                  bottom: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var index = 0; index < apps.length; index++) ...[
                        if (index > 0) const SizedBox(width: _gap),
                        _buildAppButton(
                          palette: palette,
                          app: apps[index],
                          index: index,
                          reducedMotion: reducedMotion,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _highlightedIndex(int visibleCount) {
    if (_focusedIndex >= 0 && _focusedIndex < visibleCount) {
      return _focusedIndex;
    }
    if (_mouseX == null || visibleCount == 0) return -1;
    var bestIndex = -1;
    var bestSize = _baseSize + 8;
    for (var index = 0; index < visibleCount; index++) {
      if (_sizes[index] > bestSize) {
        bestSize = _sizes[index];
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  Widget _buildAppButton({
    required AstatinePalette palette,
    required _DockApp app,
    required int index,
    required bool reducedMotion,
  }) {
    final size = _sizes[index];
    final running = widget.openApps.contains(app.id);
    final hopping = _hoppingIndex == index && !reducedMotion;
    final icon = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: app.colors,
        ),
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(app.icon, size: size * 0.55, color: Colors.white),
    );

    return Semantics(
      button: true,
      label: '${_label(app)}${running ? ', open' : ', open app'}',
      child: InkWell(
        key: ValueKey('workspace-dock-${app.id}'),
        onTap: () => _handleTap(index, app.id),
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            _focusedIndex = index;
          } else if (_focusedIndex == index) {
            _focusedIndex = -1;
          }
          _runTicker();
          setState(() {});
        },
        focusColor: palette.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          margin: EdgeInsets.only(bottom: (size - _baseSize) * 0.25),
          child: AnimatedBuilder(
            animation: _hopController,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(padding: const EdgeInsets.only(bottom: 6), child: icon),
                if (running)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            builder: (context, child) => Transform.translate(
              offset: Offset(0, hopping ? _hopOffset(_hopController.value) : 0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _DockApp {
  const _DockApp({required this.id, required this.icon, required this.colors});

  final String id;
  final IconData icon;
  final List<Color> colors;
}
