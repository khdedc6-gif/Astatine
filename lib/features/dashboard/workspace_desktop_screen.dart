import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';

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
  bool _isWindowMaximized = false;
  String? _activeApp;
  final Set<String> _openApps = {};
  late DateTime _now = DateTime.now();
  Timer? _clockTimer;

  Duration get _motionDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 220);

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
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _WorkspaceShortcut(
                              key: const Key('workspace-app-flashcard'),
                              label: 'Flashcards',
                              icon: Icons.style_rounded,
                              color: const Color(0xFFEA580C),
                              onTap: () => _openApp('flashcard'),
                            ),
                            const Gap(14),
                            _WorkspaceShortcut(
                              key: const Key('workspace-app-code'),
                              label: 'Code Studio',
                              icon: Icons.code_rounded,
                              color: const Color(0xFF4F46E5),
                              onTap: () => _openApp('code'),
                            ),
                            const Gap(14),
                            _WorkspaceShortcut(
                              key: const Key('workspace-app-browser'),
                              label: 'Browser',
                              icon: Icons.language_rounded,
                              color: const Color(0xFF0F766E),
                              onTap: () => _openApp('browser'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      bottom: 82,
                      child: AnimatedSwitcher(
                        duration: _motionDuration,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _activeApp == null
                            ? const IgnorePointer(
                                key: ValueKey('no-active-workspace-app'),
                                child: SizedBox.expand(),
                              )
                            : Center(
                                key: ValueKey(_activeApp),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: _isWindowMaximized ? 1200 : 760,
                                      maxHeight: _isWindowMaximized ? 760 : 620,
                                    ),
                                    child: _WorkspaceAppWindow(
                                      appId: _activeApp!,
                                      maximized: _isWindowMaximized,
                                      onMaximize: () => setState(
                                        () => _isWindowMaximized =
                                            !_isWindowMaximized,
                                      ),
                                      onMinimize: () =>
                                          setState(() => _activeApp = null),
                                      onClose: () {
                                        setState(() {
                                          _openApps.remove(_activeApp);
                                          _activeApp = null;
                                          _isWindowMaximized = false;
                                        });
                                      },
                                    ),
                                  ),
                                ),
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
    setState(() {
      _openApps.add(appId);
      _activeApp = appId;
      _isWindowMaximized = false;
      _isStartMenuOpen = false;
      _isControlCenterOpen = false;
    });
  }
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
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: color.withValues(alpha: 0.18),
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
        child: Container(
          width: double.infinity,
          height: 68,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12),
          decoration: BoxDecoration(
            color: palette.card.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.11),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.08),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Tooltip(
                message: strings.workspaceStartMenu,
                child: IconButton(
                  key: const Key('workspace-start-button'),
                  onPressed: onToggleStartMenu,
                  tooltip: strings.workspaceStartMenu,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: isStartMenuOpen
                        ? palette.accent.withValues(alpha: 0.14)
                        : Colors.transparent,
                    foregroundColor: palette.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.grid_view_rounded, size: 24),
                ),
              ),
              if (!compact) ...[
                const Gap(5),
                Text(
                  'ASTATINE',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    fontSize: 12,
                  ),
                ),
              ],
              const Spacer(),
              if (!narrow) ...[
                _TaskbarAppIcon(
                  label: 'Flashcards',
                  icon: Icons.style_rounded,
                  active: activeApp == 'flashcard',
                  open: openApps.contains('flashcard'),
                  onTap: () => onOpenApp('flashcard'),
                ),
                _TaskbarAppIcon(
                  label: 'Code Studio',
                  icon: Icons.code_rounded,
                  active: activeApp == 'code',
                  open: openApps.contains('code'),
                  onTap: () => onOpenApp('code'),
                ),
                _TaskbarAppIcon(
                  label: 'Browser',
                  icon: Icons.language_rounded,
                  active: activeApp == 'browser',
                  open: openApps.contains('browser'),
                  onTap: () => onOpenApp('browser'),
                ),
              ],
              const Spacer(),
              IconButton(
                key: const Key('workspace-control-center-button'),
                onPressed: onToggleControlCenter,
                tooltip: 'Control Center',
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
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
      );
    },
  );
}

class _TaskbarAppIcon extends StatelessWidget {
  const _TaskbarAppIcon({
    required this.label,
    required this.icon,
    required this.active,
    required this.open,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.campus;
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              onPressed: onTap,
              tooltip: label,
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: active ? palette.accent : palette.primaryText,
                backgroundColor: active
                    ? palette.accent.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              icon: Icon(icon, size: 21),
            ),
            if (open)
              Positioned(
                bottom: 1,
                child: Container(
                  width: active ? 14 : 5,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
                        borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
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
                    borderRadius: BorderRadius.circular(12),
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
          strings.isVietnamese
              ? 'KHÔNG GIAN HỌC TẬP ASTATINE'
              : 'ASTATINE LEARNING SPACE',
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
    required this.appId,
    required this.maximized,
    required this.onMaximize,
    required this.onMinimize,
    required this.onClose,
  });

  final String appId;
  final bool maximized;
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
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: details.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(details.icon, color: details.color, size: 19),
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
                  _WindowAction(
                    label: 'Minimize',
                    icon: Icons.remove_rounded,
                    onPressed: onMinimize,
                  ),
                  _WindowAction(
                    label: maximized ? 'Restore' : 'Maximize',
                    icon: maximized
                        ? Icons.filter_none_rounded
                        : Icons.crop_square_rounded,
                    onPressed: onMaximize,
                  ),
                  _WindowAction(
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

class _WindowAction extends StatelessWidget {
  const _WindowAction({
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
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
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
            borderRadius: BorderRadius.circular(18),
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
      borderRadius: BorderRadius.circular(18),
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
