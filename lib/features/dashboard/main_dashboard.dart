import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/notifications/toast.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/core/ui/custom_scroll_behavior.dart';
import 'package:astatine_dashboard/core/ui/hover_ripple.dart';
import 'package:astatine_dashboard/core/ui/search_bar.dart';
import 'package:astatine_dashboard/core/ui/smooth_mouse_scroll_controller.dart';
import 'package:astatine_dashboard/core/ui/ui_motion.dart';
import 'package:astatine_dashboard/core/platform/desktop_window_service.dart';
import 'package:astatine_dashboard/features/ai/gemini_assistant.dart';
import 'package:astatine_dashboard/features/assignments/assignments_daily_quests.dart';
import 'package:astatine_dashboard/features/chemistry/virtual_lab.dart';
import 'package:astatine_dashboard/features/classroom/astatine_discord_dashboard.dart';
import 'package:astatine_dashboard/features/community/study_group.dart';
import 'package:astatine_dashboard/features/admin/admin_terminal.dart';
import 'package:astatine_dashboard/features/flashcards/flashcards_dashboard.dart';


import 'package:astatine_dashboard/features/dashboard/kiosk_mode_service.dart';
import 'package:astatine_dashboard/features/dashboard/mini_news_ticker.dart';
import 'package:astatine_dashboard/features/dashboard/news_feed_parser.dart';
import 'package:astatine_dashboard/features/dashboard/update_log_dialog.dart';
import 'package:astatine_dashboard/features/dashboard/workspace_desktop_screen.dart';
import 'package:astatine_dashboard/features/profile/student_profile_settings.dart';
import 'package:astatine_dashboard/features/profile/user_profile_avatar.dart';
import 'package:astatine_dashboard/features/profile/user_profile_store.dart';
import 'package:astatine_dashboard/features/profile/subscription_name_effect.dart';
import 'package:astatine_dashboard/features/dashboard/achievement_center.dart';

const _lucideArrowUpRight = IconData(
  0xf167,
  fontFamily: 'Lucide',
  fontPackage: 'lucide_icons',
);
const _lucideArrowRight = IconData(
  0xf16b,
  fontFamily: 'Lucide',
  fontPackage: 'lucide_icons',
);
const _lucideCalendar = IconData(
  0xf1d6,
  fontFamily: 'Lucide',
  fontPackage: 'lucide_icons',
);
const _lucideClipboard = IconData(
  0xf21c,
  fontFamily: 'Lucide',
  fontPackage: 'lucide_icons',
);
const _lucideFlask = IconData(
  0xf2ec,
  fontFamily: 'Lucide',
  fontPackage: 'lucide_icons',
);
const _lucideFolder = IconData(
  0xf2f8,
  fontFamily: 'Lucide',
  fontPackage: 'lucide_icons',
);
const _lucideDashboard = IconData(
  0xf389,
  fontFamily: 'Lucide',
  fontPackage: 'lucide_icons',
);
const _lucideMessages = IconData(
  0xf3d1,
  fontFamily: 'Lucide',
  fontPackage: 'lucide_icons',
);
const _lucideSettings = IconData(
  0xf4b9,
  fontFamily: 'Lucide',
  fontPackage: 'lucide_icons',
);
const _lucideSparkles = IconData(
  0xf4e8,
  fontFamily: 'Lucide',
  fontPackage: 'lucide_icons',
);
const _lucideStore = IconData(
  0xf509,
  fontFamily: 'Lucide',
  fontPackage: 'lucide_icons',
);
const _lucideTrophy = IconData(
  0xf54e,
  fontFamily: 'Lucide',
  fontPackage: 'lucide_icons',
);

void main() {
  runApp(const AstatineApp());
}

class AstatineApp extends StatefulWidget {
  const AstatineApp({super.key});

  @override
  State<AstatineApp> createState() => _AstatineAppState();
}

