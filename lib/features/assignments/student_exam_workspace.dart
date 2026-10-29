import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';

import 'assignment_data_service.dart';

class StudentExamWorkspace extends StatefulWidget {
  const StudentExamWorkspace({
    super.key,
    required this.assignment,
    required this.questions,
    required this.service,
    this.languageCode = 'vi',
  });

  final AssignmentRecord assignment;
  final List<AssignmentQuestion> questions;
  final AssignmentDataService service;
  final String languageCode;

  @override
  State<StudentExamWorkspace> createState() => _StudentExamWorkspaceState();
}

class _StudentExamWorkspaceState extends State<StudentExamWorkspace> {
  static const _background = Color(0xFF0B0F19);
  static const _panel = Color(0xFF111827);
  static const _cyan = Color(0xFF22D3EE);
  static const _amber = Color(0xFFFBBF24);
  static const _muted = Color(0xFF94A3B8);
  static const _initialTime = Duration(minutes: 4, seconds: 32);

  final _questionScrollController = ScrollController();
  final _scratchpadKey = GlobalKey();
  final _questionKeys = <GlobalKey>[];
  final _answerControllers = <String, TextEditingController>{};
  final _answers = <String, String>{};
  final _flaggedQuestionIds = <String>{};
  final _noteStrokes = <_NoteStroke>[];

  Timer? _timer;
  late DateTime _startedAt;
  Duration _remaining = _initialTime;
  int _selectedTool = 0;
  int? _selectedElementNumber;
  String _elementSearch = '';
  String _calculatorDisplay = '0';
  double? _calculatorStoredValue;
  String? _calculatorPendingOperator;
  bool _calculatorReplaceDisplay = true;
  bool _calculatorHasError = false;
  bool _isFullscreen = false;
  bool _isSubmitting = false;
  bool _showingSubmissionDialog = false;
  String? _submissionError;
  bool _eraserEnabled = false;
  double _penWidth = 3;
  Color _penColor = const Color(0xFF22D3EE);
  _NoteStroke? _activeStroke;

  bool get _isVietnamese => widget.languageCode == 'vi';
  int get _elapsedSeconds => DateTime.now()
      .difference(_startedAt)
      .inSeconds
      .clamp(0, _initialTime.inSeconds);
  int get _answeredCount =>
      _answers.values.where((answer) => answer.trim().isNotEmpty).length;
  int get _unansweredCount => widget.questions.length - _answeredCount;

