import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:astatine_dashboard/core/notifications/toast.dart';
import 'package:astatine_dashboard/core/ui/discord_ui.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';

import 'chat_screen.dart';
import 'classroom_service.dart';

class ClassroomChatScreen extends StatefulWidget {
  const ClassroomChatScreen({
    super.key,
    this.isVietnamese = false,
    this.currentUserName = 'User',
  });

  final bool isVietnamese;
  final String currentUserName;

  @override
  State<ClassroomChatScreen> createState() => _ClassroomChatScreenState();
}

class _ClassroomChatScreenState extends State<ClassroomChatScreen> {
  DiscordUiColors get _colors => DiscordUiColors.of(context);
  Color get _background => _colors.background;
  Color get _surface => _colors.panel;
  Color get _card => _colors.card;
  Color get _accent => _colors.accent;

  final _classNameController = TextEditingController();
  final _classCodeController = TextEditingController();
  final _channelNameController = TextEditingController();
  List<Map<String, dynamic>> _memberships = const [];
  List<Map<String, dynamic>> _channels = const [];
  List<Map<String, dynamic>> _members = const [];
  String? _appRole;
  String? _selectedClassroomId;
  String? _selectedChannelId;
  String? _loadError;
  bool _isLoading = true;
  bool _isPrivateChannel = false;
  String _allowedRoles = 'all';

