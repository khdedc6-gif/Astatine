import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';
import 'package:astatine_dashboard/core/ui/hover_ripple.dart';
import 'package:astatine_dashboard/features/profile/user_profile_avatar.dart';

class TeacherClassAnalyticsScreen extends StatefulWidget {
  const TeacherClassAnalyticsScreen({
    super.key,
    required this.assignmentId,
    this.languageCode = 'vi',
  });

  final String assignmentId;
  final String languageCode;

  @override
  State<TeacherClassAnalyticsScreen> createState() =>
      _TeacherClassAnalyticsScreenState();
}

class _TeacherClassAnalyticsScreenState
    extends State<TeacherClassAnalyticsScreen> {
  static const _cyan = Color(0xFF35D9E8);
  static const _green = Color(0xFF43D9A3);
  static const _red = Color(0xFFFF777D);
  static const _amber = Color(0xFFFFB800);

  final _searchController = TextEditingController();
  final _studentTableHorizontalController = ScrollController();
  final _studentTableVerticalController = ScrollController();
  Timer? _refreshTimer;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String _searchQuery = '';
  int _selectedFilter = 0;
  int _selectedTab = 0;
  String _assignmentTitle = '';
  String _subject = '';
  double _passingScore = 5;
  List<Map<String, dynamic>> _questions = const [];
  List<_AnalyticsStudent> _students = const [];

  bool get _isVietnamese => widget.languageCode == 'vi';
  AstatinePalette get _palette =>
      Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
  String _text(String vi, String en) => widget.languageCode == 'zh'
      ? AppLocalizations.translateInline(en, languageCode: 'zh')
      : _isVietnamese
      ? vi
      : en;

  int get _totalAssigned => _students.length;
  List<_AnalyticsStudent> get _completedStudents =>
      _students.where((student) => student.completed).toList();
  int get _completedCount => _completedStudents.length;
  int get _pendingCount => _totalAssigned - _completedCount;

  double get _completionRate =>
      _totalAssigned == 0 ? 0 : _completedCount * 100 / _totalAssigned;

  double get _totalQuestionPoints => _questions.fold<double>(
    0,
    (total, question) => total + _questionPoints(question),
  );

  double get _averageScore {
    final scores = _completedStudents
        .map(_scoreForStudent)
        .whereType<double>()
        .toList();
    if (scores.isEmpty) return 0;
    return scores.reduce((left, right) => left + right) / scores.length;
  }

  double get _averageTimeMinutes {
    final times = _completedStudents
        .map((student) => student.timeSpentSeconds)
        .whereType<int>()
        .toList();
    if (times.isEmpty) return 0;
    return times.reduce((left, right) => left + right) / times.length / 60;
  }

  double get _passRate {
    final scoredStudents = _completedStudents
        .where((student) => _scoreForStudent(student) != null)
        .toList();
    if (scoredStudents.isEmpty) return 0;
    final passed = scoredStudents
        .where((student) => _scoreForStudent(student)! >= _passingScore)
        .length;
    return passed * 100 / scoredStudents.length;
  }

  double? _scoreForStudent(_AnalyticsStudent student) {
    if (!student.completed || _questions.isEmpty || _totalQuestionPoints <= 0) {
      return null;
    }
    var earnedPoints = 0.0;
    for (var index = 0; index < _questions.length; index++) {
      final question = _questions[index];
      final answer = _answerForQuestion(student, question, index);
      if (_isCorrectAnswer(answer, question)) {
        earnedPoints += _questionPoints(question);
      }
    }
    return earnedPoints / _totalQuestionPoints * 10;
  }

  double _questionPoints(Map<String, dynamic> question) {
    final value = question['question_points'];
    final points = value is num ? value.toDouble() : double.tryParse('$value');
    return points != null && points > 0 ? points : 10;
  }

  String _formatPoints(double points) =>
      points.toStringAsFixed(points == points.roundToDouble() ? 0 : 1);

  List<_AnalyticsStudent> get _visibleStudents {
    final query = _searchQuery.trim().toLowerCase();
    return _students.where((student) {
      final matchesQuery =
          query.isEmpty || student.name.toLowerCase().contains(query);
      final matchesFilter = switch (_selectedFilter) {
        1 => student.completed,
        2 => !student.completed,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList()..sort((left, right) {
      if (left.completed != right.completed) {
        return left.completed ? -1 : 1;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
  }

  List<_TopicAnalytics> get _topicAnalytics {
    final topics = <String, _TopicTotals>{};
    for (var index = 0; index < _questions.length; index++) {
      final question = _questions[index];
      final questionId = question['id']?.toString();
      if (questionId == null) continue;
      final topic = _topicName(question);
      final totals = topics.putIfAbsent(topic, _TopicTotals.new);
      for (final student in _completedStudents) {
        final answer = _answerForQuestion(student, question, index);
        if (answer == null || answer.trim().isEmpty) continue;
        totals.attempts++;
        if (_isCorrectAnswer(answer, question)) totals.correct++;
      }
    }
    return topics.entries
        .where((entry) => entry.value.attempts > 0)
        .map(
          (entry) => _TopicAnalytics(
            name: entry.key,
            correct: entry.value.correct,
            attempts: entry.value.attempts,
          ),
        )
        .toList()
      ..sort((left, right) => left.rate.compareTo(right.rate));
  }

  List<_TopicAnalytics> get _strengths =>
      _topicAnalytics.where((topic) => topic.rate >= 75).toList()
        ..sort((left, right) => right.rate.compareTo(left.rate));
  List<_TopicAnalytics> get _weaknesses =>
      _topicAnalytics.where((topic) => topic.rate < 50).toList();

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_loading) _loadAnalytics(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _studentTableHorizontalController.dispose();
    _studentTableVerticalController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics({bool showLoading = true}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final client = Supabase.instance.client;
      final assignment = await client
          .from('assignments')
          .select('id, title, subject, passing_score')
          .eq('id', widget.assignmentId)
          .single();

      final questionRows = await client
          .from('questions')
          .select('id, question_text, question_points, correct_option, options')
          .eq('assignment_id', widget.assignmentId)
          .order('order_num');

      final response = await client
          .from('teacher_assignment_progress_view')
          .select(
            'student_id, student_name, submission_status, time_spent_seconds, submitted_at, answers',
          )
          .eq('assignment_id', widget.assignmentId);

      final students = response
          .map(
            (row) => _AnalyticsStudent.fromRow(Map<String, dynamic>.from(row)),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _assignmentTitle = assignment['title']?.toString() ?? '';
        _subject = assignment['subject']?.toString() ?? '';
        _passingScore = (assignment['passing_score'] as num?)?.toDouble() ?? 5;
        _questions = questionRows
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _students = students;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    return Scaffold(
      backgroundColor: _palette.background,
      appBar: AppBar(
        backgroundColor: _palette.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: _text('Quay lại', 'Back'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_rounded, color: _palette.canvasText),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('PHÂN TÍCH LỚP HỌC', 'CLASS ANALYTICS'),
              style: TextStyle(
                color: _palette.canvasMutedText,
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _assignmentTitle.isEmpty
                  ? _text('Nhiệm vụ', 'Assignment')
                  : _assignmentTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _palette.canvasText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          if (_subject.isNotEmpty || _questions.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _cyan.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_subject.isEmpty ? _text('Nhiệm vụ', 'Assignment') : _subject} · ${_questions.length} ${_text('câu hỏi', 'questions')}',
                  style: const TextStyle(
                    color: _cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: _text('Làm mới dữ liệu', 'Refresh data'),
            onPressed: _loading ? null : () => _loadAnalytics(),
            icon: Icon(Icons.refresh_rounded, color: _palette.canvasMutedText),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Material(
        color: Colors.transparent,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : _buildContent(compact),
      ),
    );
  }

  Widget _buildError() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _red, size: 36),
            const SizedBox(height: 12),
            Text(
              _text(
                'Không tải được dữ liệu phân tích',
                'Could not load analytics',
              ),
              style: TextStyle(
                color: _palette.canvasText,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: _palette.canvasMutedText, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _loadAnalytics(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(_text('Thử lại', 'Retry')),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildContent(bool compact) => RefreshIndicator(
    onRefresh: () => _loadAnalytics(showLoading: false),
    child: ListView(
      padding: EdgeInsets.fromLTRB(compact ? 14 : 28, 8, compact ? 14 : 28, 26),
      children: [
        Wrap(
          spacing: 11,
          runSpacing: 11,
          children: [
            _metricCard(
              label: _text('TIẾN ĐỘ HOÀN THÀNH', 'COMPLETION'),
              value: '$_completedCount/$_totalAssigned',
              hint: '${_completionRate.toStringAsFixed(1)}%',
              icon: Icons.groups_rounded,
              color: _cyan,
            ),
            _metricCard(
              label: _text('ĐIỂM TRUNG BÌNH', 'CLASS AVERAGE'),
              value: '${_averageScore.toStringAsFixed(1)} / 10',
              hint: _text('Học sinh đã hoàn thành', 'Completed students'),
              icon: Icons.stacked_line_chart_rounded,
              color: _green,
            ),
            _metricCard(
              label: _text('THỜI GIAN TRUNG BÌNH', 'AVERAGE TIME'),
              value:
                  '${_averageTimeMinutes.toStringAsFixed(1)} ${_text('phút', 'min')}',
              hint: _text('Trên bài đã nộp', 'Across submitted work'),
              icon: Icons.timer_outlined,
              color: _amber,
            ),
            _metricCard(
              label: _text('TỶ LỆ ĐẠT', 'PASS RATE'),
              value: '${_passRate.toStringAsFixed(1)}%',
              hint: _text(
                'Điểm từ ${_passingScore.toStringAsFixed(1)} trở lên',
                'Score of ${_passingScore.toStringAsFixed(1)} or higher',
              ),
              icon: Icons.verified_rounded,
              color: _green,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: _palette.card,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _palette.border.withValues(alpha: 0.8)),
          ),
          child: Column(
            children: [
              _buildTabs(),
              Divider(height: 1, color: _palette.border.withValues(alpha: 0.7)),
              if (_selectedTab == 0)
                _buildProgressTab(compact)
              else
                _buildDiagnosticsTab(compact),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _metricCard({
    required String label,
    required String value,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width < 620
        ? (width - 39) / 2
        : width < 1050
        ? (width - 53) / 2
        : (width - 95) / 4;
    return SizedBox(
      width: cardWidth.clamp(150, 340),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _palette.border.withValues(alpha: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const Spacer(),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _palette.canvasMutedText,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              value,
              style: TextStyle(
                color: _palette.canvasText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: _palette.canvasMutedText,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 11, 16, 0),
    child: Row(
      children: [
        _tabButton(
          0,
          Icons.groups_outlined,
          _text('TIẾN ĐỘ HỌC SINH', 'STUDENT PROGRESS'),
        ),
        const SizedBox(width: 8),
        _tabButton(
          1,
          Icons.auto_awesome_outlined,
          _text('PHÂN TÍCH ĐIỂM MẠNH & ĐIỂM YẾU', 'STRENGTHS & WEAKNESSES'),
        ),
      ],
    ),
  );

  Widget _tabButton(int index, IconData icon, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? _cyan : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? _cyan : _palette.canvasMutedText,
              ),
              if (MediaQuery.sizeOf(context).width > 560) ...[
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _cyan : _palette.canvasMutedText,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressTab(bool compact) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchField(),
              const SizedBox(height: 10),
              _buildFilters(),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: _buildFilters()),
              const SizedBox(width: 14),
              SizedBox(width: 270, child: _buildSearchField()),
            ],
          ),
        const SizedBox(height: 14),
        if (_visibleStudents.isEmpty)
          _emptyProgressState()
        else
          _buildStudentRows(compact),
      ],
    ),
  );

  Widget _buildSearchField() => TextField(
    controller: _searchController,
    onChanged: (value) => setState(() => _searchQuery = value),
    style: TextStyle(color: _palette.canvasText, fontSize: 12),
    decoration: InputDecoration(
      hintText: _text('Tìm học sinh…', 'Search students…'),
      hintStyle: TextStyle(color: _palette.canvasMutedText, fontSize: 11),
      prefixIcon: Icon(
        Icons.search_rounded,
        color: _palette.canvasMutedText,
        size: 18,
      ),
      isDense: true,
      filled: true,
      fillColor: _palette.input,
      contentPadding: const EdgeInsets.symmetric(vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: _palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: _palette.border),
      ),
    ),
  );

  Widget _buildFilters() => Wrap(
    spacing: 7,
    runSpacing: 7,
    children: [
      _filterChip(0, _text('Tất cả', 'All'), _totalAssigned),
      _filterChip(1, _text('Đã hoàn thành', 'Completed'), _completedCount),
      _filterChip(2, _text('Chưa nộp', 'Pending'), _pendingCount),
    ],
  );

  Widget _filterChip(int index, String label, int count) {
    final selected = _selectedFilter == index;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _selectedFilter = index),
      label: GlideSelect(
        selected: selected,
        child: Text(
          '$label  $count',
          style: TextStyle(
            color: selected ? _cyan : _palette.canvasMutedText,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      backgroundColor: _palette.input,
      selectedColor: _cyan.withValues(alpha: 0.1),
      side: BorderSide(
        color: selected ? _cyan.withValues(alpha: 0.4) : _palette.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  Widget _buildStudentRows(bool compact) {
    final height = (MediaQuery.sizeOf(context).height - 430)
        .clamp(220, 620)
        .toDouble();
    if (compact) {
      return SizedBox(
        height: height,
        child: ListView.separated(
          itemCount: _visibleStudents.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _studentCard(_visibleStudents[index]),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(cardTheme: const CardThemeData(color: Colors.transparent)),
        child: Material(
          type: MaterialType.transparency,
          child: Scrollbar(
            controller: _studentTableHorizontalController,
            thumbVisibility: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _studentTableHorizontalController,
              scrollDirection: Axis.horizontal,
              child: Scrollbar(
                controller: _studentTableVerticalController,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.vertical,
                child: SingleChildScrollView(
                  controller: _studentTableVerticalController,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 970),
                    child: DataTable(
                      columnSpacing: 12,
                      horizontalMargin: 14,
                      headingRowHeight: 46,
                      dataRowMinHeight: 58,
                      dataRowMaxHeight: 58,
                      headingRowColor: WidgetStatePropertyAll(_palette.input),
                      dataRowColor: WidgetStatePropertyAll(_palette.card),
                      headingTextStyle: TextStyle(
                        color: _palette.canvasMutedText,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.65,
                      ),
                      dataTextStyle: TextStyle(
                        color: _palette.canvasText,
                        fontSize: 11,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _palette.border.withValues(alpha: 0.8),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: _palette.border.withValues(alpha: 0.55),
                        ),
                      ),
                      columns: [
                        DataColumn(label: Text(_text('HỌC SINH', 'STUDENT'))),
                        DataColumn(label: Text(_text('TRẠNG THÁI', 'STATUS'))),
                        DataColumn(label: Text(_text('ĐIỂM', 'SCORE'))),
                        DataColumn(
                          label: Text(_text('THỜI GIAN', 'TIME SPENT')),
                        ),
                        DataColumn(
                          label: Text(_text('ĐÃ NỘP LÚC', 'SUBMITTED AT')),
                        ),
                        const DataColumn(label: SizedBox.shrink()),
                      ],
                      rows: [
                        for (final student in _visibleStudents)
                          DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    _studentAvatar(student, 32),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        student.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _palette.canvasText,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(_statusBadge(student)),
                              DataCell(
                                Text(
                                  student.completed
                                      ? '${_scoreText(_scoreForStudent(student))} / 10'
                                      : '---',
                                  style: TextStyle(
                                    color: student.completed
                                        ? _palette.canvasText
                                        : _palette.canvasMutedText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  student.completed
                                      ? _formatDuration(
                                          student.timeSpentSeconds,
                                        )
                                      : '---',
                                  style: TextStyle(
                                    color: _palette.canvasMutedText,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatSubmittedTime(student.submittedAt),
                                  style: TextStyle(
                                    color: _palette.canvasMutedText,
                                  ),
                                ),
                              ),
                              DataCell(_studentAction(student)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _studentCard(_AnalyticsStudent student) => HoverRipple(
    borderRadius: BorderRadius.circular(10),
    color: _palette.accent,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _palette.input.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _palette.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _studentAvatar(student, 34),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  student.name,
                  style: TextStyle(
                    color: _palette.canvasText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _statusBadge(student),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              _mobileMetric(
                _text('Điểm', 'Score'),
                student.completed
                    ? '${_scoreText(_scoreForStudent(student))} / 10'
                    : '---',
              ),
              _mobileMetric(
                _text('Thời gian', 'Time'),
                student.completed
                    ? _formatDuration(student.timeSpentSeconds)
                    : '---',
              ),
              _mobileMetric(
                _text('Đã nộp', 'Submitted'),
                _formatSubmittedTime(student.submittedAt),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _studentAction(student),
          ),
        ],
      ),
    ),
  );

  Widget _mobileMetric(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: _palette.canvasMutedText, fontSize: 9),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _palette.canvasText,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _studentAvatar(_AnalyticsStudent student, double size) {
    final initials = student.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    return UserProfileAvatar(
      userId: student.id,
      radius: size / 2,
      fallbackText: initials.isEmpty ? '?' : initials,
      backgroundColor: _cyan.withValues(alpha: 0.14),
    );
  }

  Widget _statusBadge(_AnalyticsStudent student) {
    final color = student.completed ? _green : _red;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          student.completed
              ? _text('Đã hoàn thành', 'Completed')
              : _text('Chưa nộp', 'Pending'),
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _studentAction(_AnalyticsStudent student) {
    if (student.completed) {
      return TextButton.icon(
        onPressed: () => _showSubmissionDetails(student),
        icon: const Icon(Icons.visibility_outlined, size: 14),
        label: Text(_text('Xem bài làm', 'View submission')),
        style: TextButton.styleFrom(
          foregroundColor: _cyan,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return TextButton.icon(
      onPressed: () => _copyReminder(student),
      icon: const Icon(Icons.notifications_active_outlined, size: 14),
      label: Text(_text('Nhắc nhở', 'Remind')),
      style: TextButton.styleFrom(
        foregroundColor: _amber,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _copyReminder(_AnalyticsStudent student) async {
    final message = _text(
      'Chào ${student.name}, bạn vui lòng hoàn thành nhiệm vụ "$_assignmentTitle" nhé.',
      'Hi ${student.name}, please complete the assignment "$_assignmentTitle".',
    );
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _text(
              'Đã sao chép lời nhắc. Gửi lời nhắc qua kênh lớp học của bạn.',
              'Reminder copied. Send it through your classroom channel.',
            ),
          ),
        ),
      );
  }

  void _showSubmissionDetails(_AnalyticsStudent student) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: _palette.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _studentAvatar(student, 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: TextStyle(
                              color: _palette.canvasText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_text('Điểm', 'Score')}: ${_scoreText(_scoreForStudent(student))} / 10',
                            style: TextStyle(
                              color: _palette.canvasMutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: _palette.canvasMutedText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: _palette.border),
                Expanded(
                  child: _questions.isEmpty
                      ? Center(
                          child: Text(
                            _text(
                              'Nhiệm vụ chưa có câu hỏi.',
                              'No questions are available.',
                            ),
                            style: TextStyle(color: _palette.canvasMutedText),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _questions.length,
                          separatorBuilder: (_, _) => Divider(
                            color: _palette.border.withValues(alpha: 0.6),
                          ),
                          itemBuilder: (context, index) {
                            final question = _questions[index];
                            final answer = _answerForQuestion(
                              student,
                              question,
                              index,
                            );
                            final correct = _isCorrectAnswer(answer, question);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${index + 1}. ${question['question_text'] ?? ''}',
                                    style: TextStyle(
                                      color: _palette.canvasText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    '${_text('Câu trả lời', 'Answer')}: ${_answerDisplay(answer, question)}',
                                    style: TextStyle(
                                      color: answer == null
                                          ? _palette.canvasMutedText
                                          : correct
                                          ? _green
                                          : _red,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    '${_text('Điểm câu', 'Question points')}: ${correct ? _formatPoints(_questionPoints(question)) : '0'} / ${_formatPoints(_questionPoints(question))}',
                                    style: TextStyle(
                                      color: correct
                                          ? _green
                                          : _palette.canvasMutedText,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    '${_text('Đáp án đúng', 'Correct answer')}: ${_correctAnswerDisplay(question)}',
                                    style: TextStyle(
                                      color: _palette.canvasMutedText,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _emptyProgressState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42),
    child: Column(
      children: [
        Icon(
          Icons.person_search_rounded,
          color: _palette.canvasMutedText,
          size: 30,
        ),
        const SizedBox(height: 8),
        Text(
          _searchQuery.isEmpty
              ? _text(
                  'Chưa có học sinh được giao nhiệm vụ này.',
                  'No students are assigned to this work.',
                )
              : _text(
                  'Không tìm thấy học sinh phù hợp.',
                  'No matching students found.',
                ),
          textAlign: TextAlign.center,
          style: TextStyle(color: _palette.canvasMutedText, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _buildDiagnosticsTab(bool compact) {
    final topics = _topicAnalytics;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _text(
              'Phân tích được tính từ đáp án và đáp án đúng đã lưu trong nhiệm vụ.',
              'Analysis is computed from saved student answers and assignment answer keys.',
            ),
            style: TextStyle(color: _palette.canvasMutedText, fontSize: 11),
          ),
          const SizedBox(height: 17),
          if (topics.isEmpty)
            _emptyDiagnostics()
          else
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _topicPanel(
                  title: _text('ĐIỂM MẠNH', 'STRENGTHS'),
                  subtitle: _text(
                    'Tỷ lệ đúng từ 75% trở lên',
                    'Correct rate at least 75%',
                  ),
                  icon: Icons.trending_up_rounded,
                  color: _green,
                  topics: _strengths,
                  compact: compact,
                  emptyLabel: _text(
                    'Chưa có chủ đề đạt ngưỡng điểm mạnh.',
                    'No topics meet the strength threshold yet.',
                  ),
                ),
                _topicPanel(
                  title: _text('CẦN CẢI THIỆN', 'NEEDS IMPROVEMENT'),
                  subtitle: _text(
                    'Tỷ lệ đúng dưới 50%',
                    'Correct rate below 50%',
                  ),
                  icon: Icons.trending_down_rounded,
                  color: _red,
                  topics: _weaknesses,
                  compact: compact,
                  emptyLabel: _text(
                    'Không có chủ đề nào dưới ngưỡng 50%.',
                    'No topics are below the 50% threshold.',
                  ),
                ),
              ],
            ),
          if (topics.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              _text('TẤT CẢ CHỦ ĐỀ', 'ALL TOPICS'),
              style: TextStyle(
                color: _palette.canvasMutedText,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            for (final topic in topics.reversed) _topicProgressRow(topic),
          ],
        ],
      ),
    );
  }

  Widget _topicPanel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<_TopicAnalytics> topics,
    required bool compact,
    required String emptyLabel,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      width: compact ? double.infinity : (width - 105) / 2,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _palette.input.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _palette.border.withValues(alpha: 0.75)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 17),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: _palette.canvasMutedText, fontSize: 9),
            ),
            const SizedBox(height: 12),
            if (topics.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  emptyLabel,
                  style: TextStyle(
                    color: _palette.canvasMutedText,
                    fontSize: 10,
                  ),
                ),
              )
            else
              for (final topic in topics)
                _topicProgressRow(topic, color: color),
          ],
        ),
      ),
    );
  }

  Widget _topicProgressRow(_TopicAnalytics topic, {Color? color}) {
    final rateColor =
        color ??
        (topic.rate >= 75
            ? _green
            : topic.rate < 50
            ? _red
            : _amber);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  topic.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _palette.canvasText, fontSize: 10),
                ),
              ),
              Text(
                '${topic.rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: rateColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '${topic.correct}/${topic.attempts}',
                style: TextStyle(color: _palette.canvasMutedText, fontSize: 8),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (topic.rate / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: _palette.border.withValues(alpha: 0.45),
              valueColor: AlwaysStoppedAnimation(rateColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyDiagnostics() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Column(
      children: [
        Icon(Icons.insights_rounded, color: _palette.canvasMutedText, size: 32),
        const SizedBox(height: 9),
        Text(
          _completedCount == 0
              ? _text(
                  'Chưa có bài nộp để phân tích.',
                  'No submissions to analyze yet.',
                )
              : _text(
                  'Chưa có dữ liệu câu hỏi để phân tích.',
                  'Question data is not available for analysis.',
                ),
          style: TextStyle(color: _palette.canvasMutedText, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  String _topicName(Map<String, dynamic> question) {
    for (final key in const ['topic_name', 'topicName', 'topic', 'category']) {
      final value = question[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final questionText = question['question_text']?.toString().trim() ?? '';
    if (questionText.isNotEmpty) {
      return questionText.length > 52
          ? '${questionText.substring(0, 52)}…'
          : questionText;
    }
    final subject = _subject.trim();
    return subject.isNotEmpty ? subject : _text('Chủ đề khác', 'Other topics');
  }

  String? _answerForQuestion(
    _AnalyticsStudent student,
    Map<String, dynamic> question,
    int index,
  ) {
    final questionId = question['id']?.toString();
    return (questionId == null ? null : student.answers[questionId]) ??
        student.answers['q${index + 1}'] ??
        student.answers['${index + 1}'] ??
        student.answers['$index'];
  }

  bool _isCorrectAnswer(String? answer, Map<String, dynamic> question) {
    if (answer == null || answer.trim().isEmpty) return false;
    final correct = question['correct_option'];
    if (correct == null) return false;
    final answerValue = answer.trim();
    final optionsValue = question['options'];
    final options = optionsValue is List ? optionsValue : const <dynamic>[];

    final answerIndex = _optionIndex(answerValue, options);
    final correctIndex = _optionIndex(correct.toString(), options);
    if (answerIndex != null && correctIndex != null) {
      return answerIndex == correctIndex;
    }
    final normalizedAnswer = _normalizeAnswer(answerValue);
    final normalizedCorrect = _normalizeAnswer(
      correct is Map
          ? (correct['value'] ?? correct['text'] ?? correct['label'] ?? '')
                .toString()
          : correct.toString(),
    );
    return normalizedAnswer.isNotEmpty && normalizedAnswer == normalizedCorrect;
  }

  int? _optionIndex(String value, List<dynamic> options) {
    final normalized = value.trim();
    final numeric = int.tryParse(normalized);
    if (numeric != null && numeric >= 0 && numeric < options.length) {
      return numeric;
    }
    if (normalized.length == 1) {
      final code = normalized.toUpperCase().codeUnitAt(0) - 65;
      if (code >= 0 && code < options.length) return code;
    }
    for (var index = 0; index < options.length; index++) {
      final option = options[index];
      final values = option is Map
          ? [option['value'], option['text'], option['label']]
          : [option];
      if (values.any(
        (candidate) =>
            candidate != null &&
            _normalizeAnswer(candidate.toString()) ==
                _normalizeAnswer(normalized),
      )) {
        return index;
      }
    }
    return null;
  }

  String _normalizeAnswer(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  String _answerDisplay(String? answer, Map<String, dynamic> question) {
    if (answer == null || answer.trim().isEmpty) {
      return _text('Bỏ trống', 'Unanswered');
    }
    final options = question['options'];
    if (options is List) {
      final index = _optionIndex(answer, options);
      if (index != null && index < options.length) {
        return '${String.fromCharCode(65 + index)}. ${_optionLabel(options[index])}';
      }
    }
    return answer;
  }

  String _correctAnswerDisplay(Map<String, dynamic> question) {
    final correct = question['correct_option'];
    if (correct == null) return '---';
    final options = question['options'];
    if (options is List) {
      final index = _optionIndex(correct.toString(), options);
      if (index != null && index < options.length) {
        return '${String.fromCharCode(65 + index)}. ${_optionLabel(options[index])}';
      }
    }
    if (correct is Map) {
      return (correct['label'] ?? correct['text'] ?? correct['value'] ?? '---')
          .toString();
    }
    return correct.toString();
  }

  String _optionLabel(dynamic option) {
    if (option is Map) {
      return (option['label'] ?? option['text'] ?? option['value'] ?? '')
          .toString();
    }
    return option.toString();
  }

  String _scoreText(double? score) =>
      score == null ? '---' : score.toStringAsFixed(1);

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds < 0) return '---';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes}m ${remainder}s';
  }

  String _formatSubmittedTime(DateTime? timestamp) {
    if (timestamp == null) return '---';
    final local = timestamp.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final meridiem = local.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $meridiem';
  }
}

class _AnalyticsStudent {
  const _AnalyticsStudent({
    required this.id,
    required this.name,
    required this.status,
    required this.timeSpentSeconds,
    required this.submittedAt,
    required this.answers,
  });

  factory _AnalyticsStudent.fromRow(Map<String, dynamic> row) {
    final rawAnswers = row['answers'];
    final answers = rawAnswers is Map
        ? Map<String, dynamic>.from(rawAnswers)
              .map((key, value) => MapEntry(key, value?.toString() ?? ''))
        : <String, String>{};
    final rawTime = row['time_spent_seconds'];
    final time = rawTime is num ? rawTime.toInt() : int.tryParse('$rawTime');
    return _AnalyticsStudent(
      id: row['student_id']?.toString(),
      name: row['student_name']?.toString().trim().isNotEmpty == true
          ? row['student_name'].toString().trim()
          : '—',
      status: row['submission_status']?.toString().toUpperCase() ?? 'PENDING',
      timeSpentSeconds: time,
      submittedAt: DateTime.tryParse(row['submitted_at']?.toString() ?? ''),
      answers: answers,
    );
  }

  final String name;
  final String? id;
  final String status;
  final int? timeSpentSeconds;
  final DateTime? submittedAt;
  final Map<String, String> answers;

  bool get completed => status == 'COMPLETED';
}

class _TopicTotals {
  int correct = 0;
  int attempts = 0;
}

class _TopicAnalytics {
  const _TopicAnalytics({
    required this.name,
    required this.correct,
    required this.attempts,
  });

  final String name;
  final int correct;
  final int attempts;

  double get rate => attempts == 0 ? 0 : correct * 100 / attempts;
}
