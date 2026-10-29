import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/notifications/toast_service.dart';
import 'package:astatine_dashboard/core/ui/discord_ui.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';
import 'package:astatine_dashboard/features/profile/user_profile_avatar.dart';
import 'package:astatine_dashboard/features/profile/subscription_name_effect.dart';

import 'chat_screen.dart';
import 'classroom_service.dart';
import 'classroom_seating_chart.dart';
import 'dashboard_columns.dart';

class AstatineDiscordDashboard extends StatefulWidget {
  const AstatineDiscordDashboard({
    super.key,
    this.isVietnamese = false,
    this.languageCode,
    this.onScanNotebook,
    this.onAttachHomework,
  });

  final bool isVietnamese;
  final String? languageCode;
  final VoidCallback? onScanNotebook;
  final VoidCallback? onAttachHomework;

  @override
  State<AstatineDiscordDashboard> createState() =>
      _AstatineDiscordDashboardState();
}

class _AstatineDiscordDashboardState extends State<AstatineDiscordDashboard> {
  DiscordUiColors get _themeColors => DiscordUiColors.of(context);
  Color get _background => _themeColors.background;
  Color get _panel => _themeColors.panel;
  Color get _card => _themeColors.card;
  Color get _accent => _themeColors.accent;
  Color get _border => _themeColors.border;
  Color get _text => _themeColors.text;
  Color get _muted => _themeColors.muted;
  bool get _vi => widget.isVietnamese;
  String get _languageCode => widget.languageCode ?? (_vi ? 'vi' : 'en');

  String _textLabel(String english, String vietnamese) => _languageCode == 'zh'
      ? AppLocalizations.translateInline(english, languageCode: _languageCode)
      : _vi
      ? vietnamese
      : english;

  String _friendlyError(Object error) => _languageCode == 'zh'
      ? AppLocalizations.t('errors.unexpected', languageCode: 'zh')
      : error.toString();

  String _localizedClassRole(String role) {
    if (_languageCode != 'zh') return role;
    switch (role.toLowerCase()) {
      case 'owner':
        return '组长';
      case 'admin':
        return '管理员';
      case 'teacher':
        return '教师';
      case 'student':
        return '学生';
      case 'member':
        return '成员';
      default:
        return role;
    }
  }

  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _memberships = const [];
  List<Map<String, dynamic>> _channels = const [];
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _seatingChatGroups = const [];
  List<Map<String, dynamic>> _classroomRoles = const [];
  String _channelDataSignature = '';
  String? _appRole;
  String? _classroomId;
  String? _channelId;
  String? _loadError;
  String? _seatingRealtimeClassroomId;
  RealtimeChannel? _seatingRealtimeChannel;
  Timer? _seatingRefreshTimer;
  bool _loading = true;
  bool _sending = false;
  bool _showMembers = true;
  bool _notificationsEnabled = true;

  bool get _canCreateClass =>
      const {'teacher', 'developer'}.contains(_appRole?.toLowerCase());

  bool get _isClassStaff => _canCreateClass || _isClassOwnerOrTeacher;

  bool get _isClassOwnerOrTeacher => const {
    'owner',
    'teacher',
  }.contains(_currentMembership?['role_in_class']?.toString().toLowerCase());

  bool get _canManageRoles => _isClassStaff;

  String? get _currentCustomRoleId =>
      _currentMembership?['custom_role_id']?.toString();

  Map<String, dynamic>? get _currentCustomRole {
    final roleId = _currentCustomRoleId;
    if (roleId == null) return null;
    for (final role in _classroomRoles) {
      if (role['id']?.toString() == roleId) return role;
    }
    return null;
  }

  bool get _canCreateChannel =>
      _isClassStaff || _currentCustomRole?['can_manage_channels'] == true;