  bool get _vi => widget.isVietnamese;
  bool get _canManageClass =>
      const {'teacher', 'developer'}.contains(_appRole?.toLowerCase());
  bool get _canManageChannels =>
      _canManageClass ||
      const {
        'owner',
        'teacher',
      }.contains(_selectedMembership?['role_in_class']);
  Map<String, dynamic>? get _selectedMembership {
    for (final membership in _memberships) {
      if (_classroomOf(membership)?['id']?.toString() == _selectedClassroomId) {
        return membership;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _selectedClassroom =>
      _classroomOf(_selectedMembership ?? const {});

  Map<String, dynamic>? get _selectedChannel {
    for (final channel in _channels) {
      if (channel['id']?.toString() == _selectedChannelId) return channel;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _classCodeController.dispose();
    _channelNameController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _classroomOf(Map<String, dynamic> membership) {
    final classroom = membership['classrooms'];
    if (classroom is Map<String, dynamic>) return classroom;
    if (classroom is Map) return Map<String, dynamic>.from(classroom);
    return null;
  }

  Future<void> _loadClassrooms({String? preferredClassId}) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final role = await ClassroomService.getUserRole();
      final memberships = await ClassroomService.getMyClassrooms();
      if (!mounted) return;
      final selectedId =
          memberships.any(
            (membership) =>
                _classroomOf(membership)?['id']?.toString() ==
                (preferredClassId ?? _selectedClassroomId),
          )
          ? (preferredClassId ?? _selectedClassroomId)
          : memberships.isEmpty
          ? null
          : _classroomOf(memberships.first)?['id']?.toString();
      setState(() {
        _appRole = role?.toLowerCase();
        _memberships = memberships;
        _selectedClassroomId = selectedId;
      });
      if (selectedId == null) {
        setState(() {
          _channels = const [];
          _members = const [];
          _selectedChannelId = null;
          _isLoading = false;
        });
        return;
      }
      await _loadClassroomContent(selectedId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadClassroomContent(String classroomId) async {
    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        ClassroomService.getChannels(classroomId),
        ClassroomService.getClassroomMembers(classroomId),
      ]);
      if (!mounted || classroomId != _selectedClassroomId) return;
      final channels = results[0];
      final members = results[1];
      final membershipRole = _selectedMembership?['role_in_class']?.toString();
      final canViewRestricted =
          _canManageClass ||
          const {'owner', 'teacher', 'developer'}.contains(membershipRole);
      final visibleChannels = channels.where((channel) {
        final restricted =
            channel['is_private'] == true ||
            channel['allowed_roles'] == 'teacher_only';
        return !restricted || canViewRestricted;
      }).toList();
      setState(() {
        _channels = visibleChannels;
        _members = members;
        if (!visibleChannels.any(
          (channel) => channel['id']?.toString() == _selectedChannelId,
        )) {
          _selectedChannelId = visibleChannels.isEmpty
              ? null
              : visibleChannels.first['id']?.toString();
        }
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

  Future<void> _selectClassroom(Map<String, dynamic> classroom) async {
    final id = classroom['id']?.toString();
    if (id == null || id == _selectedClassroomId) return;
    setState(() {
      _selectedClassroomId = id;
      _selectedChannelId = null;
      _channels = const [];
      _members = const [];
      _isLoading = true;
      _loadError = null;
    });
    await _loadClassroomContent(id);
  }

  Future<void> _showClassActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_canManageClass)
                ListTile(
                  leading: Icon(Icons.add_box_outlined, color: _accent),
                  title: Text(
                    _vi ? 'Tạo lớp học' : 'Create classroom',
                    style: TextStyle(color: _colors.text),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'create'),
                ),
              ListTile(
                leading: Icon(Icons.login_rounded, color: _accent),
                title: Text(
                  _vi ? 'Tham gia bằng mã lớp' : 'Join with a class code',
                  style: TextStyle(color: _colors.text),
                ),
                onTap: () => Navigator.pop(sheetContext, 'join'),
              ),
            ],
          ),
        ),
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
    _classNameController.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: Text(
          _vi ? 'Tạo lớp học' : 'Create classroom',
          style: TextStyle(color: _colors.text),
        ),
        content: TextField(
          key: const Key('class-name-input'),
          controller: _classNameController,
          autofocus: true,
          style: TextStyle(color: _colors.text),
          decoration: InputDecoration(
            labelText: _vi ? 'Tên lớp' : 'Class name',
            labelStyle: TextStyle(color: _colors.hint),
            filled: true,
            fillColor: _card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_vi ? 'Hủy' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _classNameController.text.trim()),
            child: Text(_vi ? 'Tạo' : 'Create'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      final code = await ClassroomService.createClassroom(name);
      await _loadClassrooms();
      final classroom = _memberships
          .map(_classroomOf)
          .whereType<Map<String, dynamic>>()
          .where((item) => item['code']?.toString() == code)
          .firstOrNull;
      if (classroom != null) await _selectClassroom(classroom);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _surface,
          title: Text(
            _vi ? 'Đã tạo lớp' : 'Classroom created',
            style: TextStyle(color: _colors.text),
          ),
          content: SelectableText(
            code,
            style: TextStyle(
              color: _colors.text,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.copy),
              label: Text(_vi ? 'Sao chép mã' : 'Copy code'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) {
        ToastService.showSuccess(
          _vi ? 'Đã tạo lớp học.' : 'Classroom created.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      ToastService.showError(error.toString());
    }
  }

  Future<void> _joinClassroom() async {
    _classCodeController.clear();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: Text(
          _vi ? 'Tham gia lớp' : 'Join classroom',
          style: TextStyle(color: _colors.text),
        ),
        content: TextField(
          key: const Key('class-code-input'),
          controller: _classCodeController,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(color: _colors.text),
          decoration: InputDecoration(
            labelText: _vi ? 'Mã lớp 6 ký tự' : '6-character class code',
            counterText: '',
            labelStyle: TextStyle(color: _colors.hint),
            filled: true,
            fillColor: _card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_vi ? 'Hủy' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _classCodeController.text.trim().toUpperCase(),
            ),
            child: Text(_vi ? 'Tham gia' : 'Join'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    try {
      await ClassroomService.joinClassroom(code);
      await _loadClassrooms();
      final classroom = _memberships
          .map(_classroomOf)
          .whereType<Map<String, dynamic>>()
          .where((item) => item['code']?.toString() == code)
          .firstOrNull;
      if (classroom != null) await _selectClassroom(classroom);
      ToastService.showSuccess(
        _vi ? 'Đã tham gia lớp học.' : 'Joined classroom.',
      );
    } catch (error) {
      if (!mounted) return;
      ToastService.showError(error.toString());
    }
  }

  Future<void> _createChannel() async {
    if (!_canManageChannels || _selectedClassroomId == null) return;
    _channelNameController.clear();
    _isPrivateChannel = false;
    _allowedRoles = 'all';
    final formKey = GlobalKey<FormState>();
    final draft = await showDialog<(String, bool, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => DiscordDialog(
          title: Text(_vi ? 'Tạo kênh' : 'Create channel'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('chat-channel-name-input'),
                  controller: _channelNameController,
                  autofocus: true,
                  style: TextStyle(color: _colors.text),
                  decoration: InputDecoration(
                    labelText: _vi ? 'Tên kênh' : 'Channel name',
                    labelStyle: TextStyle(color: _colors.hint),
                    filled: true,
                    fillColor: _card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? (_vi ? 'Nhập tên kênh.' : 'Enter a channel name.')
                      : null,
                ),
                DiscordChoiceTile(
                  selected: _allowedRoles == 'all',
                  title: Text(
                    _vi ? 'Tất cả thành viên' : 'All members',
                    style: TextStyle(color: _colors.text),
                  ),
                  onTap: () => setDialogState(() {
                    _isPrivateChannel = false;
                    _allowedRoles = 'all';
                  }),
                ),
                DiscordChoiceTile(
                  selected: _allowedRoles == 'teacher_only',
                  title: Text(
                    _vi ? 'Chỉ giáo viên' : 'Teachers only',
                    style: TextStyle(color: _colors.text),
                  ),
                  onTap: () => setDialogState(() {
                    _isPrivateChannel = true;
                    _allowedRoles = 'teacher_only';
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_vi ? 'Hủy' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, (
                    _channelNameController.text.trim(),
                    _isPrivateChannel,
                    _allowedRoles,
                  ));
                }
              },
              child: Text(_vi ? 'Tạo kênh' : 'Create channel'),
            ),
          ],
        ),
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await ClassroomService.createChannel(
        _selectedClassroomId!,
        draft.$1,
        draft.$2,
        draft.$3,
      );
      await _loadClassroomContent(_selectedClassroomId!);
      ToastService.showSuccess(
        _vi ? 'Đã tạo kênh.' : 'Channel created.',
      );
    } catch (error) {
      if (!mounted) return;
      ToastService.showError(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 720;
        final showMembers = width >= 1100;
        if (_isLoading && _memberships.isEmpty) {
          return Scaffold(
            backgroundColor: _background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: _background,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopClassroomBar(compact: compact),
                Expanded(
                  child: _loadError != null
                      ? _buildError()
                      : _selectedClassroomId == null
                      ? _buildEmptyClassroomState()
                      : Row(
                          children: [
                            if (!compact) ...[
                              SizedBox(
                                width: width < 1000 ? 215 : 240,
                                child: _buildChannelSidebar(),
                              ),
                              VerticalDivider(
                                width: 1,
                                color: _colors.border.withValues(alpha: 0.55),
                              ),
                            ],
                            Expanded(child: _buildChatArea(compact: compact)),
                            if (showMembers) ...[
                              VerticalDivider(
                                width: 1,
                                color: _colors.border.withValues(alpha: 0.55),
                              ),
                              SizedBox(
                                width: 220,
                                child: _buildMemberSidebar(),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopClassroomBar({required bool compact}) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
      color: _surface,
      child: Row(
        children: [
          if (!compact) ...[
            Text(
              'AstatineEdu',
              style: TextStyle(
                color: _accent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 16),
            VerticalDivider(
              color: _colors.border.withValues(alpha: 0.65),
              indent: 12,
              endIndent: 12,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: _memberships.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _vi ? 'Lớp học của tôi' : 'My classrooms',
                      style: TextStyle(
                        color: _colors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    key: const Key('classroom-chip-list'),
                    scrollDirection: Axis.horizontal,
                    itemCount: _memberships.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final classroom = _classroomOf(_memberships[index]);
                      if (classroom == null) return const SizedBox.shrink();
                      final id = classroom['id']?.toString();
                      final selected = id == _selectedClassroomId;
                      return Center(
                        child: ChoiceChip(
                          key: Key('classroom-chip-$id'),
                          label: GlideSelect(
                            selected: selected,
                            child: Text(
                              classroom['name'] as String? ?? 'Class',
                            ),
                          ),
                          selected: selected,
                          selectedColor: _accent,
                          backgroundColor: _card,
                          labelStyle: TextStyle(
                            color: selected ? _colors.onAccent : _colors.text,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          onSelected: (_) => _selectClassroom(classroom),
                        ),
                      );
                    },
                  ),
          ),
          if (!compact && _selectedClassroom?['code'] is String)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _copyClassCode,
                icon: const Icon(Icons.key_rounded, size: 16),
                label: Text(
                  _selectedClassroom!['code'] as String,
                  style: const TextStyle(letterSpacing: 1.2),
                ),
              ),
            ),
          if (!compact && !(_canManageClass || _appRole == 'student'))
            IconButton(
              tooltip: _vi ? 'Tải lại lớp' : 'Reload classrooms',
              onPressed: _loadClassrooms,
              icon: Icon(Icons.refresh_rounded, color: _colors.muted),
            ),
          IconButton(
            key: const Key('classroom-actions'),
            tooltip: _vi ? 'Tạo hoặc tham gia lớp' : 'Create or join a class',
            onPressed: _showClassActions,
            icon: CircleAvatar(
              backgroundColor: _accent,
              radius: 17,
              child: Icon(Icons.add, color: _colors.onAccent, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyClassCode() async {
    final code = _selectedClassroom?['code']?.toString();
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ToastService.showSuccess(
      _vi ? 'Đã sao chép mã lớp.' : 'Class code copied.',
    );
  }

  Widget _buildEmptyClassroomState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, color: _accent, size: 42),
            const SizedBox(height: 14),
            Text(
              _vi
                  ? 'Hãy chọn hoặc bấm “+” để tạo/tham gia lớp học.'
                  : 'Choose a classroom or use “+” to create or join one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _colors.muted, fontSize: 14),
            ),
            if (_loadError != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadClassrooms,
                icon: const Icon(Icons.refresh),
                label: Text(_vi ? 'Thử lại' : 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, color: _colors.muted, size: 36),
          const SizedBox(height: 12),
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: _colors.muted),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loadClassrooms,
            icon: const Icon(Icons.refresh),
            label: Text(_vi ? 'Thử lại' : 'Retry'),
          ),
        ],
      ),
    ),
  );

  Widget _buildChannelSidebar() {
    final classroom = _selectedClassroom;
    return ColoredBox(
      color: _surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classroom?['name'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_vi ? 'Mã lớp' : 'Class code'}: ${classroom?['code'] ?? ''}',
                  style: TextStyle(color: _colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Divider(color: _colors.border, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _vi ? 'DANH SÁCH KÊNH' : 'CHANNELS',
                    style: TextStyle(
                      color: _colors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_canManageChannels)
                  IconButton(
                    key: const Key('create-chat-channel'),
                    tooltip: _vi ? 'Tạo kênh mới' : 'Create channel',
                    visualDensity: VisualDensity.compact,
                    onPressed: _createChannel,
                    icon: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: _colors.muted,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _channels.isEmpty
                ? Center(
                    child: Text(
                      _vi ? 'Chưa có kênh nào.' : 'No channels yet.',
                      style: TextStyle(color: _colors.muted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: _channels.length,
                    itemBuilder: (context, index) {
                      final channel = _channels[index];
                      final id = channel['id']?.toString() ?? '';
                      final name = channel['name'] as String? ?? '';
                      final selected = id == _selectedChannelId;
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          key: Key('chat-channel-$id'),
                          dense: true,
                          leading: Icon(
                            channel['is_private'] == true
                                ? Icons.lock_outline
                                : Icons.tag,
                            color: selected ? _accent : _colors.muted,
                            size: 18,
                          ),
                          title: GlideSelect(
                            selected: selected,
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? _colors.onAccent
                                    : _colors.text,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          selected: selected,
                          selectedTileColor: _accent.withValues(alpha: 0.14),
                          onTap: () => setState(() => _selectedChannelId = id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea({required bool compact}) {
    final channel = _selectedChannel;
    if (channel == null) {
      return Center(
        child: Text(
          _vi ? 'Chọn một kênh để bắt đầu chat.' : 'Select a channel to chat.',
          style: TextStyle(color: _colors.muted),
        ),
      );
    }
    final channelId = channel['id']?.toString() ?? '';
    final channelName = channel['name'] as String? ?? '';
    return Column(
      children: [
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: _surface,
          child: Row(
            children: [
              if (compact)
                IconButton(
                  key: const Key('open-class-channel-sidebar'),
                  tooltip: _vi ? 'Danh sách kênh' : 'Channels',
                  onPressed: _showChannelSidebarSheet,
                  icon: Icon(Icons.menu, color: _colors.muted),
                ),
              Icon(Icons.tag, color: _colors.muted, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _colors.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (!compact && MediaQuery.sizeOf(context).width < 1100)
                IconButton(
                  key: const Key('open-class-member-sidebar'),
                  tooltip: _vi ? 'Thành viên lớp' : 'Class members',
                  onPressed: _showMemberSidebarSheet,
                  icon: Icon(Icons.people_outline, color: _colors.muted),
                ),
            ],
          ),
        ),
        Expanded(
          child: ChatScreen(
            key: ValueKey(channelId),
            channelId: channelId,
            channelName: channelName,
            embedded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberSidebar() {
    return ColoredBox(
      color: _surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _vi ? 'THÀNH VIÊN LỚP' : 'CLASS MEMBERS',
              style: TextStyle(
                color: _colors.muted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: _members.isEmpty
                ? Center(
                    child: Text(
                      _vi ? 'Chưa có thành viên.' : 'No members found.',
                      style: TextStyle(color: _colors.muted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final user = _mapValue(member['users']);
                      final name = (user?['full_name'] as String?)?.trim();
                      final email = (user?['email'] as String?)?.trim();
                      final displayName = name?.isNotEmpty == true
                          ? name!
                          : email?.isNotEmpty == true
                          ? email!
                          : _vi
                          ? 'Thành viên'
                          : 'Member';
                      final role = member['role_in_class']?.toString() ?? '';
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          key: Key('class-member-${member['user_id']}'),
                          dense: true,
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: role == 'owner' ? _accent : _card,
                            child: Text(
                              displayName[0].toUpperCase(),
                              style: TextStyle(
                                color: _colors.onAccent,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          title: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _colors.text, fontSize: 12),
                          ),
                          subtitle: Text(
                            role,
                            style: TextStyle(
                              color: _colors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _mapValue(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  Future<void> _showChannelSidebarSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: _buildChannelSidebar(),
        ),
      ),
    );
  }

  Future<void> _showMemberSidebarSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: _buildMemberSidebar(),
        ),
      ),
    );
  }
}