  String _text(String vi, String en) => widget.languageCode == 'zh'
      ? AppLocalizations.translateInline(en, languageCode: 'zh')
      : _isVietnamese
      ? vi
      : en;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _questionKeys.addAll(
      List.generate(widget.questions.length, (_) => GlobalKey()),
    );
    for (final question in widget.questions) {
      _answerControllers[question.id] = TextEditingController();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(_startedAt).inSeconds;
      if (elapsed >= _initialTime.inSeconds) {
        setState(() => _remaining = Duration.zero);
        _timer?.cancel();
        _openSubmissionDialog();
      } else {
        setState(
          () =>
              _remaining = Duration(seconds: _initialTime.inSeconds - elapsed),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _questionScrollController.dispose();
    for (final controller in _answerControllers.values) {
      controller.dispose();
    }
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Future<void> _toggleFullscreen() async {
    final enabled = !_isFullscreen;
    await SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (mounted) setState(() => _isFullscreen = enabled);
  }

  Future<void> _openSubmissionDialog() async {
    if (_showingSubmissionDialog || !mounted || _isSubmitting) return;
    _showingSubmissionDialog = true;
    _submissionError = null;
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> confirm() async {
            if (_isSubmitting) return;
            setState(() {
              _isSubmitting = true;
              _submissionError = null;
            });
            setDialogState(() {});
            try {
              await widget.service.submitExam(
                assignmentId: widget.assignment.id,
                answers: Map<String, String>.from(_answers),
                totalQuestions: widget.questions.length,
                flaggedQuestions: _flaggedQuestionIds.toList(),
                timeSpentSeconds: _elapsedSeconds,
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } catch (error) {
              if (!mounted) return;
              setState(() {
                _isSubmitting = false;
                _submissionError = error.toString();
              });
              setDialogState(() {});
            }
          }

          return AlertDialog(
            backgroundColor: _panel,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: _cyan.withValues(alpha: 0.3)),
            ),
            title: Text(
              _text('Bạn đã sẵn sàng nộp bài?', 'Ready to submit?'),
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _submissionStat(
                        '$_answeredCount',
                        _text('Đã làm', 'Answered'),
                        const Color(0xFF34D399),
                      ),
                      const SizedBox(width: 10),
                      _submissionStat(
                        '$_unansweredCount',
                        _text('Bỏ trống', 'Unanswered'),
                        _amber,
                      ),
                      const SizedBox(width: 10),
                      _submissionStat(
                        '${_flaggedQuestionIds.length}',
                        _text('Đánh dấu', 'Flagged'),
                        const Color(0xFFFB7185),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: _amber,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '+${widget.assignment.coinReward} Coin ${_text('sẽ được cộng vào Ví khi đạt điểm qua', 'will be added to your wallet when you pass')}',
                            style: const TextStyle(
                              color: Color(0xFFFFD980),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_submissionError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _submissionError!,
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            actions: [
              TextButton(
                onPressed: _isSubmitting || _remaining == Duration.zero
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: Text(_text('Làm tiếp', 'Continue exam')),
              ),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : confirm,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(_text('Xác nhận nộp bài', 'Confirm submission')),
                style: FilledButton.styleFrom(
                  backgroundColor: _cyan,
                  foregroundColor: const Color(0xFF08202A),
                ),
              ),
            ],
          );
        },
      ),
    );
    _showingSubmissionDialog = false;
    if (submitted == true && mounted) {
      _timer?.cancel();
      Navigator.of(context).pop(true);
    } else if (_remaining == Duration.zero && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSubmissionDialog();
      });
    }
  }

  Widget _submissionStat(String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      ),
    ),
  );

  void _jumpToQuestion(int index) {
    if (index < 0 || index >= _questionKeys.length) return;
    final targetContext = _questionKeys[index].currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _selectAnswer(AssignmentQuestion question, String value) {
    setState(() => _answers[question.id] = value);
  }

  String get _timeLabel {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = _remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 850;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _background,
        systemNavigationBarColor: _background,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(compact),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 22,
                    12,
                    compact ? 12 : 22,
                    18,
                  ),
                  child: compact
                      ? Column(
                          children: [
                            Expanded(flex: 3, child: _buildQuestionFeed()),
                            const SizedBox(height: 12),
                            SizedBox(height: 290, child: _buildUtilityDrawer()),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 65, child: _buildQuestionFeed()),
                            const SizedBox(width: 16),
                            Expanded(flex: 35, child: _buildUtilityDrawer()),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool compact) {
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 22),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: _cyan.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: compact ? 5 : 4,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _cyan.withValues(alpha: 0.32)),
                    boxShadow: [
                      BoxShadow(
                        color: _cyan.withValues(alpha: 0.08),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.science_rounded,
                    color: _cyan,
                    size: 21,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 11),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.assignment.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _tag(widget.assignment.subject),
                            const SizedBox(width: 7),
                            Text(
                              '${_answeredCount.toString().padLeft(2, '0')} / ${widget.questions.length.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                                fontFeatures: [ui.FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: compact ? 4 : 3,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _amber.withValues(alpha: 0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: _amber.withValues(alpha: 0.08),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, color: _amber, size: 17),
                    const SizedBox(width: 7),
                    Text(
                      _timeLabel,
                      style: const TextStyle(
                        color: _amber,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        fontFeatures: [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: compact ? 5 : 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!compact)
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < widget.questions.length;
                            index++
                          )
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: _questionDot(index),
                            ),
                        ],
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: _isFullscreen
                      ? _text('Thoát toàn màn hình', 'Exit fullscreen')
                      : _text('Toàn màn hình', 'Fullscreen'),
                  onPressed: _toggleFullscreen,
                  icon: Icon(
                    _isFullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    color: _muted,
                    size: 20,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _openSubmissionDialog,
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: Text(_text('Nộp bài', 'Submit')),
                  style: FilledButton.styleFrom(
                    backgroundColor: _cyan,
                    foregroundColor: const Color(0xFF08202A),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 15,
                      vertical: 11,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _cyan.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: _cyan.withValues(alpha: 0.22)),
    ),
    child: Text(
      text.isEmpty ? _text('Hoá học', 'Chemistry') : text,
      style: const TextStyle(
        color: _cyan,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _questionDot(int index) {
    final questionId = widget.questions[index].id;
    final answered = (_answers[questionId] ?? '').trim().isNotEmpty;
    final flagged = _flaggedQuestionIds.contains(questionId);
    final color = flagged
        ? const Color(0xFFFB7185)
        : answered
        ? const Color(0xFF34D399)
        : _muted;
    return Tooltip(
      message: '${_text('Câu', 'Question')} ${index + 1}',
      child: InkWell(
        onTap: () => _jumpToQuestion(index),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 23,
          height: 23,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: answered || flagged ? 0.17 : 0.07),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(color: color, fontSize: 8, height: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionFeed() => Container(
    decoration: _panelDecoration(),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Row(
            children: [
              const Icon(Icons.article_outlined, color: _cyan, size: 17),
              const SizedBox(width: 8),
              Text(
                _text('ĐỀ THI', 'EXAM QUESTIONS'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                '+${widget.assignment.coinReward} Coin',
                style: const TextStyle(
                  color: _amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: _cyan.withValues(alpha: 0.12)),
        Expanded(
          child: Scrollbar(
            controller: _questionScrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _questionScrollController,
              padding: const EdgeInsets.all(14),
              itemCount: widget.questions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildQuestionCard(index),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildQuestionCard(int index) {
    final question = widget.questions[index];
    final answer = _answers[question.id];
    final flagged = _flaggedQuestionIds.contains(question.id);
    final options = question.options;
    return Container(
      key: _questionKeys[index],
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1623),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: flagged
              ? const Color(0xFFFB7185).withValues(alpha: 0.5)
              : _cyan.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_text('CÂU HỎI', 'QUESTION')} ${(index + 1).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: _cyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${question.points.toStringAsFixed(question.points == question.points.roundToDouble() ? 0 : 1)} ${_text('điểm', 'pts')}',
                style: TextStyle(
                  color: _amber.withValues(alpha: 0.92),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                tooltip: _text('Đánh dấu câu hỏi', 'Flag question'),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() {
                  if (flagged) {
                    _flaggedQuestionIds.remove(question.id);
                  } else {
                    _flaggedQuestionIds.add(question.id);
                  }
                }),
                icon: Icon(
                  flagged
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: flagged ? const Color(0xFFFB7185) : _muted,
                  size: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            question.text,
            style: const TextStyle(
              color: Color(0xFFE5EDF7),
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: TextField(
                controller: _answerControllers[question.id],
                onChanged: (value) => setState(() {
                  if (value.trim().isEmpty) {
                    _answers.remove(question.id);
                  } else {
                    _answers[question.id] = value;
                  }
                }),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: _text(
                    'Nhập câu trả lời của bạn…',
                    'Type your answer…',
                  ),
                  hintStyle: const TextStyle(color: _muted, fontSize: 12),
                  filled: true,
                  fillColor: _panel,
                  prefixIcon: const Icon(
                    Icons.edit_note_rounded,
                    color: _cyan,
                    size: 19,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(
                      color: _cyan.withValues(alpha: 0.18),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: _cyan),
                  ),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 12),
            for (
              var optionIndex = 0;
              optionIndex < options.length;
              optionIndex++
            )
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _answerOption(
                  question: question,
                  optionIndex: optionIndex,
                  label: _optionLabel(options[optionIndex]),
                  selected: answer == String.fromCharCode(65 + optionIndex),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _answerOption({
    required AssignmentQuestion question,
    required int optionIndex,
    required String label,
    required bool selected,
  }) {
    return Material(
      color: selected
          ? _cyan.withValues(alpha: 0.1)
          : const Color(0xFF111827).withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () =>
            _selectAnswer(question, String.fromCharCode(65 + optionIndex)),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? _cyan.withValues(alpha: 0.65) : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 21,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? _cyan : Colors.transparent,
                  border: Border.all(
                    color: selected ? _cyan : _muted.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  String.fromCharCode(65 + optionIndex),
                  style: TextStyle(
                    color: selected ? _background : _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlideSelect(
                  selected: selected,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFCBD5E1),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: _cyan, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _optionLabel(dynamic option) {
    if (option is Map) {
      return (option['label'] ?? option['text'] ?? option['value'] ?? '')
          .toString();
    }
    return option.toString();
  }

  BoxDecoration _panelDecoration() => BoxDecoration(
    color: _panel.withValues(alpha: 0.84),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _cyan.withValues(alpha: 0.18)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
    ],
  );

  Widget _buildUtilityDrawer() => Container(
    decoration: _panelDecoration(),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _toolTab(
                0,
                Icons.calculate_outlined,
                _text('Máy tính', 'Calculator'),
              ),
              const SizedBox(width: 5),
              _toolTab(
                1,
                Icons.grid_on_rounded,
                _text('Bảng tuần hoàn', 'Periodic table'),
              ),
              const SizedBox(width: 5),
              _toolTab(
                2,
                Icons.draw_outlined,
                _text('Giấy nháp', 'Scratchpad'),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: _cyan.withValues(alpha: 0.12)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IndexedStack(
              index: _selectedTool,
              children: [
                _buildCalculator(),
                _buildPeriodicTable(),
                _buildScratchpad(),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _toolTab(int index, IconData icon, String label) {
    final selected = _selectedTool == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTool = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 39,
          decoration: BoxDecoration(
            color: selected ? _cyan.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? _cyan.withValues(alpha: 0.28) : Colors.white10,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? _cyan : _muted),
              const SizedBox(width: 5),
              Flexible(
                child: GlideSelect(
                  selected: selected,
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _cyan : _muted,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buildCalculator() => Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF08111C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _cyan.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _calculatorPendingOperator ??
                  _text('MÁY TÍNH KHOA HỌC', 'SCIENTIFIC CALCULATOR'),
              style: const TextStyle(
                color: _muted,
                fontSize: 9,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _calculatorDisplay,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _calculatorHasError
                    ? const Color(0xFFFCA5A5)
                    : Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const keys = [
              'AC',
              '÷',
              '×',
              '−',
              '7',
              '8',
              '9',
              '+',
              '4',
              '5',
              '6',
              '⌫',
              '1',
              '2',
              '3',
              '=',
              '±',
              '0',
              ',',
              '%',
            ];
            return GridView.builder(
              itemCount: keys.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                childAspectRatio: 1.85,
              ),
              itemBuilder: (context, index) {
                final key = keys[index];
                final isOperator = const {
                  '÷',
                  '×',
                  '−',
                  '+',
                  '=',
                  'AC',
                  '⌫',
                }.contains(key);
                return FilledButton(
                  onPressed: () => _onCalculatorKey(key),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: key == '='
                        ? _cyan.withValues(alpha: 0.23)
                        : isOperator
                        ? _cyan.withValues(alpha: 0.08)
                        : const Color(0xFF182331),
                    foregroundColor: key == '=' || isOperator
                        ? _cyan
                        : const Color(0xFFE2E8F0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: (key == '=' || isOperator ? _cyan : Colors.white)
                            .withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  child: Text(
                    key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );

  void _onCalculatorKey(String key) {
    setState(() {
      _calculatorHasError = false;
      if (key == 'AC') {
        _calculatorDisplay = '0';
        _calculatorStoredValue = null;
        _calculatorPendingOperator = null;
        _calculatorReplaceDisplay = true;
        return;
      }
      if (key == '⌫') {
        if (_calculatorDisplay.length <= 1 ||
            (_calculatorDisplay.length == 2 &&
                _calculatorDisplay.startsWith('-'))) {
          _calculatorDisplay = '0';
        } else {
          _calculatorDisplay = _calculatorDisplay.substring(
            0,
            _calculatorDisplay.length - 1,
          );
        }
        _calculatorReplaceDisplay = false;
        return;
      }
      if (key == '±') {
        if (_calculatorDisplay != '0') {
          _calculatorDisplay = _calculatorDisplay.startsWith('-')
              ? _calculatorDisplay.substring(1)
              : '-$_calculatorDisplay';
        }
        return;
      }
      if (key == '%') {
        final value = double.tryParse(_calculatorDisplay.replaceAll(',', '.'));
        if (value != null) {
          _calculatorDisplay = _formatCalculatorResult(value / 100);
          _calculatorReplaceDisplay = true;
        }
        return;
      }
      if (key == ',') {
        if (_calculatorReplaceDisplay) {
          _calculatorDisplay = '0,';
          _calculatorReplaceDisplay = false;
        } else if (!_calculatorDisplay.contains(',')) {
          _calculatorDisplay += ',';
        }
        return;
      }
      if (const {'+', '−', '×', '÷'}.contains(key)) {
        final value = double.tryParse(_calculatorDisplay.replaceAll(',', '.'));
        if (value == null) {
          _calculatorHasError = true;
          _calculatorDisplay = 'Error';
          return;
        }
        _calculatorStoredValue = value;
        _calculatorPendingOperator = key;
        _calculatorReplaceDisplay = true;
        return;
      }
      if (key == '=') {
        final left = _calculatorStoredValue;
        final right = double.tryParse(_calculatorDisplay.replaceAll(',', '.'));
        final operator = _calculatorPendingOperator;
        if (left == null || right == null || operator == null) return;
        if (operator == '÷' && right == 0) {
          _calculatorDisplay = 'Error';
          _calculatorHasError = true;
        } else {
          final result = switch (operator) {
            '+' => left + right,
            '−' => left - right,
            '×' => left * right,
            '÷' => left / right,
            _ => right,
          };
          _calculatorDisplay = _formatCalculatorResult(result);
        }
        _calculatorStoredValue = null;
        _calculatorPendingOperator = null;
        _calculatorReplaceDisplay = true;
        return;
      }
      if (RegExp(r'^\d$').hasMatch(key)) {
        _calculatorDisplay =
            _calculatorReplaceDisplay ||
                _calculatorDisplay == '0' ||
                _calculatorDisplay == 'Error'
            ? key
            : '$_calculatorDisplay$key';
        _calculatorReplaceDisplay = false;
      }
    });
  }

  String _formatCalculatorResult(double value) {
    if (!value.isFinite) return 'Error';
    final rounded = double.parse(value.toStringAsPrecision(10));
    return rounded
        .toString()
        .replaceAll(RegExp(r'\.0$'), '')
        .replaceAll('.', ',');
  }

  static const _elements = <_ChemicalElement>[
    _ChemicalElement(1, 'H', 'Hydrogen', 1.008),
    _ChemicalElement(2, 'He', 'Helium', 4.0026),
    _ChemicalElement(3, 'Li', 'Lithium', 6.94),
    _ChemicalElement(4, 'Be', 'Beryllium', 9.0122),
    _ChemicalElement(5, 'B', 'Boron', 10.81),
    _ChemicalElement(6, 'C', 'Carbon', 12.011),
    _ChemicalElement(7, 'N', 'Nitrogen', 14.007),
    _ChemicalElement(8, 'O', 'Oxygen', 15.999),
    _ChemicalElement(9, 'F', 'Fluorine', 18.998),
    _ChemicalElement(10, 'Ne', 'Neon', 20.18),
    _ChemicalElement(11, 'Na', 'Sodium', 22.99),
    _ChemicalElement(12, 'Mg', 'Magnesium', 24.305),
    _ChemicalElement(13, 'Al', 'Aluminium', 26.982),
    _ChemicalElement(14, 'Si', 'Silicon', 28.085),
    _ChemicalElement(15, 'P', 'Phosphorus', 30.974),
    _ChemicalElement(16, 'S', 'Sulfur', 32.06),
    _ChemicalElement(17, 'Cl', 'Chlorine', 35.45),
    _ChemicalElement(18, 'Ar', 'Argon', 39.948),
    _ChemicalElement(19, 'K', 'Potassium', 39.098),
    _ChemicalElement(20, 'Ca', 'Calcium', 40.078),
    _ChemicalElement(21, 'Sc', 'Scandium', 44.956),
    _ChemicalElement(22, 'Ti', 'Titanium', 47.867),
    _ChemicalElement(23, 'V', 'Vanadium', 50.942),
    _ChemicalElement(24, 'Cr', 'Chromium', 51.996),
    _ChemicalElement(25, 'Mn', 'Manganese', 54.938),
    _ChemicalElement(26, 'Fe', 'Iron', 55.845),
    _ChemicalElement(27, 'Co', 'Cobalt', 58.933),
    _ChemicalElement(28, 'Ni', 'Nickel', 58.693),
    _ChemicalElement(29, 'Cu', 'Copper', 63.546),
    _ChemicalElement(30, 'Zn', 'Zinc', 65.38),
    _ChemicalElement(31, 'Ga', 'Gallium', 69.723),
    _ChemicalElement(32, 'Ge', 'Germanium', 72.63),
    _ChemicalElement(33, 'As', 'Arsenic', 74.922),
    _ChemicalElement(34, 'Se', 'Selenium', 78.971),
    _ChemicalElement(35, 'Br', 'Bromine', 79.904),
    _ChemicalElement(36, 'Kr', 'Krypton', 83.798),
    _ChemicalElement(37, 'Rb', 'Rubidium', 85.468),
    _ChemicalElement(38, 'Sr', 'Strontium', 87.62),
    _ChemicalElement(39, 'Y', 'Yttrium', 88.906),
    _ChemicalElement(40, 'Zr', 'Zirconium', 91.224),
    _ChemicalElement(41, 'Nb', 'Niobium', 92.906),
    _ChemicalElement(42, 'Mo', 'Molybdenum', 95.95),
    _ChemicalElement(43, 'Tc', 'Technetium', 98),
    _ChemicalElement(44, 'Ru', 'Ruthenium', 101.07),
    _ChemicalElement(45, 'Rh', 'Rhodium', 102.906),
    _ChemicalElement(46, 'Pd', 'Palladium', 106.42),
    _ChemicalElement(47, 'Ag', 'Silver', 107.868),
    _ChemicalElement(48, 'Cd', 'Cadmium', 112.414),
    _ChemicalElement(49, 'In', 'Indium', 114.818),
    _ChemicalElement(50, 'Sn', 'Tin', 118.71),
    _ChemicalElement(51, 'Sb', 'Antimony', 121.76),
    _ChemicalElement(52, 'Te', 'Tellurium', 127.6),
    _ChemicalElement(53, 'I', 'Iodine', 126.904),
    _ChemicalElement(54, 'Xe', 'Xenon', 131.293),
    _ChemicalElement(55, 'Cs', 'Caesium', 132.905),
    _ChemicalElement(56, 'Ba', 'Barium', 137.327),
    _ChemicalElement(57, 'La', 'Lanthanum', 138.905),
    _ChemicalElement(58, 'Ce', 'Cerium', 140.116),
    _ChemicalElement(59, 'Pr', 'Praseodymium', 140.908),
    _ChemicalElement(60, 'Nd', 'Neodymium', 144.242),
    _ChemicalElement(61, 'Pm', 'Promethium', 145),
    _ChemicalElement(62, 'Sm', 'Samarium', 150.36),
    _ChemicalElement(63, 'Eu', 'Europium', 151.964),
    _ChemicalElement(64, 'Gd', 'Gadolinium', 157.25),
    _ChemicalElement(65, 'Tb', 'Terbium', 158.925),
    _ChemicalElement(66, 'Dy', 'Dysprosium', 162.5),
    _ChemicalElement(67, 'Ho', 'Holmium', 164.93),
    _ChemicalElement(68, 'Er', 'Erbium', 167.259),
    _ChemicalElement(69, 'Tm', 'Thulium', 168.934),
    _ChemicalElement(70, 'Yb', 'Ytterbium', 173.045),
    _ChemicalElement(71, 'Lu', 'Lutetium', 174.967),
    _ChemicalElement(72, 'Hf', 'Hafnium', 178.49),
    _ChemicalElement(73, 'Ta', 'Tantalum', 180.948),
    _ChemicalElement(74, 'W', 'Tungsten', 183.84),
    _ChemicalElement(75, 'Re', 'Rhenium', 186.207),
    _ChemicalElement(76, 'Os', 'Osmium', 190.23),
    _ChemicalElement(77, 'Ir', 'Iridium', 192.217),
    _ChemicalElement(78, 'Pt', 'Platinum', 195.084),
    _ChemicalElement(79, 'Au', 'Gold', 196.967),
    _ChemicalElement(80, 'Hg', 'Mercury', 200.592),
    _ChemicalElement(81, 'Tl', 'Thallium', 204.38),
    _ChemicalElement(82, 'Pb', 'Lead', 207.2),
    _ChemicalElement(83, 'Bi', 'Bismuth', 208.98),
    _ChemicalElement(84, 'Po', 'Polonium', 209),
    _ChemicalElement(85, 'At', 'Astatine', 210),
    _ChemicalElement(86, 'Rn', 'Radon', 222),
    _ChemicalElement(87, 'Fr', 'Francium', 223),
    _ChemicalElement(88, 'Ra', 'Radium', 226),
    _ChemicalElement(89, 'Ac', 'Actinium', 227),
    _ChemicalElement(90, 'Th', 'Thorium', 232.038),
    _ChemicalElement(91, 'Pa', 'Protactinium', 231.036),
    _ChemicalElement(92, 'U', 'Uranium', 238.029),
    _ChemicalElement(93, 'Np', 'Neptunium', 237),
    _ChemicalElement(94, 'Pu', 'Plutonium', 244),
    _ChemicalElement(95, 'Am', 'Americium', 243),
    _ChemicalElement(96, 'Cm', 'Curium', 247),
    _ChemicalElement(97, 'Bk', 'Berkelium', 247),
    _ChemicalElement(98, 'Cf', 'Californium', 251),
    _ChemicalElement(99, 'Es', 'Einsteinium', 252),
    _ChemicalElement(100, 'Fm', 'Fermium', 257),
    _ChemicalElement(101, 'Md', 'Mendelevium', 258),
    _ChemicalElement(102, 'No', 'Nobelium', 259),
    _ChemicalElement(103, 'Lr', 'Lawrencium', 266),
    _ChemicalElement(104, 'Rf', 'Rutherfordium', 267),
    _ChemicalElement(105, 'Db', 'Dubnium', 268),
    _ChemicalElement(106, 'Sg', 'Seaborgium', 269),
    _ChemicalElement(107, 'Bh', 'Bohrium', 270),
    _ChemicalElement(108, 'Hs', 'Hassium', 277),
    _ChemicalElement(109, 'Mt', 'Meitnerium', 278),
    _ChemicalElement(110, 'Ds', 'Darmstadtium', 281),
    _ChemicalElement(111, 'Rg', 'Roentgenium', 282),
    _ChemicalElement(112, 'Cn', 'Copernicium', 285),
    _ChemicalElement(113, 'Nh', 'Nihonium', 286),
    _ChemicalElement(114, 'Fl', 'Flerovium', 289),
    _ChemicalElement(115, 'Mc', 'Moscovium', 290),
    _ChemicalElement(116, 'Lv', 'Livermorium', 293),
    _ChemicalElement(117, 'Ts', 'Tennessine', 294),
    _ChemicalElement(118, 'Og', 'Oganesson', 294),
  ];

  Widget _buildPeriodicTable() {
    final filtered = _elements.where((element) {
      final query = _elementSearch.trim().toLowerCase();
      return query.isEmpty ||
          element.symbol.toLowerCase().contains(query) ||
          element.name.toLowerCase().contains(query) ||
          element.atomicNumber.toString().contains(query);
    }).toList();
    final selected = _selectedElementNumber == null
        ? null
        : _elements.firstWhere(
            (element) => element.atomicNumber == _selectedElementNumber,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (value) => setState(() => _elementSearch = value),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            hintText: _text('Tìm nguyên tố…', 'Search elements…'),
            hintStyle: const TextStyle(color: _muted, fontSize: 11),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _cyan,
              size: 17,
            ),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF0B121A),
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(color: _cyan.withValues(alpha: 0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(color: _cyan.withValues(alpha: 0.15)),
            ),
          ),
        ),
        if (selected != null) ...[
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: _cyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _cyan.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Text(
                  selected.symbol,
                  style: const TextStyle(
                    color: _cyan,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_text('Số hiệu nguyên tử', 'Atomic number')} ${selected.atomicNumber}  ·  ${_text('Khối lượng', 'Mass')} ${selected.mass}',
                        style: const TextStyle(color: _muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 47).floor().clamp(4, 10);
              return GridView.builder(
                itemCount: filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (context, index) {
                  final element = filtered[index];
                  final isSelected =
                      element.atomicNumber == _selectedElementNumber;
                  return Tooltip(
                    message:
                        '${element.name} · ${element.atomicNumber} · ${element.mass}',
                    child: InkWell(
                      onTap: () => setState(
                        () => _selectedElementNumber = element.atomicNumber,
                      ),
                      borderRadius: BorderRadius.circular(7),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _cyan.withValues(alpha: 0.2)
                              : const Color(0xFF0B121A),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: isSelected
                                ? _cyan.withValues(alpha: 0.7)
                                : _cyan.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${element.atomicNumber}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 7,
                              ),
                            ),
                            const Spacer(),
                            Center(
                              child: GlideSelect(
                                selected: isSelected,
                                child: Text(
                                  element.symbol,
                                  style: TextStyle(
                                    color: isSelected ? _cyan : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScratchpad() => Column(
    children: [
      Row(
        children: [
          _scratchTool(
            icon: Icons.edit_rounded,
            selected: !_eraserEnabled,
            label: _text('Bút', 'Pen'),
            onTap: () => setState(() => _eraserEnabled = false),
          ),
          const SizedBox(width: 6),
          _scratchTool(
            icon: Icons.auto_fix_high_rounded,
            selected: _eraserEnabled,
            label: _text('Tẩy', 'Eraser'),
            onTap: () => setState(() => _eraserEnabled = true),
          ),
          const Spacer(),
          IconButton(
            tooltip: _text('Xóa giấy nháp', 'Clear scratchpad'),
            onPressed: () => setState(_noteStrokes.clear),
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFFB7185),
              size: 18,
            ),
          ),
        ],
      ),
      Row(
        children: [
          Text(
            _text('NÉT', 'STROKE'),
            style: const TextStyle(color: _muted, fontSize: 8),
          ),
          Expanded(
            child: Slider(
              value: _penWidth,
              min: 1,
              max: 10,
              onChanged: (value) => setState(() => _penWidth = value),
            ),
          ),
          for (final color in const [
            Color(0xFF22D3EE),
            Color(0xFFF8FAFC),
            Color(0xFFFBBF24),
            Color(0xFFFB7185),
          ])
            GestureDetector(
              onTap: () => setState(() => _penColor = color),
              child: GlideSelect(
                selected: _penColor == color,
                child: Container(
                  width: 15,
                  height: 15,
                  margin: const EdgeInsets.only(left: 5),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _penColor == color ? Colors.white : Colors.white24,
                      width: _penColor == color ? 2 : 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: GestureDetector(
            key: _scratchpadKey,
            onPanStart: (details) {
              final box =
                  _scratchpadKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (box == null) return;
              final point = box.globalToLocal(details.globalPosition);
              _activeStroke = _NoteStroke(
                color: _eraserEnabled ? const Color(0xFF0D1724) : _penColor,
                width: _eraserEnabled ? _penWidth * 4 : _penWidth,
                points: [point],
              );
              setState(() => _noteStrokes.add(_activeStroke!));
            },
            onPanUpdate: (details) {
              final box =
                  _scratchpadKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (box == null || _activeStroke == null) return;
              setState(
                () => _activeStroke!.points.add(
                  box.globalToLocal(details.globalPosition),
                ),
              );
            },
            onPanEnd: (_) => _activeStroke = null,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1724),
                border: Border.all(color: _cyan.withValues(alpha: 0.14)),
              ),
              child: CustomPaint(
                painter: _ScratchpadPainter(
                  strokes: _noteStrokes,
                  backgroundColor: const Color(0xFF0D1724),
                ),
                child: Center(
                  child: _noteStrokes.isEmpty
                      ? Text(
                          _text(
                            'Vẽ hoặc ghi chú tại đây',
                            'Draw or write here',
                          ),
                          style: const TextStyle(
                            color: Color(0xFF526174),
                            fontSize: 11,
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _scratchTool({
    required IconData icon,
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 13),
    label: GlideSelect(
      selected: selected,
      child: Text(label, style: const TextStyle(fontSize: 9)),
    ),
    style: TextButton.styleFrom(
      foregroundColor: selected ? _cyan : _muted,
      backgroundColor: selected
          ? _cyan.withValues(alpha: 0.1)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

class _ChemicalElement {
  const _ChemicalElement(this.atomicNumber, this.symbol, this.name, this.mass);

  final int atomicNumber;
  final String symbol;
  final String name;
  final double mass;
}

class _NoteStroke {
  _NoteStroke({required this.color, required this.width, required this.points});

  final Color color;
  final double width;
  final List<Offset> points;
}

class _ScratchpadPainter extends CustomPainter {
  const _ScratchpadPainter({
    required this.strokes,
    required this.backgroundColor,
  });

  final List<_NoteStroke> strokes;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(backgroundColor, BlendMode.src);
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (stroke.points.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke.points, paint);
        continue;
      }
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScratchpadPainter oldDelegate) => true;
}