class _AstatineAppState extends State<AstatineApp> {
  String _selectedTheme = 'Campus';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Centralized toast service is wired at the app root so all screens and
      // background tasks can trigger notifications without passing context.
      navigatorKey: ToastService.navigatorKey,
      title: 'Astatine Dashboard',
      scrollBehavior: const CustomScrollBehavior(),
      theme: AstatinePalette.themeData(_selectedTheme),
      builder: (context, child) =>
          BlueCursorOverlay(child: child ?? const SizedBox.shrink()),
      home: MainLayoutScreen(
        selectedTheme: _selectedTheme,
        onThemeChanged: (theme) => setState(() => _selectedTheme = theme),
      ),
    );
  }
}

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({
    super.key,
    this.selectedTheme = 'Campus',
    this.onThemeChanged,
    this.currentUserName = 'User',
    this.currentUserEmail = '',
    this.currentUserRole = 'guest',
    this.isVietnamese = true,
    this.currentUserId,
    this.updateLogStore,
  });

  final String selectedTheme;
  final ValueChanged<String>? onThemeChanged;
  final String currentUserName;
  final String currentUserEmail;
  final String currentUserRole;
  final bool isVietnamese;
  final String? currentUserId;
  final ReleaseNotesStore? updateLogStore;

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;
  late String _selectedLanguage = widget.isVietnamese ? 'vi' : 'en';
  bool _isWorkspaceActive = false;
  bool _workspaceFullscreenWasLost = false;
  bool _isSidebarCollapsed = false;
  bool _isAppsExpanded = false;
  String _subscriptionTier = 'FREE';
  LabSearchItem? _pendingLabSearchItem;
  final _sidebarScrollController = SmoothMouseScrollController();
  final _kioskModeService = KioskModeService();

  Color get _subscriptionAccent => switch (_subscriptionTier) {
    'PRO' => const Color(0xFFBB65E7),
    'ULTRA' => const Color(0xFFFFC928),
    _ => const Color(0xFF83D8E8),
  };

  Color get _subscriptionAccentLight => switch (_subscriptionTier) {
    'PRO' => const Color(0xFFD6A1F2),
    'ULTRA' => const Color(0xFFFFE082),
    _ => const Color(0xFFB4EDF4),
  };

  Color get _subscriptionForeground => switch (_subscriptionTier) {
    'PRO' => const Color(0xFF3B164B),
    'ULTRA' => const Color(0xFF493700),
    _ => const Color(0xFF123A44),
  };

  @override
  void initState() {
    super.initState();
    _loadSubscriptionTier();
  }

  Future<void> _loadSubscriptionTier() async {
    try {
      final userId = widget.currentUserId;
      if (userId == null) return;

      final client = Supabase.instance.client;
      final account = await client
          .from('users')
          .select('subscription_tier, subscription_expires_at')
          .eq('id', userId)
          .maybeSingle();
      if (!mounted || account == null) return;

      final tier = account['subscription_tier']?.toString().toUpperCase();
      final expiresAt = DateTime.tryParse(
        account['subscription_expires_at']?.toString() ?? '',
      );
      final isExpired =
          tier != null &&
          tier != 'FREE' &&
          (expiresAt == null || !expiresAt.isAfter(DateTime.now()));
      _setSubscriptionTier(isExpired ? 'FREE' : _validSubscriptionTier(tier));
    } catch (error) {
      debugPrint('Unable to load current subscription tier: $error');
    }
  }

  String _validSubscriptionTier(String? tier) =>
      const {'FREE', 'PRO', 'ULTRA'}.contains(tier) ? tier! : 'FREE';

  void _setSubscriptionTier(String tier) {
    if (!mounted) return;
    setState(() => _subscriptionTier = tier);
    if (!const {'PRO', 'ULTRA'}.contains(tier) &&
        widget.selectedTheme == 'Neon') {
      widget.onThemeChanged?.call('Dark');
    }
  }

  void _changeTheme(String theme) {
    if (theme == 'Neon' &&
        !const {'PRO', 'ULTRA'}.contains(_subscriptionTier)) {
      return;
    }
    widget.onThemeChanged?.call(theme);
  }

  AstatinePalette get _palette =>
      Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;

  bool get _isVietnamese => _selectedLanguage == 'vi';

  AppStrings get strings => switch (_selectedLanguage) {
    'vi' => AppStrings.vi,
    'zh' => AppStrings.zh,
    _ => AppStrings.en,
  };

  void _setLanguage(String languageCode) {
    setState(() => _selectedLanguage = languageCode);
  }

  Future<void> _showUpdateLog() => showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.68),
    builder: (_) => UpdateLogDialog(
      store: widget.updateLogStore ?? SupabaseReleaseNotesStore(),
      palette: _palette,
    ),
  );

  String get _currentUserName =>
      widget.currentUserName.trim().isEmpty ? 'User' : widget.currentUserName;

  String get _currentUserRole => switch (widget.currentUserRole.toLowerCase()) {
    'student' =>
      _selectedLanguage == 'zh'
          ? '学生'
          : _isVietnamese
          ? 'Học sinh'
          : 'Student',
    'teacher' =>
      _selectedLanguage == 'zh'
          ? '教师'
          : _isVietnamese
          ? 'Giáo viên'
          : 'Teacher',
    'developer' =>
      _selectedLanguage == 'zh'
          ? '开发者'
          : _isVietnamese
          ? 'Nhà phát triển'
          : 'Developer',
    'guest' =>
      _selectedLanguage == 'zh'
          ? '访客'
          : _isVietnamese
          ? 'Khách'
          : 'Guest',
    _ => widget.currentUserRole,
  };

  String get _currentUserInitial => _currentUserName[0].toUpperCase();

  List<String> get _menuTitles => [
    strings.dashboardOverview,
    strings.classroomChat,
    strings.virtualLab,
    strings.assignments,
    strings.schedule,
    strings.achievements,
    strings.market,
    strings.settings,
    strings.classrooms,
    'Flashcard',
  ];

  static const _menuSearchTerms = [
    'Dashboard Overview Tổng quan trang chủ',
    'Classroom Chat Phòng chat lớp học',
    'Virtual Lab Phòng thí nghiệm',
    'Assignments Nhiệm vụ',
    'Class Schedule Lịch học thời khóa biểu',
    'Achievements Thành tựu badges rewards',
    'Market Chợ marketplace items',
    'Settings Cài đặt',
    'Classrooms Lớp học classrooms groups',
    'Flashcard Thẻ ghi nhớ học tập',
  ];

  List<LabSearchItem> get _dashboardSearchItems => [
    for (var index = 0; index < _menuTitles.length; index++)
      LabSearchItem(
        title: _menuTitles[index],
        subtitle: _selectedLanguage == 'zh'
            ? '导航'
            : _isVietnamese
            ? 'Mục điều hướng'
            : 'Navigation',
        searchText: '${_menuTitles[index]} ${_menuSearchTerms[index]}',
        type: LabSearchItemType.destination,
        destinationIndex: index,
      ),
    LabSearchItem(
      title: strings.aiTutorTitle,
      subtitle: strings.aiTutorSubtitle,
      searchText: '${strings.aiTutorTitle} AI tutor gia sư Socratic',
      type: LabSearchItemType.destination,
      value: strings.aiTutorTitle,
    ),
    LabSearchItem(
      title: strings.projectTitle,
      subtitle: strings.projectSubtitle,
      searchText: '${strings.projectTitle} Project Hub dự án nhóm học tập',
      type: LabSearchItemType.destination,
      value: 'project-hub',
    ),
    ...VirtualLabScreen.searchableLessons,
  ];

  void _selectDashboardSearchItem(LabSearchItem item) {
    if (item.type == LabSearchItemType.lesson) {
      _pendingLabSearchItem = item;
      _openMainScreen(2);
    } else if (item.value == 'project-hub') {
      _openProjectHub();
    } else if (item.destinationIndex != null) {
      _openMainScreen(item.destinationIndex!);
    } else if (item.value is String) {
      ToastService.showInfo(item.value! as String);
    }
  }

  void _openMainScreen(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _openWorkspace() async {
    setState(() {
      _isWorkspaceActive = true;
      _workspaceFullscreenWasLost = false;
    });
    _startWorkspaceKioskMode();

    try {
      await _kioskModeService.enterFullscreen();
    } catch (error) {
      debugPrint('Unable to enter workspace fullscreen: $error');
      if (mounted && _isWorkspaceActive) {
        setState(() => _workspaceFullscreenWasLost = true);
      }
    }
  }

  Future<void> _retryWorkspaceFullscreen() async {
    try {
      await _kioskModeService.enterFullscreen();
      if (mounted) setState(() => _workspaceFullscreenWasLost = false);
    } catch (error) {
      debugPrint('Unable to re-enter workspace fullscreen: $error');
    }
  }

  void _startWorkspaceKioskMode() {
    _kioskModeService.start(
      onUnauthorizedFullscreenExit: () {
        if (mounted && _isWorkspaceActive) {
          setState(() => _workspaceFullscreenWasLost = true);
        }
      },
      onFullscreenShortcut: (isFullscreen) {
        _toggleWorkspaceFullscreen(isFullscreen: isFullscreen);
      },
    );
  }

  Future<void> _toggleWorkspaceFullscreen({bool? isFullscreen}) async {
    if (DesktopWindowService.isSupported) {
      try {
        await DesktopWindowService.toggleFullscreen();
        if (mounted && _isWorkspaceActive) {
          setState(() => _workspaceFullscreenWasLost = false);
        }
      } catch (error) {
        debugPrint('Unable to toggle desktop workspace fullscreen: $error');
      }
      return;
    }

    final shouldExitFullscreen = isFullscreen ?? !_workspaceFullscreenWasLost;
    if (!shouldExitFullscreen) {
      await _retryWorkspaceFullscreen();
      return;
    }

    try {
      await _kioskModeService.exitFullscreen();
    } catch (error) {
      debugPrint('Unable to exit workspace fullscreen with F11: $error');
      if (mounted && _isWorkspaceActive) {
        setState(() => _workspaceFullscreenWasLost = true);
      }
    }
  }

  Future<void> _exitWorkspace() async {
    _kioskModeService.dispose();
    try {
      await _kioskModeService.exitFullscreen();
    } catch (error) {
      debugPrint('Unable to exit workspace fullscreen: $error');
      if (mounted) {
        _startWorkspaceKioskMode();
        setState(() => _workspaceFullscreenWasLost = true);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isWorkspaceActive = false;
        _workspaceFullscreenWasLost = false;
      });
    }
  }

  void _openProjectHub() {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) =>
            CreateWorkspaceScreen(
              isVietnamese: _isVietnamese,
              languageCode: _selectedLanguage,
              currentUserName: _currentUserName,
              currentUserId: widget.currentUserId,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slide = animation.drive(
            Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _sidebarScrollController.dispose();
    _kioskModeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isWorkspaceActive
          ? WorkspaceDesktopScreen(
              strings: strings,
              fullscreenWasLost: _workspaceFullscreenWasLost,
              onRetryFullscreen: _retryWorkspaceFullscreen,
              onToggleFullscreen: _toggleWorkspaceFullscreen,
              onExitWorkspace: _exitWorkspace,
            )
          : ResponsiveBuilder(
              builder: (context, sizingInformation) {
                final compact =
                    sizingInformation.deviceScreenType ==
                    DeviceScreenType.mobile;
                final sidebarWidth = compact
                    ? 72.0
                    : _isSidebarCollapsed
                    ? 88.0
                    : 260.0;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: _DashboardBackdrop(palette: _palette),
                    ),
                    AnimatedPadding(
                      duration: const Duration(milliseconds: 360),
                      curve: Curves.easeInOutCubic,
                      padding: EdgeInsets.only(left: sidebarWidth),
                      child: SizedBox.expand(
                        child: Container(
                          color: Colors.transparent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_selectedIndex != 1 &&
                                  _selectedIndex != 2 &&
                                  _selectedIndex != 3)
                                _buildCommandHeader(compact),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    final slide = animation.drive(
                                      Tween<Offset>(
                                        begin: const Offset(0, 0.025),
                                        end: Offset.zero,
                                      ).chain(
                                        CurveTween(curve: Curves.easeOutCubic),
                                      ),
                                    );
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: slide,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    key: ValueKey('$_selectedIndex'),
                                    padding: _selectedIndex == 0
                                        ? const EdgeInsets.all(24)
                                        : EdgeInsets.zero,
                                    child: _selectedIndex == 0
                                        ? DashboardContent(
                                            strings: strings,
                                            userName: _currentUserName,
                                            isVietnamese: _isVietnamese,
                                            onOpenVirtualLab: () =>
                                                _openMainScreen(2),
                                            onOpenAssignments: () =>
                                                _openMainScreen(3),
                                            onOpenProjectHub: _openProjectHub,
                                            onOpenAppHub: _openWorkspace,
                                          )
                                        : _selectedIndex == 1
                                        ? AstatineDiscordDashboard(
                                            isVietnamese: _isVietnamese,
                                            languageCode: _selectedLanguage,
                                          )
                                        : _selectedIndex == 2
                                        ? VirtualLabScreen(
                                            isVietnamese: _isVietnamese,
                                            initialSearchItem:
                                                _pendingLabSearchItem,
                                            onInitialSearchHandled: () =>
                                                setState(() {
                                                  _pendingLabSearchItem = null;
                                                }),
                                            onNavigate: _openMainScreen,
                                            onOpenProjectHub: _openProjectHub,
                                          )
                                        : _selectedIndex == 7
                                        ? StudentProfileSettingsScreen(
                                            isVietnamese: _isVietnamese,
                                            userName: _currentUserName,
                                            userEmail: widget.currentUserEmail,
                                            userRole: _currentUserRole,
                                            subscriptionTier: _subscriptionTier,
                                            selectedTheme: widget.selectedTheme,
                                            languageCode: _selectedLanguage,
                                            onLanguageChanged: (isVietnamese) =>
                                                _setLanguage(
                                                  isVietnamese ? 'vi' : 'en',
                                                ),
                                            onLanguageCodeChanged: _setLanguage,
                                            onThemeChanged: _changeTheme,
                                          )
                                        : _selectedIndex == 3
                                        ? AssignmentsDailyQuestsScreen(
                                            isVietnamese: _isVietnamese,
                                            languageCode: _selectedLanguage,
                                            userName: _currentUserName,
                                            userRole: widget.currentUserRole,
                                          )
                                        : _selectedIndex == 8
                                        ? AstatineDiscordDashboard(
                                            isVietnamese: _isVietnamese,
                                            languageCode: _selectedLanguage,
                                          )
                                         : _selectedIndex == 5
                                         ? AchievementCenterScreen(
                                             isVietnamese: _isVietnamese,
                                           )
                                         : _selectedIndex == 9
                                         ? const FlashcardsDashboardScreen()
                                         : Center(
                                            child: Text(
                                              '${strings.screenInProgress}: "${_menuTitles[_selectedIndex]}"',
                                              style: TextStyle(
                                                color: _palette.canvasMutedText,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      key: const Key('focus-navigation-panel'),
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: sidebarWidth,
                      child: _buildSidebar(
                        compact: compact || _isSidebarCollapsed,
                        isMobile: compact,
                      ),
                    ),
                    if (_selectedIndex != 7)
                      Positioned(
                        right: 20,
                        bottom: 92,
                        child: GeminiAssistantBubble(
                          isVietnamese: _isVietnamese,
                          languageCode: _selectedLanguage,
                          interfaceName: _menuTitles[_selectedIndex],
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCommandHeader(bool compact) {
    final narrow = compact || MediaQuery.sizeOf(context).width < 1050;
    final icon = switch (_selectedIndex) {
      1 => _lucideMessages,
      2 => _lucideFlask,
      3 => _lucideClipboard,
      4 => _lucideCalendar,
      5 => _lucideTrophy,
      6 => _lucideStore,
      7 => _lucideSettings,
      _ => _lucideDashboard,
    };
    return Container(
          margin: EdgeInsets.fromLTRB(
            compact ? 12 : 24,
            compact ? 10 : 20,
            compact ? 12 : 24,
            10,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 18,
            vertical: compact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: _palette.card.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _palette.border.withValues(alpha: 0.78)),
            boxShadow: [
              BoxShadow(
                color: _palette.accent.withValues(alpha: 0.045),
                blurRadius: 24,
                spreadRadius: -8,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              if (!narrow) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _palette.accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: _palette.accent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(icon, color: _palette.accent, size: 18),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _menuTitles[_selectedIndex].toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: _palette.canvasText,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                      ),
                      Text(
                        'ASTATINE DASHBOARD',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _palette.secondaryText,
                          fontSize: 8,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                const Spacer(),
              SizedBox(
                key: const ValueKey('dashboard-toolbar-visible'),
                width: narrow ? 250 : 390,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Container(
                        key: const Key('dashboard-search'),
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: LabSearchBar(
                          items: _dashboardSearchItems,
                          onSelected: _selectDashboardSearchItem,
                          searchKey: const Key('dashboard-search-input'),
                          hintText: strings.searchPlaceholder,
                        ),
                      ),
                    ),
                    if (_selectedIndex == 0) ...[
                      const Gap(8),
                      _buildUpdateLogButton(compact: narrow),
                    ],
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 400))
        .slideY(
          begin: 0.1,
          end: 0,
          duration: const Duration(milliseconds: 400),
        );
  }

  Widget _buildSidebar({bool compact = false, bool isMobile = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rail = compact || constraints.maxWidth < 200;
        return Container(
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            color: _palette.background.withValues(alpha: 0.97),
            border: Border(
              right: BorderSide(color: _palette.border.withValues(alpha: 0.78)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 28,
                offset: const Offset(8, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  rail ? 12 : 20,
                  rail ? 16 : 24,
                  rail ? 12 : 18,
                  rail ? 16 : 21,
                ),
                child: rail
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAppFullscreenButton(),
                          if (!isMobile) ...[
                            const SizedBox(height: 5),
                            _buildSidebarCollapseButton(),
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          _buildAppFullscreenButton(),
                          const Gap(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AdminTerminalTapTarget(
                                  child: Text(
                                    strings.appName,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: _palette.canvasText,
                                        ),
                                  ),
                                ),
                                Text(
                                  'LEARNING SYSTEM',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontSize: 8,
                                        color: _palette.secondaryText,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          _buildSidebarCollapseButton(),
                        ],
                      ),
              ),
              Divider(
                color: _palette.border.withValues(alpha: 0.62),
                height: 1,
              ),
              const Gap(15),
              Expanded(child: _buildNavigationMenu(compact: rail)),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  rail ? 7 : 14,
                  8,
                  rail ? 7 : 14,
                  rail ? 9 : 16,
                ),
                child: Column(
                  children: [
                    if (!rail)
                      _buildSubscriptionAccountButton()
                    else if (!isMobile)
                      _buildCompactSubscriptionAccountButton(),
                    if (!rail) const Gap(10),
                    Container(
                      padding: EdgeInsets.all(rail ? 7 : 11),
                      decoration: BoxDecoration(
                        color: _palette.card.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: _palette.border.withValues(alpha: 0.82),
                        ),
                        boxShadow: _palette.glowEnabled
                            ? [
                                BoxShadow(
                                  color: _palette.accent.withValues(
                                    alpha: 0.04,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: -8,
                                ),
                              ]
                            : const [],
                      ),
                      child: Row(
                        mainAxisAlignment: rail
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _palette.accent.withValues(alpha: 0.7),
                              ),
                            ),
                            child: UserProfileAvatar(
                              key: const Key('sidebar-profile-avatar'),
                              userId: widget.currentUserId,
                              radius: rail ? 14 : 17,
                              fallbackText: _currentUserInitial,
                              languageCode: _selectedLanguage,
                            ),
                          ),
                          if (!rail) ...[
                            const Gap(10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedBuilder(
                                    animation: UserProfileStore.instance,
                                    builder: (context, _) {
                                      final profile =
                                          widget.currentUserId == null
                                          ? null
                                          : UserProfileStore.instance
                                                .profileFor(
                                                  widget.currentUserId!,
                                                );
                                      final name =
                                          (profile?['full_name'] as String?)
                                              ?.trim();
                                      return _SubscriptionNameLabel(
                                        name: name?.isNotEmpty == true
                                            ? name!
                                            : _currentUserName,
                                        tier: _subscriptionTier,
                                        defaultColor: _palette.primaryText,
                                      );
                                    },
                                  ),
                                  Text(
                                    _currentUserRole.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: _palette.secondaryText,
                                          fontSize: 8,
                                          letterSpacing: 0.9,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _lucideArrowUpRight,
                              size: 14,
                              color: _palette.secondaryText,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarCollapseButton() {
    final collapsed = _isSidebarCollapsed;
    return Tooltip(
      message: _isVietnamese
          ? collapsed
                ? 'Mở rộng thanh điều hướng'
                : 'Thu gọn thanh điều hướng'
          : collapsed
          ? 'Expand sidebar'
          : 'Collapse sidebar',
      child: IconButton(
        key: const Key('sidebar-collapse-toggle'),
        visualDensity: VisualDensity.compact,
        onPressed: () => setState(() {
          _isSidebarCollapsed = !_isSidebarCollapsed;
          if (_sidebarScrollController.hasClients) {
            _sidebarScrollController.jumpTo(0);
          }
        }),
        icon: Icon(
          collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
          color: _palette.secondaryText,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildAppFullscreenButton() {
    return Tooltip(
      message: _isVietnamese ? 'Bật/tắt toàn màn hình' : 'Toggle fullscreen',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('dashboard-fullscreen-toggle'),
          onTap: () {
            final actions = AdminTerminalActions.maybeOf(context);
            if (actions != null) {
              actions.toggleFullscreen();
            } else {
              unawaited(_toggleStandaloneFullscreen());
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _palette.accent.withValues(alpha: 0.19),
                  const Color(0xFF7000FF).withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _palette.accent.withValues(alpha: 0.38),
              ),
              boxShadow: [
                BoxShadow(
                  color: _palette.accent.withValues(alpha: 0.12),
                  blurRadius: 18,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Icon(
              Icons.fullscreen_rounded,
              color: _palette.accent,
              size: 23,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleStandaloneFullscreen() async {
    try {
      await DesktopWindowService.toggleFullscreen();
    } catch (error) {
      debugPrint('Unable to toggle application fullscreen: $error');
    }
  }

  Widget _buildSubscriptionAccountButton() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        key: const Key('subscription-account-pricing'),
        onTap: _showPricingPlans,
        borderRadius: BorderRadius.circular(11),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_subscriptionAccentLight, _subscriptionAccent],
            ),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _subscriptionAccentLight),
            boxShadow: [
              BoxShadow(
                color: _subscriptionAccent.withValues(alpha: 0.17),
                blurRadius: 16,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: _subscriptionForeground,
                size: 15,
              ),
              const Gap(6),
              Expanded(
                child: Text(
                  'AST $_subscriptionTier ACCOUNT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.55,
                    fontWeight: FontWeight.w800,
                    color: _subscriptionForeground,
                  ),
                ),
              ),
              const Gap(4),
              Icon(
                Icons.chevron_right_rounded,
                color: _subscriptionForeground,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSubscriptionAccountButton() {
    return Tooltip(
      message: 'AST $_subscriptionTier ACCOUNT',
      child: IconButton(
        key: const Key('compact-subscription-account'),
        onPressed: _showPricingPlans,
        icon: Icon(Icons.workspace_premium_rounded, color: _subscriptionAccent),
      ),
    );
  }

  Widget _buildUpdateLogButton({required bool compact}) {
    final button = compact
        ? IconButton(
            key: const Key('dashboard-update-log-button'),
            tooltip: 'Nhật ký cập nhật (Update Log)',
            onPressed: _showUpdateLog,
            icon: Icon(Icons.history_rounded, color: _palette.accent),
            visualDensity: VisualDensity.compact,
          )
        : OutlinedButton.icon(
            key: const Key('dashboard-update-log-button'),
            onPressed: _showUpdateLog,
            icon: const Icon(Icons.history_rounded, size: 17),
            label: const Text('Update Log'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _palette.primaryText,
              side: BorderSide(color: _palette.border),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            ),
          );
    return button;
  }

  Future<void> _showPricingPlans() {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => _PricingPlansDialog(
        onTierChanged: (tier) =>
            _setSubscriptionTier(_validSubscriptionTier(tier)),
      ),
    );
  }

  Widget _buildNavigationMenu({bool compact = false}) {
    const itemExtent = 52.0;
    const headerExtent = 32.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentHeight = itemExtent * (9 + (_isAppsExpanded && !compact ? 1 : 0)) + (compact ? 0 : headerExtent);
        final menu = SizedBox(
          height: contentHeight,
          child: Stack(
            children: [
              AnimatedPositioned(
                key: const Key('navigation-selection-indicator'),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                top:
                    (compact ? 0 : headerExtent) +
                    (_selectedIndex == 9
                        ? (compact
                            ? 7 * itemExtent
                            : (7 * itemExtent + 46))
                        : _selectedIndex * itemExtent) +
                    3,
                left: compact ? 6 : 11,
                right: compact ? 6 : 11,
                height: 46,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _palette.accent.withValues(alpha: 0.095),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _palette.accent.withValues(alpha: 0.28),
                      ),
                      boxShadow: _palette.glowEnabled
                          ? [
                              BoxShadow(
                                color: _palette.accent.withValues(alpha: 0.09),
                                blurRadius: 12,
                                spreadRadius: -5,
                              ),
                            ]
                          : const [],
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: compact ? 3 : 2,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _palette.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!compact)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                      child: Row(
                        children: [
                          Text(
                            _isVietnamese ? 'ĐIỀU HƯỚNG' : 'NAVIGATION',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 9,
                                  color: _palette.secondaryText,
                                  letterSpacing: 1.5,
                                ),
                          ),
                          const Gap(6),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: _palette.border.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildNavItem(
                    0,
                    _lucideDashboard,
                    strings.dashboardOverview,
                    compact: compact,
                  ),
                  _buildNavItem(
                    1,
                    _lucideMessages,
                    strings.classroomChat,
                    compact: compact,
                  ),
                  _buildNavItem(
                    2,
                    _lucideFlask,
                    strings.virtualLab,
                    compact: compact,
                  ),
                  _buildNavItem(
                    3,
                    _lucideClipboard,
                    strings.assignments,
                    compact: compact,
                  ),
                  _buildNavItem(
                    4,
                    _lucideCalendar,
                    strings.schedule,
                    compact: compact,
                  ),
                  _buildAchievementsNavItem(compact: compact),
                  _buildNavItem(
                    6,
                    _lucideStore,
                    strings.market,
                    compact: compact,
                  ),
                  _buildNavItem(
                    7,
                    _lucideSettings,
                    strings.settings,
                    compact: compact,
                  ),
                   _buildAppsMenuSection(compact: compact),
                 ],
               ),
            ],
          ),
        );
        if (contentHeight <= constraints.maxHeight) return menu;
        return Scrollbar(
          key: const Key('left-navigation-scrollbar'),
          controller: _sidebarScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _sidebarScrollController,
            primary: false,
            child: menu,
          ),
        );
      },
    );
  }

  // Achievements navigation item
  Widget _buildAchievementsNavItem({bool compact = false}) =>
      _buildNavItem(5, _lucideTrophy, _menuTitles[5], compact: compact);

  Widget _buildAppsMenuSection({bool compact = false}) {
    if (compact) {
      return _buildNavItem(9, Icons.style_rounded, 'Flashcard', compact: true);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _isAppsExpanded = !_isAppsExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 46,
              margin: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _isAppsExpanded ? _palette.accent.withValues(alpha: 0.06) : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(Icons.apps_rounded, color: _palette.secondaryText, size: 20),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      _isVietnamese ? 'Ứng dụng (Apps)' : 'Apps',
                      style: TextStyle(
                        color: _palette.primaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _isAppsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: _palette.secondaryText,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isAppsExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _buildNavItem(9, Icons.style_rounded, 'Flashcard', compact: false),
          ),
      ],
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String title, {
    bool compact = false,
  }) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: compact ? 6 : 11, vertical: 3),
      child: HoverLift(
        scale: 1.018,
        child: Material(
          color: Colors.transparent,
          child: Tooltip(
            message: title,
            child: InkWell(
              key: ValueKey('dashboard-nav-$index'),
              mouseCursor: SystemMouseCursors.none,
              onTap: () => _openMainScreen(index),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 46,
                padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 11),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.transparent),
                ),
                child: Row(
                  mainAxisAlignment: compact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(
                      icon,
                      color: isSelected
                          ? _palette.accent
                          : _palette.canvasMutedText,
                      size: 18,
                    ),
                    if (!compact) ...[
                      const Gap(11),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            color: isSelected
                                ? _palette.canvasText
                                : _palette.canvasMutedText,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                          child: Text(title, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Achievements Sidebar Nav Item with Hover Sub-menu
class _SubscriptionNameLabel extends StatelessWidget {
  const _SubscriptionNameLabel({
    required this.name,
    required this.tier,
    required this.defaultColor,
  });

  final String name;
  final String tier;
  final Color defaultColor;

  @override
  Widget build(BuildContext context) {
    return SubscriptionNameEffect(
      name: name,
      tier: tier,
      defaultColor: defaultColor,
    );
  }
}

class _PricingPlansDialog extends StatefulWidget {
  const _PricingPlansDialog({this.onTierChanged});

  final ValueChanged<String>? onTierChanged;

  @override
  State<_PricingPlansDialog> createState() => _PricingPlansDialogState();
}

class _PricingPlansDialogState extends State<_PricingPlansDialog> {
  final _plansScrollController = SmoothMouseScrollController();

  static const _plans = [
    _PricingPlan(
      code: 'FREE',
      title: 'FREE',
      priceAst: 0,
      accent: Color(0xFF83D8E8),
      buttonLabel: 'Dùng miễn phí',
      features: [
        'Tạo tối đa 5 máy chủ (Sức chứa 10 người/máy chủ)',
        '5 lượt hỏi AI Lab/ngày (dạng Text)',
        'Tạo Flashcard thủ công',
        'Tốc độ nhận AST Coin: 1x',
        'Dung lượng lưu trữ: 500MB (Tối đa 15MB/file)',
      ],
    ),
    _PricingPlan(
      code: 'PRO',
      title: 'PRO',
      priceAst: 490,
      accent: Color(0xFFBB65E7),
      buttonLabel: 'Nâng cấp PRO',
      isFeatured: true,
      features: [
        'Tạo tối đa 10 máy chủ (Sức chứa 20 người/máy chủ)',
        'Không giới hạn lượt hỏi AI (Text và quét ảnh OCR)',
        'AI tự động tạo Flashcard (tối đa 100 thẻ/bộ)',
        'Tốc độ nhận AST Coin: 2x',
        'Tặng 2 thẻ Bảo vệ Chuỗi Streak/tháng',
        'Dung lượng lưu trữ: 10GB (Tối đa 100MB/file)',
        'Khung Avatar LED và giao diện Liquid Glass',
      ],
    ),
    _PricingPlan(
      code: 'ULTRA',
      title: 'ULTRA',
      priceAst: 1190,
      accent: Color(0xFFFFC400),
      buttonLabel: 'Nâng cấp ULTRA',
      features: [
        'Tạo tối đa 20 máy chủ (Sức chứa 50 người/máy chủ)',
        'AI Voice Chat 1-on-1 và giải bài tập từng bước',
        'AI Flashcard không giới hạn + Ôn tập Spaced Repetition',
        'Tốc độ nhận AST Coin: 3.5x + Quỹ thưởng tuần',
        'Dung lượng lưu trữ cloud không giới hạn',
        'Thẻ cứng NFC Astat Black Card (khi đăng ký 1 năm)',
        'Báo cáo tiến độ học tập gửi qua Email/Zalo hàng tuần',
      ],
    ),
  ];

  String? _currentTier;
  DateTime? _subscriptionExpiresAt;
  String? _astBalance;
  String? _feedback;
  bool _feedbackIsError = false;
  bool _isLoadingAccount = true;
  String? _purchasingPlan;

  @override
  void dispose() {
    _plansScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingAccount = false);
        return;
      }

      final account = await client
          .from('users')
          .select('subscription_tier, subscription_expires_at')
          .eq('id', user.id)
          .single();
      final wallet = await client
          .from('user_wallets')
          .select('ast_balance')
          .eq('user_id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _currentTier = account['subscription_tier']?.toString();
        final expiry = account['subscription_expires_at']?.toString();
        _subscriptionExpiresAt = expiry == null
            ? null
            : DateTime.tryParse(expiry);
        _astBalance = wallet?['ast_balance']?.toString();
        _isLoadingAccount = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _feedback = 'Không thể tải ví/gói hiện tại: $error';
        _feedbackIsError = true;
        _isLoadingAccount = false;
      });
    }
  }

  Future<void> _purchase(_PricingPlan plan) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        setState(() {
          _feedback = 'Vui lòng đăng nhập trước khi mua gói.';
          _feedbackIsError = true;
        });
        return;
      }

      setState(() {
        _purchasingPlan = plan.code;
        _feedback = null;
      });
      final response = await client.rpc(
        'purchase_subscription',
        params: {'p_plan_code': plan.code},
      );
      if (response is! Map) {
        throw const FormatException('Kết quả mua gói không hợp lệ.');
      }
      final result = Map<String, dynamic>.from(response);
      final tier = result['subscription_tier']?.toString();
      final balance = result['ast_balance']?.toString();
      if (tier == null || balance == null) {
        throw const FormatException('Thiếu thông tin gói hoặc số dư AST.');
      }
      final expiry = result['subscription_expires_at']?.toString();
      if (!mounted) return;
      final userId = client.auth.currentUser?.id;
      if (userId != null) SubscriptionTierCache.invalidate(userId);
      setState(() {
        _currentTier = tier;
        _astBalance = balance;
        _subscriptionExpiresAt = expiry == null
            ? null
            : DateTime.tryParse(expiry);
        _feedback = plan.priceAst == 0
            ? 'Đã chuyển sang gói ${plan.title}.'
            : 'Đã mua gói ${plan.title}. Số dư mới: $_formattedAstBalance AST.';
        _feedbackIsError = false;
        _purchasingPlan = null;
      });
      widget.onTierChanged?.call(tier);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _feedback = 'Không thể mua gói ${plan.title}: $error';
        _feedbackIsError = true;
        _purchasingPlan = null;
      });
    }
  }

  String get _formattedAstBalance {
    final balance = _astBalance;
    if (balance == null) return '—';
    final parts = balance.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final fraction = parts.length > 1
        ? parts[1].replaceFirst(RegExp(r'0+$'), '')
        : '';
    return fraction.isEmpty ? whole : '$whole.$fraction';
  }

  bool _isCurrentPlan(_PricingPlan plan) =>
      _currentTier == plan.code &&
      (plan.code == 'FREE' ||
          (_subscriptionExpiresAt?.isAfter(DateTime.now()) ?? false));

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1180,
          maxHeight: screenSize.height * 0.92,
        ),
        child: SizedBox(
          width: double.infinity,
          height: screenSize.height * 0.88,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E17),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF245344)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF43D9A3).withValues(alpha: 0.08),
                  blurRadius: 42,
                  spreadRadius: -12,
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF43D9A3).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: const Color(0xFF43D9A3)
                                .withValues(alpha: 0.24),
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF75F0C0),
                          size: 20,
                        ),
                      ),
                      const Gap(13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chọn gói Astatine',
                              style: TextStyle(
                                color: Color(0xFFF3F7FF),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.35,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Mở khóa trải nghiệm học tập phù hợp với bạn',
                              style: TextStyle(
                                color: Color(0xFF93A1B5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF93A1B5),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF202A39)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: const Color(0xFF43D9A3).withValues(alpha: 0.9),
                        size: 16,
                      ),
                      const Gap(7),
                      Expanded(
                        child: Text(
                          _isLoadingAccount
                              ? 'Đang tải ví AST...'
                              : 'Ví AST: $_formattedAstBalance'
                                    '${_currentTier == null ? '' : '  ·  Gói hiện tại: $_currentTier'}'
                                    '${_subscriptionExpiresAt == null ? '' : '  ·  Hết hạn: ${_subscriptionExpiresAt!.toLocal().toString().substring(0, 10)}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9BB3B5),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_feedback != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Container(
                      key: const Key('subscription-feedback'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            (_feedbackIsError
                                    ? const Color(0xFFFF707A)
                                    : const Color(0xFF43D9A3))
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color:
                              (_feedbackIsError
                                      ? const Color(0xFFFF707A)
                                      : const Color(0xFF43D9A3))
                                  .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _feedback!,
                        style: TextStyle(
                          color: _feedbackIsError
                              ? const Color(0xFFFF9AA1)
                              : const Color(0xFF75F0C0),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final plans = constraints.maxWidth >= 860
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    var index = 0;
                                    index < _plans.length;
                                    index++
                                  )
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          index == 0 ? 20 : 8,
                                          20,
                                          index == _plans.length - 1 ? 20 : 8,
                                          20,
                                        ),
                                        child: _PricingPlanCard(
                                          plan: _plans[index],
                                          isCurrent: _isCurrentPlan(
                                            _plans[index],
                                          ),
                                          isPurchasing:
                                              _purchasingPlan ==
                                              _plans[index].code,
                                          onPurchase: () =>
                                              _purchase(_plans[index]),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                for (
                                  var index = 0;
                                  index < _plans.length;
                                  index++
                                )
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      index == 0 ? 18 : 8,
                                      16,
                                      index == _plans.length - 1 ? 18 : 8,
                                    ),
                                    child: _PricingPlanCard(
                                      plan: _plans[index],
                                      compact: true,
                                      isCurrent: _isCurrentPlan(_plans[index]),
                                      isPurchasing:
                                          _purchasingPlan == _plans[index].code,
                                      onPurchase: () =>
                                          _purchase(_plans[index]),
                                    ),
                                  ),
                              ],
                            );

                      return SingleChildScrollView(
                        controller: _plansScrollController,
                        padding: EdgeInsets.zero,
                        child: plans,
                      );
                    },
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

class _PricingPlan {
  const _PricingPlan({
    required this.code,
    required this.title,
    required this.priceAst,
    required this.accent,
    required this.buttonLabel,
    required this.features,
    this.isFeatured = false,
  });

  final String code;
  final String title;
  final int priceAst;
  String get price => '$priceAst AST';
  final Color accent;
  final String buttonLabel;
  final List<String> features;
  final bool isFeatured;
}

class _PricingPlanCard extends StatelessWidget {
  const _PricingPlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isPurchasing,
    required this.onPurchase,
    this.compact = false,
  });
  final _PricingPlan plan;
  final bool isCurrent;
  final bool isPurchasing;
  final VoidCallback onPurchase;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 244 : 272,
      decoration: BoxDecoration(
        color: plan.isFeatured
            ? const Color(0xFF111D2B)
            : const Color(0xFF101722),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: plan.accent.withValues(alpha: plan.isFeatured ? 0.78 : 0.25),
          width: plan.isFeatured ? 1.4 : 1,
        ),
        boxShadow: plan.isFeatured
            ? [
                BoxShadow(
                  color: plan.accent.withValues(alpha: 0.1),
                  blurRadius: 26,
                  spreadRadius: -8,
                ),
              ]
            : const [],
      ),
      padding: const EdgeInsets.all(19),
      child: SingleChildScrollView(
        primary: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  plan.title,
                  style: TextStyle(
                    color: plan.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                const Spacer(),
                if (plan.isFeatured)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: plan.accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: plan.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'Phổ biến nhất',
                      style: TextStyle(
                        color: plan.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const Gap(11),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      plan.price,
                      style: const TextStyle(
                        color: Color(0xFFF3F7FF),
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
                const Gap(6),
                const Text(
                  '/ tháng',
                  style: TextStyle(color: Color(0xFF93A1B5), fontSize: 11),
                ),
              ],
            ),
            const Gap(17),
            const Divider(height: 1, color: Color(0xFF263142)),
            const Gap(16),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: plan.accent,
                        size: 15,
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          color: Color(0xFFD1D9E6),
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Gap(4),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton(
                onPressed: isCurrent || isPurchasing ? null : onPurchase,
                style: FilledButton.styleFrom(
                  backgroundColor: plan.isFeatured
                      ? plan.accent
                      : plan.accent.withValues(alpha: 0.12),
                  foregroundColor: plan.isFeatured
                      ? const Color(0xFF07131A)
                      : plan.accent,
                  side: plan.isFeatured
                      ? null
                      : BorderSide(color: plan.accent.withValues(alpha: 0.32)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: isPurchasing
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isCurrent ? 'Gói hiện tại' : plan.buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardContent extends StatefulWidget {
  final AppStrings strings;
  final String userName;
  final bool isVietnamese;
  final VoidCallback onOpenVirtualLab;
  final VoidCallback onOpenAssignments;
  final VoidCallback onOpenProjectHub;
  final VoidCallback onOpenAppHub;

  const DashboardContent({
    super.key,
    required this.strings,
    required this.userName,
    required this.isVietnamese,
    required this.onOpenVirtualLab,
    required this.onOpenAssignments,
    required this.onOpenProjectHub,
    required this.onOpenAppHub,
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  final _scrollController = SmoothMouseScrollController();
  final ValueNotifier<double> _scrollProgress = ValueNotifier(0);

  AppStrings get strings => widget.strings;
  String get userName => widget.userName;
  bool get isVietnamese => widget.isVietnamese;
  VoidCallback get onOpenVirtualLab => widget.onOpenVirtualLab;
  VoidCallback get onOpenAssignments => widget.onOpenAssignments;
  VoidCallback get onOpenProjectHub => widget.onOpenProjectHub;
  VoidCallback get onOpenAppHub => widget.onOpenAppHub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final offset = _scrollController.offset;
    if (offset != _scrollProgress.value) _scrollProgress.value = offset;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    final theme = Theme.of(context);
    final nunitoFamily = GoogleFonts.nunito().fontFamily;
    final dashboardTextTheme = theme.textTheme.apply(fontFamily: nunitoFamily);
    return Theme(
      data: theme.copyWith(
        textTheme: dashboardTextTheme,
        primaryTextTheme: theme.primaryTextTheme.apply(
          fontFamily: nunitoFamily,
        ),
      ),
      child: ResponsiveBuilder(
        builder: (context, sizingInformation) {
          final compact =
              sizingInformation.deviceScreenType == DeviceScreenType.mobile ||
              MediaQuery.sizeOf(context).width < 960;
          final horizontalPadding = compact ? 16.0 : 30.0;
          return LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 1080;
              final columns = constraints.maxWidth >= 650 ? 2 : 1;
              final modules = <Widget>[
                StaggeredGridTile.extent(
                  crossAxisCellCount: 1,
                  mainAxisExtent: compact ? 220 : 232,
                  child: _ScrollReveal(
                    scrollProgress: _scrollProgress,
                    child: BentoCard(
                      icon: _lucideFlask,
                      title: strings.dashboardCardTitle,
                      subtitle: strings.dashboardCardSubtitle,
                      onTap: widget.onOpenVirtualLab,
                      accent: palette.accent,
                      featured: true,
                      actionLabel: isVietnamese
                          ? 'MỞ PHÒNG THÍ NGHIỆM'
                          : 'OPEN LAB',
                    ),
                  ),
                ),
                StaggeredGridTile.extent(
                  crossAxisCellCount: 1,
                  mainAxisExtent: compact ? 220 : 232,
                  child: _ScrollReveal(
                    scrollProgress: _scrollProgress,
                    child: BentoCard(
                      icon: _lucideClipboard,
                      title: strings.assignmentsTitle,
                      subtitle: strings.assignmentsSubtitle,
                      onTap: widget.onOpenAssignments,
                      accent: const Color(0xFF49D7C8),
                      actionLabel: isVietnamese ? 'XEM NHIỆM VỤ' : 'VIEW TASKS',
                    ),
                  ),
                ),
                StaggeredGridTile.extent(
                  crossAxisCellCount: 1,
                  mainAxisExtent: compact ? 220 : 232,
                  child: _ScrollReveal(
                    scrollProgress: _scrollProgress,
                    child: BentoCard(
                      icon: _lucideCalendar,
                      title: strings.scheduleTitle,
                      subtitle: strings.scheduleSubtitle,
                      onTap: () =>
                          _showActionToast(context, strings.scheduleTitle),
                      accent: const Color(0xFFF4B860),
                      actionLabel: isVietnamese ? 'MỞ LỊCH' : 'OPEN SCHEDULE',
                    ),
                  ),
                ),
                StaggeredGridTile.extent(
                  crossAxisCellCount: 1,
                  mainAxisExtent: compact ? 220 : 232,
                  child: _ScrollReveal(
                    scrollProgress: _scrollProgress,
                    child: BentoCard(
                      icon: _lucideFolder,
                      title: strings.projectTitle,
                      subtitle: strings.projectSubtitle,
                      onTap: widget.onOpenProjectHub,
                      accent: const Color(0xFF61B6FF),
                      actionLabel: isVietnamese ? 'VÀO WORKSPACE' : 'OPEN HUB',
                    ),
                  ),
                ),
              ];

              return SingleChildScrollView(
                key: const Key('dashboard-content-scroll'),
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  compact ? 8 : 18,
                  horizontalPadding,
                  46,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (desktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _HeroNewsTicker(
                                palette: palette,
                                userName: userName,
                                isVietnamese: isVietnamese,
                                compact: compact,
                                onOpenVirtualLab: widget.onOpenVirtualLab,
                                onOpenAssignments: widget.onOpenAssignments,
                              ),
                            ),
                            const Gap(16),
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 340,
                                child: _QuickStartPanel(
                                  palette: palette,
                                  isVietnamese: isVietnamese,
                                  workspaceTitle: strings.otherAppsTitle,
                                  workspaceSubtitle: strings.appHubSubtitle,
                                  onOpenVirtualLab: widget.onOpenVirtualLab,
                                  onOpenAssignments: widget.onOpenAssignments,
                                  onOpenProjectHub: widget.onOpenProjectHub,
                                  onOpenAppHub: onOpenAppHub,
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _HeroNewsTicker(
                          palette: palette,
                          userName: userName,
                          isVietnamese: isVietnamese,
                          compact: compact,
                          onOpenVirtualLab: widget.onOpenVirtualLab,
                          onOpenAssignments: widget.onOpenAssignments,
                        ),
                        const Gap(14),
                        _QuickStartPanel(
                          palette: palette,
                          isVietnamese: isVietnamese,
                          workspaceTitle: strings.otherAppsTitle,
                          workspaceSubtitle: strings.appHubSubtitle,
                          onOpenVirtualLab: widget.onOpenVirtualLab,
                          onOpenAssignments: widget.onOpenAssignments,
                          onOpenProjectHub: widget.onOpenProjectHub,
                          onOpenAppHub: onOpenAppHub,
                        ),
                      ],
                      const Gap(26),
                      _WorkspaceSectionHeader(
                        title: strings.quickWorkspace,
                        subtitle: isVietnamese
                            ? 'Chọn điểm đến cho phiên học của bạn'
                            : 'Choose a destination for your study session',
                        palette: palette,
                        indexLabel: '01 — 04',
                      ),
                      const Gap(14),
                      SizedBox(
                        width: double.infinity,
                        child: StaggeredGrid.count(
                          crossAxisCount: columns,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          children: modules,
                        ),
                      ),
                      const Gap(26),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showActionToast(BuildContext context, String message) {
    ToastService.showInfo(message);
  }
}

// ---------------------------------------------------------------------------
// _HeroNewsTicker
// ---------------------------------------------------------------------------

class _HeroNewsTicker extends StatefulWidget {
  const _HeroNewsTicker({
    required this.palette,
    required this.userName,
    required this.isVietnamese,
    required this.compact,
    required this.onOpenVirtualLab,
    required this.onOpenAssignments,
  });

  final AstatinePalette palette;
  final String userName;
  final bool isVietnamese;
  final bool compact;
  final VoidCallback onOpenVirtualLab;
  final VoidCallback onOpenAssignments;

  @override
  State<_HeroNewsTicker> createState() => _HeroNewsTickerState();
}

class _HeroNewsTickerState extends State<_HeroNewsTicker> {
  static const _interval = Duration(milliseconds: 3500);
  static const _rssUrl = 'https://vnexpress.net/rss/khoa-hoc-cong-nghe.rss';

  final _ctrl = PageController();
  Timer? _timer;
  int _page = 0;
  List<NewsFeedArticle> _articles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final resp = await http
          .get(Uri.parse(_rssUrl), headers: {'Accept': 'application/rss+xml'})
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final body = utf8.decode(resp.bodyBytes, allowMalformed: true);
        _articles = parseNewsFeedRss(body);
      } else {
        debugPrint(
          'Unable to load dashboard articles: HTTP ${resp.statusCode}',
        );
      }
    } catch (error) {
      debugPrint('Unable to load dashboard articles: $error');
    }
    if (mounted) {
      setState(() {
        _loading = false;
        if (_articles.isNotEmpty) _page = 1;
      });
      if (_articles.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _ctrl.hasClients) _ctrl.jumpToPage(1);
        });
      }
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final pageCount = 1 + _articles.length;
    if (pageCount < 2) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final next = (_page + 1) % pageCount;
      _ctrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final isVi = widget.isVietnamese;
    final compact = widget.compact;
    final name = widget.userName.isNotEmpty
        ? widget.userName
        : (isVi ? 'bạn' : 'there');

    final now = DateTime.now();
    final hour = now.hour;
    final greeting = isVi
        ? (hour < 12
              ? 'Chào buổi sáng'
              : hour < 18
              ? 'Chào buổi chiều'
              : 'Chào buổi tối')
        : (hour < 12
              ? 'Good morning'
              : hour < 18
              ? 'Good afternoon'
              : 'Good evening');

    final pageCount = 1 + _articles.length;

    return Container(
      height: compact ? 432 : 340,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.10),
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: palette.accent.withValues(
              alpha: palette.glowEnabled ? 0.24 : 0.10,
            ),
            blurRadius: palette.glowEnabled ? 32 : 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              PageView.builder(
                controller: _ctrl,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pageCount,
                onPageChanged: (pg) {
                  if (!mounted) return;
                  setState(() => _page = pg);
                },
                itemBuilder: (ctx, idx) {
                  if (idx == 0) {
                    return _HeroWelcomePage(
                      palette: palette,
                      name: name,
                      greeting: greeting,
                      isVietnamese: isVi,
                      compact: compact,
                      onOpenVirtualLab: widget.onOpenVirtualLab,
                      onOpenAssignments: widget.onOpenAssignments,
                    );
                  }
                  final article = _articles[idx - 1];
                  return _HeroArticlePage(
                    palette: palette,
                    article: article,
                    isVietnamese: isVi,
                    compact: compact,
                    index: idx,
                    total: _articles.length,
                  );
                },
              ),
              if (pageCount > 1)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pageCount, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? palette.accent
                              : palette.accent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              if (_loading)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Semantics(
                          label: isVi ? 'Đang tải tin tức' : 'Loading news',
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: palette.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── page 0: hero welcome ─────────────────────────────────────────────────────
class _HeroWelcomePage extends StatelessWidget {
  const _HeroWelcomePage({
    required this.palette,
    required this.name,
    required this.greeting,
    required this.isVietnamese,
    required this.compact,
    required this.onOpenVirtualLab,
    required this.onOpenAssignments,
  });

  final AstatinePalette palette;
  final String name;
  final String greeting;
  final bool isVietnamese;
  final bool compact;
  final VoidCallback onOpenVirtualLab;
  final VoidCallback onOpenAssignments;

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty
        ? (isVietnamese ? 'bạn' : 'there')
        : name.trim();
    final greetingCopy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: palette.accent),
              const Gap(7),
              Text(
                'ASTATINE EDU 2.0',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        Text(
          greeting,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: palette.secondaryText,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 15 : 17,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const Gap(3),
        Text(
          '$displayName!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: palette.primaryText,
            fontWeight: FontWeight.w900,
            fontSize: compact ? 24 : 28,
            height: 1.12,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const Gap(7),
        Text(
          isVietnamese
              ? 'Sẵn sàng cho một phiên học tuyệt vời hôm nay?'
              : 'Ready for an amazing study session today?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: palette.secondaryText,
            fontSize: compact ? 13 : 14,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    final actions = Wrap(
      spacing: 9,
      runSpacing: 8,
      children: [
        _HeroButton(
          label: isVietnamese ? 'Mở phòng thí nghiệm' : 'Open lab',
          icon: Icons.science_rounded,
          accent: palette.accent,
          filled: true,
          onTap: onOpenVirtualLab,
        ),
        _HeroButton(
          label: isVietnamese ? 'Xem nhiệm vụ' : 'View tasks',
          icon: Icons.task_alt_rounded,
          accent: palette.accent,
          filled: false,
          onTap: onOpenAssignments,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 640;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 26,
            compact ? 18 : 22,
            compact ? 18 : 26,
            compact ? 18 : 22,
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    greetingCopy,
                    const Gap(12),
                    actions,
                    const Gap(12),
                    SizedBox(
                      height: 124,
                      child: const _WelcomeNoteIllustration(),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [greetingCopy, const Spacer(), actions],
                      ),
                    ),
                    const Gap(20),
                    SizedBox(
                      width: (constraints.maxWidth * 0.34)
                          .clamp(224.0, 290.0)
                          .toDouble(),
                      child: const _WelcomeNoteIllustration(),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _WelcomeNoteIllustration extends StatelessWidget {
  const _WelcomeNoteIllustration();

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    return Container(
      key: const Key('welcome-note-illustration'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.accent.withValues(alpha: 0.2),
            palette.accent.withValues(alpha: 0.08),
            palette.card,
          ],
        ),
        border: Border.all(color: palette.accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widthScale = constraints.maxWidth / 220;
          final heightScale = constraints.maxHeight / 190;
          final scale = (widthScale < heightScale ? widthScale : heightScale)
              .clamp(0.1, 1.25)
              .toDouble();
          return ExcludeSemantics(
            child: Center(
              child: SizedBox(
                width: 220 * scale,
                height: 190 * scale,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 48 * scale,
                      top: 14 * scale,
                      child: Transform.rotate(
                        angle: -0.055,
                        child: _CartoonNote(scale: scale, palette: palette),
                      ),
                    ),
                    Positioned(
                      right: 25 * scale,
                      top: 20 * scale,
                      child: Transform.rotate(
                        angle: 0.32,
                        child: _CartoonPencil(scale: scale),
                      ),
                    ),
                    Positioned(
                      left: 22 * scale,
                      top: 132 * scale,
                      child: Transform.rotate(
                        angle: -0.24,
                        child: _CartoonEraser(scale: scale),
                      ),
                    ),
                    Positioned(
                      left: 26 * scale,
                      top: 27 * scale,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 18 * scale,
                        color: palette.accent,
                      ),
                    ),
                    Positioned(
                      right: 19 * scale,
                      bottom: 17 * scale,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 13 * scale,
                        color: const Color(0xFFF0A64A),
                      ),
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

class _CartoonNote extends StatelessWidget {
  const _CartoonNote({required this.scale, required this.palette});

  final double scale;
  final AstatinePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122 * scale,
      height: 158 * scale,
      padding: EdgeInsets.fromLTRB(
        21 * scale,
        22 * scale,
        13 * scale,
        15 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: const Color(0xFFE7C982), width: 1.5 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8 * scale,
            offset: Offset(3 * scale, 5 * scale),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              for (final lineWidth in [0.86, 1.0, 0.72, 0.92, 0.62])
                Padding(
                  padding: EdgeInsets.only(bottom: 15 * scale),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 75 * scale * lineWidth,
                      height: 3 * scale,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB9C7D8),
                        borderRadius: BorderRadius.circular(4 * scale),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < 5; i++)
                  Container(
                    width: 4 * scale,
                    height: 4 * scale,
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 2 * scale,
            bottom: 3 * scale,
            child: Icon(
              Icons.favorite_rounded,
              size: 13 * scale,
              color: const Color(0xFFF08E91),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartoonPencil extends StatelessWidget {
  const _CartoonPencil({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22 * scale,
      height: 142 * scale,
      child: Column(
        children: [
          Container(
            width: 22 * scale,
            height: 19 * scale,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8F9C),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(8 * scale),
                bottom: Radius.circular(3 * scale),
              ),
              border: Border.all(
                color: const Color(0xFFC96978),
                width: 1.3 * scale,
              ),
            ),
          ),
          Container(
            width: 22 * scale,
            height: 7 * scale,
            decoration: BoxDecoration(
              color: const Color(0xFFB9BEC9),
              border: Border.all(
                color: const Color(0xFF858B98),
                width: 1 * scale,
              ),
            ),
          ),
          Container(
            width: 18 * scale,
            height: 91 * scale,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC94F),
              border: Border.symmetric(
                vertical: BorderSide(
                  color: const Color(0xFFD9952D),
                  width: 1.2 * scale,
                ),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 3 * scale,
                color: const Color(0xFFFFE18B),
              ),
            ),
          ),
          CustomPaint(
            size: Size(18 * scale, 25 * scale),
            painter: const _PencilTipPainter(),
          ),
        ],
      ),
    );
  }
}

class _PencilTipPainter extends CustomPainter {
  const _PencilTipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final woodPaint = Paint()..color = const Color(0xFFE8B67A);
    final tipPaint = Paint()..color = const Color(0xFF45404A);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, woodPaint);
    final tip = Path()
      ..moveTo(size.width * 0.38, size.height * 0.76)
      ..lineTo(size.width * 0.62, size.height * 0.76)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(tip, tipPaint);
  }

  @override
  bool shouldRepaint(covariant _PencilTipPainter oldDelegate) => false;
}

class _CartoonEraser extends StatelessWidget {
  const _CartoonEraser({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 35 * scale,
      height: 23 * scale,
      decoration: BoxDecoration(
        color: const Color(0xFFFFA7B2),
        borderRadius: BorderRadius.circular(7 * scale),
        border: Border.all(color: const Color(0xFFD87886), width: 1.5 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4 * scale,
            offset: Offset(1 * scale, 3 * scale),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 9 * scale,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD5D6),
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(6 * scale),
            ),
          ),
        ),
      ),
    );
  }
}

// ── page 1..N: article ───────────────────────────────────────────────────────
class _HeroArticlePage extends StatefulWidget {
  const _HeroArticlePage({
    required this.palette,
    required this.article,
    required this.isVietnamese,
    required this.compact,
    required this.index,
    required this.total,
  });

  final AstatinePalette palette;
  final NewsFeedArticle article;
  final bool isVietnamese;
  final bool compact;
  final int index;
  final int total;

  @override
  State<_HeroArticlePage> createState() => _HeroArticlePageState();
}

class _HeroArticlePageState extends State<_HeroArticlePage> {
  @override
  Widget build(BuildContext context) {
    final pal = widget.palette;
    final art = widget.article;
    final isVi = widget.isVietnamese;
    final compact = widget.compact;
    final domain = Uri.tryParse(art.link)?.host ?? 'vnexpress.net';
    return Stack(
      fit: StackFit.expand,
      children: [
        NewsFeedCard(
          title: art.title,
          description: art.description,
          imageUrl: art.imageUrl,
          palette: pal,
          isVietnamese: isVi,
          borderRadius: BorderRadius.circular(22),
          contentBottomPadding: 34,
          onTap: () async {
            final uri = Uri.tryParse(art.link);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
        Positioned(
          top: compact ? 10 : 14,
          left: compact ? 12 : 16,
          right: compact ? 12 : 16,
          child: Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    domain.replaceFirst('www.', '').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFB8F7FF),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.index} / ${widget.total}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFB8F7FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── hero button ──────────────────────────────────────────────────────────────
class _HeroButton extends StatefulWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  @override
  State<_HeroButton> createState() => _HeroButtonState();
}

class _HeroButtonState extends State<_HeroButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: widget.filled
              ? (_hovered
                    ? widget.accent
                    : widget.accent.withValues(alpha: 0.88))
              : widget.accent.withValues(alpha: _hovered ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(13),
          border: widget.filled
              ? null
              : Border.all(color: widget.accent.withValues(alpha: 0.30)),
          boxShadow: widget.filled
              ? [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.18),
                    blurRadius: _hovered ? 16 : 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(13),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 16,
                      color: widget.filled ? Colors.black : widget.accent,
                    ),
                    const Gap(7),
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: widget.filled
                                  ? Colors.black
                                  : widget.accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.2,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── bento card scroll reveal ────────────────────────────────────────────────
class _ScrollReveal extends StatefulWidget {
  const _ScrollReveal({required this.scrollProgress, required this.child});

  final ValueListenable<double> scrollProgress;
  final Widget child;

  @override
  State<_ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<_ScrollReveal> {
  final GlobalKey _childKey = GlobalKey();
  double? _initialTop;
  double _initialScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = _childKey.currentContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        _initialTop = renderObject.localToGlobal(Offset.zero).dy;
        _initialScrollOffset = widget.scrollProgress.value;
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.scrollProgress,
    builder: (context, child) {
      final renderObject = _childKey.currentContext?.findRenderObject();
      final box = renderObject is RenderBox ? renderObject : null;
      final top = _initialTop == null
          ? box?.localToGlobal(Offset.zero).dy ?? 0
          : _initialTop! - (widget.scrollProgress.value - _initialScrollOffset);
      final viewportHeight = MediaQuery.sizeOf(context).height;
      final revealRange = viewportHeight * 0.48;
      final progress = ((viewportHeight * 1.35 - top) / revealRange).clamp(
        0.0,
        1.0,
      );
      return Opacity(
        opacity: 0.18 + progress * 0.82,
        child: Transform.scale(
          alignment: Alignment.bottomCenter,
          scale: 0.94 + progress * 0.06,
          child: RepaintBoundary(key: _childKey, child: child),
        ),
      );
    },
    child: widget.child,
  );
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop({required this.palette});

  final AstatinePalette palette;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      key: const Key('dashboard-grid-backdrop'),
      foregroundPainter: _DashboardGridPainter(
        lineColor: Color.lerp(palette.background, palette.border, 0.48)!,
      ),
      child: ColoredBox(color: palette.background),
    ),
  );
}

class _DashboardGridPainter extends CustomPainter {
  const _DashboardGridPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 32.0;
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.7;

    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashboardGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}

class _QuickStartPanel extends StatelessWidget {
  const _QuickStartPanel({
    required this.palette,
    required this.isVietnamese,
    required this.workspaceTitle,
    required this.workspaceSubtitle,
    required this.onOpenVirtualLab,
    required this.onOpenAssignments,
    required this.onOpenProjectHub,
    required this.onOpenAppHub,
  });

  final AstatinePalette palette;
  final bool isVietnamese;
  final String workspaceTitle;
  final String workspaceSubtitle;
  final VoidCallback onOpenVirtualLab;
  final VoidCallback onOpenAssignments;
  final VoidCallback onOpenProjectHub;
  final VoidCallback onOpenAppHub;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: _lucideFlask,
        title: isVietnamese ? 'Khám phá phòng lab' : 'Explore the lab',
        subtitle: isVietnamese
            ? 'Thí nghiệm tương tác'
            : 'Interactive experiments',
        color: const Color(0xFF4F46E5),
        onTap: onOpenVirtualLab,
      ),
      (
        icon: _lucideClipboard,
        title: isVietnamese ? 'Ôn tập & bài tập' : 'Review & assignments',
        subtitle: isVietnamese ? 'Tiếp tục nhiệm vụ' : 'Pick up your tasks',
        color: const Color(0xFFEA580C),
        onTap: onOpenAssignments,
      ),
      (
        icon: _lucideFolder,
        title: isVietnamese ? 'Dự án nhóm' : 'Group projects',
        subtitle: isVietnamese
            ? 'Cùng nhau tạo sản phẩm'
            : 'Build something together',
        color: const Color(0xFF0F766E),
        onTap: onOpenProjectHub,
      ),
      (
        icon: _lucideSparkles,
        title: workspaceTitle,
        subtitle: workspaceSubtitle,
        color: const Color(0xFF7C3AED),
        onTap: onOpenAppHub,
      ),
    ];

    return Container(
      key: const Key('dashboard-quick-start'),
      constraints: const BoxConstraints(minHeight: 340),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.1),
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: palette.accent,
                  size: 19,
                ),
              ),
              const Gap(10),
              Expanded(
                child: Text(
                  isVietnamese ? 'BẮT ĐẦU NHANH' : 'QUICK START',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.secondaryText,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const Gap(6),
          Text(
            isVietnamese
                ? 'Bạn muốn học gì hôm nay?'
                : 'What would you like to learn?',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: palette.primaryText, fontSize: 17),
          ),
          const Gap(6),
          for (final action in actions)
            _QuickStartAction(
              icon: action.icon,
              title: action.title,
              subtitle: action.subtitle,
              color: action.color,
              onTap: action.onTap,
            ),
        ],
      ),
    );
  }
}

class _QuickStartAction extends StatelessWidget {
  const _QuickStartAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.secondaryText),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: color, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceSectionHeader extends StatelessWidget {
  const _WorkspaceSectionHeader({
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.indexLabel,
  });

  final String title;
  final String subtitle;
  final AstatinePalette palette;
  final String indexLabel;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 4,
        height: 36,
        decoration: BoxDecoration(
          color: palette.accent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.44),
              blurRadius: 12,
            ),
          ],
        ),
      ),
      const Gap(13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: palette.canvasText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.secondaryText),
            ),
          ],
        ),
      ),
      Text(
        indexLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: palette.accent.withValues(alpha: 0.72),
          letterSpacing: 1,
        ),
      ),
    ],
  );
}

class BentoCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;
  final bool featured;
  final String actionLabel;

  const BentoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = const Color(0xFF00F2FE),
    this.featured = false,
    this.actionLabel = 'OPEN MODULE',
  });

  @override
  State<BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<BentoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    final accent = widget.accent;
    return MouseRegion(
      cursor: SystemMouseCursors.none,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.012 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Material(
          color: palette.card,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            mouseCursor: SystemMouseCursors.none,
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(22),
            hoverColor: accent.withValues(alpha: 0.07),
            child: HoverRipple(
              borderRadius: BorderRadius.circular(22),
              color: accent,
              child: Container(
                constraints: BoxConstraints(
                  minHeight: widget.featured ? 210 : 148,
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _hovered
                        ? accent.withValues(alpha: 0.8)
                        : palette.border,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: _hovered ? 0.2 : 0.1),
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: widget.featured ? 44 : 42,
                          height: widget.featured ? 44 : 42,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(widget.icon, color: accent, size: 22),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _hovered
                                ? accent.withValues(alpha: 0.14)
                                : palette.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _lucideArrowUpRight,
                            color: accent,
                            size: 15,
                          ),
                        ),
                      ],
                    ),
                    const Gap(6),
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: widget.featured ? 23 : 19,
                        color: palette.primaryText,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.secondaryText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.actionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.05,
                                ),
                          ),
                        ),
                        const Gap(8),
                        Icon(
                          _lucideArrowRight,
                          size: 13,
                          color: accent.withValues(alpha: 0.86),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
