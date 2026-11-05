import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/features/dashboard/workspace_app_dock.dart';

class WorkspaceDesktopScreen extends StatefulWidget {
  const WorkspaceDesktopScreen({
    super.key,
    required this.strings,
    required this.fullscreenWasLost,
    required this.onRetryFullscreen,
    required this.onToggleFullscreen,
    required this.onExitWorkspace,
  });

  final AppStrings strings;
  final bool fullscreenWasLost;
  final VoidCallback onRetryFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onExitWorkspace;

  @override
  State<WorkspaceDesktopScreen> createState() => _WorkspaceDesktopScreenState();
}

class _WorkspaceDesktopScreenState extends State<WorkspaceDesktopScreen> {
  bool _isStartMenuOpen = false;
  bool _isControlCenterOpen = false;
  bool _isFocusMode = false;
  bool _notificationsEnabled = true;
  String? _activeApp;
  final Set<String> _openApps = {};
  final Map<String, _WorkspaceWindowState> _windows = {};
  final List<String> _windowOrder = [];
  late DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f11):
            widget.onToggleFullscreen,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: palette.background,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const _WorkspaceWallpaper(),
              SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      top: 20,
                      left: 24,
                      child: _WorkspaceGreeting(
                        palette: palette,
                        strings: widget.strings,
                      ),
                    ),
                    Positioned(
                      left: 18,
                      top: 112,
                      bottom: 92,
                      child: SizedBox(
                        width: 204,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 8,
                                  bottom: 8,
                                ),
                                child: Text(
                                  switch (widget.strings.languageCode) {
                                    'vi' => 'ỨNG DỤNG',
                                    'zh' => '应用',
                                    _ => 'APPS',
                                  },
                                  style: TextStyle(
                                    color: palette.secondaryText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  _WorkspaceShortcut(
                                    key: const Key('workspace-app-files'),
                                    label:
                                        switch (widget.strings.languageCode) {
                                          'vi' => 'Tệp',
                                          'zh' => '文件',
                                          _ => 'Files',
                                        },
                                    icon: Icons.folder_rounded,
                                    color: const Color(0xFFCA8A04),
                                    onTap: () => _openApp('files'),
                                  ),
                                  _WorkspaceShortcut(
                                    key: const Key('workspace-app-settings'),
                                    label:
                                        switch (widget.strings.languageCode) {
                                          'vi' => 'Cài đặt',
                                          'zh' => '设置',
                                          _ => 'Settings',
                                        },
                                    icon: Icons.settings_rounded,
                                    color: const Color(0xFF64748B),
                                    onTap: () => _openApp('settings'),
                                  ),
                                  _WorkspaceShortcut(
                                    key: const Key('workspace-app-browser'),
                                    label: 'Browser',
                                    icon: Icons.language_rounded,
                                    color: const Color(0xFF0F766E),
                                    onTap: () => _openApp('browser'),
                                  ),
                                  _WorkspaceShortcut(
                                    key: const Key('workspace-app-panel'),
                                    label: 'Panel',
                                    icon: Icons.tune_rounded,
                                    color: const Color(0xFF2563EB),
                                    onTap: () => setState(() {
                                      _isControlCenterOpen = true;
                                      _isStartMenuOpen = false;
                                    }),
                                  ),
                                  _WorkspaceShortcut(
                                    key: const Key('workspace-app-astatine'),
                                    label: 'Astatine',
                                    icon: Icons.science_rounded,
                                    color: const Color(0xFF7C3AED),
                                    onTap: widget.onExitWorkspace,
                                  ),
                                  _WorkspaceShortcut(
                                    key: const Key('workspace-app-flashcard'),
                                    label: 'Flashcards',
                                    icon: Icons.style_rounded,
                                    color: const Color(0xFFEA580C),
                                    onTap: () => _openApp('flashcard'),
                                  ),
                                  _WorkspaceShortcut(
                                    key: const Key('workspace-app-code'),
                                    label: 'Code Studio',
                                    icon: Icons.code_rounded,
                                    color: const Color(0xFF4F46E5),
                                    onTap: () => _openApp('code'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      bottom: 82,
                      child: LayoutBuilder(
                        builder: (context, constraints) => Stack(
                          key: const Key('workspace-window-area'),
                          clipBehavior: Clip.none,
                          children: [
                            for (final appId in _windowOrder)
                              if (!_windows[appId]!.minimized)
                                _buildWorkspaceWindow(
                                  appId,
                                  constraints.biggest,
                                ),
                          ],
                        ),
                      ),
                    ),
                    if (_isStartMenuOpen || _isControlCenterOpen)
                      Positioned.fill(
                        bottom: 78,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() {
                            _isStartMenuOpen = false;
                            _isControlCenterOpen = false;
                          }),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    if (_isStartMenuOpen)
                      Positioned(
                        left: 18,
                        bottom: 86,
                        child: _StartMenu(
                          strings: widget.strings,
                          openApps: _openApps,
                          onOpenApp: _openApp,
                          onExit: widget.onExitWorkspace,
                        ),
                      ),
                    if (_isControlCenterOpen)
                      Positioned(
                        right: 18,
                        bottom: 86,
                        child: _ControlCenter(
                          strings: widget.strings,
                          focusMode: _isFocusMode,
                          notificationsEnabled: _notificationsEnabled,
                          onFocusModeChanged: (value) =>
                              setState(() => _isFocusMode = value),
                          onNotificationsChanged: (value) =>
                              setState(() => _notificationsEnabled = value),
                        ),
                      ),
                    if (widget.fullscreenWasLost)
                      Positioned(
                        top: 18,
                        left: 18,
                        right: 18,
                        child: _FullscreenNotice(
                          strings: widget.strings,
                          onRetry: widget.onRetryFullscreen,
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _WorkspaceTaskbar(
                        strings: widget.strings,
                        now: _now,
                        isStartMenuOpen: _isStartMenuOpen,
                        onToggleStartMenu: () => setState(() {
                          _isStartMenuOpen = !_isStartMenuOpen;
                          _isControlCenterOpen = false;
                        }),
                        isControlCenterOpen: _isControlCenterOpen,
                        onToggleControlCenter: () => setState(() {
                          _isControlCenterOpen = !_isControlCenterOpen;
                          _isStartMenuOpen = false;
                        }),
                        openApps: _openApps,
                        activeApp: _activeApp,
                        onOpenApp: _openApp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openApp(String appId) {
    if (appId == 'panel') {
      setState(() {
        _isControlCenterOpen = true;
        _isStartMenuOpen = false;
      });
      return;
    }
    if (appId == 'astatine') {
      widget.onExitWorkspace();
      return;
    }
    setState(() {
      if (!_windows.containsKey(appId)) {
        final viewport = MediaQuery.sizeOf(context);
        final width = (viewport.width - 48).clamp(320.0, 760.0).toDouble();
        final height = (viewport.height - 210).clamp(260.0, 620.0).toDouble();
        final left = ((viewport.width - width) / 2 + _windowOrder.length * 24)
            .clamp(0.0, math.max(0, viewport.width - width - 12));
        final top = ((viewport.height - height) / 2 + _windowOrder.length * 24)
            .clamp(0.0, math.max(0, viewport.height - height - 108));
        _windows[appId] = _WorkspaceWindowState(
          left: left.toDouble(),
          top: top.toDouble(),
          width: width,
          height: height,
        );
        _openApps.add(appId);
      } else {
        _windows[appId]!.minimized = false;
      }
      _bringWindowToFront(appId);
      _activeApp = appId;
      _isStartMenuOpen = false;
      _isControlCenterOpen = false;
    });
  }

  Widget _buildWorkspaceWindow(String appId, Size bounds) {
    final window = _windows[appId]!;
    final left = window.maximized ? 0.0 : window.left;
    final top = window.maximized ? 0.0 : window.top;
    final width = window.maximized ? bounds.width : window.width;
    final height = window.maximized ? bounds.height : window.height;

    return Positioned(
      key: ValueKey('workspace-window-position-$appId'),
      left: left,
      top: top,
      width: width,
      height: height,
      child: Listener(
        onPointerDown: (_) => _activateWindow(appId),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _WorkspaceAppWindow(
              key: ValueKey('workspace-window-$appId'),
              appId: appId,
              strings: widget.strings,
              maximized: window.maximized,
              onMove: (delta) => _moveWindow(appId, delta, bounds),
              onMaximize: () => _toggleWindowMaximize(appId, bounds),
              onMinimize: () => _minimizeWindow(appId),
              onClose: () => _closeWindow(appId),
            ),
            if (!window.maximized)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  key: Key('workspace-window-resize-$appId'),
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) =>
                      _resizeWindow(appId, details.delta, bounds),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.48),
                        ),
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

  void _bringWindowToFront(String appId) {
    _windowOrder
      ..remove(appId)
      ..add(appId);
  }

  void _activateWindow(String appId) {
    if (_activeApp == appId && !_windows[appId]!.minimized) return;
    setState(() {
      _windows[appId]!.minimized = false;
      _activeApp = appId;
      _bringWindowToFront(appId);
    });
  }

  void _moveWindow(String appId, Offset delta, Size bounds) {
    final window = _windows[appId]!;
    if (window.maximized) return;
    setState(() {
      window.left = (window.left + delta.dx)
          .clamp(0.0, math.max(0, bounds.width - window.width))
          .toDouble();
      window.top = (window.top + delta.dy)
          .clamp(0.0, math.max(0, bounds.height - 48))
          .toDouble();
    });
  }

  void _resizeWindow(String appId, Offset delta, Size bounds) {
    final window = _windows[appId]!;
    final minWidth = math.min(360.0, bounds.width - window.left);
    final minHeight = math.min(260.0, bounds.height - window.top);
    setState(() {
      window.width = (window.width + delta.dx)
          .clamp(minWidth, math.max(minWidth, bounds.width - window.left))
          .toDouble();
      window.height = (window.height + delta.dy)
          .clamp(minHeight, math.max(minHeight, bounds.height - window.top))
          .toDouble();
    });
  }

  void _toggleWindowMaximize(String appId, Size bounds) {
    final window = _windows[appId]!;
    setState(() {
      if (window.maximized) {
        final restoreBounds = window.restoreBounds;
        if (restoreBounds != null) {
          window
            ..left = restoreBounds.left
            ..top = restoreBounds.top
            ..width = restoreBounds.width
            ..height = restoreBounds.height;
        }
        window.restoreBounds = null;
        window.maximized = false;
      } else {
        window.restoreBounds = Rect.fromLTWH(
          window.left,
          window.top,
          window.width,
          window.height,
        );
        window.maximized = true;
      }
      _activeApp = appId;
      _bringWindowToFront(appId);
    });
  }

  void _minimizeWindow(String appId) {
    setState(() {
      _windows[appId]!.minimized = true;
      _activeApp = _topVisibleWindow(excluding: appId);
    });
  }

  void _closeWindow(String appId) {
    setState(() {
      _windows.remove(appId);
      _windowOrder.remove(appId);
      _openApps.remove(appId);
      if (_activeApp == appId) {
        _activeApp = _topVisibleWindow();
      }
    });
  }

  String? _topVisibleWindow({String? excluding}) {
    for (final appId in _windowOrder.reversed) {
      if (appId != excluding && _windows[appId]?.minimized == false) {
        return appId;
      }
    }
    return null;
  }
}

class _WorkspaceWindowState {
  _WorkspaceWindowState({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double left;
  double top;
  double width;
  double height;
  bool minimized = false;
  bool maximized = false;
  Rect? restoreBounds;
}

class _WorkspaceWallpaper extends StatelessWidget {
  const _WorkspaceWallpaper();

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.background,
                palette.accent.withValues(alpha: 0.1),
                const Color(0xFFFFF7E7),
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
        Positioned(
          right: -MediaQuery.sizeOf(context).width * 0.12,
          top: -MediaQuery.sizeOf(context).height * 0.38,
          child: Container(
            width: 700,
            height: 700,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF818CF8).withValues(alpha: 0.22),
                  const Color(0xFF818CF8).withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -220,
          bottom: -360,
          child: Container(
            width: 760,
            height: 760,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFB923C).withValues(alpha: 0.16),
                  const Color(0xFFFB923C).withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkspaceShortcut extends StatelessWidget {
  const _WorkspaceShortcut({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 94,
    child: Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.28),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.12),
                      blurRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: color.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const Gap(7),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.72),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WorkspaceTaskbar extends StatelessWidget {
  const _WorkspaceTaskbar({
    required this.strings,
    required this.now,
    required this.isStartMenuOpen,
    required this.onToggleStartMenu,
    required this.isControlCenterOpen,
    required this.onToggleControlCenter,
    required this.openApps,
    required this.activeApp,
    required this.onOpenApp,
  });

  final AppStrings strings;
  final DateTime now;
  final bool isStartMenuOpen;
  final VoidCallback onToggleStartMenu;
  final bool isControlCenterOpen;
  final VoidCallback onToggleControlCenter;
  final Set<String> openApps;
  final String? activeApp;
  final ValueChanged<String> onOpenApp;
  String get _time =>
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 560;
      final narrow = constraints.maxWidth < 390;
      final palette =
          Theme.of(context).extension<AstatinePalette>() ??
          AstatinePalette.campus;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: SizedBox(
            height: 84,
            child: Row(
              children: [
                Expanded(
                  child: WorkspaceAppDock(
                    strings: strings,
                    openApps: openApps,
                    activeApp: activeApp,
                    isStartMenuOpen: isStartMenuOpen,
                    onToggleStartMenu: onToggleStartMenu,
                    onOpenApp: onOpenApp,
                  ),
                ),
                const Gap(8),
                Container(
                  key: const Key('workspace-status-bar'),
                  height: 52,
                  padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
                  decoration: BoxDecoration(
                    color: palette.card.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const Key('workspace-control-center-button'),
                        onPressed: onToggleControlCenter,
                        tooltip: 'Control Center',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(40, 40),
                          backgroundColor: isControlCenterOpen
                              ? palette.accent.withValues(alpha: 0.14)
                              : Colors.transparent,
                          foregroundColor: palette.primaryText,
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 21),
                      ),
                      const Gap(4),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _time,
                            style: TextStyle(
                              color: palette.primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (!compact)
                            Text(
                              '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
                              style: TextStyle(
                                color: palette.secondaryText,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                      if (!narrow) ...[
                        const Gap(8),
                        Icon(
                          Icons.wifi_rounded,
                          color: palette.secondaryText,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _StartMenu extends StatelessWidget {
  const _StartMenu({
    required this.strings,
    required this.openApps,
    required this.onOpenApp,
    required this.onExit,
  });

  final AppStrings strings;
  final Set<String> openApps;
  final ValueChanged<String> onOpenApp;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    return SizedBox(
      width: width < 410 ? width - 36 : 370,
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: palette.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.18),
                blurRadius: 34,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: palette.accent,
                        size: 23,
                      ),
                    ),
                    const Gap(11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.workspaceStartMenu,
                            style: TextStyle(
                              color: palette.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            switch (strings.languageCode) {
                              'vi' => 'Không gian học tập của bạn',
                              'zh' => '你的学习空间',
                              _ => 'Your learning space',
                            },
                            style: TextStyle(
                              color: palette.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(18),
                Text(
                  strings.workspaceApps,
                  style: TextStyle(
                    color: palette.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const Gap(8),
                _StartMenuApp(
                  label: switch (strings.languageCode) {
                    'vi' => 'Tệp',
                    'zh' => '文件',
                    _ => 'Files',
                  },
                  icon: Icons.folder_rounded,
                  color: const Color(0xFFCA8A04),
                  isOpen: openApps.contains('files'),
                  onTap: () => onOpenApp('files'),
                ),
                _StartMenuApp(
                  label: switch (strings.languageCode) {
                    'vi' => 'Cài đặt',
                    'zh' => '设置',
                    _ => 'Settings',
                  },
                  icon: Icons.settings_rounded,
                  color: const Color(0xFF64748B),
                  isOpen: openApps.contains('settings'),
                  onTap: () => onOpenApp('settings'),
                ),
                _StartMenuApp(
                  label: 'Flashcards',
                  icon: Icons.style_rounded,
                  color: const Color(0xFFEA580C),
                  isOpen: openApps.contains('flashcard'),
                  onTap: () => onOpenApp('flashcard'),
                ),
                _StartMenuApp(
                  label: 'Code Studio',
                  icon: Icons.code_rounded,
                  color: const Color(0xFF4F46E5),
                  isOpen: openApps.contains('code'),
                  onTap: () => onOpenApp('code'),
                ),
                _StartMenuApp(
                  label: 'Browser',
                  icon: Icons.language_rounded,
                  color: const Color(0xFF0F766E),
                  isOpen: openApps.contains('browser'),
                  onTap: () => onOpenApp('browser'),
                ),
                const Gap(12),
                Divider(color: palette.border, height: 1),
                const Gap(12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('workspace-exit-button'),
                    onPressed: onExit,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(strings.workspaceExit),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartMenuApp extends StatelessWidget {
  const _StartMenuApp({
    required this.label,
    required this.icon,
    required this.color,
    required this.isOpen,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 54,
            child: Row(
              children: [
                const Gap(8),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Gap(12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isOpen) Icon(Icons.circle, color: palette.accent, size: 8),
                const Gap(12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceGreeting extends StatelessWidget {
  const _WorkspaceGreeting({required this.palette, required this.strings});

  final AstatinePalette palette;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: palette.card.withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: palette.border.withValues(alpha: 0.85)),
      boxShadow: [
        BoxShadow(
          color: palette.accent.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.isVietnamese ? 'ASTATINE WORKSPACE' : 'ASTATINE WORKSPACE',
          style: TextStyle(
            color: palette.accent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const Gap(4),
        Text(
          strings.isVietnamese
              ? 'Không gian tập trung để học và sáng tạo.'
              : 'A calm place to learn and create.',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ControlCenter extends StatelessWidget {
  const _ControlCenter({
    required this.strings,
    required this.focusMode,
    required this.notificationsEnabled,
    required this.onFocusModeChanged,
    required this.onNotificationsChanged,
  });

  final AppStrings strings;
  final bool focusMode;
  final bool notificationsEnabled;
  final ValueChanged<bool> onFocusModeChanged;
  final ValueChanged<bool> onNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    String text(String vi, String en, String zh) =>
        switch (strings.languageCode) {
          'vi' => vi,
          'zh' => zh,
          _ => en,
        };
    return SizedBox(
      width: MediaQuery.sizeOf(context).width < 410
          ? MediaQuery.sizeOf(context).width - 36
          : 330,
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.17),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text('Trung tâm điều khiển', 'Control Center', '控制中心'),
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Gap(12),
              _ControlTile(
                icon: Icons.self_improvement_rounded,
                title: text('Chế độ tập trung', 'Study focus', '专注学习'),
                subtitle: text(
                  'Giảm xao nhãng khi học',
                  'Keep your workspace distraction-free',
                  '减少学习时的干扰',
                ),
                value: focusMode,
                onChanged: onFocusModeChanged,
              ),
              const Gap(8),
              _ControlTile(
                icon: Icons.notifications_active_outlined,
                title: text('Thông báo', 'Notifications', '通知'),
                subtitle: text(
                  'Cho phép thông báo trong workspace',
                  'Allow workspace notifications',
                  '允许工作区通知',
                ),
                value: notificationsEnabled,
                onChanged: onNotificationsChanged,
              ),
              const Gap(12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.input,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_rounded, color: palette.accent, size: 20),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        text(
                          'Workspace đang hoạt động',
                          'Workspace is running',
                          '工作区正在运行',
                        ),
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.check_circle_rounded,
                      color: const Color(0xFF16835D),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: palette.input,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.accent, size: 20),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.secondaryText, fontSize: 10),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _WorkspaceAppWindow extends StatelessWidget {
  const _WorkspaceAppWindow({
    super.key,
    required this.appId,
    required this.strings,
    required this.maximized,
    required this.onMove,
    required this.onMaximize,
    required this.onMinimize,
    required this.onClose,
  });

  final String appId;
  final AppStrings strings;
  final bool maximized;
  final ValueChanged<Offset> onMove;
  final VoidCallback onMaximize;
  final VoidCallback onMinimize;
  final VoidCallback onClose;

  static const _appDetails = {
    'flashcard': (
      title: 'Flashcards',
      icon: Icons.style_rounded,
      color: Color(0xFFEA580C),
    ),
    'code': (
      title: 'Code Studio',
      icon: Icons.code_rounded,
      color: Color(0xFF4F46E5),
    ),
    'browser': (
      title: 'Browser',
      icon: Icons.language_rounded,
      color: Color(0xFF0F766E),
    ),
    'files': (
      title: 'Files',
      icon: Icons.folder_rounded,
      color: Color(0xFFCA8A04),
    ),
    'settings': (
      title: 'Settings',
      icon: Icons.settings_rounded,
      color: Color(0xFF64748B),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    final details = _appDetails[appId] ?? _appDetails['flashcard']!;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(maximized ? 22 : 24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: palette.border, width: 2),
          borderRadius: BorderRadius.circular(maximized ? 22 : 24),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.2),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: palette.input.withValues(alpha: 0.72),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      key: Key('workspace-window-titlebar-$appId'),
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) => onMove(details.delta),
                      onDoubleTap: onMaximize,
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: details.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              details.icon,
                              color: details.color,
                              size: 19,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: Text(
                              details.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _WindowAction(
                    key: Key('workspace-window-minimize-$appId'),
                    label: 'Minimize',
                    icon: Icons.remove_rounded,
                    onPressed: onMinimize,
                  ),
                  _WindowAction(
                    key: Key('workspace-window-maximize-$appId'),
                    label: maximized ? 'Restore' : 'Maximize',
                    icon: maximized
                        ? Icons.filter_none_rounded
                        : Icons.crop_square_rounded,
                    onPressed: onMaximize,
                  ),
                  _WindowAction(
                    key: Key('workspace-window-close-$appId'),
                    label: 'Close',
                    icon: Icons.close_rounded,
                    onPressed: onClose,
                    close: true,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: switch (appId) {
                  'code' => const _CodeStudioContent(),
                  'browser' => const _StudyBrowserContent(),
                  'files' => _WorkspaceFilesContent(strings: strings),
                  'settings' => _WorkspaceSettingsContent(strings: strings),
                  _ => const _FlashcardContent(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceFilesContent extends StatelessWidget {
  const _WorkspaceFilesContent({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    final isVietnamese = strings.languageCode == 'vi';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVietnamese ? 'Truy cập nhanh' : 'Quick access',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Gap(14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _FileLocationChip(
              icon: Icons.schedule_rounded,
              label: isVietnamese ? 'Gần đây' : 'Recent',
            ),
            _FileLocationChip(
              icon: Icons.people_alt_outlined,
              label: isVietnamese ? 'Được chia sẻ' : 'Shared with me',
            ),
            _FileLocationChip(
              icon: Icons.star_outline_rounded,
              label: isVietnamese ? 'Đã đánh dấu' : 'Starred',
            ),
          ],
        ),
        const Gap(18),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: palette.input.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 38,
                  color: palette.accent.withValues(alpha: 0.75),
                ),
                const Gap(12),
                Text(
                  isVietnamese
                      ? 'Tệp của bạn sẽ ở đây'
                      : 'Your files live here',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(5),
                Text(
                  isVietnamese
                      ? 'Tài liệu học tập được chia sẻ sẽ tập hợp tại một nơi.'
                      : 'Shared learning materials will be gathered in one place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FileLocationChip extends StatelessWidget {
  const _FileLocationChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: palette.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: palette.accent),
          const Gap(7),
          Text(
            label,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSettingsContent extends StatelessWidget {
  const _WorkspaceSettingsContent({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    final isVietnamese = strings.languageCode == 'vi';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVietnamese ? 'Không gian của bạn' : 'Your workspace',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Gap(6),
        Text(
          isVietnamese
              ? 'Tùy chỉnh trải nghiệm học tập của bạn.'
              : 'Personalize your learning experience.',
          style: TextStyle(color: palette.secondaryText, fontSize: 13),
        ),
        const Gap(18),
        _WorkspaceSettingRow(
          icon: Icons.palette_outlined,
          title: isVietnamese ? 'Giao diện' : 'Appearance',
          subtitle: isVietnamese
              ? 'Màu sắc và hình nền workspace'
              : 'Workspace colors and wallpaper',
        ),
        const Gap(10),
        _WorkspaceSettingRow(
          icon: Icons.notifications_none_rounded,
          title: isVietnamese ? 'Thông báo' : 'Notifications',
          subtitle: isVietnamese
              ? 'Quản lý thông báo học tập'
              : 'Manage learning notifications',
        ),
        const Gap(10),
        _WorkspaceSettingRow(
          icon: Icons.accessibility_new_rounded,
          title: isVietnamese ? 'Trợ năng' : 'Accessibility',
          subtitle: isVietnamese
              ? 'Chuyển động và cách hiển thị'
              : 'Motion and display preferences',
        ),
        const Spacer(),
        Text(
          isVietnamese
              ? 'Các tùy chọn sẽ sớm khả dụng.'
              : 'More workspace options are coming soon.',
          style: TextStyle(color: palette.secondaryText, fontSize: 11),
        ),
      ],
    );
  }
}

class _WorkspaceSettingRow extends StatelessWidget {
  const _WorkspaceSettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.input.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.accent, size: 21),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                Text(
                  subtitle,
                  style: TextStyle(color: palette.secondaryText, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: palette.secondaryText,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _WindowAction extends StatelessWidget {
  const _WindowAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.close = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool close;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      foregroundColor: close
          ? const Color(0xFFB42318)
          : Theme.of(context).colorScheme.onSurface,
    ),
    icon: Icon(icon, size: 18),
  );
}

class _FlashcardContent extends StatefulWidget {
  const _FlashcardContent();

  @override
  State<_FlashcardContent> createState() => _FlashcardContentState();
}

class _FlashcardContentState extends State<_FlashcardContent> {
  bool _showAnswer = false;
  int _cardIndex = 0;

  static const _cards = [
    ('What is a hypothesis?', 'A testable explanation for an observation.'),
    ('What does a variable do?', 'Stores a value that can be used or changed.'),
    (
      'What is active recall?',
      'Retrieving an idea from memory to strengthen it.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    final card = _cards[_cardIndex % _cards.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'SCIENCE · QUICK REVIEW',
                style: TextStyle(
                  color: palette.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              '${_cardIndex + 1} / ${_cards.length}',
              style: TextStyle(
                color: palette.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const Gap(14),
        Expanded(
          child: Material(
            color: const Color(0xFFFFF7E7),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1D8AE), width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showAnswer
                          ? Icons.lightbulb_rounded
                          : Icons.help_outline_rounded,
                      color: const Color(0xFFEA580C),
                      size: 32,
                    ),
                    const Gap(16),
                    Text(
                      _showAnswer ? card.$2 : card.$1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 21,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(12),
                    Text(
                      _showAnswer ? 'Answer' : 'Tap to reveal the answer',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Gap(14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showAnswer = !_showAnswer),
                icon: Icon(
                  _showAnswer ? Icons.quiz_outlined : Icons.visibility_outlined,
                ),
                label: Text(_showAnswer ? 'Show question' : 'Reveal answer'),
              ),
            ),
            const Gap(10),
            FilledButton.icon(
              onPressed: () => setState(() {
                _cardIndex = (_cardIndex + 1) % _cards.length;
                _showAnswer = false;
              }),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CodeStudioContent extends StatefulWidget {
  const _CodeStudioContent();

  @override
  State<_CodeStudioContent> createState() => _CodeStudioContentState();
}

class _CodeStudioContentState extends State<_CodeStudioContent> {
  bool _hasRun = false;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final code = Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B4B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'void main() {\n'
            '  final subject = "Science";\n'
            '  print("Ready to learn \$subject");\n'
            '}',
            style: TextStyle(
              color: Color(0xFFE0E7FF),
              fontFamily: 'monospace',
              fontSize: 14,
              height: 1.6,
            ),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'LESSON 01  /  YOUR FIRST PROGRAM',
              style: TextStyle(
                color: palette.secondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const Gap(14),
            Expanded(
              child: compact
                  ? Column(
                      children: [
                        Expanded(child: code),
                        const Gap(12),
                        Expanded(
                          child: _CodeOutput(palette: palette, hasRun: _hasRun),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 3, child: code),
                        const Gap(14),
                        Expanded(
                          flex: 2,
                          child: _CodeOutput(palette: palette, hasRun: _hasRun),
                        ),
                      ],
                    ),
            ),
            const Gap(14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => setState(() => _hasRun = true),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Run example'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CodeOutput extends StatelessWidget {
  const _CodeOutput({required this.palette, required this.hasRun});

  final AstatinePalette palette;
  final bool hasRun;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: palette.input,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: palette.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OUTPUT',
          style: TextStyle(
            color: palette.secondaryText,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const Gap(12),
        Text(
          hasRun
              ? 'Ready to learn Science'
              : 'Run the example to see the result.',
          style: TextStyle(
            color: palette.primaryText,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _StudyBrowserContent extends StatefulWidget {
  const _StudyBrowserContent();

  @override
  State<_StudyBrowserContent> createState() => _StudyBrowserContentState();
}

class _StudyBrowserContentState extends State<_StudyBrowserContent> {
  final _queryController = TextEditingController();
  String? _searchedQuery;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'STUDY BROWSER',
          style: TextStyle(
            color: palette.secondaryText,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const Gap(14),
        TextField(
          controller: _queryController,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: InputDecoration(
            labelText: 'Search for a learning topic',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Search',
              onPressed: () => _search(_queryController.text),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
        const Gap(16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.input,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.border),
            ),
            child: _searchedQuery == null
                ? _SuggestedStudyTopics(palette: palette, onSelect: _search)
                : _SearchPreview(palette: palette, query: _searchedQuery!),
          ),
        ),
      ],
    );
  }

  void _search(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() => _searchedQuery = trimmed);
  }
}

class _SuggestedStudyTopics extends StatelessWidget {
  const _SuggestedStudyTopics({required this.palette, required this.onSelect});

  final AstatinePalette palette;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Try a topic',
        style: TextStyle(
          color: palette.primaryText,
          fontWeight: FontWeight.w800,
        ),
      ),
      const Gap(12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final topic in ['Chemistry', 'Study skills', 'Programming'])
            ActionChip(
              label: Text(topic),
              avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
              onPressed: () => onSelect(topic),
            ),
        ],
      ),
      const Spacer(),
      Text(
        'Search suggestions stay in this workspace preview.',
        style: TextStyle(color: palette.secondaryText, fontSize: 12),
      ),
    ],
  );
}

class _SearchPreview extends StatelessWidget {
  const _SearchPreview({required this.palette, required this.query});

  final AstatinePalette palette;
  final String query;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.menu_book_rounded, color: palette.accent, size: 28),
      const Gap(12),
      Text(
        'Learning path',
        style: TextStyle(
          color: palette.primaryText,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      const Gap(4),
      Text(
        'A study outline for “$query”',
        style: TextStyle(color: palette.secondaryText, fontSize: 13),
      ),
      const Gap(16),
      for (final step in [
        'Start with the key ideas',
        'Review an example',
        'Test your understanding',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: palette.accent, size: 18),
              const Gap(9),
              Expanded(
                child: Text(
                  step,
                  style: TextStyle(color: palette.primaryText, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _FullscreenNotice extends StatelessWidget {
  const _FullscreenNotice({required this.strings, required this.onRetry});

  final AppStrings strings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 500;
            final message = Row(
              children: [
                const Icon(
                  Icons.fullscreen_exit_rounded,
                  color: Color(0xFFB45309),
                  size: 26,
                ),
                const Gap(12),
                Expanded(
                  child: Text(
                    strings.workspaceFullscreenNotice,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
            final retryButton = FilledButton.icon(
              key: const Key('workspace-reenter-fullscreen'),
              onPressed: onRetry,
              icon: const Icon(Icons.fullscreen_rounded, size: 18),
              label: Text(strings.workspaceReenterFullscreen),
            );
            return Material(
              color: palette.card,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [message, const Gap(10), retryButton],
                      )
                    : Row(
                        children: [
                          Expanded(child: message),
                          const Gap(12),
                          retryButton,
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
