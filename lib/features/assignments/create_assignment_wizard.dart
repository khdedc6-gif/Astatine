import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';

import 'assignment_data_service.dart';

class CreateAssignmentWizard extends StatefulWidget {
  const CreateAssignmentWizard({
    super.key,
    required this.service,
    required this.classrooms,
    required this.isVietnamese,
    this.languageCode,
  });

  final AssignmentDataService service;
  final List<AssignmentClassroom> classrooms;
  final bool isVietnamese;
  final String? languageCode;

  @override
  State<CreateAssignmentWizard> createState() => _CreateAssignmentWizardState();
}

class _QuizQuestionDraft {
  _QuizQuestionDraft({
    String text = 'Which coefficients balance the equation H₂ + O₂ → H₂O?',
    List<String>? options,
    this.correctOption = 1,
    double points = 10,
  }) : textController = TextEditingController(text: text),
       pointsController = TextEditingController(
         text: points.toStringAsFixed(points == points.roundToDouble() ? 0 : 1),
       ),
       optionControllers = [
         for (final option
             in options ?? ['1, 1, 1', '2, 1, 2', '1, 2, 1', '2, 2, 1'])
           TextEditingController(text: option),
       ];

  final TextEditingController textController;
  final TextEditingController pointsController;
  final List<TextEditingController> optionControllers;
  int correctOption;
  double get points => double.tryParse(pointsController.text.trim()) ?? 0;

  _QuizQuestionDraft duplicate() => _QuizQuestionDraft(
    text: textController.text,
    options: optionControllers.map((controller) => controller.text).toList(),
    correctOption: correctOption,
    points: points,
  );

  void dispose() {
    textController.dispose();
    pointsController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
  }
}

class _CreateAssignmentWizardState extends State<CreateAssignmentWizard> {
  static const _gold = Color(0xFFFFB800);
  static const _green = Color(0xFF10B981);

  final _titleController = TextEditingController(text: 'Balanced Equations');
  final _searchController = TextEditingController();
  final _questionsScrollController = ScrollController();
  final _studentsScrollController = ScrollController();
  final List<_QuizQuestionDraft> _questions = [_QuizQuestionDraft()];
  final Set<String> _selectedStudentIds = {};

  late String _selectedClassId = widget.classrooms.first.id;
  String _subject = 'Chemistry';
  final _passingScoreController = TextEditingController(text: '5');
  int _currentStep = 1;
  int _coinReward = 200;
  bool _wholeClass = true;
  bool _loadingStudents = false;
  bool _publishing = false;
  String? _studentLoadError;
  List<AssignmentStudent> _students = const [];
  DateTime _dueAt = DateTime.now().add(const Duration(days: 5));

  AstatinePalette get _palette =>
      Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;

  bool get _vi => widget.isVietnamese;
  String get _languageCode => widget.languageCode ?? (_vi ? 'vi' : 'en');

  String _text(String vi, String en) => _languageCode == 'zh'
      ? AppLocalizations.translateInline(en, languageCode: _languageCode)
      : _vi
      ? vi
      : en;

  AssignmentClassroom get _selectedClass => widget.classrooms.firstWhere(
    (classroom) => classroom.id == _selectedClassId,
    orElse: () => widget.classrooms.first,
  );

  List<AssignmentStudent> get _filteredStudents {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _students;
    return _students
        .where(
          (student) =>
              student.name.toLowerCase().contains(query) ||
              student.email.toLowerCase().contains(query),
        )
        .toList();
  }

  List<AssignmentStudent> get _selectedStudents => _students
      .where((student) => _selectedStudentIds.contains(student.id))
      .toList();

