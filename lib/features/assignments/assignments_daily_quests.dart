import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/notifications/toast.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/core/ui/hover_ripple.dart';
import 'package:astatine_dashboard/core/ui/loading_skeleton.dart';
import 'package:astatine_dashboard/core/ui/ui_motion.dart';

import 'assignment_data_service.dart';
import 'create_assignment_wizard.dart';
import 'student_exam_workspace.dart';
import 'teacher_class_analytics_screen.dart';

class AssignmentsDailyQuestsScreen extends StatefulWidget {
  const AssignmentsDailyQuestsScreen({
    super.key,
    required this.isVietnamese,
    this.languageCode,
    this.userRole = 'student',
    this.userName = 'An',
  });

  final bool isVietnamese;
  final String? languageCode;
  final String userRole;
  final String userName;

  @override
  State<AssignmentsDailyQuestsScreen> createState() =>
      _AssignmentsDailyQuestsScreenState();
}

class _AssignmentsDailyQuestsScreenState
    extends State<AssignmentsDailyQuestsScreen> {
  static const _gold = Color(0xFFFFB800);
  static const _success = Color(0xFF43D9A3);
  static const _emptyDashboard = AssignmentDashboardData(
    assignments: [],
    classrooms: [],
    quests: [],
    completedQuestIds: {},
    totalPoints: 0,
    claimedMilestones: [],
    chatChannelId: null,
    chatChannelName: null,
  );

  final _assignmentScrollController = ScrollController();
  AssignmentDataService? _dataService;
  AssignmentDashboardData? _dashboard;
  String? _loadError;
  String? _walletBalance;
  String? _astWalletBalance;
  bool _isLoading = true;
  bool _showCompleted = false;

  List<AssignmentRecord> get _pendingAssignments =>
      _dashboard?.pendingAssignments ?? const [];
  List<AssignmentRecord> get _completedAssignments =>
      _dashboard?.completedAssignments ?? const [];
  int get _activityPoints => _dashboard?.totalPoints ?? 0;

  AstatinePalette get _palette =>
      Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;

  String get _languageCode =>
      widget.languageCode ?? (widget.isVietnamese ? 'vi' : 'en');

  bool get _isTeacher =>
      const {'teacher', 'developer'}.contains(widget.userRole.toLowerCase());

  String _text(String vietnamese, String english) => _languageCode == 'zh'
      ? AppLocalizations.translateInline(english, languageCode: _languageCode)
      : widget.isVietnamese
      ? vietnamese
      : english;

  String get _formattedWallet => (_walletBalance?.toString() ?? '—')
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  String get _formattedAstWallet {
    final balance = _astWalletBalance;
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

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    if (widget.userRole.toLowerCase() == 'guest') {
      setState(() {
        _dashboard = _emptyDashboard;
        _isLoading = false;
      });
      return;
    }

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() {
          _loadError = _text(
            'Vui lòng đăng nhập để xem bài tập.',
            'Sign in to view assignments.',
          );
          _isLoading = false;
        });
        return;
      }

      final service = _dataService ??= AssignmentDataService(client);
      final dashboard = await service.loadDashboard();
      final wallet = await client
          .from('user_wallets')
          .select('isotope_coin_balance, ast_balance')
          .eq('user_id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _walletBalance = wallet?['isotope_coin_balance']?.toString();
        _astWalletBalance = wallet?['ast_balance']?.toString();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      debugPrint('Failed to load assignments dashboard: $error');
      setState(() {
        _loadError = switch (error) {
          AuthException() => _text(
            'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
            'Your session has expired. Please sign in again.',
          ),
          PostgrestException() => _text(
            'Không thể tải bài tập. Vui lòng thử lại.',
            'Unable to load assignments. Please try again.',
          ),
          _ => _text(
            'Đã xảy ra lỗi khi tải bài tập. Vui lòng thử lại.',
            'An error occurred while loading assignments. Please try again.',
          ),
        };
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _assignmentScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 960;
        return Padding(
              padding: EdgeInsets.all(compact ? 12 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPageHeader(constraints.maxWidth),
                  const Gap(12),
                  _buildActivityProgress(),
                  const Gap(10),
                  Expanded(child: _buildAssignmentsPanel()),
                ],
              ),
            )
            .animate()
            .fadeIn(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
            )
            .slideY(begin: 0.02, duration: const Duration(milliseconds: 420));
      },
    );
  }

  Widget _buildPageHeader(double width) {
    final classroomName = _dashboard?.classrooms.firstOrNull?.name;
    final now = DateTime.now();
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _text('BÀI TẬP', 'ASSIGNMENTS'),
          style: TextStyle(
            color: _palette.secondaryText,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          classroomName == null || classroomName.isEmpty
              ? _text('Chưa tham gia lớp học', 'No class selected')
              : '${_text('Lớp', 'Class')} $classroomName · ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}',
          style: TextStyle(color: _palette.canvasMutedText, fontSize: 10),
        ),
      ],
    );
    final coinWallet = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_outlined, color: _gold, size: 19),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COIN WALLET',
                style: TextStyle(
                  color: _gold.withValues(alpha: 0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '$_formattedWallet Coin',
                style: const TextStyle(
                  color: _gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final astWallet = Container(
      key: const Key('ast-wallet-balance'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: _success,
            size: 19,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AST WALLET',
                style: TextStyle(
                  color: _success.withValues(alpha: 0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '$_formattedAstWallet AST',
                style: const TextStyle(
                  color: _success,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final wallets = Row(
      mainAxisSize: MainAxisSize.min,
      children: [coinWallet, const SizedBox(width: 8), astWallet],
    );

    if (width < 500) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Align(alignment: Alignment.centerRight, child: wallets),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 12),
        wallets,
      ],
    );
  }

  Widget _buildActivityProgress() {
    return Container(
      key: const Key('daily-activity-progress'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _palette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _palette.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: _palette.accent, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _text('Hoạt động hôm nay', 'Daily activity'),
                  style: TextStyle(
                    color: _palette.canvasText,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$_activityPoints / 100 ${_text('điểm', 'pts')}',
                style: TextStyle(
                  color: _palette.canvasMutedText,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_activityPoints / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: _palette.border.withValues(alpha: 0.65),
              valueColor: AlwaysStoppedAnimation(_palette.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsPanel() {
    final list = _showCompleted ? _completedAssignments : _pendingAssignments;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _text('Bài tập của bạn', 'Your assignments'),
                  style: TextStyle(
                    color: _palette.canvasText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isTeacher)
                TextButton.icon(
                  onPressed: _createQuiz,
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: Text(
                    _text('Giao bài tập', 'Assign work'),
                    style: const TextStyle(fontSize: 10),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _palette.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              if (_isTeacher) const SizedBox(width: 2),
              IconButton(
                tooltip: _text('Làm mới bài tập', 'Refresh assignments'),
                onPressed: _isLoading ? null : _loadDashboard,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: _palette.canvasMutedText,
                  size: 17,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _statusTab(
                label: _text('Đang chờ', 'Pending'),
                count: _pendingAssignments.length,
                selected: !_showCompleted,
                onTap: () => setState(() => _showCompleted = false),
              ),
              const SizedBox(width: 6),
              _statusTab(
                label: _text('Hoàn thành', 'Completed'),
                count: _completedAssignments.length,
                selected: _showCompleted,
                onTap: () => setState(() => _showCompleted = true),
              ),
              const Spacer(),
              if (!_showCompleted)
                Text(
                  _text('Sắp đến hạn', 'Due soon'),
                  style: TextStyle(
                    color: _palette.canvasMutedText,
                    fontSize: 9,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildAssignmentList(list)),
        ],
      ),
    );
  }

  Widget _statusTab({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: selected
          ? _palette.canvasText
          : _palette.canvasMutedText,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: selected
                ? _palette.accent.withValues(alpha: 0.15)
                : _palette.input,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: selected ? _palette.accent : _palette.canvasMutedText,
              fontSize: 9,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildAssignmentList(List<AssignmentRecord> assignments) {
    if (_isLoading) {
      return AssignmentCardsSkeleton(
        label: _text('Đang tải bài tập', 'Loading assignments'),
      );
    }
    if (_loadError != null) {
      return _emptyState(
        icon: Icons.cloud_off_outlined,
        message: _languageCode == 'zh'
            ? AppLocalizations.t('errors.unexpected', languageCode: 'zh')
            : _loadError!,
        action: _text('Thử tải lại', 'Retry'),
        onAction: _loadDashboard,
      );
    }
    if (assignments.isEmpty) {
      return _emptyState(
        icon: _showCompleted
            ? Icons.task_alt_rounded
            : Icons.assignment_outlined,
        message: _showCompleted
            ? _text(
                'Chưa có bài tập đã hoàn thành.',
                'No completed assignments yet.',
              )
            : _text(
                'Hiện tại chưa có bài tập nào.',
                'There are no assignments right now.',
              ),
      );
    }

    return Scrollbar(
      controller: _assignmentScrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _assignmentScrollController,
        padding: const EdgeInsets.only(right: 6, bottom: 3),
        itemCount: assignments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _assignmentCard(
          assignments[index],
          completed: assignments[index].isCompleted,
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String message,
    String? action,
    VoidCallback? onAction,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _palette.canvasMutedText, size: 25),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: _palette.canvasMutedText, fontSize: 11),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(action)),
          ],
        ],
      ),
    ),
  );

  Widget _assignmentCard(
    AssignmentRecord assignment, {
    required bool completed,
  }) {
    final subjectColor = _subjectColor(assignment.subject);
    final submission = assignment.submission;
    final canViewAnalytics =
        const {
          'teacher',
          'developer',
        }.contains(widget.userRole.toLowerCase()) &&
        Supabase.instance.client.auth.currentUser?.id == assignment.teacherId;
    final VoidCallback? onCardTap = canViewAnalytics
        ? () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => TeacherClassAnalyticsScreen(
                assignmentId: assignment.id,
                languageCode: _languageCode,
              ),
            ),
          )
        : completed
        ? null
        : () => _startQuiz(assignment);
    final answeredCount = submission?['answered_count'];
    final totalQuestions =
        submission?['total_questions'] ?? assignment.questionCount;
    final submissionSummary = answeredCount == null
        ? _text(
            'Đã nộp · ${submission?['score'] ?? 0}/$totalQuestions',
            'Submitted · ${submission?['score'] ?? 0}/$totalQuestions',
          )
        : _text(
            'Đã nộp · $answeredCount/$totalQuestions câu đã làm',
            'Submitted · $answeredCount/$totalQuestions answered',
          );
    final card = Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _palette.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _palette.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: subjectColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: subjectColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        assignment.subject,
                        style: TextStyle(
                          color: subjectColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      assignment.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _palette.canvasText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+${assignment.coinReward} Coin',
                style: const TextStyle(
                  color: _gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _meta(
                Icons.quiz_outlined,
                '${assignment.questionCount} ${_text('câu hỏi', 'questions')}',
              ),
              _meta(Icons.person_outline_rounded, assignment.teacherName),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                completed ? Icons.check_circle_outline : Icons.timer_outlined,
                color: completed ? _success : const Color(0xFFFF8C86),
                size: 13,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  completed
                      ? _languageCode == 'zh'
                            ? '已提交 · ${submission?['score'] ?? answeredCount ?? 0}/$totalQuestions'
                            : submissionSummary
                      : _formatDue(assignment.dueAt),
                  style: TextStyle(
                    color: completed ? _success : const Color(0xFFFFA09A),
                    fontSize: 9,
                  ),
                ),
              ),
              if (completed && !canViewAnalytics)
                Text(
                  _text('Đã nhận Coin', 'Coin earned'),
                  style: const TextStyle(color: _success, fontSize: 9),
                )
              else if (onCardTap != null)
                Tooltip(
                  message: canViewAnalytics
                      ? _text('Xem phân tích', 'View analytics')
                      : _text('Bấm để bắt đầu làm bài', 'Open quiz'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _palette.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      canViewAnalytics
                          ? Icons.analytics_outlined
                          : Icons.arrow_forward_rounded,
                      color: _palette.accent,
                      size: 15,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    if (onCardTap == null) return card;

    return HoverLift(
      scale: 1.015,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onCardTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: _palette.accent.withValues(alpha: 0.035),
          child: HoverRipple(
            borderRadius: BorderRadius.circular(8),
            color: _palette.accent,
            child: card,
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: _palette.canvasMutedText),
      const SizedBox(width: 3),
      Text(
        label,
        style: TextStyle(color: _palette.canvasMutedText, fontSize: 9),
      ),
    ],
  );

  Color _subjectColor(String subject) {
    final normalized = subject.toLowerCase();
    if (normalized.contains('phys')) return const Color(0xFF9B8CFF);
    if (normalized.contains('math')) return _gold;
    if (normalized.contains('bio')) return _success;
    return _palette.accent;
  }

  String _formatDue(DateTime? dueAt) {
    if (dueAt == null) return _text('Chưa có hạn nộp', 'No due date');
    final difference = dueAt.difference(DateTime.now());
    if (difference.isNegative) return _text('Đã quá hạn', 'Past due');
    if (difference.inDays > 0) {
      if (_languageCode == 'zh') {
        return '剩余 ${difference.inDays} 天 ${difference.inHours.remainder(24)} 小时';
      }
      return '${_text('Còn', 'Due in')} ${difference.inDays}d ${difference.inHours.remainder(24).toString().padLeft(2, '0')}h';
    }
    if (_languageCode == 'zh') {
      return '剩余 ${difference.inHours.toString().padLeft(2, '0')}小时 ${difference.inMinutes.remainder(60).toString().padLeft(2, '0')}分';
    }
    return '${_text('Còn', 'Due in')} ${difference.inHours.toString().padLeft(2, '0')}:${difference.inMinutes.remainder(60).toString().padLeft(2, '0')}:${difference.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  Widget _panel({required Widget child, EdgeInsetsGeometry? padding}) =>
      Container(
        padding: padding ?? const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _palette.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _palette.border.withValues(alpha: 0.8)),
        ),
        child: child,
      );

  Future<void> _startQuiz(AssignmentRecord assignment) async {
    try {
      final service = _dataService ??= AssignmentDataService(
        Supabase.instance.client,
      );
      final questions = await service.fetchQuestions(assignment.id);
      if (!mounted) return;
      if (questions.isEmpty) {
        ToastService.showWarning(
          _text(
            'Bài tập này chưa có câu hỏi.',
            'This assignment has no questions yet.',
          ),
        );
        return;
      }

      final submitted = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          fullscreenDialog: true,
          builder: (_) => StudentExamWorkspace(
            assignment: assignment,
            questions: questions,
            service: service,
            languageCode: _languageCode,
          ),
        ),
      );
      if (submitted != true || !mounted) return;
      setState(() {
        _showCompleted = true;
      });
      await _loadDashboard();
      if (mounted) {
        ToastService.showSuccess(
          _text('Đã nộp bài thành công.', 'Assignment submitted successfully.'),
        );
      }
    } catch (error) {
      if (mounted) {
        ToastService.showError(
          _languageCode == 'zh'
              ? AppLocalizations.t('errors.unexpected', languageCode: 'zh')
              : error.toString(),
        );
      }
    }
  }

  Future<void> _createQuiz() async {
    final classrooms = _dashboard?.classrooms ?? const <AssignmentClassroom>[];
    if (classrooms.isEmpty) {
      ToastService.showWarning(
        _text('Bạn chưa thuộc lớp nào.', 'You are not assigned to a class.'),
      );
      return;
    }
    final service = _dataService ??= AssignmentDataService(
      Supabase.instance.client,
    );
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => CreateAssignmentWizard(
          service: service,
          classrooms: classrooms,
          isVietnamese: widget.isVietnamese,
          languageCode: _languageCode,
        ),
      ),
    );
    if (published == true && mounted) {
      setState(() => _showCompleted = false);
      await _loadDashboard();
      ToastService.showSuccess(
        _text('Đã giao bài tập.', 'Assignment published.'),
      );
    }
  }
}
