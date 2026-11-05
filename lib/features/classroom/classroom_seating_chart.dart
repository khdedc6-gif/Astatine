import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:astatine_dashboard/core/notifications/toast_service.dart';
import 'package:astatine_dashboard/core/ui/discord_ui.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';
import 'package:astatine_dashboard/core/ui/loading_skeleton.dart';
import 'package:astatine_dashboard/core/ui/smooth_mouse_scroll_controller.dart';
import 'package:astatine_dashboard/core/ui/ui_motion.dart';

import 'classroom_service.dart';
import 'student_index_scoring.dart';

class ClassroomSeatingChartScreen extends StatefulWidget {
  const ClassroomSeatingChartScreen({
    super.key,
    required this.classroomId,
    required this.classroomName,
    required this.canManage,
  });

  final String classroomId;
  final String classroomName;
  final bool canManage;

  @override
  State<ClassroomSeatingChartScreen> createState() =>
      _ClassroomSeatingChartScreenState();
}

class _ClassroomSeatingChartScreenState
    extends State<ClassroomSeatingChartScreen> {
  static const _layoutOptionsSize = 12;

  DiscordUiColors get _colors => DiscordUiColors.of(context);

  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _availableClassrooms = const [];
  List<Map<String, dynamic>> _columnsData = const [];
  final Set<String> _newTableKeys = {};
  final _chartScrollController = SmoothMouseScrollController();
  final _seatingTransformController = TransformationController();
  late List<List<_SeatingTable>> _tables = _createGrid(4, 2);
  int _rows = 4;
  int _columns = 2;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  Map<String, dynamic>? _selectedStudent;
  bool _groupingPanelOpen = false;
  bool _groupingLoadingSubjects = false;
  bool _groupingRunning = false;
  _GroupingMode _groupingMode = _GroupingMode.random;
  int _groupingCount = 2;
  final _groupCountController = TextEditingController(text: '2');
  List<Map<String, dynamic>> _groupingSubjects = const [];
  final Set<String> _selectedGroupingSubjectIds = {};
  List<_GroupingResult>? _groupingResults;
  final _canvasViewportKey = GlobalKey();

  List<List<_SeatingTable>> _createGrid(int rows, int columns) => List.generate(
    rows,
    (_) => List.generate(columns, (_) => _SeatingTable()),
  );

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadAvailableClassrooms();
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    _seatingTransformController.dispose();
    _groupCountController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers({bool forceRefresh = false}) async {
    final cachedMembers = ClassroomService.getCachedClassroomMembers(
      widget.classroomId,
    );
    final cachedChart = ClassroomService.getCachedClassroomSeatingChart(
      widget.classroomId,
    );
    final hasCachedData = cachedMembers != null && cachedChart != null;
    setState(() {
      _isLoading = !hasCachedData;
      _loadError = null;
      if (hasCachedData) _applyLoadedChart(cachedMembers, cachedChart);
    });
    try {
      final results = await Future.wait([
        ClassroomService.getClassroomMembers(
          widget.classroomId,
          forceRefresh: forceRefresh,
        ),
        ClassroomService.getClassroomSeatingChart(
          widget.classroomId,
          forceRefresh: forceRefresh,
        ),
      ]);
      final members = results[0] as List<Map<String, dynamic>>;
      var chart = results[1] as Map<String, dynamic>;
      final initialColumns = (chart['columns'] as List)
          .cast<Map<String, dynamic>>();
      if (widget.canManage &&
          initialColumns.any((column) => column['id'] == null)) {
        await ClassroomService.saveClassroomSeatingChart(
          classroomId: widget.classroomId,
          rowCount: chart['row_count'] as int,
          columnCount: chart['column_count'] as int,
          columns: initialColumns,
          seats: const [],
        );
        chart = await ClassroomService.getClassroomSeatingChart(
          widget.classroomId,
        );
      }

      if (!mounted) return;
      setState(() {
        _applyLoadedChart(members, chart);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (hasCachedData) {
        setState(() => _isLoading = false);
        ToastService.showWarning(
          'Hiển thị sơ đồ đã lưu tạm thời. Không thể làm mới: $error',
        );
      } else {
        setState(() {
          _loadError = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applyLoadedChart(
    List<Map<String, dynamic>> members,
    Map<String, dynamic> chart,
  ) {
    final rows = chart['row_count'] as int;
    final columns = chart['column_count'] as int;
    _members = members
        .where(
          (member) => !const {
            'owner',
            'teacher',
          }.contains(member['role_in_class']?.toString().toLowerCase()),
        )
        .toList();
    _rows = rows;
    _columns = columns;
    _tables = _gridFromChart(chart, members);
    _columnsData = (chart['columns'] as List)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  Future<void> _loadAvailableClassrooms() async {
    try {
      final memberships = await ClassroomService.getMyClassrooms();
      if (!mounted) return;
      final classrooms = <Map<String, dynamic>>[];
      for (final membership in memberships) {
        final value = membership['classrooms'];
        final classroom = value is Map<String, dynamic>
            ? value
            : value is Map
            ? Map<String, dynamic>.from(value)
            : null;
        if (classroom?['id'] != null) {
          classrooms.add({
            ...classroom!,
            'role_in_class': membership['role_in_class'],
          });
        }
      }
      setState(() => _availableClassrooms = classrooms);
    } catch (error) {
      if (!mounted) return;
      ToastService.showError('Không tải được danh sách lớp: $error');
    }
  }

  Future<void> _switchClassroom(String classroomId) async {
    if (classroomId == widget.classroomId || !mounted) return;
    final classroom = _availableClassrooms.firstWhere(
      (item) => item['id']?.toString() == classroomId,
      orElse: () => const {},
    );
    if (classroom.isEmpty) return;
    final role = classroom['role_in_class']?.toString().toLowerCase();
    final canManage = role == 'owner' || role == 'teacher';
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ClassroomSeatingChartScreen(
          classroomId: classroomId,
          classroomName: classroom['name']?.toString() ?? 'Lớp học',
          canManage: canManage,
        ),
      ),
    );
  }

  Future<void> _persistChart() async {
    if (!widget.canManage || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final columns = [
        for (var index = 0; index < _columns; index++)
          {'column_index': index, 'name': _columnsData[index]['name']},
      ];
      final seats = [
        for (var row = 0; row < _rows; row++)
          for (var column = 0; column < _columns; column++)
            for (var seat = 0; seat < 2; seat++)
              if (_tables[row][column].students[seat] case final student?)
                {
                  'row_index': row,
                  'column_id': _columnsData[column]['id'],
                  'seat_index': seat,
                  'student_id': student['user_id'],
                },
      ];
      await ClassroomService.saveClassroomSeatingChart(
        classroomId: widget.classroomId,
        rowCount: _rows,
        columnCount: _columns,
        columns: columns,
        seats: seats,
      );
      final saved = await ClassroomService.getClassroomSeatingChart(
        widget.classroomId,
      );
      if (!mounted) return;
      setState(() {
        _rows = saved['row_count'] as int;
        _columns = saved['column_count'] as int;
        _tables = _gridFromChart(saved, _members);
        _columnsData = (saved['columns'] as List)
            .cast<Map<String, dynamic>>()
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      ToastService.showError(error.toString());
      await _loadMembers(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<List<_SeatingTable>> _gridFromChart(
    Map<String, dynamic> chart,
    List<Map<String, dynamic>> members,
  ) {
    final rows = chart['row_count'] as int;
    final columns = chart['column_count'] as int;
    final grid = _createGrid(rows, columns);
    final membersById = {
      for (final member in members) member['user_id'].toString(): member,
    };
    final columnIndexesById = {
      for (final column in chart['columns'] as List<Map<String, dynamic>>)
        column['id']?.toString(): column['column_index'] as int,
    };
    for (final seat in chart['seats'] as List<Map<String, dynamic>>) {
      final seatingColumnId = seat['seating_column_id']?.toString();
      final column = columnIndexesById[seatingColumnId];
      if (column == null) {
        throw StateError(
          'Ghế được lưu với ID cột không tồn tại. Hãy kiểm tra migration sơ đồ chỗ ngồi.',
        );
      }
      final row = seat['row_index'] as int;
      final index = seat['seat_index'] as int;
      final member = membersById[seat['student_id']?.toString()];
      if (row >= 0 &&
          row < rows &&
          column >= 0 &&
          column < columns &&
          index >= 0 &&
          index < 2 &&
          member != null) {
        grid[row][column].students[index] = member;
      }
    }
    return grid;
  }

  Set<String> get _seatedStudentIds => {
    for (final row in _tables)
      for (final table in row)
        for (final student in table.students)
          if (student != null) student['user_id'].toString(),
  };

  Future<void> _resizeGrid({required int rows, required int columns}) async {
    if (rows == _rows && columns == _columns) return;

    final oldStudents = [
      for (final row in _tables)
        for (final table in row)
          ...table.students.whereType<Map<String, dynamic>>(),
    ];
    final capacity = rows * columns * 2;
    if (capacity < oldStudents.length) {
      ToastService.showError(
        'Không thể thu nhỏ: bố cục mới không đủ chỗ cho ${oldStudents.length} học sinh đã xếp.',
      );
      return;
    }

    final resized = _createGrid(rows, columns);
    for (var row = 0; row < math.min(rows, _rows); row++) {
      for (var column = 0; column < math.min(columns, _columns); column++) {
        final oldTable = _tables[row][column];
        final newTable = resized[row][column];
        for (var seat = 0; seat < 2; seat++) {
          newTable.students[seat] = oldTable.students[seat];
        }
      }
    }

    final retainedIds = {
      for (final row in resized)
        for (final table in row)
          for (final student in table.students)
            if (student != null) student['user_id'].toString(),
    };
    final studentsToReassign = oldStudents
        .where(
          (student) => !retainedIds.contains(student['user_id'].toString()),
        )
        .toList();
    var nextStudent = 0;
    for (final row in resized) {
      for (final table in row) {
        for (
          var seat = 0;
          seat < 2 && nextStudent < studentsToReassign.length;
          seat++
        ) {
          if (table.students[seat] == null) {
            table.students[seat] = studentsToReassign[nextStudent++];
          }
        }
      }
    }

    final newColumnData = List<Map<String, dynamic>>.generate(
      columns,
      (index) => index < _columnsData.length
          ? _columnsData[index]
          : {'column_index': index, 'name': 'Cột ${index + 1}'},
    );
    _newTableKeys
      ..clear()
      ..addAll({
        for (var row = 0; row < rows; row++)
          for (var column = 0; column < columns; column++)
            if (row >= _rows || column >= _columns) '$row:$column',
      });
    setState(() {
      _rows = rows;
      _columns = columns;
      _tables = resized;
      _columnsData = newColumnData;
    });
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(_newTableKeys.clear);
    });
    await _persistChart();
  }

  Future<void> _addStudent(int row, int column, int seat) async {
    final alreadySeated = _seatedStudentIds;
    final availableStudents = _members
        .where(
          (member) =>
              !alreadySeated.contains(member['user_id']?.toString()) &&
              !const {
                'owner',
                'teacher',
              }.contains(member['role_in_class']?.toString().toLowerCase()),
        )
        .toList();
    final student = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _StudentPickerSheet(students: availableStudents, colors: _colors),
    );
    if (student == null || !mounted) return;
    setState(() => _tables[row][column].students[seat] = student);
    await _persistChart();
  }

  Future<void> _removeStudent(int row, int column, int seat) async {
    final seatingColumnId = _columnsData[column]['id']?.toString();
    if (seatingColumnId == null) {
      ToastService.showError('Không tìm thấy ID cột để gỡ học sinh.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ClassroomService.removeClassroomSeatingStudent(
        classroomId: widget.classroomId,
        seatingColumnId: seatingColumnId,
        rowIndex: row,
        seatIndex: seat,
        studentId: _tables[row][column].students[seat]!['user_id'].toString(),
      );
      if (!mounted) return;
      setState(() => _tables[row][column].students[seat] = null);
    } catch (error) {
      if (!mounted) return;
      ToastService.showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _moveStudent(
    Map<String, dynamic> student,
    int targetRow,
    int targetColumn,
    int targetSeat,
  ) async {
    if (!widget.canManage || _isSaving) return;

    final studentId = student['user_id']?.toString();
    if (studentId == null) return;
    for (var row = 0; row < _rows; row++) {
      for (var column = 0; column < _columns; column++) {
        for (var seat = 0; seat < 2; seat++) {
          if (_tables[row][column].students[seat]?['user_id']?.toString() ==
              studentId) {
            if (row == targetRow &&
                column == targetColumn &&
                seat == targetSeat) {
              return;
            }
            final targetStudent =
                _tables[targetRow][targetColumn].students[targetSeat];
            setState(() {
              _tables[row][column].students[seat] = null;
              _tables[targetRow][targetColumn].students[targetSeat] = student;
              if (targetStudent != null) {
                _tables[row][column].students[seat] = targetStudent;
              }
            });
            await _persistChart();
            return;
          }
        }
      }
    }
  }

  Future<void> _renameColumn(int column) async {
    final controller = TextEditingController(
      text: _columnsData[column]['name']?.toString() ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đặt tên cột'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Tên cột'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    setState(() => _columnsData[column]['name'] = name);
    await _persistChart();
  }

  void _selectStudent(Map<String, dynamic> student) {
    setState(() => _selectedStudent = student);
  }

  String _studentDisplayName(Map<String, dynamic> student) {
    final user = student['users'] as Map<String, dynamic>?;
    final name = user?['full_name']?.toString().trim();
    return name?.isNotEmpty == true ? name! : 'Học sinh';
  }

  String _tableLabel(int column, int row) {
    var value = column + 1;
    var label = '';
    while (value > 0) {
      value--;
      label = String.fromCharCode(65 + value % 26) + label;
      value ~/= 26;
    }
    return '$label${row + 1}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _colors.text,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            color: _colors.panel,
            border: Border(
              bottom: BorderSide(color: _colors.border.withValues(alpha: 0.55)),
            ),
          ),
        ),
        title: _buildClassroomSelect(),
      ),
      body: _isLoading
          ? const SeatingChartSkeleton()
          : _loadError != null
          ? _buildLoadError()
          : _buildChart(),
    );
  }

  Widget _buildLoadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 38, color: _colors.muted),
          const SizedBox(height: 12),
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _loadMembers(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );

  Widget _buildChart() => LayoutBuilder(
    builder: (context, constraints) {
      final inspectorOpen = _selectedStudent != null;
      final availableWidth = math
          .max(0, constraints.maxWidth - (inspectorOpen ? 420 : 0))
          .toDouble();
      final canvasHeight = math
          .max(380.0, constraints.maxHeight - 190)
          .toDouble();
      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: Column(
              children: [
                _buildStudioHeader(),
                const SizedBox(height: 14),
                Expanded(
                  child: SizedBox(
                    height: canvasHeight,
                    width: availableWidth,
                    child: _buildVerticalSeatingCanvas(availableWidth),
                  ),
                ),
                const SizedBox(height: 10),
                _buildCanvasFooter(),
              ],
            ),
          ),
          if (_selectedStudent case final student?)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedStudent = null),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.52),
                      ),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1, end: 0),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, child) =>
                        FractionalTranslation(
                          translation: Offset(progress, 0),
                          child: child,
                        ),
                    child: SizedBox(
                      width: math.min(420, constraints.maxWidth * 0.88),
                      child: _StudentIndexSheet(
                        classroomId: widget.classroomId,
                        studentId: student['user_id'].toString(),
                        studentName: _studentDisplayName(student),
                        studentRole:
                            student['role_in_class']?.toString() ?? 'Học sinh',
                        classroomName: widget.classroomName,
                        canManage: widget.canManage,
                        colors: _colors,
                        onClose: () => setState(() => _selectedStudent = null),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _buildStudioHeader() {
    final occupied = _tables
        .expand((group) => group)
        .expand((table) => table.students)
        .whereType<Map<String, dynamic>>()
        .length;
    final total = _rows * _columns * 2;
    final stats = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StudioStat(
          value: '$occupied/$total',
          label: 'ghế đã xếp',
          icon: Icons.event_seat_outlined,
          colors: _colors,
        ),
        const SizedBox(width: 10),
        _StudioStat(
          value: '$_rows × $_columns',
          label: 'bố cục hiện tại',
          icon: Icons.grid_view_rounded,
          colors: _colors,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStudioToolbar(scrollable: false),
                const SizedBox(width: 12),
                stats,
              ],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _buildStudioToolbar(scrollable: true)),
            const SizedBox(width: 14),
            stats,
          ],
        );
      },
    );
  }

  Widget _buildClassroomSelect() {
    final hasCurrentClass = _availableClassrooms.any(
      (classroom) => classroom['id']?.toString() == widget.classroomId,
    );
    final options = [
      if (!hasCurrentClass)
        GlideSelectOption<String>(
          value: widget.classroomId,
          label: widget.classroomName,
        ),
      for (final classroom in _availableClassrooms)
        GlideSelectOption<String>(
          value: classroom['id'].toString(),
          label: classroom['name']?.toString() ?? 'Lớp học',
        ),
    ];
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: _colors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _colors.border),
      ),
      child: GlideSelect<String>.dropdown(
        value: widget.classroomId,
        options: options,
        onChanged: _availableClassrooms.length < 2
            ? null
            : (value) {
                if (value != null) _switchClassroom(value);
              },
      ),
    );
  }

  Widget _buildStudioToolbar({required bool scrollable}) {
    final toolbar = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 650),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _colors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _colors.border.withValues(alpha: 0.9)),
        ),
        child: Row(
          children: [
            _StudioToolButton(
              buttonKey: const Key('seating-auto-assign'),
              icon: Icons.auto_awesome_rounded,
              label: 'Tự động xếp chỗ',
              accent: true,
              onPressed: _members.isEmpty ? null : _toggleGroupingPanel,
              colors: _colors,
            ),
            const SizedBox(width: 8),
            _StudioToolButton(
              icon: Icons.search_rounded,
              label: 'Tìm học sinh',
              onPressed: _members.isEmpty ? null : _showStudentSearch,
              colors: _colors,
            ),
            const SizedBox(width: 8),
            _StudioToolButton(
              buttonKey: const Key('seating-layout'),
              icon: Icons.grid_view_rounded,
              label: 'Bố cục',
              disabledMessage: widget.canManage
                  ? null
                  : 'Chỉ giáo viên hoặc chủ lớp mới có thể đổi bố cục.',
              onPressed: widget.canManage ? _showLayoutDialog : null,
              colors: _colors,
            ),
            const SizedBox(width: 20),
            Text(
              'VIEW',
              style: TextStyle(
                color: _colors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            _StudioIconButton(
              icon: Icons.remove_rounded,
              tooltip: 'Thu nhỏ',
              onPressed: () => _zoomSeatingCanvas(-1, Offset.zero),
              colors: _colors,
            ),
            _StudioIconButton(
              icon: Icons.center_focus_strong_rounded,
              tooltip: 'Căn giữa sơ đồ',
              onPressed: _recenterSeatingCanvas,
              colors: _colors,
            ),
            _StudioIconButton(
              icon: Icons.add_rounded,
              tooltip: 'Phóng to',
              onPressed: () => _zoomSeatingCanvas(1, Offset.zero),
              colors: _colors,
            ),
            const SizedBox(width: 5),
            _StudioToolButton(
              buttonKey: const Key('seating-refresh'),
              icon: Icons.refresh_rounded,
              label: 'Làm mới',
              onPressed: _isLoading
                  ? null
                  : () => _loadMembers(forceRefresh: true),
              colors: _colors,
            ),
          ],
        ),
      ),
    );
    if (!scrollable) return toolbar;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: toolbar,
    );
  }

  Widget _buildLayoutControls() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _colors.card,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _colors.border),
    ),
    child: Row(
      children: [
        Icon(Icons.grid_view_rounded, color: _colors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Bố cục',
            style: TextStyle(color: _colors.text, fontWeight: FontWeight.w600),
          ),
        ),
        GlideSelect<String>.dropdown(
          value: '$_rows×$_columns',
          options: [
            for (
              var rows = 1;
              rows <= math.max(_layoutOptionsSize, _rows);
              rows++
            )
              for (
                var columns = 1;
                columns <= math.max(_layoutOptionsSize, _columns);
                columns++
              )
                GlideSelectOption(
                  value: '$rows×$columns',
                  label: '$rows hàng × $columns cột',
                ),
          ],
          onChanged: !widget.canManage || _isSaving
              ? null
              : (value) {
                  if (value == null) return;
                  final dimensions = value.split('×');
                  _resizeGrid(
                    rows: int.parse(dimensions[0]),
                    columns: int.parse(dimensions[1]),
                  );

                  Widget buildWorkspaceHeader() => Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bản đồ lớp học & Hồ sơ học sinh',
                              style: TextStyle(
                                color: _colors.text,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${widget.classroomName}  /  Không gian quản lý trực quan',
                              style: TextStyle(
                                color: _colors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: !widget.canManage || _isSaving
                            ? null
                            : () => _resizeGrid(
                                rows: _rows,
                                columns: _columns + 1,
                              ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Thêm khu vực'),
                      ),
                    ],
                  );

                  Widget buildRoomPulse() {
                    final occupied = _tables
                        .expand((group) => group)
                        .expand((table) => table.students)
                        .whereType<Map<String, dynamic>>()
                        .length;
                    final total = _rows * _columns * 2;
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _colors.accent.withValues(alpha: 0.18),
                            _colors.panel,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _colors.accent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _colors.accent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.space_dashboard_rounded,
                              color: _colors.onAccent,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Không gian lớp học',
                                  style: TextStyle(
                                    color: _colors.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Kéo thả để sắp xếp. Chọn học sinh để mở hồ sơ chuyên sâu.',
                                  style: TextStyle(
                                    color: _colors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _PulseMetric(
                            value: '$occupied/$total',
                            label: 'đã xếp chỗ',
                            colors: _colors,
                          ),
                          const SizedBox(width: 18),
                          _PulseMetric(
                            value: '$_rows',
                            label: 'tổ / khu vực',
                            colors: _colors,
                          ),
                        ],
                      ),
                    );
                  }

                  Widget buildCanvasToolbar() => Row(
                    children: [
                      Text(
                        'Bản đồ lớp',
                        style: TextStyle(
                          color: _colors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(width: 220, child: _buildLayoutControls()),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: 'Thêm hàng',
                        onPressed: !widget.canManage || _isSaving
                            ? null
                            : () => _resizeGrid(
                                rows: _rows + 1,
                                columns: _columns,
                              ),
                        icon: const Icon(Icons.view_agenda_outlined),
                      ),
                    ],
                  );

                  Widget buildGroupHeader(int row) => Row(
                    children: [
                      Container(
                        width: 8,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _colors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Tổ ${row + 1}',
                        style: TextStyle(
                          color: _colors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_columns bàn học',
                        style: TextStyle(color: _colors.muted, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        'Khu vực ${String.fromCharCode(65 + row)}',
                        style: TextStyle(color: _colors.muted, fontSize: 11),
                      ),
                    ],
                  );

                  Widget buildCanvasFooter() => Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: _colors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mỗi bàn có hai vị trí. Học sinh được chọn sẽ mở inspector ở cạnh phải.',
                          style: TextStyle(color: _colors.muted, fontSize: 11),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.canManage
                            ? () => _loadMembers(forceRefresh: true)
                            : null,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Làm mới'),
                      ),
                    ],
                  );
                  assert(() {
                    buildWorkspaceHeader();
                    buildRoomPulse();
                    buildCanvasToolbar();
                    buildGroupHeader(0);
                    buildCanvasFooter();
                    return true;
                  }());
                },
        ),
      ],
    ),
  );

  // ignore: unused_element
  Widget _buildWorkspaceHeader() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bản đồ lớp học',
              style: TextStyle(
                color: _colors.text,
                fontSize: 28,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tổ chức không gian lớp học và mở nhanh hồ sơ từng học sinh.',
              style: TextStyle(color: _colors.muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
      const SizedBox(width: 20),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            widget.classroomName,
            style: TextStyle(
              color: _colors.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          DecoratedBox(
            decoration: BoxDecoration(
              color: widget.canManage
                  ? _colors.accent.withValues(alpha: 0.12)
                  : _colors.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: widget.canManage
                    ? _colors.accent.withValues(alpha: 0.32)
                    : _colors.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.canManage
                        ? Icons.edit_outlined
                        : Icons.visibility_outlined,
                    size: 13,
                    color: widget.canManage ? _colors.accent : _colors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.canManage ? 'Chế độ quản lý' : 'Chỉ xem',
                    style: TextStyle(
                      color: widget.canManage ? _colors.accent : _colors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );

  // ignore: unused_element
  Widget _buildRoomPulse() {
    final occupied = _tables
        .expand((group) => group)
        .expand((table) => table.students)
        .whereType<Map<String, dynamic>>()
        .length;
    final total = _rows * _columns * 2;
    final ratio = total == 0 ? 0.0 : occupied / total;
    return TweenAnimationBuilder<double>(
      key: ValueKey('$occupied-$total'),
      tween: Tween(begin: 0, end: ratio),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _colors.accent.withValues(alpha: 0.18),
              _colors.panel,
              _colors.panel,
            ],
            stops: const [0, 0.38, 1],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _colors.accent.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: _colors.accent.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _colors.accent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _colors.accent.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Icon(
                Icons.space_dashboard_rounded,
                color: _colors.onAccent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Không gian lớp học',
                    style: TextStyle(
                      color: _colors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Kéo thả để sắp xếp. Nhấn vào học sinh để xem hồ sơ.',
                    style: TextStyle(color: _colors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: _colors.card.withValues(alpha: 0.8),
                      valueColor: AlwaysStoppedAnimation(_colors.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            _PulseMetric(
              value: '$occupied/$total',
              label: 'đã xếp chỗ',
              colors: _colors,
            ),
            const SizedBox(width: 22),
            _PulseMetric(
              value: '$_rows × $_columns',
              label: 'bố cục',
              colors: _colors,
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildActionRail() => SizedBox(
    width: 92,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
          decoration: BoxDecoration(
            color: _colors.panel.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _colors.border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'CÔNG CỤ',
                style: TextStyle(
                  color: _colors.muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 2,
                width: 28,
                decoration: BoxDecoration(
                  color: _colors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              _ClassroomActionButton(
                icon: Icons.grid_view_rounded,
                label: 'Bố cục',
                onPressed: widget.canManage ? _showLayoutDialog : null,
                colors: _colors,
              ),
              _ClassroomActionButton(
                icon: Icons.view_column_outlined,
                label: 'Thêm cột',
                onPressed: !widget.canManage || _isSaving
                    ? null
                    : () => _resizeGrid(rows: _rows, columns: _columns + 1),
                colors: _colors,
              ),
              _ClassroomActionButton(
                icon: Icons.view_agenda_outlined,
                label: 'Thêm hàng',
                onPressed: !widget.canManage || _isSaving
                    ? null
                    : () => _resizeGrid(rows: _rows + 1, columns: _columns),
                colors: _colors,
              ),
              const Divider(height: 18),
              _ClassroomActionButton(
                icon: Icons.shuffle_rounded,
                label: 'Ngẫu nhiên',
                onPressed: _members.isEmpty ? null : _selectRandomStudent,
                colors: _colors,
              ),
              _ClassroomActionButton(
                icon: Icons.account_tree_outlined,
                label: 'Chia nhóm',
                onPressed: _members.isEmpty ? null : _toggleGroupingPanel,
                colors: _colors,
              ),
              _ClassroomActionButton(
                icon: Icons.search_rounded,
                label: 'Tra cứu',
                onPressed: _members.isEmpty ? null : _showStudentSearch,
                colors: _colors,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildVerticalSeatingCanvas(double contentWidth) {
    final tableWidth = math.max(190.0, math.min(250.0, contentWidth / 4));
    final canvasWidth =
        34 + _columns * tableWidth + math.max(0, _columns - 1) * 14;
    final canvasHeight = 58 + _rows * 224 + math.max(0, _rows - 1) * 12;
    final resultsWidth = _groupingResults == null
        ? 0.0
        : (48 +
                  _groupingResults!.length * 220 +
                  math.max(0, _groupingResults!.length - 1) * 10)
              .toDouble();
    final viewportWidth = math.max(0.0, contentWidth - 28);
    final viewportHeight = math.max(
      0.0,
      math.min(
            620.0,
            math.max(380.0, MediaQuery.sizeOf(context).height - 190),
          ) -
          28,
    );
    final workspaceWidth = math.max(canvasWidth + resultsWidth, viewportWidth);
    final workspaceHeight = math.max(canvasHeight.toDouble(), viewportHeight);
    return Container(
      height: math.min(
        620,
        math.max(380, MediaQuery.sizeOf(context).height - 190),
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _colors.background.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _colors.border.withValues(alpha: 0.8)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            right: 14,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _colors.panel.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _colors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pan_tool_alt_outlined,
                        size: 13,
                        color: _colors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Kéo để di chuyển · Cuộn để zoom',
                        style: TextStyle(color: _colors.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _zoomSeatingCanvas(event.scrollDelta.dy, event.localPosition);
              }
            },
            child: RepaintBoundary(
              child: InteractiveViewer.builder(
                transformationController: _seatingTransformController,
                boundaryMargin: const EdgeInsets.all(10000),
                minScale: 0.45,
                maxScale: 2.5,
                panEnabled: true,
                scaleEnabled: true,
                trackpadScrollCausesScale: false,
                key: _canvasViewportKey,
                builder: (context, viewport) {
                  final left = math.min(
                    math.min(viewport.point0.x, viewport.point1.x),
                    math.min(viewport.point2.x, viewport.point3.x),
                  );
                  final top = math.min(
                    math.min(viewport.point0.y, viewport.point1.y),
                    math.min(viewport.point2.y, viewport.point3.y),
                  );
                  final right = math.max(
                    math.max(viewport.point0.x, viewport.point1.x),
                    math.max(viewport.point2.x, viewport.point3.x),
                  );
                  final bottom = math.max(
                    math.max(viewport.point0.y, viewport.point1.y),
                    math.max(viewport.point2.y, viewport.point3.y),
                  );
                  return _buildVisibleSeatingScene(
                    viewport: Rect.fromLTRB(left, top, right, bottom),
                    workspaceWidth: workspaceWidth,
                    workspaceHeight: workspaceHeight,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight.toDouble(),
                    resultsWidth: resultsWidth,
                    tableWidth: tableWidth,
                  );
                },
              ),
            ),
          ),
          if (_groupingPanelOpen)
            Positioned(
              left: 12,
              top: 46,
              child: SizedBox(
                width: math.max(0.0, math.min(360.0, contentWidth - 36)),
                child: _buildGroupingOverlay(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisibleSeatingScene({
    required Rect viewport,
    required double workspaceWidth,
    required double workspaceHeight,
    required double canvasWidth,
    required double canvasHeight,
    required double resultsWidth,
    required double tableWidth,
  }) {
    const rowStride = 236.0;
    final firstRow = ((viewport.top - 48) / rowStride)
        .floor()
        .clamp(0, _rows)
        .toInt();
    final lastRow = ((viewport.bottom - 48) / rowStride)
        .ceil()
        .clamp(0, _rows)
        .toInt();
    final columnStride = tableWidth + 14;
    final firstColumn = ((viewport.left - 34) / columnStride)
        .floor()
        .clamp(0, _columns)
        .toInt();
    final lastColumn = ((viewport.right - 34) / columnStride)
        .ceil()
        .clamp(0, _columns)
        .toInt();
    final children = <Widget>[
      Positioned(
        left: 0,
        top: 0,
        width: canvasWidth,
        height: canvasHeight,
        child: IgnorePointer(
          child: CustomPaint(
            painter: _DottedGridPainter(
              color: _colors.accent.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    ];

    for (var row = firstRow; row < lastRow; row++) {
      children.add(
        Positioned(
          left: 0,
          top: 48 + row * rowStride,
          width: 34,
          height: 224,
          child: Center(
            child: Text(
              '${row + 1}',
              style: TextStyle(
                color: _colors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    for (var column = firstColumn; column < lastColumn; column++) {
      final left = 34 + column * columnStride;
      if (viewport.top <= 48 && viewport.bottom >= 0) {
        children.add(
          Positioned(
            left: left,
            top: 0,
            width: tableWidth,
            height: 48,
            child: _buildGroupNameEditor(column),
          ),
        );
      }
      for (var row = firstRow; row < lastRow; row++) {
        children.add(
          Positioned(
            left: left,
            top: 58 + row * rowStride,
            width: tableWidth,
            height: 224,
            child: _buildTable(row, column),
          ),
        );
      }
    }

    final resultsLeft =
        34 + _columns * tableWidth + math.max(0, _columns - 1) * 14 + 48;
    if (_groupingResults != null &&
        viewport.right >= resultsLeft &&
        viewport.left <= resultsLeft + resultsWidth) {
      children.add(
        Positioned(left: resultsLeft, top: 0, child: _buildGroupingResults()),
      );
    }

    return SizedBox(
      width: workspaceWidth,
      height: workspaceHeight,
      child: Stack(children: children),
    );
  }

  void _zoomSeatingCanvas(double scrollDelta, Offset focalPoint) {
    final currentScale = _seatingTransformController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * (scrollDelta > 0 ? 0.9 : 1.1))
        .clamp(0.45, 2.5)
        .toDouble();
    if (targetScale == currentScale) return;
    final ratio = targetScale / currentScale;
    _seatingTransformController.value = Matrix4.identity()
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
      ..scaleByDouble(ratio, ratio, ratio, 1)
      ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1)
      ..multiply(_seatingTransformController.value);
  }

  void _recenterSeatingCanvas() {
    if (_groupingResults == null) {
      _seatingTransformController.value = Matrix4.identity();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitCanvasToContent();
    });
  }

  void _fitCanvasToContent() {
    final viewport =
        _canvasViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final results = _groupingResults;
    final tableWidth = math.max(
      190.0,
      math.min(250.0, viewport.size.width / 4),
    );
    final chartWidth =
        34 + _columns * tableWidth + math.max(0, _columns - 1) * 14;
    final resultsWidth = results == null
        ? 0.0
        : results.length * 220 + math.max(0, results.length - 1) * 10;
    final contentWidth = chartWidth + (results == null ? 0 : 48 + resultsWidth);
    final scale = ((viewport.size.width - 32) / contentWidth)
        .clamp(0.45, 1.0)
        .toDouble();
    final resultsHeight = results == null
        ? 0.0
        : math.min(
            560.0,
            math.max(380.0, 58 + _rows * 224 + math.max(0, _rows - 1) * 12),
          );
    final contentHeight = math.max(
      58 + _rows * 224 + math.max(0, _rows - 1) * 12,
      resultsHeight,
    );
    final offsetX = (viewport.size.width - contentWidth * scale) / 2;
    final offsetY = math.max(
      16.0,
      (viewport.size.height - contentHeight * scale) / 2,
    );
    _seatingTransformController.value = Matrix4.identity()
      ..translateByDouble(offsetX, offsetY, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  Widget _buildGroupNameEditor(int column) {
    final name = _columnsData[column]['name']?.toString().trim();
    return InkWell(
      key: Key('rename-seating-column-$column'),
      onTap: widget.canManage ? () => _renameColumn(column) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _colors.accent.withValues(alpha: 0.18),
              _colors.accent.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _colors.accent.withValues(alpha: 0.36)),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _colors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name?.isNotEmpty == true ? name! : 'Tổ ${column + 1}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _colors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(Icons.edit_outlined, size: 15, color: _colors.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasFooter() => Row(
    children: [
      Icon(Icons.info_outline_rounded, size: 16, color: _colors.muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Số bên trái là thứ tự dãy; tiêu đề phía trên là tên tổ và áp dụng cho toàn bộ cột.',
          style: TextStyle(color: _colors.muted, fontSize: 11),
        ),
      ),
      TextButton.icon(
        onPressed: widget.canManage
            ? () => _loadMembers(forceRefresh: true)
            : null,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Làm mới'),
      ),
    ],
  );

  Future<void> _showLayoutDialog() async {
    final dimensions = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Điều chỉnh bố cục'),
        content: GlideSelect<String>.dropdown(
          value: '$_rows×$_columns',
          decoration: const InputDecoration(labelText: 'Kích thước sơ đồ'),
          options: [
            for (
              var rows = 1;
              rows <= math.max(_layoutOptionsSize, _rows);
              rows++
            )
              for (
                var columns = 1;
                columns <= math.max(_layoutOptionsSize, _columns);
                columns++
              )
                GlideSelectOption(
                  value: '$rows×$columns',
                  label: '$rows hàng × $columns cột',
                ),
          ],
          onChanged: (value) => Navigator.of(dialogContext).pop(value),
        ),
      ),
    );
    if (dimensions == null || !mounted) return;
    final values = dimensions.split('×');
    await _resizeGrid(
      rows: int.parse(values[0]),
      columns: int.parse(values[1]),
    );
  }

  void _selectRandomStudent() {
    final students = _members
        .where(
          (member) => !const {
            'owner',
            'teacher',
          }.contains(member['role_in_class']?.toString().toLowerCase()),
        )
        .toList();
    if (students.isEmpty) return;
    final student = students[math.Random().nextInt(students.length)];
    _selectStudent(student);
  }

  Future<void> _showStudentSearch() async {
    final student = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _StudentSearchDialog(students: _members, colors: _colors),
    );
    if (student != null && mounted) _selectStudent(student);
  }

  List<Map<String, dynamic>> get _groupableStudents => _members
      .where(
        (member) => !const {
          'owner',
          'teacher',
        }.contains(member['role_in_class']?.toString().toLowerCase()),
      )
      .toList();

  void _toggleGroupingPanel() {
    setState(() => _groupingPanelOpen = !_groupingPanelOpen);
    if (_groupingPanelOpen && _groupingSubjects.isEmpty) {
      _loadGroupingSubjects();
    }
  }

  Future<void> _loadGroupingSubjects() async {
    final students = _groupableStudents;
    if (students.isEmpty) return;
    setState(() => _groupingLoadingSubjects = true);
    try {
      final subjects = await ClassroomService.getStudentSubjectIndexData(
        classroomId: widget.classroomId,
        studentId: students.first['user_id'].toString(),
      );
      if (!mounted) return;
      setState(() {
        _groupingSubjects = subjects
            .map(
              (entry) => {
                'id': (entry['subject'] as Map<String, dynamic>)['id']
                    .toString(),
                'name': (entry['subject'] as Map<String, dynamic>)['name']
                    .toString(),
              },
            )
            .toList();
        _groupingLoadingSubjects = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _groupingLoadingSubjects = false);
      ToastService.showError('Không tải được danh sách môn: $error');
    }
  }

  Future<void> _generateGroups() async {
    final students = _groupableStudents;
    if (_groupingCount > students.length) {
      ToastService.showError('Số nhóm không thể lớn hơn số học sinh.');
      return;
    }
    if (_groupingMode == _GroupingMode.bySubject &&
        _selectedGroupingSubjectIds.isEmpty) {
      ToastService.showError('Hãy chọn ít nhất một môn để cân bằng.');
      return;
    }
    setState(() => _groupingRunning = true);
    try {
      final scoreByStudent = <String, double>{};
      final averageByStudent = <String, double>{};
      final subjectScoresByStudent = <String, Map<String, double>>{};
      final subjectData = await Future.wait(
        students.map(
          (student) => ClassroomService.getStudentSubjectRates(
            studentId: student['user_id'].toString(),
          ),
        ),
      );
      for (var index = 0; index < students.length; index++) {
        final studentId = students[index]['user_id'].toString();
        final allScores = <double>[];
        final selectedScores = <String, double>{};
        for (final entry in subjectData[index]) {
          final subject = entry['subject'] as Map<String, dynamic>;
          final rate = entry['rate'] as Map<String, dynamic>?;
          final score = (rate?['score'] as num?)?.toDouble() ?? 5.0;
          allScores.add(score);
          final subjectId = subject['id'].toString();
          if (_selectedGroupingSubjectIds.contains(subjectId)) {
            selectedScores[subjectId] = score;
          }
        }
        if (allScores.isNotEmpty) {
          averageByStudent[studentId] =
              allScores.reduce((a, b) => a + b) / allScores.length;
        }
        subjectScoresByStudent[studentId] = selectedScores;
        if (selectedScores.isNotEmpty) {
          final selectedValues = selectedScores.values;
          scoreByStudent[studentId] =
              selectedValues.reduce((a, b) => a + b) / selectedValues.length;
        }
      }

      final ordered = [...students];
      if (_groupingMode == _GroupingMode.bySubject) {
        ordered.shuffle(math.Random());
        ordered.sort((a, b) {
          final scoreA = scoreByStudent[a['user_id'].toString()];
          final scoreB = scoreByStudent[b['user_id'].toString()];
          if (scoreA == null) return scoreB == null ? 0 : 1;
          if (scoreB == null) return -1;
          return scoreB.compareTo(scoreA);
        });
      } else {
        ordered.shuffle(math.Random());
      }
      final groups = List.generate(
        _groupingCount,
        (_) => <Map<String, dynamic>>[],
      );
      for (var index = 0; index < ordered.length; index++) {
        final round = index ~/ _groupingCount;
        final position = index % _groupingCount;
        final groupIndex = round.isEven
            ? position
            : _groupingCount - position - 1;
        groups[groupIndex].add(ordered[index]);
      }
      if (!mounted) return;
      setState(() {
        _groupingResults = [
          for (var index = 0; index < groups.length; index++)
            _GroupingResult(
              index: index,
              students: groups[index],
              scores: scoreByStudent,
              averageByStudent: averageByStudent,
              subjectScoresByStudent: subjectScoresByStudent,
              selectedSubjects: [
                for (final subject in _groupingSubjects)
                  if (_selectedGroupingSubjectIds.contains(
                    subject['id'].toString(),
                  ))
                    subject,
              ],
            ),
        ];
        _groupingRunning = false;
        _groupingPanelOpen = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitCanvasToContent();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _groupingRunning = false);
      ToastService.showError('Không thể chia nhóm: $error');
    }
  }

  Widget _buildGroupingOverlay() => Material(
    color: Colors.transparent,
    elevation: 18,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: _colors.panel.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors.accent.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(children: [_buildGroupingPanel()]),
      ),
    ),
  );

  Widget _buildGroupingPanel() {
    final canGenerate =
        !_groupingRunning &&
        _groupingCount > 0 &&
        _groupingCount <= _groupableStudents.length &&
        (_groupingMode != _GroupingMode.bySubject ||
            _selectedGroupingSubjectIds.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_tree_rounded, color: _colors.accent, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Thiết lập chia nhóm',
                style: TextStyle(
                  color: _colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _groupingPanelOpen = false),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
        SegmentedButton<_GroupingMode>(
          segments: const [
            ButtonSegment(
              value: _GroupingMode.random,
              label: Text('Ngẫu nhiên'),
              icon: Icon(Icons.shuffle, size: 16),
            ),
            ButtonSegment(
              value: _GroupingMode.bySubject,
              label: Text('Subject Rate'),
              icon: Icon(Icons.insights, size: 16),
            ),
          ],
          selected: {_groupingMode},
          onSelectionChanged: (value) => setState(() {
            _groupingMode = value.first;
            _groupingResults = null;
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.groups_outlined, size: 18, color: _colors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Số nhóm',
                style: TextStyle(color: _colors.muted, fontSize: 12),
              ),
            ),
            SizedBox(
              width: 92,
              child: TextField(
                controller: _groupCountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  isDense: true,
                  suffixText: 'nhóm',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0 && parsed <= 12) {
                    setState(() {
                      _groupingCount = parsed;
                      _groupingResults = null;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        if (_groupingMode == _GroupingMode.bySubject) ...[
          const SizedBox(height: 8),
          Text(
            'Môn dùng để cân bằng',
            style: TextStyle(color: _colors.muted, fontSize: 11),
          ),
          const SizedBox(height: 5),
          if (_groupingLoadingSubjects)
            const LinearProgressIndicator()
          else if (_groupingSubjects.isEmpty)
            Text(
              'Chưa có môn học để chọn.',
              style: TextStyle(color: _colors.muted, fontSize: 12),
            )
          else
            _SubjectTagInput(
              subjects: _groupingSubjects,
              selectedIds: _selectedGroupingSubjectIds,
              colors: _colors,
              onSelected: (subjectId) => setState(() {
                _selectedGroupingSubjectIds.add(subjectId);
                _groupingResults = null;
              }),
              onRemoved: (subjectId) => setState(() {
                _selectedGroupingSubjectIds.remove(subjectId);
                _groupingResults = null;
              }),
            ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canGenerate ? _generateGroups : null,
            icon: _groupingRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 17),
            label: Text(_groupingRunning ? 'Đang chia...' : 'Tạo bảng nhóm'),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupingResults() {
    final results = _groupingResults!;
    final height = math
        .min(
          560.0,
          math.max(380.0, 58 + _rows * 224 + math.max(0, _rows - 1) * 12),
        )
        .toDouble();
    return SizedBox(
      width: (results.length * 220 + math.max(0, results.length - 1) * 10)
          .toDouble(),
      height: height,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: _colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _colors.accent.withValues(alpha: 0.38)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DottedGridPainter(
                    color: _colors.accent.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_tree_rounded,
                      color: _colors.accent,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nhóm học tập',
                            style: TextStyle(
                              color: _colors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _groupingMode == _GroupingMode.random
                                ? 'Bản xem trước · Ngẫu nhiên · ${results.length} nhóm'
                                : 'Bản xem trước · Cân bằng Subject Rate · ${results.length} nhóm',
                            style: TextStyle(
                              color: _colors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ẩn kết quả chia nhóm',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _groupingResults = null),
                      icon: Icon(Icons.close_rounded, color: _colors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final group in results) ...[
                          SizedBox(
                            width: 220,
                            child: _buildGroupingColumn(group),
                          ),
                          if (group.index < results.length - 1)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _moveGroupedStudent(
    String studentId,
    int destinationGroup, {
    String? beforeStudentId,
  }) {
    final groups = _groupingResults;
    if (groups == null ||
        destinationGroup < 0 ||
        destinationGroup >= groups.length ||
        studentId == beforeStudentId) {
      return;
    }

    _GroupingResult? source;
    Map<String, dynamic>? student;
    for (final group in groups) {
      final index = group.students.indexWhere(
        (item) => item['user_id']?.toString() == studentId,
      );
      if (index >= 0) {
        source = group;
        student = group.students.removeAt(index);
        break;
      }
    }
    if (source == null || student == null) return;

    final destination = groups[destinationGroup];
    final insertAt = beforeStudentId == null
        ? destination.students.length
        : destination.students.indexWhere(
            (item) => item['user_id']?.toString() == beforeStudentId,
          );
    if (source == destination &&
        (insertAt < 0 || insertAt == source.students.length)) {
      source.students.add(student);
    } else {
      destination.students.insert(
        insertAt < 0 ? destination.students.length : insertAt,
        student,
      );
    }
    setState(() {});
  }

  Widget _buildGroupingColumn(_GroupingResult group) => DragTarget<String>(
    key: ValueKey('group-target-${group.index}'),
    onWillAcceptWithDetails: (details) =>
        _groupingResults?.any(
          (candidate) => candidate.students.any(
            (student) => student['user_id']?.toString() == details.data,
          ),
        ) ??
        false,
    onAcceptWithDetails: (details) =>
        _moveGroupedStudent(details.data, group.index),
    builder: (context, candidates, rejected) => AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: candidates.isNotEmpty
            ? Color.lerp(
                _colors.panel,
                _colors.accent.withValues(alpha: 0.09),
                0.42,
              )
            : _colors.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: candidates.isNotEmpty
              ? _colors.accent.withValues(alpha: 0.6)
              : _colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _colors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${group.index + 1}',
                  style: TextStyle(
                    color: _colors.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nhóm ${group.index + 1}',
                  style: TextStyle(
                    color: _colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_groupingMode == _GroupingMode.bySubject &&
                  group.averageScore != null)
                Text(
                  group.averageScore!.toStringAsFixed(2),
                  style: TextStyle(
                    color: _colors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const Divider(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: group.students.length,
              separatorBuilder: (_, _) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final student = group.students[index];
                final studentId = student['user_id'].toString();
                final reduceMotion = MediaQuery.disableAnimationsOf(context);
                final subjectScores =
                    group.subjectScoresByStudent[studentId] ?? const {};
                final subjectRates = [
                  for (final subject in group.selectedSubjects)
                    _SubjectRateValue(
                      name: subject['name'].toString(),
                      score: subjectScores[subject['id'].toString()],
                    ),
                ];
                return DragTarget<String>(
                  key: ValueKey('group-${group.index}-student-$studentId'),
                  onWillAcceptWithDetails: (details) =>
                      details.data != studentId,
                  onAcceptWithDetails: (details) => _moveGroupedStudent(
                    details.data,
                    group.index,
                    beforeStudentId: studentId,
                  ),
                  builder: (context, candidates, rejected) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        height: candidates.isNotEmpty ? 48 : 0,
                        margin: EdgeInsets.only(
                          bottom: candidates.isNotEmpty ? 6 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: _colors.accent.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: _colors.accent.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      _GroupingStudentCard(
                        studentId: studentId,
                        name: _studentDisplayName(student),
                        overallAverage: group.averageByStudent[studentId],
                        subjectRates: subjectRates,
                        width: 196,
                        colors: _colors,
                        groupIndex: group.index,
                        groupCount: _groupingResults?.length ?? 0,
                        isDropTarget: candidates.isNotEmpty,
                        reduceMotion: reduceMotion,
                        onMoveToGroup: (destination) =>
                            _moveGroupedStudent(studentId, destination),
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
  );

  Widget _buildTable(int row, int column) {
    final table = _tables[row][column];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _colors.panel.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _newTableKeys.contains('$row:$column')
              ? _colors.accent
              : _colors.border,
          width: _newTableKeys.contains('$row:$column') ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _tableLabel(column, row),
                  style: TextStyle(
                    color: _colors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _columnsData[column]['name']?.toString() ??
                      'Bàn ${column + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _colors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.canManage)
                IconButton(
                  key: Key('rename-seating-column-$column'),
                  onPressed: () => _renameColumn(column),
                  icon: Icon(Icons.more_horiz_rounded, color: _colors.muted),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                for (var seat = 0; seat < 2; seat++) ...[
                  if (seat > 0) const SizedBox(width: 8),
                  Expanded(
                    child: table.students[seat] == null
                        ? DragTarget<Map<String, dynamic>>(
                            onWillAcceptWithDetails: (details) =>
                                widget.canManage &&
                                !_isSaving &&
                                details.data['user_id'] != null,
                            onAcceptWithDetails: (details) =>
                                _moveStudent(details.data, row, column, seat),
                            builder: (context, candidates, rejected) =>
                                _EmptySeat(
                                  colors: _colors,
                                  highlighted: candidates.isNotEmpty,
                                  onTap: widget.canManage && !_isSaving
                                      ? () => _addStudent(row, column, seat)
                                      : null,
                                ),
                          )
                        : _buildOccupiedSeat(
                            table.students[seat]!,
                            row,
                            column,
                            seat,
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupiedSeat(
    Map<String, dynamic> student,
    int row,
    int column,
    int seat,
  ) {
    final occupiedSeat = PressScale(
      child: _OccupiedSeat(
        student: student,
        colors: _colors,
        onTap: () => _selectStudent(student),
        onRemove: widget.canManage && !_isSaving
            ? () => _removeStudent(row, column, seat)
            : null,
      ),
    );
    if (!widget.canManage || _isSaving) return occupiedSeat;

    return Draggable<Map<String, dynamic>>(
      data: student,
      feedback: Material(
        color: Colors.transparent,
        elevation: 14,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 96,
          height: 112,
          child: Opacity(
            opacity: 0.88,
            child: Transform.scale(
              scale: 0.96,
              child: _OccupiedSeat(
                student: student,
                colors: _colors,
                onTap: () {},
                onRemove: null,
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.28, child: occupiedSeat),
      child: occupiedSeat,
    );
  }
}

enum _GroupingMode { random, bySubject }

class _SubjectRateValue {
  const _SubjectRateValue({required this.name, required this.score});

  final String name;
  final double? score;
}

class _GroupingResult {
  const _GroupingResult({
    required this.index,
    required this.students,
    required this.scores,
    required this.averageByStudent,
    required this.subjectScoresByStudent,
    required this.selectedSubjects,
  });

  final int index;
  final List<Map<String, dynamic>> students;
  final Map<String, double> scores;
  final Map<String, double> averageByStudent;
  final Map<String, Map<String, double>> subjectScoresByStudent;
  final List<Map<String, dynamic>> selectedSubjects;

  double? get averageScore {
    final knownScores = students
        .map((student) => scores[student['user_id'].toString()])
        .whereType<double>()
        .toList();
    if (knownScores.isEmpty) return null;
    return knownScores.reduce((a, b) => a + b) / knownScores.length;
  }
}

// Lucian UX/UI Prompt #255 · MIT License (c) 2026 Seokwoooo · https://lucianlabs.dev/uxui-prompt/#255
class _GroupingStudentCard extends StatelessWidget {
  const _GroupingStudentCard({
    required this.studentId,
    required this.name,
    required this.overallAverage,
    required this.subjectRates,
    required this.width,
    required this.colors,
    required this.groupIndex,
    required this.groupCount,
    required this.isDropTarget,
    required this.reduceMotion,
    required this.onMoveToGroup,
  });

  final String studentId;
  final String name;
  final double? overallAverage;
  final List<_SubjectRateValue> subjectRates;
  final double width;
  final DiscordUiColors colors;
  final int groupIndex;
  final int groupCount;
  final bool isDropTarget;
  final bool reduceMotion;
  final ValueChanged<int> onMoveToGroup;

  Widget _buildCard({bool dimmed = false}) => AnimatedContainer(
    duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
    curve: Curves.easeOut,
    width: width,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: isDropTarget
          ? Color.lerp(colors.card, colors.accent.withValues(alpha: 0.1), 0.4)
          : colors.card,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(
        color: isDropTarget
            ? colors.accent.withValues(alpha: 0.65)
            : colors.border.withValues(alpha: 0.5),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Opacity(
      opacity: dimmed ? 0.22 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.drag_indicator_rounded,
                size: 15,
                color: colors.muted.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildMetric(
                label: 'Trung bình',
                score: overallAverage,
                emphasize: true,
              ),
              for (final rate in subjectRates)
                _buildMetric(label: rate.name, score: rate.score),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildMetric({
    required String label,
    required double? score,
    bool emphasize = false,
  }) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width - 18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: (emphasize ? colors.accent : colors.muted).withValues(
          alpha: emphasize ? 0.13 : 0.1,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: emphasize ? colors.accent : colors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            score?.toStringAsFixed(2) ?? '—',
            style: TextStyle(
              color: colors.text,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final direction = switch (event.logicalKey) {
        LogicalKeyboardKey.arrowLeft => -1,
        LogicalKeyboardKey.arrowRight => 1,
        _ => 0,
      };
      final destination = groupIndex + direction;
      if (direction == 0 || destination < 0 || destination >= groupCount) {
        return KeyEventResult.ignored;
      }
      onMoveToGroup(destination);
      return KeyEventResult.handled;
    },
    child: Semantics(
      button: true,
      label:
          '$name, Subject Rate trung bình ${overallAverage?.toStringAsFixed(2) ?? 'chưa có'}, kéo để chuyển nhóm hoặc dùng phím mũi tên trái phải',
      child: Draggable<String>(
        data: studentId,
        maxSimultaneousDrags: 1,
        feedback: Material(
          color: Colors.transparent,
          elevation: 12,
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: width,
            child: Transform.rotate(
              angle: 0.05236,
              child: Transform.scale(scale: 1.04, child: _buildCard()),
            ),
          ),
        ),
        childWhenDragging: _buildCard(dimmed: true),
        child: _buildCard(),
      ),
    ),
  );
}

class _SeatingTable {
  final List<Map<String, dynamic>?> students = [null, null];
}

// Lucian UX/UI Prompt #029 · MIT License (c) 2026 Seokwoooo · https://lucianlabs.dev/uxui-prompt/#029
class _SubjectTagInput extends StatefulWidget {
  const _SubjectTagInput({
    required this.subjects,
    required this.selectedIds,
    required this.colors,
    required this.onSelected,
    required this.onRemoved,
  });

  final List<Map<String, dynamic>> subjects;
  final Set<String> selectedIds;
  final DiscordUiColors colors;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onRemoved;

  @override
  State<_SubjectTagInput> createState() => _SubjectTagInputState();
}

class _SubjectTagInputState extends State<_SubjectTagInput> {
  static const _tagColors = [
    Color(0xFF7B61FF),
    Color(0xFFE0457B),
    Color(0xFF0E9F8E),
    Color(0xFFD6731E),
    Color(0xFF2F7FE0),
    Color(0xFFB04FD0),
  ];

  final _queryController = TextEditingController();
  final _focusNode = FocusNode();
  final _fieldKey = GlobalKey();
  final _suggestionsLink = LayerLink();
  String _query = '';
  String? _armedSubjectId;
  double _suggestionsWidth = 0;
  bool _suggestionsAlignRight = false;
  double _suggestionsOffsetX = 0;
  OverlayEntry? _suggestionsOverlay;

  List<Map<String, dynamic>> get _selectedSubjects => [
    for (final id in widget.selectedIds)
      for (final subject in widget.subjects)
        if (subject['id'].toString() == id) subject,
  ];

  List<Map<String, dynamic>> get _suggestions {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return widget.subjects
        .where(
          (subject) =>
              !widget.selectedIds.contains(subject['id'].toString()) &&
              subject['name'].toString().toLowerCase().contains(query),
        )
        .take(6)
        .toList();
  }

  @override
  void dispose() {
    _suggestionsOverlay?.remove();
    _suggestionsOverlay = null;
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateSuggestionsOverlay() {
    if (!_focusNode.hasFocus || _query.trim().isEmpty) {
      _suggestionsOverlay?.remove();
      _suggestionsOverlay = null;
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayRenderObject = overlay.context.findRenderObject();
    final fieldRenderObject = _fieldKey.currentContext?.findRenderObject();
    if (overlayRenderObject is RenderBox &&
        overlayRenderObject.hasSize &&
        fieldRenderObject is RenderBox &&
        fieldRenderObject.hasSize) {
      final overlayBox = overlayRenderObject;
      final fieldBox = fieldRenderObject;
      final fieldLeft = overlayBox.globalToLocal(
        fieldBox.localToGlobal(Offset.zero),
      );
      final fieldRight = overlayBox.globalToLocal(
        fieldBox.localToGlobal(Offset(fieldBox.size.width, 0)),
      );
      final renderedFieldWidth = (fieldRight.dx - fieldLeft.dx).abs();
      _suggestionsWidth = math
          .min(
            renderedFieldWidth,
            math.min(320.0, math.max(0.0, overlayBox.size.width - 24)),
          )
          .toDouble();
      final desiredLeft = fieldLeft.dx + renderedFieldWidth - _suggestionsWidth;
      _suggestionsAlignRight =
          desiredLeft > overlayBox.size.width - 12 - _suggestionsWidth;
      final alignedLeft = _suggestionsAlignRight
          ? fieldRight.dx - _suggestionsWidth
          : fieldLeft.dx;
      final clampedLeft = alignedLeft
          .clamp(
            12.0,
            math.max(12.0, overlayBox.size.width - 12 - _suggestionsWidth),
          )
          .toDouble();
      _suggestionsOffsetX = _suggestionsAlignRight
          ? clampedLeft - (fieldRight.dx - _suggestionsWidth)
          : clampedLeft - fieldLeft.dx;
    } else {
      return;
    }

    if (_suggestionsOverlay != null) {
      _suggestionsOverlay!.markNeedsBuild();
      return;
    }

    _suggestionsOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: _suggestionsWidth,
        child: CompositedTransformFollower(
          link: _suggestionsLink,
          showWhenUnlinked: false,
          targetAnchor: _suggestionsAlignRight
              ? Alignment.topRight
              : Alignment.topLeft,
          followerAnchor: _suggestionsAlignRight
              ? Alignment.bottomRight
              : Alignment.bottomLeft,
          offset: Offset(_suggestionsOffsetX, -8),
          child: SizedBox(width: _suggestionsWidth, child: _buildSuggestions()),
        ),
      ),
    );
    overlay.insert(_suggestionsOverlay!);
  }

  Color _tagColor(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0xFFFFFFFF;
    }
    return _tagColors[hash % _tagColors.length];
  }

  void _selectSubject(Map<String, dynamic> subject) {
    final id = subject['id'].toString();
    if (widget.selectedIds.contains(id)) return;
    widget.onSelected(id);
    _queryController.clear();
    setState(() {
      _query = '';
      _armedSubjectId = null;
    });
    _updateSuggestionsOverlay();
    _focusNode.requestFocus();
  }

  void _selectFirstSuggestion() {
    final suggestions = _suggestions;
    if (suggestions.isNotEmpty) _selectSubject(suggestions.first);
  }

  void _handleBackspace() {
    final selected = _selectedSubjects;
    if (selected.isEmpty) return;
    final lastId = selected.last['id'].toString();
    if (_armedSubjectId == lastId) {
      widget.onRemoved(lastId);
      setState(() => _armedSubjectId = null);
    } else {
      setState(() => _armedSubjectId = lastId);
    }
  }

  Widget _buildSuggestions() {
    final suggestions = _suggestions;
    if (!_focusNode.hasFocus || _query.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 116),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: widget.colors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: suggestions.isEmpty
            ? Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Text(
                    'Không tìm thấy môn phù hợp',
                    style: TextStyle(color: widget.colors.muted, fontSize: 12),
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final subject in suggestions)
                      _buildSuggestion(subject),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSuggestion(Map<String, dynamic> subject) {
    final color = _tagColor(subject['name'].toString());
    return Semantics(
      button: true,
      label: 'Thêm môn ${subject['name']}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _selectSubject(subject),
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: widget.colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 14, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    subject['name'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.colors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(Map<String, dynamic> subject) {
    final id = subject['id'].toString();
    final name = subject['name'].toString();
    final color = _tagColor(name);
    final textColor = Color.lerp(color, widget.colors.text, 0.28)!;
    final armed = id == _armedSubjectId;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: const Cubic(0.34, 1.45, 0.64, 1),
      builder: (context, scale, child) => Opacity(
        opacity: scale.clamp(0, 1),
        child: Transform.scale(scale: scale, child: child),
      ),
      child: Semantics(
        label: '$name${armed ? ', nhấn Backspace lần nữa để xóa' : ''}',
        child: Container(
          height: 34,
          padding: const EdgeInsets.only(left: 11, right: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(11),
            border: armed ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  '#$name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Semantics(
                button: true,
                label: 'Xóa môn $name',
                child: InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: () => widget.onRemoved(id),
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: textColor,
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

  @override
  Widget build(BuildContext context) {
    final selectedSubjects = _selectedSubjects;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedSubjects.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 5),
            child: Text(
              'Môn đã chọn · ${selectedSubjects.length} · tối đa 5 dòng hiển thị',
              style: TextStyle(
                color: widget.colors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        AnimatedSize(
          alignment: Alignment.topCenter,
          duration: const Duration(milliseconds: 300),
          curve: const Cubic(0.2, 0.8, 0.2, 1),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inputWidth = math.min(
                180.0,
                math.max(90.0, constraints.maxWidth - 24),
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _focusNode.requestFocus,
                child: CompositedTransformTarget(
                  key: _fieldKey,
                  link: _suggestionsLink,
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      maxHeight: 200,
                    ),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.colors.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Focus(
                      onFocusChange: (focused) {
                        if (!focused) {
                          setState(() => _armedSubjectId = null);
                        }
                        setState(() {});
                        _updateSuggestionsOverlay();
                      },
                      onKeyEvent: (_, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.backspace &&
                            _queryController.text.isEmpty) {
                          _handleBackspace();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.comma) {
                          _selectFirstSuggestion();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final subject in selectedSubjects)
                              _buildTag(subject),
                            SizedBox(
                              width: inputWidth,
                              height: 34,
                              child: TextField(
                                controller: _queryController,
                                focusNode: _focusNode,
                                onChanged: (value) {
                                  setState(() {
                                    _query = value;
                                    _armedSubjectId = null;
                                  });
                                  _updateSuggestionsOverlay();
                                },
                                onSubmitted: (_) => _selectFirstSuggestion(),
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  hintText: selectedSubjects.isEmpty
                                      ? 'Nhập tên môn...'
                                      : 'Thêm môn...',
                                  hintStyle: TextStyle(
                                    color: widget.colors.muted,
                                    fontSize: 12,
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: TextStyle(
                                  color: widget.colors.text,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DottedGridPainter extends CustomPainter {
  const _DottedGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const spacing = 20.0;
    const radius = 1.5;
    for (var x = spacing / 2; x < size.width; x += spacing) {
      for (var y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _EmptySeat extends StatelessWidget {
  const _EmptySeat({
    required this.colors,
    required this.onTap,
    this.highlighted = false,
  });

  final DiscordUiColors colors;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedSeatBorder(
      color: highlighted ? colors.accent : colors.border.withValues(alpha: 0.8),
    ),
    child: Container(
      decoration: highlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            )
          : null,
      child: Material(
        color: highlighted
            ? colors.accent.withValues(alpha: 0.12)
            : colors.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: PressScale(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: highlighted ? colors.accent : colors.muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    highlighted
                        ? Icons.move_to_inbox_outlined
                        : Icons.add_circle_outline_rounded,
                    size: 20,
                    color: colors.accent,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    highlighted ? 'Thả để chuyển' : 'Thêm học sinh',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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

class _OccupiedSeat extends StatelessWidget {
  const _OccupiedSeat({
    required this.student,
    required this.colors,
    required this.onTap,
    required this.onRemove,
  });

  final Map<String, dynamic> student;
  final DiscordUiColors colors;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final user = student['users'] as Map<String, dynamic>?;
    final profileName = user?['full_name']?.toString().trim();
    final name = profileName?.isNotEmpty == true ? profileName! : 'Học sinh';
    final avatarUrl = user?['avatar_url']?.toString();
    final nickname =
        user?['nickname']?.toString().trim() ??
        student['nickname']?.toString().trim();
    final role = student['classroom_role'] as Map<String, dynamic>?;
    final roleName =
        role?['name']?.toString() ??
        student['role_in_class']?.toString() ??
        'Học sinh';

    return PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.card, colors.card.withValues(alpha: 0.72)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.accent.withValues(alpha: 0.24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: colors.accent.withValues(alpha: 0.2),
                        backgroundImage: avatarUrl?.isNotEmpty == true
                            ? NetworkImage(avatarUrl!)
                            : null,
                        child: avatarUrl?.isNotEmpty == true
                            ? null
                            : Text(
                                name.characters.first.toUpperCase(),
                                style: TextStyle(
                                  color: colors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (nickname?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@$nickname',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 78),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          roleName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  Positioned(
                    top: -7,
                    right: -7,
                    child: PopupMenuButton<String>(
                      tooltip: 'Gỡ khỏi chỗ',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      iconSize: 15,
                      icon: Icon(Icons.more_horiz, color: colors.muted),
                      itemBuilder: (_) => [
                        const PopupMenuItem<String>(
                          value: 'remove',
                          child: Text('Gỡ khỏi chỗ'),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'remove') onRemove?.call();
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

class _StudentIndexSheet extends StatefulWidget {
  const _StudentIndexSheet({
    required this.classroomId,
    required this.studentId,
    required this.studentName,
    required this.studentRole,
    required this.classroomName,
    required this.canManage,
    required this.colors,
    required this.onClose,
  });

  final String classroomId;
  final String studentId;
  final String studentName;
  final String studentRole;
  final String classroomName;
  final bool canManage;
  final DiscordUiColors colors;
  final VoidCallback onClose;

  @override
  State<_StudentIndexSheet> createState() => _StudentIndexSheetState();
}

class _StudentIndexSheetState extends State<_StudentIndexSheet> {
  List<Map<String, dynamic>> _subjects = const [];
  int _selectedSubject = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showSubjectDetails = false;
  String? _error;
  final _reasonController = TextEditingController();

  Map<String, dynamic>? get _activeSubject =>
      _subjects.isEmpty ? null : _subjects[_selectedSubject];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final subjects = await ClassroomService.getStudentSubjectIndexData(
        classroomId: widget.classroomId,
        studentId: widget.studentId,
      );
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _selectedSubject = subjects.isEmpty
            ? 0
            : _selectedSubject.clamp(0, subjects.length - 1);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _apply({
    required StudentIndexChangeType type,
    required double impact,
    required String label,
  }) async {
    final active = _activeSubject;
    if (!widget.canManage || active == null || _isSaving) return;
    final subject = active['subject'] as Map<String, dynamic>;
    final reason = _reasonController.text.trim().isEmpty
        ? label
        : _reasonController.text.trim();
    setState(() => _isSaving = true);
    try {
      await ClassroomService.applyStudentSubjectIndexChange(
        classroomId: widget.classroomId,
        studentId: widget.studentId,
        subjectId: subject['id'].toString(),
        subjectName: subject['name'].toString(),
        baseImpact: impact,
        type: type,
        reason: reason,
      );
      _reasonController.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label cho ${widget.studentName}')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Material(
      color: colors.panel,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _isLoading
              ? const SubjectRatePanelSkeleton()
              : _error != null
              ? _buildError()
              : _buildContent(colors),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
      ],
    ),
  );

  Widget _buildOverview(DiscordUiColors colors) {
    final scores = _subjects.map((entry) {
      final rate = entry['rate'] as Map<String, dynamic>?;
      return (rate?['score'] as num?)?.toDouble() ?? 5;
    }).toList();
    final total = scores.fold<double>(0, (sum, score) => sum + score);
    final average = scores.isEmpty ? 0 : total / scores.length;

    return ListView(
      padding: const EdgeInsets.only(top: 10),
      children: [
        Row(
          children: [
            Expanded(
              child: _StudentSummaryCard(
                label: 'Điểm trung bình',
                value: average.toStringAsFixed(2),
                icon: Icons.insights_rounded,
                color: colors.accent,
                colors: colors,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StudentSummaryCard(
                label: 'Tổng tất cả môn',
                value: total.toStringAsFixed(2),
                icon: Icons.functions_rounded,
                color: Colors.amber.shade700,
                colors: colors,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Chỉ số theo môn',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < _subjects.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SubjectIndexCard(
              subject: _subjects[index],
              colors: colors,
              onTap: () => setState(() {
                _selectedSubject = index;
                _showSubjectDetails = true;
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(DiscordUiColors colors) {
    final active = _activeSubject;
    final rate = active?['rate'] as Map<String, dynamic>?;
    final score = (rate?['score'] as num?)?.toDouble() ?? 5;
    final transactions =
        (active?['transactions'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.accent.withValues(alpha: 0.18),
              child: Text(
                widget.studentName.characters.first.toUpperCase(),
                style: TextStyle(
                  color: colors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.studentName,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.studentRole} · ${widget.classroomName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_subjects.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'Chưa có môn học trong hệ thống.',
                style: TextStyle(color: colors.muted),
              ),
            ),
          )
        else if (!_showSubjectDetails)
          Expanded(child: _buildOverview(colors))
        else ...[
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showSubjectDetails = false),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Quay lại tổng quan',
              ),
              Text(
                'Chi tiết chỉ số',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Text(
            'Môn học',
            style: TextStyle(color: colors.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _subjects.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final subject =
                    _subjects[index]['subject'] as Map<String, dynamic>;
                final subjectRate =
                    (_subjects[index]['rate']
                        as Map<String, dynamic>?)?['score'];
                return ChoiceChip(
                  selected: index == _selectedSubject,
                  label: Text(
                    '${subject['name']} · ${((subjectRate as num?)?.toDouble() ?? 5).toStringAsFixed(2)}',
                  ),
                  onSelected: (_) => setState(() => _selectedSubject = index),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Text(
            active?['subject']['name']?.toString() ?? '',
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${score.toStringAsFixed(2)} / 10',
            style: TextStyle(
              color: colors.accent,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Lý do (tùy chọn với cộng, bắt buộc khi trừ)',
              prefixIcon: Icon(Icons.edit_note_outlined),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Cộng điểm theo bậc',
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _IndexActionButton(
                label: '+0.5 Phát biểu',
                color: Colors.green,
                onPressed: () => _apply(
                  type: StudentIndexChangeType.positive,
                  impact: 0.5,
                  label: 'Phát biểu',
                ),
              ),
              _IndexActionButton(
                label: '+1.0 Xây dựng bài',
                color: colors.accent,
                onPressed: () => _apply(
                  type: StudentIndexChangeType.positive,
                  impact: 1,
                  label: 'Xây dựng bài',
                ),
              ),
              _IndexActionButton(
                label: '+1.5 Làm tốt',
                color: Colors.amber.shade700,
                onPressed: () => _apply(
                  type: StudentIndexChangeType.positive,
                  impact: 1.5,
                  label: 'Làm tốt',
                ),
              ),
              _IndexActionButton(
                label: '-0.5 Mất tập trung',
                color: Colors.redAccent,
                onPressed: () => _apply(
                  type: StudentIndexChangeType.negative,
                  impact: 0.5,
                  label: 'Mất tập trung',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Lịch sử gần đây',
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: transactions.isEmpty
                ? Text(
                    'Chưa có giao dịch.',
                    style: TextStyle(color: colors.muted),
                  )
                : ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      final delta =
                          (transaction['delta_score'] as num?)?.toDouble() ?? 0;
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            delta >= 0
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: delta >= 0 ? Colors.green : Colors.redAccent,
                          ),
                          title: Text(transaction['reason']?.toString() ?? ''),
                          trailing: Text(
                            '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: delta >= 0
                                  ? Colors.green
                                  : Colors.redAccent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}

class _StudentSummaryCard extends StatelessWidget {
  const _StudentSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.colors,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final DiscordUiColors colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: colors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: colors.text,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: colors.muted, fontSize: 10)),
      ],
    ),
  );
}

class _PulseMetric extends StatelessWidget {
  const _PulseMetric({
    required this.value,
    required this.label,
    required this.colors,
  });

  final String value;
  final String label;
  final DiscordUiColors colors;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        value,
        style: TextStyle(
          color: colors.text,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(color: colors.muted, fontSize: 10)),
    ],
  );
}

class _StudioStat extends StatelessWidget {
  const _StudioStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.colors,
  });

  final String value;
  final String label;
  final IconData icon;
  final DiscordUiColors colors;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 112),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: colors.panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: colors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.accent),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(label, style: TextStyle(color: colors.muted, fontSize: 9)),
          ],
        ),
      ],
    ),
  );
}

class _StudioToolButton extends StatelessWidget {
  const _StudioToolButton({
    this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.colors,
    this.accent = false,
    this.disabledMessage,
  });

  final Key? buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final DiscordUiColors colors;
  final bool accent;
  final String? disabledMessage;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: onPressed == null ? disabledMessage ?? label : label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: buttonKey,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: onPressed == null
                ? Colors.transparent
                : accent
                ? colors.accent
                : colors.card,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: accent
                  ? colors.accent
                  : colors.border.withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: onPressed == null
                    ? colors.muted
                    : accent
                    ? colors.onAccent
                    : colors.accent,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: onPressed == null
                      ? colors.muted
                      : accent
                      ? colors.onAccent
                      : colors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StudioIconButton extends StatelessWidget {
  const _StudioIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.colors,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final DiscordUiColors colors;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      color: colors.text,
      style: IconButton.styleFrom(
        backgroundColor: colors.card,
        foregroundColor: colors.text,
        disabledForegroundColor: colors.muted,
        minimumSize: const Size(36, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.border),
        ),
      ),
    ),
  );
}

class _ClassroomActionButton extends StatelessWidget {
  const _ClassroomActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final DiscordUiColors colors;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
        decoration: BoxDecoration(
          color: onPressed == null
              ? Colors.transparent
              : colors.accent.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: onPressed == null ? colors.muted : colors.accent,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onPressed == null ? colors.muted : colors.text,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StudentSearchDialog extends StatefulWidget {
  const _StudentSearchDialog({required this.students, required this.colors});

  final List<Map<String, dynamic>> students;
  final DiscordUiColors colors;

  @override
  State<_StudentSearchDialog> createState() => _StudentSearchDialogState();
}

class _StudentSearchDialogState extends State<_StudentSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final students = widget.students.where((student) {
      final name =
          (student['users'] as Map<String, dynamic>?)?['full_name']
              ?.toString() ??
          '';
      return name.toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();
    return AlertDialog(
      title: const Text('Tra cứu học sinh'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Nhập tên học sinh',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: students.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final student = students[index];
                  final name =
                      (student['users'] as Map<String, dynamic>?)?['full_name']
                          ?.toString()
                          .trim();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: widget.colors.accent.withValues(
                        alpha: 0.16,
                      ),
                      child: Text(
                        (name?.isNotEmpty == true ? name! : 'H')
                            .characters
                            .first
                            .toUpperCase(),
                      ),
                    ),
                    title: Text(name?.isNotEmpty == true ? name! : 'Học sinh'),
                    subtitle: Text(
                      student['role_in_class']?.toString() ?? 'Học sinh',
                    ),
                    onTap: () => Navigator.of(context).pop(student),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectIndexCard extends StatelessWidget {
  const _SubjectIndexCard({
    required this.subject,
    required this.colors,
    required this.onTap,
  });

  final Map<String, dynamic> subject;
  final DiscordUiColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subjectInfo = subject['subject'] as Map<String, dynamic>;
    final rate = subject['rate'] as Map<String, dynamic>?;
    final score = (rate?['score'] as num?)?.toDouble() ?? 5;
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.menu_book_rounded, color: colors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subjectInfo['name']?.toString() ?? 'Môn học',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${score.toStringAsFixed(2)} / 10',
                style: TextStyle(
                  color: colors.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndexActionButton extends StatelessWidget {
  const _IndexActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.6)),
    ),
    child: Text(label),
  );
}

class _DashedSeatBorder extends CustomPainter {
  const _DashedSeatBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 5, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedSeatBorder oldDelegate) =>
      oldDelegate.color != color;
}

class _StudentPickerSheet extends StatefulWidget {
  const _StudentPickerSheet({required this.students, required this.colors});

  final List<Map<String, dynamic>> students;
  final DiscordUiColors colors;

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  final _searchController = TextEditingController();
  final _studentListScrollController = SmoothMouseScrollController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _studentListScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.students.where((student) {
      final user = student['users'] as Map<String, dynamic>?;
      final name = user?['full_name']?.toString() ?? '';
      return name.toLowerCase().contains(query);
    }).toList();
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            widget.colors.border.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: widget.colors.panel.withValues(alpha: 0.96),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Chọn học sinh',
                    style: TextStyle(
                      color: widget.colors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên học sinh',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: widget.colors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: widget.colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: widget.colors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              widget.students.isEmpty
                                  ? 'Không còn học sinh khả dụng.'
                                  : 'Không tìm thấy học sinh.',
                              style: TextStyle(color: widget.colors.muted),
                            ),
                          )
                        : ListView.separated(
                            controller: _studentListScrollController,
                            addAutomaticKeepAlives: true,
                            scrollCacheExtent: ScrollCacheExtent.pixels(500),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: widget.colors.border),
                            itemBuilder: (context, index) {
                              final student = filtered[index];
                              final avatarCacheSize =
                                  (40 * MediaQuery.devicePixelRatioOf(context))
                                      .round();
                              final user =
                                  student['users'] as Map<String, dynamic>?;
                              final name =
                                  user?['full_name']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ==
                                      true
                                  ? user!['full_name'].toString().trim()
                                  : 'Học sinh';
                              final avatarUrl = user?['avatar_url']?.toString();
                              final role =
                                  student['classroom_role']
                                      as Map<String, dynamic>?;
                              return TweenAnimationBuilder<double>(
                                key: ValueKey(student['user_id']?.toString()),
                                tween: Tween(begin: 0, end: 1),
                                duration: Duration(
                                  milliseconds: 200 + math.min(index, 10) * 30,
                                ),
                                curve: Curves.easeOutCubic,
                                builder: (context, progress, child) => Opacity(
                                  opacity: progress,
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - progress) * 12),
                                    child: child,
                                  ),
                                ),
                                child: PressScale(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor: widget.colors.accent
                                            .withValues(alpha: 0.2),
                                        backgroundImage:
                                            avatarUrl?.isNotEmpty == true
                                            ? ResizeImage(
                                                NetworkImage(avatarUrl!),
                                                width: avatarCacheSize,
                                                height: avatarCacheSize,
                                              )
                                            : null,
                                        child: avatarUrl?.isNotEmpty == true
                                            ? null
                                            : Text(
                                                name.characters.first
                                                    .toUpperCase(),
                                              ),
                                      ),
                                      title: Text(name),
                                      subtitle: Text(
                                        role?['name']?.toString() ??
                                            student['role_in_class']
                                                ?.toString() ??
                                            'Học sinh',
                                      ),
                                      onTap: () =>
                                          Navigator.of(context).pop(student),
                                    ),
                                  ),
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
      ),
    );
  }
}