  Map<String, dynamic>? get _currentMembership {
    for (final membership in _memberships) {
      if (_classroomOf(membership)?['id']?.toString() == _classroomId) {
        return membership;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _currentClassroom =>
      _classroomOf(_currentMembership ?? const {});

  Map<String, dynamic>? get _currentChannel {
    for (final channel in _channels) {
      if (channel['id']?.toString() == _channelId) return channel;
    }
    return null;
  }

  List<String> _channelRoleIds(Map<String, dynamic> channel) {
    final value = channel['target_role_ids'];
    final ids = value is Iterable
        ? value.map((id) => id.toString()).toList()
        : <String>[];
    final legacyId = channel['target_role_id']?.toString();
    if (ids.isEmpty && legacyId != null) ids.add(legacyId);
    return ids;
  }

  List<String> _chatRoleIds(Map<String, dynamic> channel) {
    final value = channel['chat_role_ids'];
    return value is Iterable
        ? value.map((id) => id.toString()).toList()
        : const [];
  }

  Color _roleColor(Map<String, dynamic>? role) {
    final value = role?['color']?.toString().replaceFirst('#', '');
    if (value == null || (value.length != 6 && value.length != 8)) {
      return _accent;
    }
    try {
      return Color(
        int.parse(value.length == 6 ? 'FF$value' : value, radix: 16),
      );
    } on FormatException {
      return _accent;
    }
  }

  Map<String, dynamic>? _roleForMember(Map<String, dynamic>? member) {
    final roleId = member?['custom_role_id']?.toString();
    if (roleId == null) return null;
    return _classroomRoles
        .where((role) => role['id']?.toString() == roleId)
        .firstOrNull;
  }

  bool get _canSendToCurrentChannel {
    final channel = _currentChannel;
    if (channel == null) return false;
    final chatAccess = channel['chat_access']?.toString() ?? 'everyone';
    if (chatAccess == 'teachers') return _isClassOwnerOrTeacher;
    if (chatAccess == 'roles') {
      return _isClassOwnerOrTeacher ||
          _chatRoleIds(channel).contains(_currentCustomRoleId);
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _seatingRefreshTimer?.cancel();
    final channel = _seatingRealtimeChannel;
    if (channel != null) {
      unawaited(_supabase.removeChannel(channel));
    }
    super.dispose();
  }

  Map<String, dynamic>? _classroomOf(Map<String, dynamic> membership) {
    final value = membership['classrooms'];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, dynamic>? _mapValue(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  Future<void> _loadWorkspace({String? preferredClassroomId}) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final role = await ClassroomService.getUserRole();
      final memberships = await ClassroomService.getMyClassrooms();
      if (!mounted) return;

      final requestedId = preferredClassroomId ?? _classroomId;
      final selectedId =
          memberships.any(
            (item) => _classroomOf(item)?['id']?.toString() == requestedId,
          )
          ? requestedId
          : memberships.isEmpty
          ? null
          : _classroomOf(memberships.first)?['id']?.toString();
      setState(() {
        _appRole = role?.toLowerCase();
        _memberships = memberships;
        _classroomId = selectedId;
      });
      if (selectedId == null) {
        _stopWatchingSeatingChart();
        setState(() {
          _channels = const [];
          _members = const [];
          _classroomRoles = const [];
          _channelId = null;
          _loading = false;
        });
        return;
      }
      await _loadClassroom(selectedId);
      _watchSeatingChart(selectedId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _friendlyError(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadClassroom(String classroomId) async {
    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        ClassroomService.getChannels(classroomId),
        ClassroomService.getClassroomMembers(classroomId),
        ClassroomService.getClassroomRoles(classroomId),
      ]);
      final seatingGroups = await _loadAccessibleSeatingChatGroups(classroomId);
      if (!mounted || classroomId != _classroomId) return;

      final canViewRestricted = _isClassOwnerOrTeacher;
      final channels = results[0].where((channel) {
        final restricted =
            channel['is_private'] == true ||
            channel['allowed_roles'] == 'teacher_only';
        final targetRoleIds = _channelRoleIds(channel);
        final roleMatches =
            targetRoleIds.isEmpty ||
            targetRoleIds.contains(_currentCustomRoleId) ||
            _canCreateChannel;
        return (roleMatches || canViewRestricted) &&
            (!restricted || canViewRestricted) &&
            (channel['is_hidden'] != true || canViewRestricted);
      }).toList();
      final nextChannelId =
          channels.any((item) => item['id']?.toString() == _channelId)
          ? _channelId
          : channels.isEmpty
          ? null
          : channels.first['id']?.toString();
      _channelDataSignature = _channelSignature(channels);

      setState(() {
        _channels = channels;
        _members = results[1];
        _classroomRoles = results[2];
        _seatingChatGroups = seatingGroups;
        _channelId = nextChannelId;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _friendlyError(error);
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadAccessibleSeatingChatGroups(
    String classroomId,
  ) async {
    final chart = await ClassroomService.getClassroomSeatingChart(classroomId);
    final currentUserId = _supabase.auth.currentUser?.id;
    final accessibleColumnIds = <String>{};
    if (_isClassOwnerOrTeacher) {
      for (final column in chart['columns'] as List<Map<String, dynamic>>) {
        final id = column['id']?.toString();
        if (id != null) accessibleColumnIds.add(id);
      }
    } else {
      for (final seat in chart['seats'] as List<Map<String, dynamic>>) {
        if (seat['student_id']?.toString() == currentUserId) {
          final id = seat['seating_column_id']?.toString();
          if (id != null) accessibleColumnIds.add(id);
        }
      }
    }
    final groups =
        (chart['columns'] as List<Map<String, dynamic>>)
            .where(
              (column) =>
                  column['id'] != null &&
                  accessibleColumnIds.contains(column['id'].toString()),
            )
            .toList()
          ..sort(
            (left, right) => (right['column_index'] as int).compareTo(
              left['column_index'] as int,
            ),
          );
    return groups;
  }

  void _watchSeatingChart(String classroomId) {
    if (_seatingRealtimeClassroomId == classroomId) return;
    _stopWatchingSeatingChart();
    _seatingRealtimeClassroomId = classroomId;
    _seatingRealtimeChannel = _supabase
        .channel('classroom-seating-$classroomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'classroom_seating_chart_seats',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'classroom_id',
            value: classroomId,
          ),
          callback: (_) => _scheduleSeatingChatRefresh(classroomId),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'classroom_seating_columns',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'classroom_id',
            value: classroomId,
          ),
          callback: (_) => _scheduleSeatingChatRefresh(classroomId),
        )
        .subscribe();
  }

  void _stopWatchingSeatingChart() {
    _seatingRefreshTimer?.cancel();
    _seatingRefreshTimer = null;
    _seatingRealtimeClassroomId = null;
    final channel = _seatingRealtimeChannel;
    _seatingRealtimeChannel = null;
    if (channel != null) unawaited(_supabase.removeChannel(channel));
  }

  void _scheduleSeatingChatRefresh(String classroomId) {
    _seatingRefreshTimer?.cancel();
    _seatingRefreshTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted || classroomId != _classroomId) return;
      try {
        final groups = await _loadAccessibleSeatingChatGroups(classroomId);
        if (!mounted || classroomId != _classroomId) return;
        setState(() => _seatingChatGroups = groups);
      } catch (error) {
        if (!mounted || classroomId != _classroomId) return;
        setState(() => _loadError = _friendlyError(error));
      }
    });
  }

  List<Map<String, dynamic>> _filterChannels(
    List<Map<String, dynamic>> channels,
  ) {
    final isStaff = _isClassOwnerOrTeacher;
    return channels.where((channel) {
      final restricted =
          channel['is_private'] == true ||
          channel['allowed_roles'] == 'teacher_only';
      final roleMatches =
          _channelRoleIds(channel).isEmpty ||
          _channelRoleIds(channel).contains(_currentCustomRoleId) ||
          _canCreateChannel;
      return (roleMatches || isStaff) &&
          (!restricted || isStaff) &&
          (channel['is_hidden'] != true || isStaff);
    }).toList();
  }

  String _channelSignature(List<Map<String, dynamic>> channels) => channels
      .map(
        (channel) =>
            '${channel['id']}:${channel['name']}:${channel['is_hidden']}:${_channelRoleIds(channel).join(',')}',
      )
      .join('|');

  void _handleStreamChannels(List<Map<String, dynamic>> channels) {
    final signature = _channelSignature(channels);
    if (!mounted || signature == _channelDataSignature) return;
    _channelDataSignature = signature;
    final nextChannelId =
        channels.any((channel) => channel['id']?.toString() == _channelId)
        ? _channelId
        : channels.isEmpty
        ? null
        : channels.first['id']?.toString();
    setState(() {
      _channels = channels;
      _channelId = nextChannelId;
    });
  }

  Future<void> _selectClassroom(Map<String, dynamic> classroom) async {
    final id = classroom['id']?.toString();
    if (id == null || id == _classroomId) return;
    _stopWatchingSeatingChart();
    setState(() {
      _classroomId = id;
      _channelId = null;
      _channels = const [];
      _seatingChatGroups = const [];
      _members = const [];
      _classroomRoles = const [];
      _loading = true;
    });
    await _loadClassroom(id);
    _watchSeatingChart(id);
  }

  Future<void> _showClassActions() async {
    if (_appRole == 'student') {
      await _joinClassroom();
      return;
    }
    if (!_canCreateClass) {
      await _joinClassroom();
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => DiscordDialog(
        title: Text(
          _textLabel('Classrooms', 'Lớp học'),
          style: TextStyle(color: _text),
        ),
        content: Text(
          _textLabel(
            'Create a new class or join an existing one.',
            'Tạo lớp mới hoặc tham gia lớp hiện có.',
          ),
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'join'),
            child: Text(_textLabel('Join class', 'Tham gia lớp')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'create'),
            child: Text(_textLabel('Create class', 'Tạo lớp')),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'create') {
      await _createClassroom();
    } else {
      await _joinClassroom();
    }
  }

  Future<void> _createClassroom() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => DiscordDialog(
        title: Text(
          _textLabel('Create class', 'Tạo lớp'),
          style: TextStyle(color: _text),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: _text),
          decoration: _dialogInput(_textLabel('Class name', 'Tên lớp')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_textLabel('Cancel', 'Hủy')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(_textLabel('Create', 'Tạo')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;

    try {
      final code = await ClassroomService.createClassroom(name);
      await _loadWorkspace();
      final created = _memberships
          .map(_classroomOf)
          .whereType<Map<String, dynamic>>()
          .where((item) => item['code']?.toString() == code)
          .firstOrNull;
      if (created != null) await _selectClassroom(created);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => DiscordDialog(
          title: Text(
            _textLabel('Class created', 'Đã tạo lớp'),
            style: TextStyle(color: _text),
          ),
          content: SelectableText(
            code,
            style: TextStyle(
              color: _text,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(_textLabel('Copy code', 'Sao chép mã')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_textLabel('Done', 'Xong')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ToastService.showError(_friendlyError(error));
    }
  }

  Future<void> _joinClassroom() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => DiscordDialog(
        title: Text(
          _textLabel('Join class', 'Tham gia lớp'),
          style: TextStyle(color: _text),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(color: _text),
          decoration: _dialogInput(
            _textLabel('6-character class code', 'Mã lớp gồm 6 ký tự'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_textLabel('Cancel', 'Hủy')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim().toUpperCase(),
            ),
            child: Text(_textLabel('Join', 'Tham gia')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !mounted) return;

    try {
      await ClassroomService.joinClassroom(code);
      await _loadWorkspace();
      final joined = _memberships
          .map(_classroomOf)
          .whereType<Map<String, dynamic>>()
          .where((item) => item['code']?.toString() == code)
          .firstOrNull;
      if (joined != null) await _selectClassroom(joined);
      if (!mounted) return;
      ToastService.showSuccess(
        _textLabel('Joined classroom.', 'Đã tham gia lớp học.'),
      );
    } catch (error) {
      if (!mounted) return;
      ToastService.showError(_friendlyError(error));
    }
  }

  Future<void> _createChannel({required String category}) async {
    final classroomId = _classroomId;
    if (classroomId == null || !_canCreateChannel) return;
    final controller = TextEditingController();
    var isPrivate = false;
    var allowedRoles = 'all';
    var roleSpecific = false;
    final selectedRoleIds = <String>{};
    var missingRole = false;
    var missingName = false;
    final values = await showDialog<(String, bool, String, List<String>)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => DiscordDialog(
          scrollable: true,
          title: Text(
            '${_textLabel('Create channel', 'Tạo kênh')} · $category',
            style: TextStyle(color: _text),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: _text),
                decoration: _dialogInput(
                  _textLabel('Channel name', 'Tên kênh'),
                ),
                onChanged: (_) {
                  if (missingName) {
                    setDialogState(() => missingName = false);
                  }
                },
              ),
              if (missingName)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text(
                      _textLabel('Enter a channel name.', 'Nhập tên kênh.'),
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              DiscordChoiceTile(
                selected: !isPrivate,
                onTap: () => setDialogState(() {
                  isPrivate = false;
                  allowedRoles = 'all';
                }),
                title: Text(
                  _textLabel(
                    'All members can view',
                    'Tất cả thành viên có thể xem',
                  ),
                  style: TextStyle(color: _text, fontSize: 13),
                ),
              ),
              DiscordChoiceTile(
                selected: isPrivate,
                onTap: () => setDialogState(() {
                  isPrivate = true;
                  allowedRoles = 'teacher_only';
                }),
                title: Text(
                  _textLabel(
                    'Teachers only can view',
                    'Chỉ giáo viên có thể xem',
                  ),
                  style: TextStyle(color: _text, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _textLabel('CHANNEL ACCESS', 'QUYỀN TRUY CẬP KÊNH'),
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              DiscordChoiceTile(
                selected: !roleSpecific,
                onTap: () => setDialogState(() {
                  roleSpecific = false;
                  missingRole = false;
                }),
                title: Text(
                  _textLabel(
                    'All members (@everyone)',
                    'Tất cả thành viên (@everyone)',
                  ),
                  style: TextStyle(color: _text, fontSize: 13),
                ),
              ),
              DiscordChoiceTile(
                selected: roleSpecific,
                onTap: () => setDialogState(() {
                  roleSpecific = true;
                  missingRole = false;
                }),
                title: Text(
                  _textLabel(
                    'Specific roles only',
                    'Chỉ cho phép vai trò cụ thể',
                  ),
                  style: TextStyle(color: _text, fontSize: 13),
                ),
              ),
              if (roleSpecific && _classroomRoles.isNotEmpty)
                for (final role in _classroomRoles)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        DiscordCheckbox(
                          value: selectedRoleIds.contains(
                            role['id'].toString(),
                          ),
                          onChanged: (value) => setDialogState(() {
                            final id = role['id'].toString();
                            if (value) {
                              selectedRoleIds.add(id);
                            } else {
                              selectedRoleIds.remove(id);
                            }
                            missingRole = false;
                          }),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _roleLabel(role)),
                      ],
                    ),
                  ),
              if (roleSpecific && _classroomRoles.isEmpty)
                Text(
                  _textLabel(
                    'Create a classroom role before restricting channel access.',
                    'Hãy tạo vai trò lớp trước khi giới hạn quyền truy cập kênh.',
                  ),
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              if (missingRole)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    _textLabel(
                      'Select a role for this channel.',
                      'Chọn vai trò cho kênh này.',
                    ),
                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_textLabel('Cancel', 'Hủy')),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  setDialogState(() => missingName = true);
                  return;
                }
                if (roleSpecific && selectedRoleIds.isEmpty) {
                  setDialogState(() => missingRole = true);
                  return;
                }
                Navigator.pop(dialogContext, (
                  controller.text.trim(),
                  isPrivate,
                  allowedRoles,
                  roleSpecific ? selectedRoleIds.toList() : <String>[],
                ));
              },
              child: Text(_textLabel('Create', 'Tạo')),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (values == null || !mounted) return;
    try {
      await ClassroomService.createChannel(
        classroomId,
        values.$1,
        values.$2,
        values.$3,
        targetRoleIds: values.$4,
      );
      await _loadClassroom(classroomId);
      final createdChannel = _channels.where((item) {
        return item['name']?.toString() == values.$1;
      }).firstOrNull;
      if (createdChannel != null) {
        _selectChannel(createdChannel['id']?.toString());
      }
    } catch (error) {
      if (!mounted) return;
      ToastService.showError(_friendlyError(error));
    }
  }

  InputDecoration _dialogInput(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: _muted),
    filled: true,
    fillColor: _card,
    hintStyle: TextStyle(color: _themeColors.hint),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _accent, width: 1.5),
    ),
  );

  void _selectChannel(String? channelId) {
    if (channelId == _channelId) return;
    setState(() => _channelId = channelId);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 960;
        final showMembers = _showMembers && width >= 1120;
        final channelWidth = width < 1200 ? 220.0 : 250.0;

        return Scaffold(
          backgroundColor: _background,
          body: SafeArea(
            child: Column(
              children: [
                TopBarClassroomSwitcher(
                  key: ValueKey(
                    'top_bar_${_supabase.auth.currentUser?.id ?? 'anonymous'}',
                  ),
                  currentUserId: _supabase.auth.currentUser?.id ?? 'anonymous',
                  memberships: _memberships,
                  selectedClassroomId: _classroomId,
                  isVietnamese: _vi,
                  languageCode: _languageCode,
                  onSelect: _selectClassroom,
                  onAdd: _showClassActions,
                ),
                Expanded(
                  child: Row(
                    children: [
                      if (!compact) ...[
                        ChannelSidebar(
                          key: ValueKey('channels_${_classroomId ?? 'none'}'),
                          selectedClassroomId: _classroomId,
                          filterChannels: _filterChannels,
                          onChannelsChanged: _handleStreamChannels,
                          builder: (_) => SizedBox(
                            width: channelWidth,
                            child: _buildChannelSidebar(),
                          ),
                        ),
                        VerticalDivider(width: 1, color: _border),
                      ],
                      Expanded(
                        child: _loading && _memberships.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : _loadError != null
                            ? _buildLoadError()
                            : _classroomId == null
                            ? _buildEmptyWorkspace()
                            : _buildChatWorkspace(
                                showMembers: showMembers,
                                compact: compact,
                                availableWidth: width,
                              ),
                      ),
                      if (showMembers) ...[
                        VerticalDivider(width: 1, color: _border),
                        MemberListSidebar(
                          key: ValueKey('members_${_classroomId ?? 'none'}'),
                          selectedClassroomId: _classroomId,
                          builder: (_) => SizedBox(
                            width: 240,
                            child: _buildMemberSidebar(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: compact && _classroomId != null
              ? FloatingActionButton.small(
                  tooltip: _textLabel(
                    'Channels and members',
                    'Kênh và thành viên',
                  ),
                  backgroundColor: _accent,
                  foregroundColor: _themeColors.onAccent,
                  onPressed: _showCompactNavigation,
                  child: const Icon(Icons.menu_rounded),
                )
              : null,
        );
      },
    );
  }

  Widget _buildChannelSidebar() {
    final classroom = _currentClassroom;
    final groups = _groupChannels(_channels);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panel,
        border: Border(
          right: BorderSide(color: _border.withValues(alpha: 0.45)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 18, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            classroom?['name']?.toString() ??
                                _textLabel('Classroom', 'Lớp học'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${_textLabel('Class code', 'Mã lớp')}: ${classroom?['code'] ?? ''}',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 10,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: _textLabel(
                        'Class settings and code',
                        'Cài đặt lớp và mã lớp',
                      ),
                      onPressed: _showClassDetails,
                      icon: Icon(
                        Icons.settings_outlined,
                        size: 18,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('open-classroom-seating-chart'),
                  onPressed: classroom == null ? null : _openSeatingChart,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 31, 221, 255),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color.fromARGB(
                      255,
                      36,
                      229,
                      255,
                    ).withValues(alpha: 0.38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.event_seat_rounded, size: 19),
                  label: Text(
                    _textLabel('Seating chart', 'Sơ đồ lớp'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _border),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _channels.isEmpty && _seatingChatGroups.isEmpty
                ? Center(
                    child: Text(
                      _textLabel('No channels yet', 'Chưa có kênh nào'),
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(8, 15, 8, 16),
                    children: [
                      if (_seatingChatGroups.isNotEmpty)
                        _buildSeatingChatGroups(_seatingChatGroups),
                      _buildCategory(
                        _textLabel('Private chat', 'Chat riêng'),
                        groups['ai'] ?? const [],
                      ),
                      _buildCategory(
                        _textLabel('TEXT CHANNELS', 'KÊNH VĂN BẢN'),
                        groups['text'] ?? const [],
                      ),
                      _buildCategory(
                        _textLabel('DIRECT CHANNELS', 'TRỰC TIẾP'),
                        groups['interactive'] ?? const [],
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 13),
            child: Row(
              children: [
                UserProfileAvatar(
                  userId: _supabase.auth.currentUser?.id,
                  radius: 16,
                  fallbackText: _currentUserInitial,
                  languageCode: _languageCode,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUserName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _text,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _localizedClassRole(
                          _currentMembership?['role_in_class']?.toString() ??
                              '',
                        ),
                        style: TextStyle(color: _muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _textLabel('Refresh classroom', 'Làm mới lớp học'),
                  onPressed: () =>
                      _loadWorkspace(preferredClassroomId: _classroomId),
                  icon: Icon(Icons.refresh_rounded, size: 17, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSeatingChart() async {
    final classroomId = _classroomId;
    final classroom = _currentClassroom;
    if (classroomId == null || classroom == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ClassroomSeatingChartScreen(
          classroomId: classroomId,
          classroomName: classroom['name']?.toString() ?? 'Classroom',
          canManage: _isClassOwnerOrTeacher,
        ),
      ),
    );
    if (!mounted) return;
    await _loadClassroom(classroomId);
  }

  Widget _buildSeatingChatGroups(List<Map<String, dynamic>> columns) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 2, 5),
        child: Text(
          _textLabel('COLUMN GROUP CHATS', 'NHÓM CHAT THEO CỘT'),
          style: TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
      for (final column in columns)
        ListTile(
          key: Key('seating-column-chat-${column['id']}'),
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(Icons.groups_2_outlined, size: 17, color: _muted),
          title: Text(
            column['name']?.toString() ?? 'Nhóm cột',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _text, fontSize: 11),
          ),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ChatScreen(
                classroomGroupId: column['id'].toString(),
                classroomGroupClassroomId: _classroomId,
                channelName: column['name']?.toString() ?? 'Nhóm cột',
                languageCode: _languageCode,
              ),
            ),
          ),
        ),
    ],
  );

  String get _currentUserName {
    final user = _supabase.auth.currentUser;
    for (final row in _members) {
      if (row['user_id'] == user?.id) {
        final profile = _mapValue(row['users']);
        final name = (profile?['full_name'] as String?)?.trim();
        if (name?.isNotEmpty == true) return name!;
      }
    }
    return user?.email ?? 'User';
  }

  String get _currentUserInitial => _currentUserName.isEmpty
      ? 'U'
      : _currentUserName.characters.first.toUpperCase();

  Map<String, List<Map<String, dynamic>>> _groupChannels(
    List<Map<String, dynamic>> channels,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{
      'ai': [],
      'text': [],
      'interactive': [],
    };
    for (final channel in channels) {
      final name = (channel['name'] as String? ?? '').toLowerCase();
      if (name.contains('ai') || name.contains('tutor')) {
        groups['ai']!.add(channel);
      } else if (name.contains('room') ||
          name.contains('lab') ||
          name.contains('voice')) {
        groups['interactive']!.add(channel);
      } else {
        groups['text']!.add(channel);
      }
    }
    return groups;
  }

  Widget _buildCategory(String title, List<Map<String, dynamic>> channels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 2, 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (_canCreateChannel)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: _languageCode == 'zh'
                        ? '在$title中创建频道'
                        : _textLabel(
                            'Create channel in $title',
                            'Tạo kênh trong $title',
                          ),
                    onPressed: () => _createChannel(category: title),
                    icon: Icon(Icons.add_rounded, size: 16, color: _muted),
                  ),
                ),
            ],
          ),
        ),
        for (final channel in channels) _buildChannelTile(channel),
        if (channels.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 2, 8, 4),
            child: Text(
              _textLabel('No channels', 'Không có kênh'),
              style: TextStyle(color: _muted, fontSize: 10),
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildChannelTile(Map<String, dynamic> channel) {
    final id = channel['id']?.toString() ?? '';
    final name = channel['name']?.toString() ?? '';
    final active = id == _channelId;
    final interactive = _groupChannels([channel])['interactive']!.isNotEmpty;
    final icon = interactive
        ? (name.toLowerCase().contains('lab')
              ? Icons.science_outlined
              : Icons.volume_up_outlined)
        : channel['is_private'] == true
        ? Icons.lock_outline
        : Icons.tag;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: active ? _accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active
                ? _accent.withValues(alpha: 0.28)
                : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            key: Key('discord-channel-$id'),
            borderRadius: BorderRadius.circular(9),
            onTap: () => _selectChannel(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: active ? _accent : _muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? _text : _muted,
                        fontSize: 11,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (active)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
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

  Widget _buildChatWorkspace({
    required bool showMembers,
    required bool compact,
    required double availableWidth,
  }) {
    final channel = _currentChannel;
    if (channel == null || _channelId == null) {
      return _buildNoChannel(
        compact: compact,
        showMembers: showMembers,
        availableWidth: availableWidth,
      );
    }
    return ChatAreaWorkspace(
      key: ValueKey('chat_$_channelId'),
      selectedChannelId: _channelId!,
      channelName: channel['name']?.toString() ?? '',
      isVietnamese: _vi,
      languageCode: _languageCode,
      currentUserId: _supabase.auth.currentUser?.id,
      compact: compact,
      showMembers: showMembers,
      availableWidth: availableWidth,
      notificationsEnabled: _notificationsEnabled,
      canSend: _canSendToCurrentChannel,
      isSending: _sending,
      onSend: _sendMessage,
      onToggleNotifications: () =>
          setState(() => _notificationsEnabled = !_notificationsEnabled),
      onToggleMembers: () => setState(() => _showMembers = !_showMembers),
      onShowMembers: _showMemberDrawer,
      onShowChannels: _showChannelDrawer,
      onPinnedMessages: () => ToastService.showInfo(
        _textLabel(
          'Pinned messages are not available in the current messages schema.',
          'Tin nhắn ghim chưa khả dụng với cấu trúc dữ liệu hiện tại.',
        ),
      ),
      onChannelSettings: () => _showChannelSettings(channel),
      onScanNotebook: widget.onScanNotebook,
      onAttachHomework: widget.onAttachHomework,
      messageBuilder: _buildMessage,
    );
  }

  Widget _buildNoChannel({
    required bool compact,
    required bool showMembers,
    required double availableWidth,
  }) {
    return Column(
      children: [
        Container(
          height: 68,
          color: _panel,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 19),
          child: Row(
            children: [
              Icon(Icons.tag, color: _muted, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _textLabel('Select a channel', 'Chọn một kênh'),
                  style: TextStyle(color: _text, fontWeight: FontWeight.w700),
                ),
              ),
              if (compact)
                IconButton(
                  onPressed: _showChannelDrawer,
                  icon: Icon(Icons.menu_rounded, color: _muted),
                ),
              IconButton(
                onPressed: availableWidth < 1120
                    ? _showMemberDrawer
                    : () => setState(() => _showMembers = !_showMembers),
                icon: Icon(Icons.people_alt_outlined, color: _muted),
              ),
            ],
          ),
        ),
        Expanded(child: _buildEmptyWorkspace()),
      ],
    );
  }

  Widget _buildMessage(
    BuildContext context,
    Map<String, dynamic> message,
    String? currentUserId,
  ) {
    final senderId = message['sender_id']?.toString();
    final mine = senderId != null && senderId == currentUserId;
    final member = _memberFor(senderId);
    final senderRole =
        _roleForMember(member) ?? (mine ? _currentCustomRole : null);
    final senderName = mine ? _currentUserName : _displayName(member) ?? 'User';
    final content = message['content']?.toString() ?? '';
    final createdAt = DateTime.tryParse(message['created_at']?.toString() ?? '')
        ?.toLocal();
    final time = createdAt == null
        ? ''
        : TimeOfDay.fromDateTime(createdAt).format(context);
    final structured = _parseStructuredContent(content);
    final nameInitial = senderName.characters.first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserProfileAvatar(
            userId: senderId,
            radius: 17,
            fallbackText: nameInitial,
            backgroundColor: mine ? _accent : _panel,
            languageCode: _languageCode,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: SubscriptionUserName(
                        userId: senderId,
                        fallbackName: senderName,
                        defaultColor: mine ? _accent : _text,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (senderRole != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _roleColor(senderRole).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: _roleColor(senderRole)
                                .withValues(alpha: 0.55),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _roleColor(senderRole),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                senderRole['name']?.toString() ?? 'Role',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _roleColor(senderRole),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(time, style: TextStyle(color: _muted, fontSize: 9)),
                  ],
                ),
                const SizedBox(height: 6),
                if (structured?['type'] == 'file')
                  _buildFileCard(structured!)
                else if (structured?['type'] == 'ai_tutor')
                  _buildAiCard(structured!)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: mine
                          ? _accent.withValues(alpha: 0.08)
                          : _panel.withValues(alpha: 0.78),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: mine
                            ? _accent.withValues(alpha: 0.2)
                            : _border.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Text(
                      content,
                      style: TextStyle(
                        color: _text,
                        fontSize: 12,
                        height: 1.55,
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

  Map<String, dynamic>? _memberFor(String? id) {
    if (id == null) return null;
    for (final member in _members) {
      if (member['user_id']?.toString() == id) return member;
    }
    return null;
  }

  String? _displayName(Map<String, dynamic>? member) {
    if (member == null) return null;
    final profile = _mapValue(member['users']);
    final name = (profile?['full_name'] as String?)?.trim();
    if (name?.isNotEmpty == true) return name;
    final email = (profile?['email'] as String?)?.trim();
    return email?.isNotEmpty == true ? email : null;
  }

  Map<String, dynamic>? _parseStructuredContent(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic> &&
          const {'file', 'ai_tutor'}.contains(decoded['type'])) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Widget _buildFileCard(Map<String, dynamic> data) {
    final name = data['name']?.toString() ?? 'File';
    final size = data['size']?.toString() ?? '';
    final url = data['url']?.toString();
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEB5757).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Color(0xFFF07777),
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (size.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(size, style: TextStyle(color: _muted, fontSize: 9)),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: url == null
                ? _textLabel('No download link', 'Không có liên kết tải xuống')
                : _textLabel(
                    'Copy download link',
                    'Sao chép liên kết tải xuống',
                  ),
            onPressed: url == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (!mounted) return;
                    ToastService.showSuccess(
                      _textLabel(
                        'Download link copied.',
                        'Đã sao chép liên kết tải xuống.',
                      ),
                    );
                  },
            icon: Icon(Icons.download_outlined, size: 18, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard(Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? 'AI Tutor';
    final body = data['body']?.toString() ?? '';
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(9),
        border: Border(left: BorderSide(color: _accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: _accent,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: _themeColors.onAccent,
                  size: 13,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: _accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              body,
              style: TextStyle(color: _text, fontSize: 11, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendMessage(String content) async {
    final channelId = _channelId;
    if (channelId == null ||
        content.isEmpty ||
        _sending ||
        !_canSendToCurrentChannel) {
      return;
    }
    setState(() => _sending = true);
    try {
      await ClassroomService.sendMessage(channelId, content);
    } catch (error) {
      if (!mounted) return;
      ToastService.showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showChannelSettings(Map<String, dynamic> channel) async {
    if (!_canCreateChannel) return;
    final channelId = channel['id']?.toString();
    if (channelId == null) return;

    final nameController = TextEditingController(
      text: channel['name']?.toString() ?? '',
    );
    final visibleRoleIds = _channelRoleIds(channel).toSet();
    final chatRoleIds = _chatRoleIds(channel).toSet();
    var everyoneCanView = visibleRoleIds.isEmpty;
    var chatAccess =
        channel['chat_access']?.toString() ??
        (channel['allowed_roles'] == 'teacher_only' ? 'teachers' : 'everyone');
    var isHidden = channel['is_hidden'] == true;
    var missingRole = false;
    var missingVisibleRole = false;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => DiscordDialog(
          title: Text(_textLabel('Channel settings', 'Cài đặt kênh')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: _text),
                  decoration: _dialogInput(
                    _textLabel('Channel name', 'Tên kênh'),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _textLabel('CHANNEL ACCESS', 'QUYỀN TRUY CẬP KÊNH'),
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _discordCheckRow(
                  value: everyoneCanView,
                  label: _textLabel(
                    'Visible to everyone',
                    'Mọi người đều có thể xem',
                  ),
                  onChanged: (value) => setDialogState(() {
                    everyoneCanView = value;
                    if (everyoneCanView) visibleRoleIds.clear();
                  }),
                ),
                if (!everyoneCanView)
                  for (final role in _classroomRoles)
                    _discordCheckRow(
                      value: visibleRoleIds.contains(role['id'].toString()),
                      label: role['name']?.toString() ?? 'Role',
                      color: _roleColor(role),
                      indent: 16,
                      onChanged: (value) => setDialogState(() {
                        final id = role['id'].toString();
                        if (value) {
                          visibleRoleIds.add(id);
                        } else {
                          visibleRoleIds.remove(id);
                        }
                        missingVisibleRole = false;
                      }),
                    ),
                const SizedBox(height: 10),
                Text(
                  _textLabel('WHO CAN CHAT', 'AI CÓ THỂ TRÒ CHUYỆN'),
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Column(
                  children: [
                    _chatAccessOption(
                      chatAccess,
                      'everyone',
                      _textLabel('Everyone', 'Mọi người'),
                      () => setDialogState(() {
                        chatAccess = 'everyone';
                        missingRole = false;
                      }),
                    ),
                    _chatAccessOption(
                      chatAccess,
                      'roles',
                      _textLabel('Selected roles', 'Vai trò đã chọn'),
                      () => setDialogState(() {
                        chatAccess = 'roles';
                        missingRole = false;
                      }),
                    ),
                    _chatAccessOption(
                      chatAccess,
                      'teachers',
                      _textLabel('Teachers only', 'Chỉ giáo viên'),
                      () => setDialogState(() {
                        chatAccess = 'teachers';
                        missingRole = false;
                      }),
                    ),
                  ],
                ),
                if (chatAccess == 'roles')
                  for (final role in _classroomRoles)
                    _discordCheckRow(
                      value: chatRoleIds.contains(role['id'].toString()),
                      label: role['name']?.toString() ?? 'Role',
                      color: _roleColor(role),
                      indent: 16,
                      onChanged: (value) => setDialogState(() {
                        final id = role['id'].toString();
                        if (value) {
                          chatRoleIds.add(id);
                        } else {
                          chatRoleIds.remove(id);
                        }
                        missingRole = false;
                      }),
                    ),
                if (missingRole)
                  Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      _textLabel(
                        'Select at least one role who can chat.',
                        'Chọn ít nhất một vai trò được phép trò chuyện.',
                      ),
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
                if (missingVisibleRole)
                  Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      _textLabel(
                        'Select at least one role or enable everyone access.',
                        'Chọn ít nhất một vai trò hoặc bật quyền cho mọi người.',
                      ),
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                _discordSwitchRow(
                  value: isHidden,
                  title: isHidden
                      ? _textLabel('Channel is hidden', 'Kênh đang bị ẩn')
                      : _textLabel('Hide channel', 'Ẩn kênh'),
                  subtitle: _textLabel(
                    'Only teachers can see or reopen a hidden channel.',
                    'Chỉ giáo viên mới có thể xem hoặc mở lại kênh bị ẩn.',
                  ),
                  enabled: _isClassOwnerOrTeacher,
                  onChanged: (value) => setDialogState(() => isHidden = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'delete'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(_textLabel('Delete channel', 'Xóa kênh')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_textLabel('Cancel', 'Hủy')),
            ),
            FilledButton(
              onPressed: () {
                if (!everyoneCanView && visibleRoleIds.isEmpty) {
                  setDialogState(() => missingVisibleRole = true);
                  return;
                }
                if (chatAccess == 'roles' && chatRoleIds.isEmpty) {
                  setDialogState(() => missingRole = true);
                  return;
                }
                Navigator.pop(dialogContext, 'save');
              },
              child: Text(_textLabel('Save changes', 'Lưu thay đổi')),
            ),
          ],
        ),
      ),
    );
    final updatedName = nameController.text;
    nameController.dispose();
    if (!mounted || action == null) return;

    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => DiscordDialog(
          title: Text(_textLabel('Delete channel?', 'Xóa kênh?')),
          content: Text(
            _textLabel(
              'This permanently deletes the channel. This action cannot be undone.',
              'Kênh sẽ bị xóa vĩnh viễn và không thể khôi phục.',
            ),
            style: TextStyle(color: _muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_textLabel('Cancel', 'Hủy')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: Text(_textLabel('Delete', 'Xóa')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      try {
        await ClassroomService.deleteChannel(channelId);
        _selectChannel(null);
        await _loadClassroom(_classroomId!);
      } catch (error) {
        if (!mounted) return;
        ToastService.showError(_friendlyError(error));
      }
      return;
    }

    try {
      await ClassroomService.updateChannel(
        channelId: channelId,
        name: updatedName,
        targetRoleIds: everyoneCanView ? const [] : visibleRoleIds.toList(),
        chatAccess: chatAccess,
        chatRoleIds: chatAccess == 'roles' ? chatRoleIds.toList() : const [],
        isHidden: isHidden,
      );
      await _loadClassroom(_classroomId!);
      if (!mounted) return;
      ToastService.showSuccess(
        isHidden
            ? _textLabel(
                'Channel hidden from members.',
                'Đã ẩn kênh khỏi thành viên.',
              )
            : _textLabel('Channel updated.', 'Đã cập nhật kênh.'),
      );
    } catch (error) {
      if (!mounted) return;
      ToastService.showError(_friendlyError(error));
    }
  }

  Widget _discordCheckRow({
    required bool value,
    required String label,
    Color? color,
    double indent = 0,
    required ValueChanged<bool> onChanged,
  }) => Padding(
    padding: EdgeInsets.only(left: indent, top: 4, bottom: 4),
    child: Row(
      children: [
        DiscordCheckbox(value: value, onChanged: onChanged),
        const SizedBox(width: 10),
        if (color != null) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(label, style: TextStyle(color: _text, fontSize: 13)),
        ),
      ],
    ),
  );

  Widget _discordSwitchRow({
    required bool value,
    required String title,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) => Opacity(
    opacity: enabled ? 1 : 0.55,
    child: IgnorePointer(
      ignoring: !enabled,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: _muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          DiscordSwitch(value: value, onChanged: onChanged),
        ],
      ),
    ),
  );

  Widget _roleLabel(Map<String, dynamic> role) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: _roleColor(role),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          role['name']?.toString() ?? 'Role',
          style: TextStyle(color: _text, fontSize: 13),
        ),
      ),
    ],
  );

  Widget _chatAccessOption(
    String selectedValue,
    String value,
    String title,
    VoidCallback onTap,
  ) => DiscordChoiceTile(
    selected: selectedValue == value,
    title: Text(title, style: TextStyle(color: _text, fontSize: 13)),
    onTap: onTap,
  );

  List<List<Map<String, dynamic>>> _categorizedMembers() {
    final teachers = <Map<String, dynamic>>[];
    final officers = <Map<String, dynamic>>[];
    final students = <Map<String, dynamic>>[];
    for (final member in _members) {
      final role = member['role_in_class']?.toString().toLowerCase() ?? '';
      if (const {'owner', 'teacher', 'admin', 'developer'}.contains(role)) {
        teachers.add(member);
      } else if (role.contains('officer') ||
          role.contains('president') ||
          role.contains('leader') ||
          role.contains('monitor')) {
        officers.add(member);
      } else {
        students.add(member);
      }
    }
    return [teachers, officers, students];
  }

  Widget _buildMemberSidebar() {
    final groups = _categorizedMembers();
    final titles = [
      _textLabel('TEACHERS (ADMIN)', 'GIÁO VIÊN (QUẢN TRỊ)'),
      _textLabel('CLASS OFFICERS', 'BAN CÁN SỰ'),
      _textLabel('STUDENTS (MEMBERS)', 'HỌC SINH (THÀNH VIÊN)'),
    ];
    return ColoredBox(
      color: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 20, 12, 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _textLabel('MEMBERS', 'THÀNH VIÊN'),
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                Text(
                  '${_members.length}',
                  style: TextStyle(color: _muted, fontSize: 9),
                ),
              ],
            ),
          ),
          Expanded(
            child: _members.isEmpty
                ? Center(
                    child: Text(
                      _textLabel('No members found', 'Chưa có thành viên'),
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    children: [
                      for (var index = 0; index < groups.length; index++) ...[
                        if (groups[index].isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(9, 13, 8, 6),
                            child: Text(
                              '${titles[index]}  ${groups[index].length}',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          for (final member in groups[index])
                            _buildMemberTile(member),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member) {
    final name = _displayName(member) ?? 'User';
    final role = member['role_in_class']?.toString() ?? '';
    final customRole = _classroomRoles
        .where(
          (item) =>
              item['id']?.toString() == member['custom_role_id']?.toString(),
        )
        .firstOrNull;
    final owner =
        role.toLowerCase() == 'owner' || role.toLowerCase() == 'admin';
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: Key('discord-member-${member['user_id']}'),
        dense: true,
        minLeadingWidth: 30,
        horizontalTitleGap: 8,
        leading: UserProfileAvatar(
          userId: member['user_id']?.toString(),
          radius: 14,
          fallbackText: name.characters.first.toUpperCase(),
          backgroundColor: owner ? _accent : _card,
          languageCode: _languageCode,
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _text,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          customRole == null
              ? _localizedClassRole(role)
              : '${_localizedClassRole(role)} · ${customRole['name']?.toString() ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _muted, fontSize: 8),
        ),
        trailing: _canManageRoles
            ? Icon(Icons.manage_accounts_outlined, color: _muted, size: 18)
            : null,
        onTap: _canManageRoles ? () => _manageMemberRole(member) : null,
      ),
    );
  }

  Future<void> _manageMemberRole(Map<String, dynamic> member) async {
    final classroomId = _classroomId;
    final userId = member['user_id']?.toString();
    if (!_canManageRoles || classroomId == null || userId == null) return;

    var selectedRoleId = member['custom_role_id']?.toString() ?? '';
    final roles = List<Map<String, dynamic>>.of(_classroomRoles);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => DiscordDialog(
          title: Text(_textLabel('Set member role', 'Gán vai trò thành viên')),
          subtitle: _displayName(member) ?? _textLabel('Member', 'Thành viên'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName(member) ?? _textLabel('Member', 'Thành viên'),
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              DiscordChoiceTile(
                selected: selectedRoleId.isEmpty,
                title: Text(
                  _textLabel('No custom role', 'Không có vai trò riêng'),
                  style: TextStyle(color: _text, fontSize: 13),
                ),
                onTap: () => setDialogState(() => selectedRoleId = ''),
              ),
              for (final role in roles)
                Row(
                  children: [
                    Expanded(
                      child: DiscordChoiceTile(
                        selected: role['id']?.toString() == selectedRoleId,
                        title: _roleLabel(role),
                        onTap: () => setDialogState(
                          () => selectedRoleId = role['id'].toString(),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Edit role',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final updatedRole =
                              await showDialog<Map<String, dynamic>>(
                                context: dialogContext,
                                builder: (_) => RoleManagementDialog(
                                  classroomId: classroomId,
                                  initialRole: role,
                                  isVietnamese: _vi,
                                  languageCode: _languageCode,
                                ),
                              );
                          if (updatedRole == null ||
                              !dialogContext.mounted ||
                              !mounted) {
                            return;
                          }
                          final index = roles.indexWhere(
                            (item) =>
                                item['id']?.toString() ==
                                updatedRole['id']?.toString(),
                          );
                          if (index >= 0) roles[index] = updatedRole;
                          setState(() {
                            _classroomRoles = [...roles];
                          });
                          setDialogState(() {});
                        },
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.edit_outlined,
                            color: _muted,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final createdRole = await showDialog<Map<String, dynamic>>(
                      context: dialogContext,
                      builder: (_) => RoleManagementDialog(
                        classroomId: classroomId,
                        isVietnamese: _vi,
                        languageCode: _languageCode,
                      ),
                    );
                    if (createdRole == null ||
                        !dialogContext.mounted ||
                        !mounted) {
                      return;
                    }
                    setState(() {
                      _classroomRoles = [..._classroomRoles, createdRole];
                    });
                    setDialogState(() {
                      roles.add(createdRole);
                      selectedRoleId = createdRole['id'].toString();
                    });
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(_textLabel('Create role', 'Tạo vai trò')),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_textLabel('Cancel', 'Hủy')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selectedRoleId),
              child: Text(_textLabel('Set role', 'Gán vai trò')),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    try {
      await ClassroomService.assignClassroomRole(
        classroomId: classroomId,
        userId: userId,
        roleId: result.isEmpty ? null : result,
      );
      await _loadWorkspace(preferredClassroomId: classroomId);
      ToastService.showSuccess(
        _textLabel('Member role updated.', 'Đã cập nhật vai trò thành viên.'),
      );
    } catch (error) {
      if (!mounted) return;
      ToastService.showError(error.toString());
    }
  }

  Future<void> _showClassDetails() async {
    final classroom = _currentClassroom;
    final code = classroom?['code']?.toString() ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DiscordDialog(
        title: Text(
          classroom?['name']?.toString() ?? _textLabel('Classroom', 'Lớp học'),
          style: TextStyle(color: _text),
        ),
        content: SelectableText(
          '${_textLabel('Class code', 'Mã lớp')}: $code',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              ToastService.showSuccess(
                _textLabel('Class code copied.', 'Đã sao chép mã lớp.'),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(_textLabel('Copy code', 'Sao chép mã')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_textLabel('Close', 'Đóng')),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompactNavigation() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Row(
            children: [
              SizedBox(width: 230, child: _buildChannelSidebar()),
              VerticalDivider(width: 1, color: _border),
              Expanded(child: _buildMemberSidebar()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChannelDrawer() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: _buildChannelSidebar(),
        ),
      ),
    );
  }

  Future<void> _showMemberDrawer() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: _buildMemberSidebar(),
        ),
      ),
    );
  }

  Widget _buildEmptyWorkspace() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _panel.withValues(alpha: 0.96),
                _background.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _accent.withValues(alpha: 0.35)),
                ),
                child: Icon(Icons.hub_outlined, color: _accent, size: 27),
              ),
              const SizedBox(height: 18),
              Text(
                _loadError ??
                    _textLabel(
                      'Your classroom workspace is ready.',
                      'Không gian lớp học của bạn đã sẵn sàng.',
                    ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                _textLabel(
                  'Select a classroom from the rail, or create or join one to start collaborating.',
                  'Chọn lớp từ thanh bên, hoặc tạo hay tham gia lớp để bắt đầu cộng tác.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12, height: 1.6),
              ),
              if (_loadError != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _loadWorkspace,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: Text(_textLabel('Retry connection', 'Kết nối lại')),
                ),
              ] else ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('classroom-empty-create-join'),
                  onPressed: _showClassActions,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    _textLabel(
                      'Create or join classroom',
                      'Tạo hoặc tham gia lớp',
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

  Widget _buildLoadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, color: _muted, size: 34),
          const SizedBox(height: 11),
          Text(
            _loadError ??
                _textLabel(
                  'Unable to load classroom data.',
                  'Không thể tải dữ liệu lớp học.',
                ),
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _loadWorkspace,
            icon: const Icon(Icons.refresh),
            label: Text(_textLabel('Retry', 'Thử lại')),
          ),
        ],
      ),
    ),
  );
}

class RoleManagementDialog extends StatefulWidget {
  const RoleManagementDialog({
    super.key,
    required this.classroomId,
    this.isVietnamese = false,
    this.languageCode,
    this.initialRole,
  });

  final String classroomId;
  final bool isVietnamese;
  final String? languageCode;
  final Map<String, dynamic>? initialRole;

  @override
  State<RoleManagementDialog> createState() => _RoleManagementDialogState();
}

class _RoleManagementDialogState extends State<RoleManagementDialog> {
  static const _roleColors = [
    '#F59E0B',
    '#EF4444',
    '#06B6D4',
    '#3B82F6',
    '#8B5CF6',
    '#EC4899',
  ];

  final _nameController = TextEditingController();
  String _selectedColor = _roleColors.first;
  bool _canManageChannels = false;
  bool _canPinMessages = false;
  bool _canInvokeAi = false;
  bool _saving = false;
  String? _error;

  DiscordUiColors get _colors => DiscordUiColors.of(context);

  String _textLabel(String english, String vietnamese) {
    final languageCode =
        widget.languageCode ?? (widget.isVietnamese ? 'vi' : 'en');
    if (languageCode == 'zh') {
      return AppLocalizations.translateInline(
        english,
        languageCode: languageCode,
      );
    }
    return widget.isVietnamese ? vietnamese : english;
  }

  String _friendlyError(Object error) => widget.languageCode == 'zh'
      ? AppLocalizations.t('errors.unexpected', languageCode: 'zh')
      : error.toString();

  @override
  void initState() {
    super.initState();
    final role = widget.initialRole;
    if (role == null) return;
    _nameController.text = role['name']?.toString() ?? '';
    final color = role['color']?.toString() ?? _roleColors.first;
    if (_roleColors.contains(color)) _selectedColor = color;
    _canManageChannels = role['can_manage_channels'] == true;
    _canPinMessages = role['can_pin_messages'] == true;
    _canInvokeAi = role['can_invoke_ai'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _colorFromHex(String hex) =>
      Color(int.parse('FF${hex.substring(1)}', radix: 16));

  Future<void> _saveRole() async {
    if (_nameController.text.trim().isEmpty) {
      setState(
        () => _error = _textLabel('Enter a role name.', 'Nhập tên vai trò.'),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existingRoleId = widget.initialRole?['id']?.toString();
      final role = existingRoleId == null
          ? await ClassroomService.createClassroomRole(
              classroomId: widget.classroomId,
              name: _nameController.text,
              color: _selectedColor,
              canManageChannels: _canManageChannels,
              canPinMessages: _canPinMessages,
              canInvokeAi: _canInvokeAi,
            )
          : await ClassroomService.updateClassroomRole(
              roleId: existingRoleId,
              name: _nameController.text,
              color: _selectedColor,
              canManageChannels: _canManageChannels,
              canPinMessages: _canPinMessages,
              canInvokeAi: _canInvokeAi,
            );
      if (mounted) Navigator.of(context).pop(role);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return DiscordDialog(
      title: Text(_textLabel('Role Management', 'Quản lý vai trò')),
      subtitle: _textLabel(
        'Create and configure member permissions',
        'Tạo và thiết lập quyền cho thành viên',
      ),
      maxWidth: 480,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionLabel(_textLabel('ROLE NAME', 'TÊN VAI TRÒ')),
            const SizedBox(height: 7),
            TextField(
              controller: _nameController,
              enabled: !_saving,
              style: TextStyle(color: colors.text),
              decoration: InputDecoration(
                hintText: _textLabel('Role name', 'Tên vai trò'),
                hintStyle: TextStyle(color: colors.hint),
                filled: true,
                fillColor: colors.card,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.accent, width: 1.5),
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 18),
            _sectionLabel(_textLabel('ROLE COLOR', 'MÀU VAI TRÒ')),
            const SizedBox(height: 9),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                for (final hex in _roleColors)
                  Tooltip(
                    message: hex,
                    child: GestureDetector(
                      onTap: _saving
                          ? null
                          : () => setState(() => _selectedColor = hex),
                      child: GlideSelect(
                        selected: _selectedColor == hex,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _colorFromHex(hex),
                            border: Border.all(
                              color: _selectedColor == hex
                                  ? colors.text
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: _selectedColor == hex
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionLabel(_textLabel('PERMISSIONS', 'QUYỀN HẠN')),
            const SizedBox(height: 5),
            _permissionSwitch(
              title: _textLabel('Manage Channels', 'Quản lý kênh'),
              subtitle: _textLabel(
                'Allows adding, editing, and deleting channels for this classroom.',
                'Cho phép thêm, sửa và xóa kênh trong lớp học này.',
              ),
              value: _canManageChannels,
              onChanged: (value) => setState(() => _canManageChannels = value),
            ),
            _permissionSwitch(
              title: _textLabel('Pin Messages', 'Ghim tin nhắn'),
              subtitle: _textLabel(
                'Pin important messages and guidelines to the top of classroom channels.',
                'Ghim tin nhắn và hướng dẫn quan trọng lên đầu kênh lớp học.',
              ),
              value: _canPinMessages,
              onChanged: (value) => setState(() => _canPinMessages = value),
            ),
            _permissionSwitch(
              title: _textLabel('Tag', 'Tag'),
              subtitle: _textLabel(
                'Allows tagging members in messages and discussions.',
                'Cho phép gắn thẻ thành viên trong tin nhắn và thảo luận.',
              ),
              value: _canInvokeAi,
              onChanged: (value) => setState(() => _canInvokeAi = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(_textLabel('Cancel', 'Hủy')),
        ),
        FilledButton(
          onPressed: _saving ? null : _saveRole,
          style: FilledButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: colors.onAccent,
          ),
          child: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onAccent,
                  ),
                )
              : Text(_textLabel('Save Role Settings', 'Lưu cài đặt vai trò')),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      color: _colors.muted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
  );

  Widget _permissionSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _colors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(color: _colors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        DiscordSwitch(value: value, onChanged: _saving ? (_) {} : onChanged),
      ],
    ),
  );
}