  @override
  void initState() {
    super.initState();
    _dueAt = DateTime.now().add(const Duration(days: 5));
    _dueAt = DateTime(_dueAt.year, _dueAt.month, _dueAt.day, 18);
    _loadStudents();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    _questionsScrollController.dispose();
    _studentsScrollController.dispose();
    _passingScoreController.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loadingStudents = true;
      _studentLoadError = null;
      _selectedStudentIds.clear();
    });
    try {
      final students = await widget.service.fetchStudentsForClass(
        _selectedClassId,
      );
      if (!mounted) return;
      setState(() {
        _students = students;
        _loadingStudents = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _studentLoadError = error.toString();
        _students = const [];
        _loadingStudents = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      backgroundColor: _palette.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(compact),
            _buildStepper(compact),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_currentStep),
                  child: _currentStep == 1
                      ? _buildQuestionsStep()
                      : _currentStep == 2
                      ? _buildAssigneesStep()
                      : _buildRewardStep(),
                ),
              ),
            ),
            _buildFooter(compact),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool compact) => Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 28, vertical: 12),
    decoration: BoxDecoration(
      color: _palette.card,
      border: Border(bottom: BorderSide(color: _palette.border)),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: _text('Đóng', 'Close'),
          onPressed: _saveAndClose,
          icon: Icon(Icons.arrow_back_rounded, color: _palette.canvasMutedText),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(
                  'WORKSPACE  -  TẠO NHIÊm VỤ',
                  'WORKSPACE  -  CREATE ASSIGNMENT',
                ),
                style: TextStyle(
                  color: _palette.accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(
                height: 34,
                child: TextField(
                  controller: _titleController,
                  style: TextStyle(
                    color: _palette.canvasText,
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  Text(_subject, style: _metaText()),
                  Text('•', style: _metaText()),
                  Text(_selectedClass.name, style: _metaText()),
                  Text('•', style: _metaText()),
                  Text(
                    _text('Bản nháp · Chưa tạo', 'Draft · Not published'),
                    style: _metaText(color: _green),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!compact)
          OutlinedButton.icon(
            onPressed: _saveAndClose,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: Text(_text('Lưu & đóng', 'Save & close')),
          ),
      ],
    ),
  );

  TextStyle _metaText({Color? color}) =>
      TextStyle(color: color ?? _palette.canvasMutedText, fontSize: 10);

  Widget _buildStepper(bool compact) {
    final labels = [
      _text('Câu hỏi & đáp án', 'Questions & answers'),
      _text('Người nhận', 'Assignees'),
      _text('Thưởng Coin', 'Coin reward'),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 28,
        vertical: 12,
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            Expanded(child: _stepPill(index + 1, labels[index])),
            if (index < labels.length - 1)
              Container(
                width: compact ? 12 : 35,
                height: 1,
                color: _currentStep > index + 1
                    ? _palette.accent
                    : _palette.border,
              ),
          ],
        ],
      ),
    );
  }

  Widget _stepPill(int step, String label) {
    final active = step == _currentStep;
    final done = step < _currentStep;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: active ? 10 : 6, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? _palette.accent.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: active
              ? _palette.accent.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? _palette.accent : _palette.input,
              border: Border.all(
                color: active ? _palette.accent : _palette.border,
              ),
            ),
            child: done
                ? Icon(
                    Icons.check_rounded,
                    color: _palette.accentText,
                    size: 14,
                  )
                : Text(
                    '$step',
                    style: TextStyle(
                      color: active
                          ? _palette.accent
                          : _palette.canvasMutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          if (active || MediaQuery.sizeOf(context).width >= 720) ...[
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active
                      ? _palette.canvasText
                      : _palette.canvasMutedText,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionsStep() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 660;
                  return Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      Text(
                        _text('CÂU HỎI & ĐÁP ÁN', 'QUESTIONS & ANSWERS'),
                        style: TextStyle(
                          color: _palette.canvasMutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: _palette.input,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _palette.border),
                            ),
                            child: DropdownButton<String>(
                              value: _subject,
                              borderRadius: BorderRadius.circular(16),
                              dropdownColor: _palette.card,
                              iconEnabledColor: _palette.accent,
                              style: TextStyle(color: _palette.primaryText),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              underline: const SizedBox.shrink(),
                              items: [
                                DropdownMenuItem(
                                  value: 'Chemistry',
                                  child: GlideSelect(
                                    selected: _subject == 'Chemistry',
                                    child: Text(_text('Hóa học', 'Chemistry')),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Physics',
                                  child: GlideSelect(
                                    selected: _subject == 'Physics',
                                    child: Text(_text('Vật lý', 'Physics')),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Math',
                                  child: GlideSelect(
                                    selected: _subject == 'Math',
                                    child: Text(_text('Toán học', 'Math')),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Biology',
                                  child: GlideSelect(
                                    selected: _subject == 'Biology',
                                    child: Text(_text('Sinh học', 'Biology')),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _subject = value);
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width: compact ? 132 : 158,
                            child: TextField(
                              controller: _passingScoreController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: _text('Điểm đạt', 'Pass score'),
                                suffixText: '/ 10',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _questionsScrollController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _questionsScrollController,
                  padding: const EdgeInsets.only(bottom: 12, right: 8),
                  itemCount: _questions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _questionCard(index),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: Text(_text('Thêm câu hỏi', 'Add question')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _palette.accent,
                  side: BorderSide(
                    color: _palette.accent.withValues(alpha: 0.55),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _questionCard(int index) {
    final question = _questions[index];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _languageCode == 'zh'
                      ? '第 ${index + 1} 题，共 ${_questions.length} 题'
                      : '${_text('Câu hỏi', 'Question')} ${index + 1} ${_text('trong', 'of')} ${_questions.length}',
                  style: TextStyle(
                    color: _palette.canvasText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: _text('Nhân đôi', 'Duplicate'),
                onPressed: () => _duplicateQuestion(index),
                icon: const Icon(Icons.copy_outlined, size: 17),
              ),
              IconButton(
                tooltip: _text('Xóa câu hỏi', 'Delete question'),
                onPressed: _questions.length > 1
                    ? () => _removeQuestion(index)
                    : null,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
          Row(
            children: [
              DropdownButton<String>(
                value: 'multiple_choice',
                borderRadius: BorderRadius.circular(16),
                dropdownColor: _palette.card,
                style: TextStyle(color: _palette.primaryText),
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: 'multiple_choice',
                    child: Text(_text('Trắc nghiệm', 'Multiple choice')),
                  ),
                ],
                onChanged: (_) {},
              ),
              const Spacer(),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: question.pointsController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: _text('Điểm câu', 'Question points'),
                    suffixText: _text('điểm', 'pts'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          TextField(
            controller: question.textController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: _text('Nội dung câu hỏi', 'Question text'),
              hintText: 'H₂ + O₂ → H₂O',
              helperText: _text(
                'Có thể nhập công thức và ký hiệu hóa học.',
                'Chemical formulas and symbols are supported.',
              ),
              filled: true,
              fillColor: _palette.input,
            ),
          ),
          const SizedBox(height: 10),
          RadioGroup<int>(
            groupValue: question.correctOption,
            onChanged: (value) {
              if (value != null) {
                setState(() => question.correctOption = value);
              }
            },
            child: Column(
              children: [
                for (
                  var optionIndex = 0;
                  optionIndex < question.optionControllers.length;
                  optionIndex++
                )
                  _answerOption(question, optionIndex),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerOption(_QuizQuestionDraft question, int index) {
    final correct = question.correctOption == index;
    final label = String.fromCharCode(65 + index);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        decoration: BoxDecoration(
          color: correct ? _green.withValues(alpha: 0.08) : _palette.input,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: correct ? _green : _palette.border,
            width: correct ? 1.5 : 1,
          ),
          boxShadow: correct
              ? [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.12),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Radio<int>(value: index, activeColor: _green),
            Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: correct ? _green.withValues(alpha: 0.18) : _palette.card,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: correct ? _green : _palette.canvasMutedText,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: question.optionControllers[index],
                decoration: InputDecoration(
                  hintText: _languageCode == 'zh'
                      ? '选项 $label'
                      : _text('Đáp án $label', 'Option $label'),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (correct)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  _text('ĐÁP ÁN ĐÚNG', 'CORRECT'),
                  style: const TextStyle(
                    color: _green,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneesStep() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedClassId,
              borderRadius: BorderRadius.circular(16),
              decoration: InputDecoration(
                labelText: _text('Lớp nhận bài', 'Assignment class'),
              ),
              items: [
                for (final classroom in widget.classrooms)
                  DropdownMenuItem(
                    value: classroom.id,
                    child: GlideSelect(
                      selected: _selectedClassId == classroom.id,
                      child: Text(classroom.name),
                    ),
                  ),
              ],
              onChanged: (classId) {
                if (classId == null || classId == _selectedClassId) return;
                setState(() => _selectedClassId = classId);
                _loadStudents();
              },
            ),
            const SizedBox(height: 8),
            Text(
              _languageCode == 'zh'
                  ? '选择班级 ${_selectedClass.name} 中接收“${_titleController.text}”的学生'
                  : _text(
                      'Chọn người nhận bài "${_titleController.text}" trong lớp ${_selectedClass.name}',
                      'Choose who receives ${_titleController.text} in ${_selectedClass.name}',
                    ),
              style: TextStyle(
                color: _palette.canvasText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: GlideSelect(
                    selected: _wholeClass,
                    child: Text(_text('Cả lớp', 'Whole Class')),
                  ),
                  icon: const Icon(Icons.groups_rounded),
                ),
                ButtonSegment(
                  value: false,
                  label: GlideSelect(
                    selected: !_wholeClass,
                    child: Text(_text('Chọn học sinh', 'Select Students')),
                  ),
                  icon: const Icon(Icons.person_search_rounded),
                ),
              ],
              selected: {_wholeClass},
              onSelectionChanged: (selection) {
                final wholeClass = selection.first;
                setState(() {
                  _wholeClass = wholeClass;
                  if (_wholeClass) _selectedStudentIds.clear();
                });
                if (!wholeClass && _students.isEmpty) _loadStudents();
              },
            ),
            const SizedBox(height: 10),
            if (!_wholeClass) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: _text(
                          'Tìm học sinh...',
                          'Search student name...',
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    _languageCode == 'zh'
                        ? '已选择 ${_selectedStudentIds.length} 人'
                        : _text(
                            '${_selectedStudentIds.length} đã chọn',
                            '${_selectedStudentIds.length} selected',
                          ),
                    style: TextStyle(color: _palette.accent, fontSize: 10),
                  ),
                  TextButton(
                    onPressed: () => setState(_selectedStudentIds.clear),
                    child: Text(_text('Bỏ chọn', 'Clear')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loadingStudents
                    ? const Center(child: CircularProgressIndicator())
                    : _studentLoadError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_off_outlined,
                              color: _palette.canvasMutedText,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _languageCode == 'zh'
                                  ? AppLocalizations.t(
                                      'errors.unexpected',
                                      languageCode: 'zh',
                                    )
                                  : _studentLoadError!,
                              textAlign: TextAlign.center,
                              style: _metaText(),
                            ),
                            TextButton(
                              onPressed: _loadStudents,
                              child: Text(_text('Thử lại', 'Retry')),
                            ),
                          ],
                        ),
                      )
                    : Scrollbar(
                        controller: _studentsScrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _studentsScrollController,
                          itemCount: _filteredStudents.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: _palette.border.withValues(alpha: 0.55),
                          ),
                          itemBuilder: (context, index) {
                            final student = _filteredStudents[index];
                            final selected = _selectedStudentIds.contains(
                              student.id,
                            );
                            return CheckboxListTile(
                              value: selected,
                              onChanged: (checked) => setState(() {
                                if (checked == true) {
                                  _selectedStudentIds.add(student.id);
                                } else {
                                  _selectedStudentIds.remove(student.id);
                                }
                              }),
                              secondary: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _palette.accent.withValues(
                                      alpha: 0.12,
                                    ),
                                    child: Text(
                                      student.name.isEmpty
                                          ? '?'
                                          : student.name.characters.first
                                                .toUpperCase(),
                                      style: TextStyle(color: _palette.accent),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Chip(
                                    label: Text(_selectedClass.name),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                              title: GlideSelect(
                                selected: selected,
                                child: Text(student.name),
                              ),
                              subtitle: student.email.isEmpty
                                  ? null
                                  : Text(student.email),
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
                        ),
                      ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 9),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _palette.accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: _palette.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  _selectedStudents.isEmpty
                      ? _text(
                          'Chưa chọn học sinh nào.',
                          'No students selected.',
                        )
                      : _text(
                          'Chỉ ${_selectedStudents.map((student) => student.name).join(', ')} nhận bài này.',
                          'Only ${_selectedStudents.map((student) => student.name).join(', ')} will receive this quiz. Unchecked students will not be assigned.',
                        ),
                  style: TextStyle(
                    color: _palette.canvasMutedText,
                    fontSize: 10,
                  ),
                ),
              ),
            ] else ...[
              const Spacer(),
              Icon(Icons.groups_rounded, color: _palette.accent, size: 42),
              const SizedBox(height: 9),
              Text(
                _languageCode == 'zh'
                    ? '${_selectedClass.name} 班的所有学生都会收到此作业。'
                    : _text(
                        'Tất cả học sinh trong lớp ${_selectedClass.name} sẽ nhận bài.',
                        'All students in ${_selectedClass.name} will receive this assignment.',
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(color: _palette.canvasMutedText),
              ),
              const Spacer(),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _buildRewardStep() {
    final recipientCount = _wholeClass
        ? _students.length
        : _selectedStudentIds.length;
    final potentialReward = recipientCount * _coinReward;
    final dueLabel = MaterialLocalizations.of(context).formatMediumDate(_dueAt);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _wizardPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.event_outlined,
                        color: _palette.accent,
                      ),
                      title: Text(_text('Hạn nộp', 'Due date')),
                      subtitle: Text(
                        '${MaterialLocalizations.of(context).formatMediumDate(_dueAt)} · 18:00',
                        style: _metaText(),
                      ),
                      trailing: TextButton(
                        onPressed: _pickDueDate,
                        child: Text(_text('Đổi ngày', 'Change')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _text('Thưởng quiz cho học sinh', 'Student Quiz Reward'),
                      style: _sectionTitle(),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _text(
                        'Nhận khi hoàn thành và đạt điểm qua bài quiz',
                        'Earned when a student completes and passes the quiz',
                      ),
                      style: _metaText(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: 500,
                            divisions: 50,
                            value: _coinReward.toDouble(),
                            label: '$_coinReward Coin',
                            onChanged: (value) =>
                                setState(() => _coinReward = value.round()),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.12),
                            border: Border.all(
                              color: _gold.withValues(alpha: 0.4),
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '$_coinReward Coin',
                            style: const TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('0 Coin'), Text('500 Coin')],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 11),
              _wizardPanel(
                accent: _palette.accent,
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: _palette.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text(
                              '+10 Coin mỗi học sinh đạt điểm qua',
                              '+10 Coin earned per student who passes',
                            ),
                            style: TextStyle(
                              color: _palette.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _text(
                              'Thưởng khuyến khích giáo viên, tách biệt với phần thưởng học sinh.',
                              'Teacher incentive, separate from each student reward.',
                            ),
                            style: _metaText(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 11),
              _wizardPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text('Sẵn sàng phát hành', 'Ready to publish'),
                      style: _sectionTitle(),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _titleController.text,
                      style: TextStyle(
                        color: _palette.canvasText,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_subject · ${_questions.length} ${_text('câu hỏi', 'questions')} · ${_questions.length * 2} min · $dueLabel',
                      style: _metaText(),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _wholeClass
                          ? _text(
                              'Cả lớp ${_selectedClass.name}',
                              'Whole class · ${_selectedClass.name}',
                            )
                          : '${_selectedStudents.length} ${_text('học sinh được chọn', 'selected students')} · ${_selectedClass.name}',
                      style: TextStyle(
                        color: _palette.canvasText,
                        fontSize: 11,
                      ),
                    ),
                    if (!_wholeClass && _selectedStudents.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _selectedStudents
                            .map((student) => student.name)
                            .join(', '),
                        style: _metaText(),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Text(
                      '$_coinReward Coin ${_text('mỗi học sinh', 'each')} · $potentialReward Coin ${_text('tổng', ' total')}',
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => _currentStep = 1),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: Text(_text('Xem lại ', 'Review ')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _sectionTitle() => TextStyle(
    color: _palette.canvasText,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  Widget _wizardPanel({required Widget child, Color? accent}) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: _palette.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: (accent ?? _palette.border).withValues(alpha: 0.7),
      ),
    ),
    child: child,
  );

  Widget _buildFooter(bool compact) => Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 28, vertical: 10),
    decoration: BoxDecoration(
      color: _palette.card,
      border: Border(top: BorderSide(color: _palette.border)),
    ),
    child: Row(
      children: [
        TextButton(
          onPressed: _currentStep == 1 ? _saveAndClose : _previousStep,
          child: Text(
            _currentStep == 1
                ? _text('Lưu & đóng', 'Save & close')
                : _text('← Quay lại', '← Back'),
          ),
        ),
        const Spacer(),
        Text(
          '${_text('Bước', 'Step')} $_currentStep ${_text('trên', 'of')} 3',
          style: _metaText(),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _publishing
              ? null
              : (_currentStep < 3 ? _nextStep : _publish),
          icon: _publishing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _currentStep < 3
                      ? Icons.arrow_forward_rounded
                      : Icons.rocket_launch_rounded,
                  size: 16,
                ),
          label: Text(
            _publishing
                ? _text('Đang tạo...', 'Publishing...')
                : _currentStep == 1
                ? _text('Tiếp: Người nhận', 'Next: Assignees')
                : _currentStep == 2
                ? _text('Tiếp: Thưởng Coin', 'Next: Coin reward')
                : _text('Tạo', 'Create'),
          ),
        ),
      ],
    ),
  );

  void _addQuestion() => setState(
    () => _questions.add(
      _QuizQuestionDraft(text: '', options: const ['', '', '', '']),
    ),
  );

  void _duplicateQuestion(int index) => setState(() {
    _questions.insert(index + 1, _questions[index].duplicate());
  });

  void _removeQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() {
      _questions.removeAt(index).dispose();
    });
  }

  Future<void> _nextStep() async {
    if (_currentStep == 1 && !_validateQuestions()) return;
    if (_currentStep == 2 && !_wholeClass && _selectedStudentIds.isEmpty) {
      _showNotice(
        _text('Hãy chọn ít nhất một học sinh.', 'Select at least one student.'),
      );
      return;
    }
    if (_currentStep == 1) await _loadStudents();
    if (mounted) setState(() => _currentStep = (_currentStep + 1).clamp(1, 3));
  }

  void _previousStep() =>
      setState(() => _currentStep = (_currentStep - 1).clamp(1, 3));

  bool _validateQuestions() {
    final passingScore = double.tryParse(_passingScoreController.text.trim());
    if (passingScore == null || passingScore < 0 || passingScore > 10) {
      _showNotice(
        _text(
          'Điểm đạt phải nằm trong khoảng từ 0 đến 10.',
          'The pass score must be between 0 and 10.',
        ),
      );
      return false;
    }
    for (final question in _questions) {
      if (question.textController.text.trim().isEmpty ||
          question.optionControllers.any(
            (controller) => controller.text.trim().isEmpty,
          ) ||
          !question.points.isFinite ||
          question.points <= 0 ||
          question.points > 10) {
        _showNotice(
          _text(
            'Hãy nhập nội dung, đủ 4 đáp án và điểm mỗi câu từ lớn hơn 0 đến 10.',
            'Enter each question, all four answers, and a question score greater than 0 and at most 10.',
          ),
        );
        return false;
      }
    }
    return _titleController.text.trim().isNotEmpty;
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() => _dueAt = DateTime(date.year, date.month, date.day, 18));
  }

  Future<void> _publish() async {
    if (!_validateQuestions()) {
      setState(() => _currentStep = 1);
      return;
    }
    if (!_wholeClass && _selectedStudentIds.isEmpty) {
      setState(() => _currentStep = 2);
      return;
    }
    setState(() => _publishing = true);
    try {
      await widget.service.createAssignment(
        classId: _selectedClassId,
        title: _titleController.text.trim(),
        subject: _subject,
        coinReward: _coinReward,
        recipients: _wholeClass ? const [] : _selectedStudentIds.toList(),
        dueAt: _dueAt,
        passingScore: double.tryParse(_passingScoreController.text.trim()) ?? 5,
        questions: [
          for (final question in _questions)
            NewAssignmentQuestion(
              text: question.textController.text.trim(),
              options: question.optionControllers
                  .map((controller) => controller.text.trim())
                  .toList(),
              correctOption: question.correctOption,
              points: question.points,
            ),
        ],
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _publishing = false);
        _showNotice(
          _languageCode == 'zh'
              ? AppLocalizations.t('errors.unexpected', languageCode: 'zh')
              : error.toString(),
        );
      }
    }
  }

  Future<void> _saveAndClose() async {
    Navigator.pop(context, false);
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
