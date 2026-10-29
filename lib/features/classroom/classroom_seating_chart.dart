import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:astatine_dashboard/core/notifications/toast_service.dart';
import 'package:astatine_dashboard/core/ui/discord_ui.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';
import 'package:astatine_dashboard/core/ui/hover_ripple.dart';
import 'package:astatine_dashboard/core/ui/smooth_mouse_scroll_controller.dart';
import 'package:astatine_dashboard/core/ui/ui_motion.dart';

import 'classroom_service.dart';

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
  List<Map<String, dynamic>> _columnsData = const [];
  final Set<String> _newTableKeys = {};
  final _chartScrollController = SmoothMouseScrollController();
  final _gridScrollController = SmoothMouseScrollController();
  late List<List<_SeatingTable>> _tables = _createGrid(4, 2);
  int _rows = 4;
  int _columns = 2;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  List<List<_SeatingTable>> _createGrid(int rows, int columns) => List.generate(
    rows,
    (_) => List.generate(columns, (_) => _SeatingTable()),
  );

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        ClassroomService.getClassroomMembers(widget.classroomId),
        ClassroomService.getClassroomSeatingChart(widget.classroomId),
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
      final rows = chart['row_count'] as int;
      final columns = chart['column_count'] as int;
      final grid = _gridFromChart(chart, members);
      if (!mounted) return;
      setState(() {
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
        _tables = grid;
        _columnsData = (chart['columns'] as List)
            .cast<Map<String, dynamic>>()
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
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
      await _loadMembers();
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
    if (_tables[targetRow][targetColumn].students[targetSeat] != null) return;

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
            setState(() {
              _tables[row][column].students[seat] = null;
              _tables[targetRow][targetColumn].students[targetSeat] = student;
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
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _colors.panel.withValues(alpha: 0.78),
                border: Border(
                  bottom: BorderSide(
                    color: _colors.border.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
        ),
        title: const Text('Sơ đồ chỗ ngồi'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
            onPressed: _loadMembers,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );

  Widget _buildChart() => LayoutBuilder(
    builder: (context, constraints) {
      final availableGridWidth = constraints.maxWidth - 68;
      final sizeFactor = math
          .sqrt((_rows * _columns) / 8)
          .clamp(0.88, 1.0)
          .toDouble();
      final tableWidth = 202.0 * sizeFactor;
      final gridWidth = _columns * tableWidth + (_columns - 1) * 10.0;
      return ListView(
        controller: _chartScrollController,
        padding: const EdgeInsets.all(16),
        addAutomaticKeepAlives: true,
        scrollCacheExtent: ScrollCacheExtent.pixels(500),
        children: [
          _buildLayoutControls(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _colors.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _colors.border),
            ),
            child: Text(
              widget.classroomName,
              style: TextStyle(
                color: _colors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _gridScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(availableGridWidth, gridWidth),
                    child: Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: gridWidth,
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          addAutomaticKeepAlives: true,
                          scrollCacheExtent: ScrollCacheExtent.pixels(500),
                          itemCount: _rows * _columns,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _columns,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.16,
                              ),
                          itemBuilder: (context, index) {
                            final row = index ~/ _columns;
                            final column = index % _columns;
                            final tableKey = '$row:$column';
                            return TweenAnimationBuilder<double>(
                              key: ValueKey(tableKey),
                              tween: Tween(
                                begin: _newTableKeys.contains(tableKey)
                                    ? 0.0
                                    : 1.0,
                                end: 1.0,
                              ),
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              builder: (context, progress, child) => Opacity(
                                opacity: progress,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - progress) * 12),
                                  child: child,
                                ),
                              ),
                              child: _buildTable(row, column),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _AddDimensionButton(
                label: 'Thêm\ncột',
                icon: Icons.add,
                onPressed: !widget.canManage || _isSaving
                    ? null
                    : () => _resizeGrid(rows: _rows, columns: _columns + 1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: !widget.canManage || _isSaving
                ? null
                : () => _resizeGrid(rows: _rows + 1, columns: _columns),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm hàng'),
          ),
        ],
      );
    },
  );

  Widget _buildLayoutControls() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _colors.card,
      borderRadius: BorderRadius.circular(12),
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
        DropdownButton<String>(
          value: '$_rows×$_columns',
          underline: const SizedBox.shrink(),
          dropdownColor: _colors.panel,
          style: TextStyle(color: _colors.text),
          items: [
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
                DropdownMenuItem(
                  value: '$rows×$columns',
                  child: GlideSelect(
                    selected: '$_rows×$_columns' == '$rows×$columns',
                    child: Text('$rows hàng × $columns cột'),
                  ),
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
                },
        ),
      ],
    ),
  );

  Widget _buildTable(int row, int column) {
    final table = _tables[row][column];
    return HoverRipple(
      borderRadius: BorderRadius.circular(14),
      color: _colors.accent,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _colors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _colors.border),
        ),
        child: Column(
          children: [
            if (row == 0)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _columnsData[column]['name']?.toString() ??
                          'Cột ${column + 1}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _colors.text,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.canManage)
                    InkWell(
                      key: Key('rename-seating-column-$column'),
                      onTap: () => _renameColumn(column),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: _colors.muted,
                      ),
                    ),
                ],
              ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _colors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    _tableLabel(column, row),
                    style: TextStyle(
                      color: _colors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.table_restaurant_outlined,
                  size: 16,
                  color: _colors.muted,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Expanded(
              child: Row(
                children: [
                  for (var seat = 0; seat < 2; seat++) ...[
                    if (seat > 0) const SizedBox(width: 6),
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
        borderRadius: BorderRadius.circular(10),
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

class _SeatingTable {
  final List<Map<String, dynamic>?> students = [null, null];
}

class _AddDimensionButton extends StatelessWidget {
  const _AddDimensionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => PressScale(
    child: SizedBox(
      width: 60,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
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
      color: highlighted ? colors.accent : colors.border,
    ),
    child: Container(
      decoration: highlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            )
          : null,
      child: Material(
        color: highlighted
            ? colors.accent.withValues(alpha: 0.12)
            : colors.card,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
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
                  const SizedBox(height: 4),
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
    required this.onRemove,
  });

  final Map<String, dynamic> student;
  final DiscordUiColors colors;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final user = student['users'] as Map<String, dynamic>?;
    final profileName = user?['full_name']?.toString().trim();
    final name = profileName?.isNotEmpty == true ? profileName! : 'Học sinh';
    final avatarUrl = user?['avatar_url']?.toString();
    final role = student['classroom_role'] as Map<String, dynamic>?;
    final roleName =
        role?['name']?.toString() ??
        student['role_in_class']?.toString() ??
        'Học sinh';

    return PressScale(
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
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
                  const SizedBox(height: 2),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 78),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
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
    );
  }
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
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
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
        borderRadius: BorderRadius.circular(22),
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
        borderRadius: BorderRadius.circular(21),
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
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
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
