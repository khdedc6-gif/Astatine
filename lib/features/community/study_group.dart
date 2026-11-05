import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/notifications/toast_service.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';
import 'package:astatine_dashboard/core/ui/hover_ripple.dart';
import 'package:astatine_dashboard/features/ai/ai_service.dart';
import 'package:astatine_dashboard/features/ai/gemini_assistant.dart';
import 'package:astatine_dashboard/features/profile/subscription_name_effect.dart';

import 'invitecard_parttern.dart';
import 'study_group_repository.dart';

class _InviteCardData {
  _InviteCardData({
    required this.id,
    required this.inviterName,
    required this.members,
    required this.groupName,
    required this.subject,
    required this.className,
    required this.topic,
    required this.deadline,
    required this.taskAssignments,
    required this.aiDetectionEnabled,
    this.remoteId,
  });

  final int id;
  final String inviterName;
  final List<String> members;
  final String groupName;
  final String subject;
  final String className;
  final String topic;
  final String deadline;
  final List<_TaskAssignment> taskAssignments;
  final bool aiDetectionEnabled;
  final String? remoteId;
  String status = 'pending';

  int get totalMembers => members.length;
  String taskDescriptionFor(String? userId) {
    if (userId != null) {
      return taskAssignments
              .where((assignment) => assignment.assigneeUserId == userId)
              .firstOrNull
              ?.description ??
          '';
    }
    return taskAssignments
            .where((assignment) => assignment.assignee == inviterName)
            .firstOrNull
            ?.description ??
        taskAssignments.firstOrNull?.description ??
        '';
  }
}

class _TaskAssignment {
  const _TaskAssignment({
    required this.assignee,
    required this.description,
    required this.rubric,
    required this.formattingRules,
    required this.contentFormat,
    required this.requiredFileCount,
    required this.submissionCriteria,
    this.assigneeUserId,
  });

  final String assignee;
  final String description;
  final String rubric;
  final String formattingRules;
  final String? contentFormat;
  final int requiredFileCount;
  final String submissionCriteria;
  final String? assigneeUserId;
}

enum _WorkspaceUploadStatus { uploading, success, error }

class _WorkspaceUpload {
  _WorkspaceUpload({
    required this.name,
    required this.assignee,
    this.file,
    this.remoteId,
    this.storagePath,
    this.assigneeUserId,
    this.sizeBytes,
    this.mimeType,
    this.status = _WorkspaceUploadStatus.uploading,
    this.uploadedAt,
  });

  final String name;
  final String assignee;
  final PlatformFile? file;
  final String? remoteId;
  final String? storagePath;
  final String? assigneeUserId;
  final int? sizeBytes;
  final String? mimeType;
  _WorkspaceUploadStatus status;
  DateTime? uploadedAt;
}

class _ChatAttachment {
  const _ChatAttachment({required this.file, this.imageBytes});

  final PlatformFile file;
  final Uint8List? imageBytes;
}

class _GroupChatMessage {
  const _GroupChatMessage({
    required this.senderName,
    required this.text,
    required this.sentAt,
    this.attachments = const [],
    this.isGemini = false,
    this.isPending = false,
  });

  final String senderName;
  final String text;
  final DateTime sentAt;
  final List<_ChatAttachment> attachments;
  final bool isGemini;
  final bool isPending;
}

class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({
    super.key,
    this.isVietnamese = false,
    this.languageCode,
    this.currentUserName,
    this.currentUserId,
    this.dataSource,
    this.filePicker,
    this.geminiRequest,
  });

  final bool isVietnamese;
  final String? languageCode;
  final String? currentUserName;
  final String? currentUserId;
  final StudyGroupDataSource? dataSource;
  final Future<List<PlatformFile>?> Function()? filePicker;
  final GeminiRequest? geminiRequest;

  @override
  State<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends State<CreateWorkspaceScreen> {
  static const _subjects = [
    'Math',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'Literature',
    'Civic Education',
    'History & Geography',
    'Computer Science',
    'Technology',
    'Other',
  ];
  List<String> get _availableMembers {
    if (_usesRemoteGroups) {
      return _classroomMembers
          .where((member) => member.id != widget.currentUserId)
          .map((member) => member.name)
          .toList();
    }
    const members = ['A', 'B', 'Leo Carter', 'Socratic AI Bot'];
    if (members.any(_isCurrentUserAssignment)) return members;
    return [_currentUserName, ...members];
  }

  static const _contentFormats = ['image', 'content', 'video', 'document'];

  AstatinePalette get _palette =>
      Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
  bool get _vi => widget.isVietnamese;
  String get _languageCode => widget.languageCode ?? (_vi ? 'vi' : 'en');
  String get _currentUserName =>
      widget.currentUserName ?? _text('User', 'Người dùng');
  bool get _usesRemoteGroups => widget.currentUserId?.isNotEmpty == true;
  StudyGroupDataSource? _repository;
  List<StudyGroupClassroom> _classrooms = const [];
  List<StudyGroupMember> _classroomMembers = const [];
  final Map<String, String> _memberIdsByName = {};
  final TextEditingController _memberSearchController = TextEditingController();
  String? _selectedClassroomId;
  String? _loadError;
  bool _loadingClassrooms = false;
  bool _loadingMembers = false;
  bool _savingGroup = false;
  bool _remoteDataLoaded = false;
  Future<void>? _remoteDataLoad;
  final Map<String, Future<void>> _projectFileLoads = {};
  final Set<String> _loadedProjectFileGroups = {};
  final Set<String> _inviteResponsesInProgress = {};
  int _projectFilesRevision = 0;

  int _selectedNavIndex = 0;
  bool _aiDetectionEnabled = true;
  String? _selectedSubject;
  final List<String> _invitedMembers = [''];
  String? _selectedAssignee = '';
  final Map<String, _TaskAssignment> _taskAssignmentsByAssignee = {};
  final List<_InviteCardData> _createdInvites = [];
  final List<_InviteCardData> _activeProjects = [];
  _InviteCardData? _selectedProject;
  final Map<int, Map<String, int>> _submittedFileCounts = {};
  final Map<int, List<_WorkspaceUpload>> _workspaceUploads = {};
  final Map<int, List<_GroupChatMessage>> _groupMessages = {};
  int _nextGroupId = 0;
  final ScrollController _inviteScrollController = ScrollController();
  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _chatMessageController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _taskDescController = TextEditingController();
  final TextEditingController _rubricController = TextEditingController();
  final TextEditingController _formattingRulesController =
      TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _criteriaController = TextEditingController();
  String? _selectedContentFormat;
  final DateTime _deadline = DateTime(2026, 10, 24);
  late final TextEditingController _deadlineController = TextEditingController(
    text: _formatDeadline(_deadline),
  );

  String _text(String english, String vietnamese) => _languageCode == 'zh'
      ? AppLocalizations.translateInline(english, languageCode: _languageCode)
      : _vi
      ? vietnamese
      : english;

  Future<void> _loadRemoteData({bool forceRefresh = false}) {
    final inFlight = _remoteDataLoad;
    if (inFlight != null) return inFlight;
    if (_remoteDataLoaded && !forceRefresh) return Future<void>.value();
    final request = _performRemoteDataLoad(forceRefresh: forceRefresh);
    _remoteDataLoad = request;
    return request.whenComplete(() {
      if (identical(_remoteDataLoad, request)) _remoteDataLoad = null;
    });
  }

  Future<void> _performRemoteDataLoad({required bool forceRefresh}) async {
    final repository = _repository;
    final userId = widget.currentUserId;
    if (repository == null || userId == null) return;
    setState(() {
      _loadingClassrooms = true;
      _loadError = null;
    });
    try {
      final classroomsRequest = repository.loadClassrooms(userId);
      final workspacesRequest = repository.loadWorkspaces(userId);
      final results = await Future.wait<Object>([
        classroomsRequest,
        workspacesRequest,
      ]);
      final classrooms = results[0] as List<StudyGroupClassroom>;
      final workspaces = results[1] as List<StudyGroupWorkspace>;
      if (!mounted) return;
      if (forceRefresh) {
        _projectFilesRevision++;
        _projectFileLoads.clear();
        _loadedProjectFileGroups.clear();
        _workspaceUploads.clear();
        _submittedFileCounts.clear();
      }
      _remoteDataLoaded = true;
      setState(() {
        _classrooms = classrooms;
        _loadingClassrooms = false;
        _memberIdsByName.clear();
        _createdInvites.clear();
        _activeProjects.clear();
        for (final workspace in workspaces) {
          final project = _workspaceToInvite(workspace);
          if (workspace.membershipStatus == 'pending') {
            _createdInvites.add(project);
          } else {
            _activeProjects.add(project);
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingClassrooms = false;
        _loadError = error.toString();
      });
    }
  }

  _InviteCardData _workspaceToInvite(StudyGroupWorkspace workspace) {
    final group = workspace.group;
    final memberNamesById = {
      for (final member in workspace.members)
        member['user_id'].toString(): member['name'].toString(),
    };
    final creatorId = group['created_by']?.toString();
    final creatorName = memberNamesById[creatorId] ?? _currentUserName;
    final taskRows = group['task_assignments'];
    final tasks = taskRows is List
        ? taskRows.whereType<Map>().map((row) {
            final task = Map<String, dynamic>.from(row);
            return _TaskAssignment(
              assignee: task['assignee']?.toString() ?? '',
              assigneeUserId: task['assignee_user_id']?.toString(),
              description: task['description']?.toString() ?? '',
              rubric: task['rubric']?.toString() ?? '',
              formattingRules: task['formatting_rules']?.toString() ?? '',
              contentFormat: task['content_format']?.toString(),
              requiredFileCount:
                  int.tryParse(task['required_file_count']?.toString() ?? '') ??
                  1,
              submissionCriteria: task['submission_criteria']?.toString() ?? '',
            );
          }).toList()
        : <_TaskAssignment>[];
    final memberNames = workspace.members
        .map((member) => member['name'].toString())
        .toList();
    final project = _InviteCardData(
      id: _nextGroupId++,
      remoteId: group['id']?.toString(),
      inviterName: creatorName,
      members: List.unmodifiable(memberNames),
      groupName: group['group_name']?.toString() ?? '',
      subject: group['subject']?.toString() ?? '',
      className: group['class_name']?.toString() ?? '',
      topic: group['topic']?.toString() ?? '',
      deadline: group['deadline']?.toString() ?? '',
      taskAssignments: List.unmodifiable(tasks),
      aiDetectionEnabled: group['ai_detection_enabled'] == true,
    )..status = workspace.membershipStatus;
    for (final member in workspace.members) {
      final userId = member['user_id']?.toString();
      final name = member['name']?.toString();
      if (userId != null && name != null) _memberIdsByName[name] = userId;
    }
    return project;
  }

  Future<void> _loadProjectFiles(_InviteCardData project) {
    final repository = _repository;
    final remoteId = project.remoteId;
    if (repository == null || remoteId == null) return Future<void>.value();
    if (_loadedProjectFileGroups.contains(remoteId)) {
      return Future<void>.value();
    }
    final inFlight = _projectFileLoads[remoteId];
    if (inFlight != null) return inFlight;
    final revision = _projectFilesRevision;
    final request = _fetchProjectFiles(repository, project, remoteId, revision);
    _projectFileLoads[remoteId] = request;
    return request.whenComplete(() {
      if (identical(_projectFileLoads[remoteId], request)) {
        _projectFileLoads.remove(remoteId);
      }
    });
  }

  Future<void> _fetchProjectFiles(
    StudyGroupDataSource repository,
    _InviteCardData project,
    String remoteId,
    int revision,
  ) async {
    final rows = await repository.loadGroupFiles(remoteId);
    final namesByUserId = {
      for (final member in project.members)
        if (_memberIdsByName[member] != null) _memberIdsByName[member]!: member,
    };
    final uploads = rows.map((row) {
      final assigneeId = row['assignee_user_id']?.toString();
      final uploaderId = row['uploaded_by']?.toString();
      final memberId = assigneeId ?? uploaderId;
      return _WorkspaceUpload(
        remoteId: row['id']?.toString(),
        storagePath: row['storage_path']?.toString(),
        name: row['file_name']?.toString() ?? '',
        assignee:
            namesByUserId[memberId] ?? _text('Group member', 'Thành viên nhóm'),
        assigneeUserId: assigneeId,
        sizeBytes: int.tryParse(row['size_bytes']?.toString() ?? ''),
        mimeType: row['mime_type']?.toString(),
        status: _WorkspaceUploadStatus.success,
        uploadedAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      );
    }).toList();
    if (!mounted || revision != _projectFilesRevision) return;
    setState(() {
      _workspaceUploads[project.id] = uploads;
      _updateSubmittedFileCounts(project, uploads);
    });
    _loadedProjectFileGroups.add(remoteId);
  }

  void _updateSubmittedFileCounts(
    _InviteCardData project,
    List<_WorkspaceUpload> uploads,
  ) {
    final assigneeByUserId = {
      for (final assignment in project.taskAssignments)
        if (assignment.assigneeUserId != null)
          assignment.assigneeUserId!: assignment.assignee,
    };
    final submitted = <String, int>{};
    for (final upload in uploads) {
      if (upload.status != _WorkspaceUploadStatus.success) continue;
      final assignee = assigneeByUserId[upload.assigneeUserId];
      if (assignee == null) continue;
      submitted.update(assignee, (count) => count + 1, ifAbsent: () => 1);
    }
    _submittedFileCounts[project.id] = submitted;
  }

  Future<void> _loadProjectFilesSafely(_InviteCardData project) async {
    try {
      await _loadProjectFiles(project);
    } catch (error) {
      if (!mounted) return;
      ToastService.showError(
        _text(
          'Could not load group files: $error',
          'Không thể tải tệp nhóm: $error',
        ),
      );
    }
  }

  Future<void> _selectClassroom(String? classroomId) async {
    if (classroomId == null || classroomId == _selectedClassroomId) return;
    final repository = _repository;
    if (repository == null) return;
    setState(() {
      _selectedClassroomId = classroomId;
      _classroomMembers = const [];
      _memberIdsByName.clear();
      _invitedMembers.clear();
      _taskAssignmentsByAssignee.clear();
      _selectedAssignee = '';
      _loadTaskDescription('');
      _loadingMembers = true;
      _loadError = null;
    });
    try {
      final members = await repository.loadClassroomMembers(classroomId);
      if (!mounted || _selectedClassroomId != classroomId) return;
      setState(() {
        _classroomMembers = members;
        _memberIdsByName
          ..clear()
          ..addEntries(
            members.map((member) => MapEntry(member.name, member.id)),
          );
        _loadingMembers = false;
        _classNameController.text = _classrooms
            .firstWhere((classroom) => classroom.id == classroomId)
            .name;
      });
    } catch (error) {
      if (!mounted || _selectedClassroomId != classroomId) return;
      setState(() {
        _loadingMembers = false;
        _loadError = error.toString();
      });
    }
  }

  String _subjectLabel(String subject) {
    if (_languageCode == 'zh') {
      return AppLocalizations.translateInline(subject, languageCode: 'zh');
    }
    if (!_vi) return subject;
    return switch (subject) {
      'Math' => 'Toán',
      'Physics' => 'Vật lý',
      'Chemistry' => 'Hóa học',
      'Biology' => 'Sinh học',
      'English' => 'Tiếng Anh',
      'Literature' => 'Ngữ văn',
      'Civic Education' => 'GDCD',
      'History & Geography' => 'Lịch sử & Địa lí',
      'Computer Science' => 'Tin học',
      'Technology' => 'Công nghệ',
      'Other' => 'Khác',
      _ => subject,
    };
  }

  String _contentFormatLabel(String format) => switch (format) {
    'image' => _text('Image', 'Ảnh'),
    'content' => _text('Content', 'Nội dung'),
    'video' => 'Video',
    _ => _text('Document', 'Tài liệu'),
  };

  @override
  void initState() {
    super.initState();
    if (_usesRemoteGroups) {
      _repository =
          widget.dataSource ?? StudyGroupRepository(Supabase.instance.client);
      _loadRemoteData();
    }
  }

  @override
  void dispose() {
    _inviteScrollController.dispose();
    _chatScrollController.dispose();
    _chatMessageController.dispose();
    _groupNameController.dispose();
    _classNameController.dispose();
    _topicController.dispose();
    _taskDescController.dispose();
    _rubricController.dispose();
    _formattingRulesController.dispose();
    _quantityController.dispose();
    _criteriaController.dispose();
    _deadlineController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: _palette.background,
          body: Stack(
            children: [
              Row(
                children: [
                  if (wide) _buildSidebar(),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(wide ? 30 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(wide),
                          if (!wide) ...[
                            const SizedBox(height: 12),
                            _buildCompactNavigation(),
                          ],
                          if (_loadError != null) ...[
                            const SizedBox(height: 10),
                            Material(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _text(
                                          'Could not load classrooms or groups: $_loadError',
                                          'Không thể tải lớp hoặc nhóm: $_loadError',
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFFFF8A80),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _loadRemoteData(forceRefresh: true),
                                      child: Text(_text('Retry', 'Tải lại')),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Expanded(
                            child: _selectedNavIndex == 1
                                ? _buildInvitesView()
                                : _selectedNavIndex == 2
                                ? _buildDetailsPanel()
                                : SingleChildScrollView(
                                    physics: const ClampingScrollPhysics(),
                                    child: _buildSelectedContent(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedNavIndex != 3)
                Positioned(
                  right: 20,
                  bottom: 92,
                  child: GeminiAssistantBubble(
                    isVietnamese: _vi,
                    languageCode: _languageCode,
                    interfaceName: _selectedProject?.groupName ?? 'Project Hub',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return SizedBox(
      width: 240,
      child: ColoredBox(
        color: _palette.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _palette.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.hub, color: _palette.accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ASTATINE',
                        style: TextStyle(
                          color: _palette.canvasText,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'PROJECT HUB',
                        style: TextStyle(
                          color: _palette.canvasMutedText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: _palette.border, height: 1),
            const SizedBox(height: 16),
            _buildNavItem(
              0,
              Icons.add_circle_outline,
              _text('Create', 'Tạo nhóm'),
            ),
            _buildNavItem(1, Icons.group_outlined, _text('Invites', 'Lời mời')),
            _buildNavItem(2, Icons.info_outline, _text('Details', 'Chi tiết')),
            _buildNavItem(
              3,
              Icons.settings_outlined,
              _text('Settings', 'Cài đặt'),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _palette.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _palette.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _palette.accent,
                    child: Text(
                      _currentUserName[0].toUpperCase(),
                      style: TextStyle(
                        color: _palette.accentText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUserName,
                        style: TextStyle(
                          color: _palette.primaryText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _text('Signed in', 'Đã đăng nhập'),
                        style: TextStyle(
                          color: _palette.secondaryText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactNavigation() {
    return DefaultTabController(
      length: 4,
      initialIndex: _selectedNavIndex,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        onTap: _navigateTo,
        tabs: [
          for (var index = 0; index < 4; index++) Tab(text: _navLabel(index)),
        ],
      ),
    );
  }

  String _navLabel(int index) => switch (index) {
    0 => _text('Create', 'Tạo nhóm'),
    1 => _text('Invites', 'Lời mời'),
    2 => _text('Details', 'Chi tiết'),
    _ => _text('Settings', 'Cài đặt'),
  };

  void _navigateTo(int index) {
    setState(() => _selectedNavIndex = index);
    if (index == 1 && _usesRemoteGroups) unawaited(_loadRemoteData());
  }

  Widget _buildNavItem(int index, IconData icon, String title) {
    final selected = _selectedNavIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected
            ? _palette.accent.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          onTap: () => _navigateTo(index),
          leading: Icon(
            icon,
            color: selected ? _palette.accent : _palette.secondaryText,
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: selected ? _palette.primaryText : _palette.secondaryText,
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool wide) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text('STUDENT WORKSPACE', 'KHÔNG GIAN HỌC TẬP'),
                style: TextStyle(
                  color: _palette.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _text(
                  'Create Study Group & Project',
                  'Tạo nhóm học tập & dự án',
                ),
                style: TextStyle(
                  color: _palette.canvasText,
                  fontSize: wide ? 24 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedContent() => switch (_selectedNavIndex) {
    0 => _buildCreateForm(),
    2 => _buildDetailsPanel(),
    _ => _buildRulesPanel(),
  };

  Widget _buildCreateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          title: _text('CREATION PARAMETERS', 'THÔNG TIN TẠO NHÓM'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final fieldWidth = constraints.maxWidth >= 760
                      ? (constraints.maxWidth - 28) / 3
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: _fieldGroup(
                          _text('SUBJECT', 'MÔN HỌC'),
                          GlideSelect<String>.dropdown(
                            key: const Key('subject-dropdown'),
                            value: _selectedSubject,
                            decoration: _inputDecoration(
                              hintText: _text('', ''),
                            ),
                            options: [
                              for (final subject in _subjects)
                                GlideSelectOption(
                                  value: subject,
                                  label: _subjectLabel(subject),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedSubject = value),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _fieldGroup(
                          _text('TOPIC', 'CHỦ ĐỀ'),
                          TextField(
                            key: const Key('topic-input'),
                            controller: _topicController,
                            style: TextStyle(color: _palette.primaryText),
                            decoration: _inputDecoration(
                              hintText: _text('Enter topic', 'Nhập chủ đề'),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _fieldGroup(
                          _text('DEADLINE', 'HẠN HOÀN THÀNH'),
                          TextField(
                            key: const Key('deadline-picker'),
                            controller: _deadlineController,
                            readOnly: true,
                            onTap: _pickDeadline,
                            style: TextStyle(color: _palette.primaryText),
                            decoration: _inputDecoration(
                              suffixIcon: Icons.calendar_today_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fieldWidth = constraints.maxWidth >= 520
                      ? (constraints.maxWidth - 14) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: _fieldGroup(
                          _text('GROUP NAME', 'TÊN NHÓM'),
                          TextField(
                            key: const Key('group-name-input'),
                            controller: _groupNameController,
                            style: TextStyle(color: _palette.primaryText),
                            decoration: _inputDecoration(
                              hintText: _text(
                                'Enter group name',
                                'Nhập tên nhóm',
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _fieldGroup(
                          _text('CLASS', 'LỚP'),
                          _usesRemoteGroups
                              ? GlideSelect<String>.dropdown(
                                  key: const Key('class-name-input'),
                                  value: _selectedClassroomId,
                                  decoration: _inputDecoration(
                                    hintText: _loadingClassrooms
                                        ? _text(
                                            'Loading classes...',
                                            'Đang tải lớp...',
                                          )
                                        : _classrooms.isEmpty
                                        ? _text(
                                            'No joined classes',
                                            'Chưa tham gia lớp nào',
                                          )
                                        : _text('', ''),
                                  ),
                                  options: [
                                    for (final classroom in _classrooms)
                                      GlideSelectOption(
                                        value: classroom.id,
                                        label: classroom.name,
                                      ),
                                  ],
                                  onChanged:
                                      _loadingClassrooms || _classrooms.isEmpty
                                      ? null
                                      : _selectClassroom,
                                )
                              : TextField(
                                  key: const Key('class-name-input'),
                                  controller: _classNameController,
                                  style: TextStyle(color: _palette.primaryText),
                                  decoration: _inputDecoration(
                                    hintText: _text('Enter class', 'Nhập lớp'),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: _buildInviteeField())],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final status = Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: _palette.accent,
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _text(
                            'All settings validated • Ready to deploy',
                            'Thông tin hợp lệ • Sẵn sàng tạo nhóm',
                          ),
                          style: TextStyle(
                            color: _palette.secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _palette.secondaryText,
                          side: BorderSide(color: _palette.border),
                        ),
                        child: Text(_text('Back', 'Quay lại')),
                      ),
                      ElevatedButton(
                        onPressed: _savingGroup ? null : _createInvite,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _palette.accent,
                          foregroundColor: _palette.accentText,
                        ),
                        child: Text(_text('Create Group', 'Tạo nhóm')),
                      ),
                    ],
                  );
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [status, const SizedBox(height: 8), actions],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: status),
                      const SizedBox(width: 12),
                      actions,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTaskAssignmentPanel(),
        const SizedBox(height: 16),
        _panel(
          title: _text('WORKSPACE RULES', 'QUY TẮC NHÓM'),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text('AI Detection', 'Phát hiện AI'),
                      style: TextStyle(color: _palette.primaryText),
                    ),
                    Text(
                      _text(
                        'Analyze submissions automatically.',
                        'Tự động phân tích bài nộp.',
                      ),
                      style: TextStyle(color: _palette.secondaryText),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _aiDetectionEnabled,
                onChanged: (value) =>
                    setState(() => _aiDetectionEnabled = value),
                activeThumbColor: _palette.accent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskAssignmentPanel() {
    return _panel(
      title: _text('TASK ASSIGNMENT & CONTENT', 'PHÂN CÔNG & NỘI DUNG'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          final assignmentFields = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldGroup(
                _text('ASSIGNEE', 'NGƯỜI PHỤ TRÁCH'),
                GlideSelect<String>.dropdown(
                  key: const Key('assignee-dropdown'),
                  value:
                      _selectedAssignee?.isNotEmpty == true &&
                          _invitedMembers.contains(_selectedAssignee)
                      ? _selectedAssignee
                      : null,
                  decoration: _inputDecoration(hintText: _text('', '')),
                  options: [
                    for (final member in _invitedMembers.where(
                      (member) => member.isNotEmpty,
                    ))
                      GlideSelectOption(
                        value: member,
                        label: member,
                        tag: _hasTaskDescription(member) ? '✓' : null,
                      ),
                  ],
                  onChanged: _selectAssignee,
                ),
              ),
              const SizedBox(height: 14),
              _fieldGroup(
                _text('TASK DESCRIPTION', 'MÔ TẢ NHIỆM VỤ'),
                TextField(
                  key: const Key('task-description-input'),
                  controller: _taskDescController,
                  minLines: 3,
                  maxLines: 5,
                  onChanged: (_) {
                    _saveTaskAssignment(_selectedAssignee);
                    setState(() {});
                  },
                  style: TextStyle(color: _palette.primaryText),
                  decoration: _inputDecoration(
                    hintText: _text('Enter task details', 'Nhập nội dung'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _fieldGroup(
                _text('RUBRIC', 'RUBRIC'),
                TextField(
                  key: const Key('task-rubric-input'),
                  controller: _rubricController,
                  minLines: 2,
                  maxLines: 3,
                  onChanged: (_) => _saveTaskAssignment(_selectedAssignee),
                  style: TextStyle(color: _palette.primaryText),
                  decoration: _inputDecoration(
                    hintText: _text(
                      'Describe the grading rubric',
                      'Mô tả rubric chấm điểm',
                    ),
                  ),
                ),
              ),
            ],
          );
          final contentFields = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final contentFormatField = _fieldGroup(
                    _text('CONTENT FORMAT', 'ĐỊNH DẠNG NỘI DUNG'),
                    GlideSelect<String>.dropdown(
                      key: const Key('content-format-dropdown'),
                      value: _selectedContentFormat,
                      decoration: _inputDecoration(hintText: _text('', '')),
                      options: [
                        for (final format in _contentFormats)
                          GlideSelectOption(
                            value: format,
                            label: _contentFormatLabel(format),
                          ),
                      ],
                      onChanged: (format) =>
                          setState(() => _selectedContentFormat = format),
                    ),
                  );
                  final quantityField = SizedBox(
                    width: 150,
                    child: _fieldGroup(
                      _text('QUANTITY', 'SỐ LƯỢNG'),
                      Row(
                        children: [
                          IconButton(
                            tooltip: _text(
                              'Decrease quantity',
                              'Giảm số lượng',
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _changeQuantity(-1),
                            icon: const Icon(Icons.remove),
                          ),
                          Expanded(
                            child: TextField(
                              key: const Key('quantity-input'),
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _palette.primaryText),
                              decoration: _inputDecoration(),
                            ),
                          ),
                          IconButton(
                            tooltip: _text(
                              'Increase quantity',
                              'Tăng số lượng',
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _changeQuantity(1),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (constraints.maxWidth < 460) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        contentFormatField,
                        const SizedBox(height: 10),
                        quantityField,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: contentFormatField),
                      const SizedBox(width: 12),
                      quantityField,
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              _fieldGroup(
                _text('EVALUATION CRITERIA', 'TIÊU CHÍ ĐÁNH GIÁ'),
                TextField(
                  key: const Key('criteria-description-input'),
                  controller: _criteriaController,
                  minLines: 2,
                  maxLines: 3,
                  style: TextStyle(color: _palette.primaryText),
                  decoration: _inputDecoration(
                    hintText: _text(
                      'Describe the completion criteria',
                      'Mô tả tiêu chí hoàn thành',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _fieldGroup(
                _text('FORMATTING RULES', 'QUY TẮC ĐỊNH DẠNG'),
                TextField(
                  key: const Key('formatting-rules-input'),
                  controller: _formattingRulesController,
                  minLines: 2,
                  maxLines: 3,
                  onChanged: (_) => _saveTaskAssignment(_selectedAssignee),
                  style: TextStyle(color: _palette.primaryText),
                  decoration: _inputDecoration(
                    hintText: _text(
                      'Describe required formatting',
                      'Mô tả định dạng cần tuân thủ',
                    ),
                  ),
                ),
              ),
            ],
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                assignmentFields,
                const SizedBox(height: 18),
                contentFields,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: assignmentFields),
              const SizedBox(width: 20),
              Expanded(flex: 6, child: contentFields),
            ],
          );
        },
      ),
    );
  }

  void _changeQuantity(int delta) {
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    _quantityController.text = (quantity + delta).clamp(1, 999).toString();
  }

  Widget _buildInviteeField() {
    final selected = _invitedMembers.where((member) => member.isNotEmpty);
    final canAddMembers =
        !_usesRemoteGroups ||
        (_selectedClassroomId != null &&
            !_loadingMembers &&
            _availableMembers.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldGroup(
          _text('INVITE', 'MỜI THÀNH VIÊN'),
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _palette.input,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _palette.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      for (final member in selected)
                        InputChip(
                          key: Key(
                            'invite-chip-${member.replaceAll(' ', '-')}',
                          ),
                          label: Text(member),
                          labelStyle: TextStyle(color: _palette.primaryText),
                          backgroundColor: _palette.card,
                          deleteIconColor: _palette.secondaryText,
                          onDeleted: () => _removeInvitee(member),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('add-invitee'),
                  tooltip: _text('Add members', 'Thêm thành viên'),
                  onPressed: canAddMembers ? _pickInvitees : null,
                  icon: Icon(Icons.add_circle_outline, color: _palette.accent),
                ),
              ],
            ),
          ),
        ),
        if (!canAddMembers)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _text(
                _selectedClassroomId == null
                    ? 'Choose a class before adding members.'
                    : 'There are no other members in this class.',
                _selectedClassroomId == null
                    ? 'Hãy chọn lớp trước khi thêm thành viên.'
                    : 'Lớp này không có thành viên nào khác.',
              ),
              style: TextStyle(color: _palette.secondaryText, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildInvitesView() {
    final pendingInvites = _createdInvites
        .where((invite) => invite.status == 'pending')
        .toList();
    if (pendingInvites.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: () => _loadRemoteData(forceRefresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mail_outline, size: 36, color: _palette.accent),
                    const SizedBox(height: 12),
                    Text(
                      _text(
                        'You have no invites yet.',
                        'Bạn chưa có lời mời nào',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _palette.secondaryText),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _selectedNavIndex = 0),
                      icon: const Icon(Icons.add),
                      label: Text(_text('Create an invite', 'Tạo lời mời')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _palette.accent,
                        side: BorderSide(color: _palette.border),
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

    return RefreshIndicator(
      onRefresh: () => _loadRemoteData(forceRefresh: true),
      child: Scrollbar(
        key: const Key('invite-scrollbar'),
        controller: _inviteScrollController,
        thumbVisibility: true,
        child: ListView.separated(
          key: const Key('invite-list'),
          controller: _inviteScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(right: 12, bottom: 16),
          itemCount: pendingInvites.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final invite = pendingInvites[index];
            return InviteDetailsCard(
              key: ValueKey('invite-card-$index'),
              compact: true,
              inviterName: invite.inviterName,
              totalMembers: invite.totalMembers,
              className: invite.className.isNotEmpty
                  ? invite.className
                  : invite.subject,
              topic: invite.topic,
              deadline: invite.deadline,
              taskDescription: invite.taskDescriptionFor(widget.currentUserId),
              onDecline: () => _declineInvite(invite),
              onAccept: () => _acceptInvite(invite),
              languageCode: _languageCode,
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailsPanel() {
    final selectedProject = _selectedProject;
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _text('PROJECT HUB DETAILS', 'CHI TIẾT PROJECT HUB'),
            style: TextStyle(
              color: _palette.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          if (selectedProject == null) ...[
            Text(
              _text('Your groups', 'Nhóm của bạn'),
              style: TextStyle(
                color: _palette.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _activeProjects.isEmpty
                  ? Center(
                      child: Text(
                        _text(
                          'No accepted projects yet.',
                          'Chưa có dự án được chấp nhận.',
                        ),
                        style: TextStyle(color: _palette.secondaryText),
                      ),
                    )
                  : ListView.separated(
                      key: const Key('accepted-project-list'),
                      itemCount: _activeProjects.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _buildProjectCard(_activeProjects[index]),
                    ),
            ),
          ] else ...[
            TextButton.icon(
              key: const Key('back-to-project-list'),
              onPressed: () => setState(() => _selectedProject = null),
              icon: const Icon(Icons.arrow_back),
              label: Text(_text('All groups', 'Tất cả nhóm')),
              style: TextButton.styleFrom(foregroundColor: _palette.accent),
            ),
            const SizedBox(height: 4),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: _text('Personal Workspace', 'Không gian cá nhân')),
                Tab(
                  text: _text('Member Progress Matrix', 'Tiến độ thành viên'),
                ),
                Tab(text: _text('Group Chat', 'Trò chuyện nhóm')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 16, bottom: 20),
                    child: _buildPersonalWorkspace(selectedProject),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 16, bottom: 20),
                    child: _buildMemberProgressMatrix(selectedProject),
                  ),
                  _buildGroupChat(selectedProject),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupChat(_InviteCardData project) {
    if (!_isProjectMember(project, _currentUserName)) {
      return Center(
        child: Text(
          _text(
            'Chat is limited to group members.',
            'Trò chuyện chỉ dành cho thành viên nhóm.',
          ),
          style: TextStyle(color: _palette.secondaryText),
        ),
      );
    }

    final messages = _groupMessages[project.id] ?? const <_GroupChatMessage>[];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: _palette.accent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  project.groupName,
                  style: TextStyle(
                    color: _palette.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${project.members.length} ${_text('members', 'thành viên')}',
                style: TextStyle(color: _palette.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ),
        Divider(color: _palette.border, height: 1),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    _text('No messages yet.', 'Chưa có tin nhắn nào.'),
                    style: TextStyle(color: _palette.secondaryText),
                  ),
                )
              : ListView.builder(
                  key: Key('group-chat-feed-${project.id}'),
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(14),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _buildChatMessage(project, messages[index], index),
                ),
        ),
        Divider(color: _palette.border, height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                key: Key('chat-attach-${project.id}'),
                tooltip: _text('Share media', 'Chia sẻ tệp'),
                onPressed: () => _pickChatAttachment(project),
                icon: Icon(Icons.attach_file, color: _palette.accent),
              ),
              Expanded(
                child: TextField(
                  key: Key('chat-input-${project.id}'),
                  controller: _chatMessageController,
                  maxLength: 2000,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _sendChatMessage(project),
                  style: TextStyle(color: _palette.primaryText),
                  decoration: _inputDecoration(
                    hintText: _text(
                      'Message... use @Gemini to ask AI',
                      'Nhắn tin... dùng @Gemini để hỏi AI',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: Key('chat-send-${project.id}'),
                tooltip: _text('Send message', 'Gửi tin nhắn'),
                onPressed: () => _sendChatMessage(project),
                style: IconButton.styleFrom(
                  backgroundColor: _palette.accent,
                  foregroundColor: _palette.accentText,
                ),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isProjectMember(_InviteCardData project, String member) =>
      project.members.any(
        (groupMember) =>
            _memberIdentity(groupMember) == _memberIdentity(member),
      );

  String _chatRole(
    _InviteCardData project,
    String sender, {
    bool isGemini = false,
  }) {
    if (isGemini) return 'Gemini AI';
    final isOwner =
        _memberIdentity(sender) == _memberIdentity(project.inviterName);
    final isCurrentUser = _isCurrentUserAssignment(sender);
    if (isOwner && isCurrentUser) {
      return _text('Owner · You', 'Trưởng nhóm · Bạn');
    }
    if (isOwner) return _text('Owner', 'Trưởng nhóm');
    if (isCurrentUser) return _text('You', 'Bạn');
    if (sender.toLowerCase().contains('bot')) return 'AI';
    return _text('Member', 'Thành viên');
  }

  void _sendChatMessage(
    _InviteCardData project, {
    List<_ChatAttachment> attachments = const [],
  }) {
    if (!_isProjectMember(project, _currentUserName)) return;
    final messageText = _chatMessageController.text.trim();
    if (messageText.isEmpty && attachments.isEmpty) return;
    final geminiPrompt = LabAIService.extractGeminiPrompt(messageText);
    var pendingResponseIndex = -1;

    setState(() {
      final messages = _groupMessages.putIfAbsent(project.id, () => []);
      messages.add(
        _GroupChatMessage(
          senderName: _currentUserName,
          text: messageText,
          sentAt: DateTime.now(),
          attachments: List.unmodifiable(attachments),
        ),
      );
      if (geminiPrompt != null) {
        pendingResponseIndex = messages.length;
        messages.add(
          _GroupChatMessage(
            senderName: 'Gemini',
            text: '',
            sentAt: DateTime.now(),
            isGemini: true,
            isPending: true,
          ),
        );
      }
      _chatMessageController.clear();
    });
    if (geminiPrompt != null) {
      _completeGroupGeminiRequest(project, geminiPrompt, pendingResponseIndex);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _completeGroupGeminiRequest(
    _InviteCardData project,
    String prompt,
    int messageIndex,
  ) async {
    String answer;
    if (prompt.isEmpty) {
      answer = _text(
        'Add a question after @Gemini.',
        'Hãy nhập câu hỏi sau @Gemini.',
      );
    } else {
      try {
        answer = await (widget.geminiRequest ?? LabAIService.askAssistant)(
          userQuestion: _languageCode == 'zh' ? '请使用简体中文回答：$prompt' : prompt,
          interfaceName: project.groupName,
        );
      } catch (_) {
        answer = _text(
          'The AI service is temporarily unavailable. Please try again later.',
          'Dịch vụ AI hiện không khả dụng. Vui lòng thử lại sau.',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      final messages = _groupMessages[project.id];
      if (messages == null || messageIndex >= messages.length) return;
      final pendingMessage = messages[messageIndex];
      if (!pendingMessage.isGemini || !pendingMessage.isPending) return;
      messages[messageIndex] = _GroupChatMessage(
        senderName: 'Gemini',
        text: answer,
        sentAt: pendingMessage.sentAt,
        isGemini: true,
      );
    });
  }

  Future<void> _pickChatAttachment(_InviteCardData project) async {
    if (!_isProjectMember(project, _currentUserName)) return;
    try {
      final files = widget.filePicker != null
          ? await widget.filePicker!.call()
          : await FilePicker.pickFiles(type: FileType.any);
      if (files == null || files.isEmpty || !mounted) return;

      final file = files.first;
      Uint8List? imageBytes;
      if (_fileKind(file.name) == 'Image') {
        final fileSize = file.lengthSync();
        if (fileSize == null || fileSize <= 8 * 1024 * 1024) {
          try {
            imageBytes = await file.readAsBytes();
          } catch (_) {
            imageBytes = null;
          }
        }
      }
      if (!mounted) return;
      _sendChatMessage(
        project,
        attachments: [_ChatAttachment(file: file, imageBytes: imageBytes)],
      );
    } catch (_) {
      if (!mounted) return;
      ToastService.showError(
        _text('Could not attach file.', 'Không thể đính kèm tệp.'),
      );
    }
  }

  Widget _buildChatMessage(
    _InviteCardData project,
    _GroupChatMessage message,
    int index,
  ) {
    final isCurrentUser =
        !message.isGemini && _isCurrentUserAssignment(message.senderName);
    final bubbleColor = isCurrentUser ? _palette.accent : _palette.input;
    final bubbleTextColor = isCurrentUser
        ? _palette.accentText
        : _palette.primaryText;
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: isCurrentUser
          ? _palette.accent.withValues(alpha: 0.2)
          : _palette.card,
      child: message.isGemini
          ? Icon(Icons.auto_awesome, color: _palette.accent, size: 16)
          : Text(
              message.senderName.characters.first.toUpperCase(),
              style: TextStyle(
                color: isCurrentUser ? _palette.accent : _palette.primaryText,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
    );

    return Padding(
      key: Key('chat-message-${project.id}-$index'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[avatar, const SizedBox(width: 8)],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (message.isGemini)
                        Text(
                          message.senderName,
                          key: Key('chat-sender-${project.id}-$index'),
                          style: TextStyle(
                            color: _palette.primaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        SubscriptionUserName(
                          key: Key('chat-sender-${project.id}-$index'),
                          userId: null,
                          fallbackName: message.senderName,
                          defaultColor: _palette.primaryText,
                          fontSize: 12,
                        ),
                      Container(
                        key: Key('chat-role-${project.id}-$index'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _palette.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _chatRole(
                            project,
                            message.senderName,
                            isGemini: message.isGemini,
                          ),
                          style: TextStyle(
                            color: _palette.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        MaterialLocalizations.of(context).formatTimeOfDay(
                          TimeOfDay.fromDateTime(message.sentAt.toLocal()),
                        ),
                        key: Key('chat-time-${project.id}-$index'),
                        style: TextStyle(
                          color: _palette.secondaryText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(8),
                        topRight: const Radius.circular(8),
                        bottomLeft: Radius.circular(isCurrentUser ? 12 : 3),
                        bottomRight: Radius.circular(isCurrentUser ? 3 : 12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.isPending)
                          Text(
                            _text(
                              'Gemini is thinking...',
                              'Gemini đang suy nghĩ...',
                            ),
                            style: TextStyle(color: bubbleTextColor),
                          )
                        else if (message.text.isNotEmpty)
                          Text(
                            message.text,
                            style: TextStyle(color: bubbleTextColor),
                          ),
                        for (final attachment in message.attachments) ...[
                          if (message.text.isNotEmpty)
                            const SizedBox(height: 8),
                          _buildChatAttachment(attachment),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[const SizedBox(width: 8), avatar],
        ],
      ),
    );
  }

  Widget _buildChatAttachment(_ChatAttachment attachment) {
    final name = attachment.file.name;
    final kind = _fileKind(name);
    if (kind == 'Image' && attachment.imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          attachment.imageBytes!,
          width: 240,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _attachmentFileTag(attachment, icon: Icons.broken_image_outlined),
        ),
      );
    }
    if (kind == 'Audio' || kind == 'Video') {
      return Container(
        constraints: const BoxConstraints(minWidth: 210, maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _palette.background.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kind == 'Audio' ? Icons.graphic_eq : Icons.movie_outlined,
              color: _palette.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _palette.primaryText),
              ),
            ),
            IconButton(
              tooltip: _text('Save media', 'Lưu tệp'),
              onPressed: () => _downloadChatAttachment(attachment),
              icon: const Icon(Icons.download_outlined, size: 18),
            ),
          ],
        ),
      );
    }
    return _attachmentFileTag(attachment, icon: Icons.description_outlined);
  }

  Widget _attachmentFileTag(
    _ChatAttachment attachment, {
    required IconData icon,
  }) => ActionChip(
    avatar: Icon(icon, size: 18, color: _palette.accent),
    label: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Text(attachment.file.name, overflow: TextOverflow.ellipsis),
    ),
    onPressed: () => _downloadChatAttachment(attachment),
    backgroundColor: _palette.background.withValues(alpha: 0.16),
    side: BorderSide(color: _palette.border),
  );

  Future<void> _downloadChatAttachment(_ChatAttachment attachment) async {
    try {
      await FilePicker.saveFile(
        fileName: attachment.file.name,
        bytes: await attachment.file.readAsBytes(),
      );
    } catch (_) {
      if (!mounted) return;
      ToastService.showError(
        _text('Could not save file.', 'Không thể lưu tệp.'),
      );
    }
  }

  Widget _buildProjectCard(_InviteCardData project) {
    final progress = _groupProgress(project);
    return Material(
      color: _palette.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key('project-card-${project.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _selectedProject = project);
          if (_usesRemoteGroups) unawaited(_loadProjectFilesSafely(project));
        },
        child: HoverRipple(
          borderRadius: BorderRadius.circular(8),
          color: _palette.accent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GlideSelect(
                        selected: _selectedProject?.id == project.id,
                        child: Text(
                          project.groupName,
                          style: TextStyle(
                            color: _palette.primaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: _palette.secondaryText),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    Text(
                      '${_text('Class', 'Lớp')}: ${project.className.isEmpty ? _text('Not set', 'Chưa đặt') : project.className}',
                      style: TextStyle(color: _palette.secondaryText),
                    ),
                    Text(
                      '${_text('Subject', 'Môn học')}: ${project.subject}',
                      style: TextStyle(color: _palette.secondaryText),
                    ),
                    Text(
                      '${_text('Topic', 'Chủ đề')}: ${project.topic}',
                      style: TextStyle(color: _palette.secondaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: _palette.input,
                        color: _palette.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        color: _palette.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _groupProgress(_InviteCardData project) {
    final requiredCount = project.taskAssignments.fold<int>(
      0,
      (total, assignment) => total + assignment.requiredFileCount,
    );
    final submittedCount = project.taskAssignments.fold<int>(
      0,
      (total, assignment) =>
          total + (_submittedFileCounts[project.id]?[assignment.assignee] ?? 0),
    );
    return requiredCount == 0
        ? 0.0
        : (submittedCount / requiredCount).clamp(0.0, 1.0);
  }

  String _memberIdentity(String member) {
    return member.trim().toLowerCase();
  }

  List<String> _membersForProject(_InviteCardData project) {
    final members = List<String>.of(project.members);
    if (!members.any((member) => _isCurrentUserAssignment(member))) {
      members.insert(0, _currentUserName);
    }
    return members;
  }

  List<_TaskAssignment> _assignmentsForMember(
    _InviteCardData project,
    String member,
  ) => project.taskAssignments
      .where(
        (assignment) =>
            _memberIdentity(assignment.assignee) == _memberIdentity(member),
      )
      .toList();

  Widget _buildMemberProgressMatrix(_InviteCardData project) {
    final members = _membersForProject(project);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _text('MEMBER PROGRESS', 'TIẾN ĐỘ THÀNH VIÊN'),
          style: TextStyle(
            color: _palette.accent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < members.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          _buildMemberProgressRow(project, members[index]),
        ],
      ],
    );
  }

  Widget _buildMemberProgressRow(_InviteCardData project, String member) {
    final assignments = _assignmentsForMember(project, member);
    final targetFiles = assignments.fold<int>(
      0,
      (total, assignment) => total + assignment.requiredFileCount,
    );
    final submittedFiles = assignments.fold<int>(
      0,
      (total, assignment) =>
          total + (_submittedFileCounts[project.id]?[assignment.assignee] ?? 0),
    );
    final progress = targetFiles == 0
        ? 0.0
        : (submittedFiles / targetFiles).clamp(0.0, 1.0);
    final memberKey = member.replaceAll(' ', '-').toLowerCase();

    return Material(
      color: _palette.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key('member-progress-row-${project.id}-$memberKey'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showMemberFiles(project, member),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      member,
                      style: TextStyle(
                        color: _palette.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$submittedFiles / $targetFiles ${_text('files', 'tệp')} · ${(progress * 100).round()}%',
                    key: Key('member-progress-value-${project.id}-$memberKey'),
                    style: TextStyle(
                      color: _palette.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: _palette.secondaryText),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                key: Key('member-progress-bar-${project.id}-$memberKey'),
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: _palette.input,
                color: _palette.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMemberFiles(_InviteCardData project, String member) async {
    if (_usesRemoteGroups) {
      try {
        await _loadProjectFiles(project);
      } catch (error) {
        if (!mounted) return;
        ToastService.showError(
          _text(
            'Could not load group files: $error',
            'Không thể tải tệp nhóm: $error',
          ),
        );
      }
    }
    final files =
        (_workspaceUploads[project.id] ?? const <_WorkspaceUpload>[])
            .where(
              (upload) =>
                  _memberIdentity(upload.assignee) == _memberIdentity(member) &&
                  upload.status == _WorkspaceUploadStatus.success,
            )
            .toList()
          ..sort(
            (first, second) => (second.uploadedAt ?? DateTime(0)).compareTo(
              first.uploadedAt ?? DateTime(0),
            ),
          );

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _palette.card,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _languageCode == 'zh'
                            ? '$member 的提交'
                            : _text(
                                '$member submissions',
                                'Bài nộp của $member',
                              ),
                        style: TextStyle(
                          color: _palette.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _text('Close', 'Đóng'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Divider(color: _palette.border),
                Expanded(
                  child: files.isEmpty
                      ? Center(
                          child: Text(
                            _text(
                              'No successful files submitted yet.',
                              'Chưa có tệp nộp thành công.',
                            ),
                            style: TextStyle(color: _palette.secondaryText),
                          ),
                        )
                      : ListView.separated(
                          itemCount: files.length,
                          separatorBuilder: (context, index) =>
                              Divider(color: _palette.border, height: 1),
                          itemBuilder: (context, index) =>
                              _buildMemberFileRow(files[index]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberFileRow(_WorkspaceUpload upload) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        _fileKindBadge(upload.name),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                upload.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _palette.primaryText),
              ),
              const SizedBox(height: 3),
              Text(
                _formatUploadTimestamp(upload.uploadedAt),
                style: TextStyle(color: _palette.secondaryText, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: _text('View file details', 'Xem tệp'),
          onPressed: () => _showUploadPreview(upload),
          icon: const Icon(Icons.visibility_outlined),
        ),
        IconButton(
          tooltip: _text('Download file', 'Tải xuống'),
          onPressed: () => _downloadUpload(upload),
          icon: const Icon(Icons.download_outlined),
        ),
      ],
    ),
  );

  Widget _fileKindBadge(String name) {
    final kind = _fileKind(name);
    final icon = switch (kind) {
      'Image' => Icons.image_outlined,
      'Audio' => Icons.audiotrack_outlined,
      'Video' => Icons.movie_outlined,
      'Slides' => Icons.slideshow_outlined,
      _ => Icons.description_outlined,
    };
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: _palette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _palette.accent, size: 20),
          const SizedBox(height: 3),
          Text(
            _text(kind, switch (kind) {
              'Image' => 'Ảnh',
              'Audio' => 'Âm thanh',
              'Video' => 'Video',
              'Slides' => 'Slide',
              _ => 'Tài liệu',
            }),
            style: TextStyle(color: _palette.secondaryText, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _fileKind(String name) {
    final extension = name.split('.').last.toLowerCase();
    if (const {
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'bmp',
    }.contains(extension)) {
      return 'Image';
    }
    if (const {'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'}.contains(extension)) {
      return 'Audio';
    }
    if (const {'mp4', 'mov', 'avi', 'mkv', 'webm'}.contains(extension)) {
      return 'Video';
    }
    if (const {'ppt', 'pptx', 'odp', 'key'}.contains(extension)) {
      return 'Slides';
    }
    return 'Document';
  }

  String _formatUploadTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return _text('Time unavailable', 'Không có thời gian');
    }
    final localTime = timestamp.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(localTime);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(localTime));
    return '$date · $time';
  }

  Future<void> _showUploadPreview(_WorkspaceUpload upload) async {
    final file = upload.file;
    final size = upload.sizeBytes ?? file?.lengthSync();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _palette.card,
        title: Text(_text('File preview', 'Xem tệp')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _fileKindBadge(upload.name)),
            const SizedBox(height: 16),
            _metadataLine(_text('Name', 'Tên tệp'), upload.name),
            _metadataLine(
              _text('Type', 'Loại'),
              _text(_fileKind(upload.name), switch (_fileKind(upload.name)) {
                'Audio' => 'Âm thanh',
                'Video' => 'Video',
                'Slides' => 'Slide',
                _ => 'Tài liệu',
              }),
            ),
            _metadataLine(
              _text('Submitted', 'Thời gian nộp'),
              _formatUploadTimestamp(upload.uploadedAt),
            ),
            if (size != null)
              _metadataLine(_text('Size', 'Dung lượng'), '$size bytes'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_text('Close', 'Đóng')),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadUpload(_WorkspaceUpload upload) async {
    try {
      final storagePath = upload.storagePath;
      if (storagePath != null && _repository != null) {
        final bytes = await _repository!.downloadGroupFile(storagePath);
        await FilePicker.saveFile(fileName: upload.name, bytes: bytes);
        return;
      }
      final file = upload.file;
      if (file == null) throw StateError('File data is unavailable');
      await FilePicker.saveFile(
        fileName: upload.name,
        bytes: await file.readAsBytes(),
      );
    } catch (error) {
      if (!mounted) return;
      ToastService.showWithContext(
        context,
        message: _text('Download failed: $error', 'Tải tệp thất bại: $error'),
        type: ToastType.error,
        title: 'Đã có lỗi xảy ra',
      );
    }
  }

  Widget _buildPersonalWorkspace(_InviteCardData project) {
    final personalAssignments = project.taskAssignments.where((assignment) {
      final userId = widget.currentUserId;
      return userId != null && assignment.assigneeUserId != null
          ? assignment.assigneeUserId == userId
          : _isCurrentUserAssignment(assignment.assignee);
    }).toList();
    final progress = _groupProgress(project);
    final uploads =
        (_workspaceUploads[project.id] ?? const <_WorkspaceUpload>[])
            .where((upload) => _isCurrentUserAssignment(upload.assignee))
            .toList();

    return _panel(
      title: project.groupName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metadataLine(_text('Subject', 'Môn học'), project.subject),
          _metadataLine(
            _text('Class', 'Lớp'),
            project.className.isEmpty
                ? _text('Not set', 'Chưa đặt')
                : project.className,
          ),
          _metadataLine(_text('Project topic', 'Chủ đề dự án'), project.topic),
          const SizedBox(height: 16),
          Text(
            _text('GROUP TASKS & DESCRIPTIONS', 'NHIỆM VỤ & MÔ TẢ NHÓM'),
            style: TextStyle(
              color: _palette.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (project.taskAssignments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _text('No tasks have been assigned.', 'Chưa có nhiệm vụ nào.'),
                style: TextStyle(color: _palette.secondaryText),
              ),
            ),
          for (final assignment in project.taskAssignments)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _palette.input,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.assignee,
                      style: TextStyle(
                        color: _palette.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assignment.description,
                      style: TextStyle(color: _palette.secondaryText),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _text('TOTAL GROUP PROGRESS', 'TIẾN ĐỘ TỔNG CỦA NHÓM'),
                  style: TextStyle(
                    color: _palette.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                key: Key('group-progress-${project.id}'),
                style: TextStyle(
                  color: _palette.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            key: Key('group-progress-bar-${project.id}'),
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: _palette.input,
            color: _palette.accent,
          ),
          const SizedBox(height: 20),
          Text(
            _text('YOUR ASSIGNED TASKS', 'NHIỆM VỤ ĐƯỢC GIAO CHO BẠN'),
            style: TextStyle(
              color: _palette.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (personalAssignments.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _text(
                'No task is assigned to your account.',
                'Tài khoản của bạn chưa được giao nhiệm vụ nào.',
              ),
              key: Key('no-personal-task-${project.id}'),
              style: TextStyle(color: _palette.secondaryText),
            ),
          ],
          for (final assignment in personalAssignments) ...[
            const SizedBox(height: 10),
            _personalAssignment(project, assignment),
          ],
          if (uploads.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _text('UPLOADED FILES', 'TỆP ĐÃ TẢI LÊN'),
              style: TextStyle(
                color: _palette.secondaryText,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            for (final upload in uploads) _buildUploadStatus(upload),
          ],
        ],
      ),
    );
  }

  bool _isCurrentUserAssignment(String assignee) {
    return _memberIdentity(assignee) == _memberIdentity(_currentUserName);
  }

  Widget _metadataLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: TextStyle(color: _palette.secondaryText)),
        ),
        Expanded(
          child: Text(value, style: TextStyle(color: _palette.primaryText)),
        ),
      ],
    ),
  );

  Widget _personalAssignment(
    _InviteCardData project,
    _TaskAssignment assignment,
  ) {
    final submitted =
        _submittedFileCounts[project.id]?[assignment.assignee] ?? 0;
    final required = assignment.requiredFileCount;
    final taskProgress = required == 0
        ? 0.0
        : (submitted / required).clamp(0.0, 1.0);
    final format = assignment.contentFormat == null
        ? _text('Not set', 'Chưa chọn')
        : _contentFormatLabel(assignment.contentFormat!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metadataLine(
          _text('Task instructions', 'Hướng dẫn nhiệm vụ'),
          assignment.description,
        ),
        _metadataLine(
          _text('Rubric', 'Rubric'),
          assignment.rubric.isEmpty
              ? _text('Not set', 'Chưa đặt')
              : assignment.rubric,
        ),
        _metadataLine(
          _text('Formatting rules', 'Quy tắc định dạng'),
          '$format${assignment.formattingRules.isEmpty ? '' : ' · ${assignment.formattingRules}'}',
        ),
        _metadataLine(
          _text('Evaluation criteria', 'Tiêu chí đánh giá'),
          assignment.submissionCriteria.isEmpty
              ? _text('Not set', 'Chưa đặt')
              : assignment.submissionCriteria,
        ),
        _metadataLine(
          _text('Submitted files', 'Tệp đã nộp'),
          '$submitted / $required',
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          key: Key('personal-progress-${project.id}-${assignment.assignee}'),
          value: taskProgress,
          minHeight: 5,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: _palette.input,
          color: _palette.accent,
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: Key('upload-files-${project.id}-${assignment.assignee}'),
          onPressed: () => _pickWorkspaceFiles(project, assignment),
          icon: const Icon(Icons.upload_file),
          label: Text(_text('Upload files', 'Tải tệp lên')),
          style: FilledButton.styleFrom(
            backgroundColor: _palette.accent,
            foregroundColor: _palette.accentText,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadStatus(_WorkspaceUpload upload) {
    final (icon, color, label) = switch (upload.status) {
      _WorkspaceUploadStatus.uploading => (
        Icons.sync,
        _palette.accent,
        _text('Uploading', 'Đang tải lên'),
      ),
      _WorkspaceUploadStatus.success => (
        Icons.check_circle_outline,
        Colors.green,
        _text('Success', 'Thành công'),
      ),
      _WorkspaceUploadStatus.error => (
        Icons.error_outline,
        Colors.redAccent,
        _text('Error', 'Lỗi'),
      ),
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 18),
      title: Text(upload.name, style: TextStyle(color: _palette.primaryText)),
      trailing: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Future<void> _pickWorkspaceFiles(
    _InviteCardData project,
    _TaskAssignment assignment,
  ) async {
    if (_usesRemoteGroups &&
        (project.remoteId == null || widget.currentUserId == null)) {
      ToastService.showError(
        _text(
          'This group is not ready for file uploads.',
          'Nhóm này chưa sẵn sàng để tải tệp lên.',
        ),
      );
      return;
    }
    List<PlatformFile>? files;
    try {
      if (widget.filePicker != null) {
        files = await widget.filePicker!.call();
      } else {
        files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'pdf',
            'doc',
            'docx',
            'txt',
            'rtf',
            'xls',
            'xlsx',
            'csv',
            'ppt',
            'pptx',
            'odp',
            'key',
            'mp3',
            'wav',
            'm4a',
            'aac',
            'ogg',
            'flac',
            'mp4',
            'mov',
            'avi',
            'mkv',
            'webm',
          ],
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _workspaceUploads
            .putIfAbsent(project.id, () => [])
            .add(
              _WorkspaceUpload(
                name: _text('Could not choose file', 'Không thể chọn tệp'),
                assignee: assignment.assignee,
                status: _WorkspaceUploadStatus.error,
                uploadedAt: DateTime.now(),
              ),
            );
      });
      return;
    }
    if (files == null || files.isEmpty || !mounted) return;

    final uploads = files
        .map(
          (file) => _WorkspaceUpload(
            name: file.name,
            assignee: assignment.assignee,
            file: file,
          ),
        )
        .toList();
    setState(() {
      _workspaceUploads.putIfAbsent(project.id, () => []).addAll(uploads);
    });

    for (var index = 0; index < files.length; index++) {
      if (!mounted) return;
      final file = files[index];
      try {
        if (_usesRemoteGroups) {
          final fileSize = await file.length();
          if (fileSize == null) {
            throw StateError('Could not verify the file size.');
          }
          if (fileSize > StudyGroupRepository.maximumFileSizeBytes) {
            throw ArgumentError('File exceeds the 50 MB upload limit.');
          }
          final bytes = await file.readAsBytes();
          final repository = _repository;
          final groupId = project.remoteId;
          final uploaderId = widget.currentUserId;
          if (repository == null || groupId == null || uploaderId == null) {
            throw StateError('Group file storage is not available');
          }
          final row = await repository.uploadGroupFile(
            groupId: groupId,
            uploaderUserId: uploaderId,
            assigneeUserId:
                assignment.assigneeUserId ??
                _memberIdsByName[assignment.assignee],
            fileName: file.name,
            mimeType: _mimeTypeFor(file.name),
            bytes: bytes,
          );
          final pendingUpload = uploads[index];
          final uploadedFile = _uploadFromRow(project, row);
          uploads[index] = uploadedFile;
          final projectUploads = _workspaceUploads.putIfAbsent(
            project.id,
            () => [],
          );
          final pendingIndex = projectUploads.indexOf(pendingUpload);
          if (pendingIndex == -1) {
            projectUploads.add(uploadedFile);
          } else {
            projectUploads[pendingIndex] = uploadedFile;
          }
          _updateSubmittedFileCounts(project, projectUploads);
        } else {
          await for (final _ in file.readAsByteStream()) {}
          uploads[index].status = _WorkspaceUploadStatus.success;
          uploads[index].uploadedAt = DateTime.now();
          final counts = _submittedFileCounts.putIfAbsent(project.id, () => {});
          counts[assignment.assignee] = (counts[assignment.assignee] ?? 0) + 1;
        }
      } catch (error) {
        uploads[index].status = _WorkspaceUploadStatus.error;
        if (!mounted) return;
        ToastService.showWithContext(
          context,
          message: _text(
            'Could not upload ${file.name}: $error',
            'Không thể tải ${file.name} lên: $error',
          ),
          type: ToastType.error,
          title: 'Đã có lỗi xảy ra',
        );
      }
      if (mounted) setState(() {});
    }
  }

  String? _mimeTypeFor(String fileName) => switch (fileName
      .split('.')
      .last
      .toLowerCase()) {
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'mp3' => 'audio/mpeg',
    'mp4' => 'video/mp4',
    _ => null,
  };

  _WorkspaceUpload _uploadFromRow(
    _InviteCardData project,
    Map<String, dynamic> row,
  ) {
    final assigneeId = row['assignee_user_id']?.toString();
    final assignee = project.taskAssignments
        .where((task) => task.assigneeUserId == assigneeId)
        .firstOrNull
        ?.assignee;
    return _WorkspaceUpload(
      remoteId: row['id']?.toString(),
      storagePath: row['storage_path']?.toString(),
      name: row['file_name']?.toString() ?? '',
      assignee: assignee ?? _text('Group member', 'Thành viên nhóm'),
      assigneeUserId: assigneeId,
      sizeBytes: int.tryParse(row['size_bytes']?.toString() ?? ''),
      mimeType: row['mime_type']?.toString(),
      status: _WorkspaceUploadStatus.success,
      uploadedAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    );
  }

  Widget _buildRulesPanel() => _panel(
    title: _text('WORKSPACE SETTINGS', 'CÀI ĐẶT NHÓM'),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _text('AI Detection', 'Phát hiện AI'),
            style: TextStyle(color: _palette.primaryText),
          ),
        ),
        Switch(
          value: _aiDetectionEnabled,
          onChanged: (value) => setState(() => _aiDetectionEnabled = value),
          activeThumbColor: _palette.accent,
        ),
      ],
    ),
  );

  Widget _panel({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _palette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _palette.border),
        boxShadow: _palette.glowEnabled
            ? [
                BoxShadow(
                  color: _palette.accent.withValues(alpha: 0.07),
                  blurRadius: 12,
                ),
              ]
            : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _palette.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _fieldGroup(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _palette.secondaryText,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  InputDecoration _inputDecoration({IconData? suffixIcon, String? hintText}) {
    return InputDecoration(
      filled: true,
      fillColor: _palette.input,
      hintText: hintText,
      hintStyle: TextStyle(color: _palette.secondaryText, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _palette.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      suffixIcon: suffixIcon == null
          ? null
          : Icon(suffixIcon, color: _palette.secondaryText, size: 16),
    );
  }

  Future<void> _pickDeadline() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _deadline.isBefore(today) ? today : _deadline,
      firstDate: today,
      lastDate: DateTime(today.year + 10),
      helpText: _text('Choose group deadline', 'Chọn hạn hoàn thành nhóm'),
    );
    if (selectedDate == null || !mounted) return;
    setState(() {
      _deadlineController.text = _formatDeadline(selectedDate);
    });
  }

  String _formatDeadline(DateTime date) {
    if (_languageCode == 'zh') {
      return '${date.year}年${date.month}月${date.day}日';
    }
    if (!_vi) return MaterialLocalizations.of(context).formatMediumDate(date);
    const months = [
      'thg 1',
      'thg 2',
      'thg 3',
      'thg 4',
      'thg 5',
      'thg 6',
      'thg 7',
      'thg 8',
      'thg 9',
      'thg 10',
      'thg 11',
      'thg 12',
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  Future<void> _pickInvitees() async {
    if (_usesRemoteGroups &&
        (_selectedClassroomId == null || _loadingMembers)) {
      return;
    }
    final draft = Set<String>.from(_invitedMembers.where((m) => m.isNotEmpty));
    _memberSearchController.clear();
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final search = _memberSearchController.text.trim().toLowerCase();
          final availableMembers = _availableMembers
              .where((member) => member.toLowerCase().contains(search))
              .toList();
          return AlertDialog(
            backgroundColor: _palette.card,
            title: Text(
              _text('Add members', 'Thêm thành viên'),
              style: TextStyle(color: _palette.primaryText),
            ),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('invite-member-search'),
                    controller: _memberSearchController,
                    onChanged: (_) => setDialogState(() {}),
                    style: TextStyle(color: _palette.primaryText),
                    decoration: _inputDecoration(
                      hintText: _text(
                        'Search class members',
                        'Tìm thành viên trong lớp',
                      ),
                      suffixIcon: Icons.search,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (availableMembers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _text(
                          'No matching members in this class.',
                          'Không tìm thấy thành viên phù hợp trong lớp.',
                        ),
                        style: TextStyle(color: _palette.secondaryText),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final (index, member)
                              in availableMembers.indexed)
                            CheckboxListTile(
                              key: Key(
                                index == 0 && member == _currentUserName
                                    ? 'invite-option-current-user'
                                    : 'invite-option-${member.replaceAll(' ', '-')}',
                              ),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: GlideSelect(
                                selected: draft.contains(member),
                                child: Text(
                                  member,
                                  style: TextStyle(color: _palette.primaryText),
                                ),
                              ),
                              value: draft.contains(member),
                              onChanged: (checked) => setDialogState(() {
                                if (checked == true) {
                                  draft.add(member);
                                } else {
                                  draft.remove(member);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_text('Cancel', 'Hủy')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, draft),
                style: FilledButton.styleFrom(
                  backgroundColor: _palette.accent,
                  foregroundColor: _palette.accentText,
                ),
                child: Text(_text('Add members', 'Thêm thành viên đã chọn')),
              ),
            ],
          );
        },
      ),
    );
    if (selected == null || !mounted) return;

    setState(() {
      _invitedMembers
        ..clear()
        ..addAll(_availableMembers.where(selected.contains));
      if (!_invitedMembers.contains(_selectedAssignee)) {
        _saveTaskAssignment(_selectedAssignee);
        _selectedAssignee = _invitedMembers.isEmpty
            ? ''
            : _invitedMembers.first;
        _loadTaskDescription(_selectedAssignee);
      }
    });
  }

  void _selectAssignee(String? assignee) {
    if (assignee == _selectedAssignee) return;
    _saveTaskAssignment(_selectedAssignee);
    setState(() {
      _selectedAssignee = assignee ?? '';
      _loadTaskDescription(_selectedAssignee);
    });
  }

  bool _hasTaskDescription(String assignee) => assignee == _selectedAssignee
      ? _taskDescController.text.trim().isNotEmpty
      : _taskAssignmentsByAssignee[assignee]?.description.trim().isNotEmpty ==
            true;

  void _saveTaskAssignment(String? assignee) {
    if (assignee == null || assignee.isEmpty) return;
    _taskAssignmentsByAssignee[assignee] = _TaskAssignment(
      assignee: assignee,
      assigneeUserId: _memberIdsByName[assignee],
      description: _taskDescController.text.trim(),
      rubric: _rubricController.text.trim(),
      formattingRules: _formattingRulesController.text.trim(),
      contentFormat: _selectedContentFormat,
      requiredFileCount: int.tryParse(_quantityController.text) ?? 1,
      submissionCriteria: _criteriaController.text.trim(),
    );
  }

  void _loadTaskDescription(String? assignee) {
    final assignment = assignee == null
        ? null
        : _taskAssignmentsByAssignee[assignee];
    _taskDescController.text = assignment?.description ?? '';
    _rubricController.text = assignment?.rubric ?? '';
    _formattingRulesController.text = assignment?.formattingRules ?? '';
    _selectedContentFormat = assignment?.contentFormat;
    _quantityController.text = assignment?.requiredFileCount.toString() ?? '1';
    _criteriaController.text = assignment?.submissionCriteria ?? '';
  }

  void _removeInvitee(String member) {
    setState(() {
      _saveTaskAssignment(_selectedAssignee);
      _invitedMembers.remove(member);
      if (_selectedAssignee == member) {
        _selectedAssignee = _invitedMembers.isEmpty
            ? ''
            : _invitedMembers.first;
        _loadTaskDescription(_selectedAssignee);
      }
    });
  }

  String get _groupSubjectText => _selectedSubject == null
      ? _text('Subject', 'Môn học')
      : _subjectLabel(_selectedSubject!);

  bool get _hasCompleteInviteDetails =>
      _selectedSubject?.isNotEmpty == true &&
      _topicController.text.trim().isNotEmpty &&
      _invitedMembers.any((member) => member.isNotEmpty) &&
      (!_usesRemoteGroups || _selectedClassroomId != null) &&
      (!_usesRemoteGroups ||
          _invitedMembers
              .where((member) => member.isNotEmpty)
              .every(_memberIdsByName.containsKey)) &&
      _selectedAssignee?.isNotEmpty == true &&
      _deadlineController.text.trim().isNotEmpty &&
      _taskDescController.text.trim().isNotEmpty;

  Future<void> _createInvite() async {
    if (!_hasCompleteInviteDetails) {
      ToastService.showError(
        _text(
          'Choose a class, invite at least one class member, and complete all group details.',
          'Hãy chọn lớp, mời ít nhất một thành viên trong lớp và nhập đầy đủ thông tin.',
        ),
      );
      return;
    }

    _saveTaskAssignment(_selectedAssignee);
    final taskAssignments = List<_TaskAssignment>.unmodifiable(
      _taskAssignmentsByAssignee.values
          .where(
            (assignment) =>
                _invitedMembers.contains(assignment.assignee) &&
                assignment.description.isNotEmpty,
          )
          .toList(),
    );
    final groupName = _groupNameController.text.trim().isEmpty
        ? _topicController.text.trim()
        : _groupNameController.text.trim();
    if (_usesRemoteGroups) {
      final repository = _repository;
      final classroomId = _selectedClassroomId;
      if (repository == null || classroomId == null) return;
      setState(() {
        _savingGroup = true;
        _loadError = null;
      });
      try {
        final remoteId = await repository.createGroup(
          classroomId: classroomId,
          groupName: groupName,
          className: _classNameController.text.trim(),
          subject: _groupSubjectText,
          topic: _topicController.text.trim(),
          deadline: _deadlineController.text.trim(),
          aiDetectionEnabled: _aiDetectionEnabled,
          invitedUserIds: _invitedMembers
              .where((member) => member.isNotEmpty)
              .map((member) => _memberIdsByName[member]!)
              .toSet()
              .toList(),
          taskAssignments: [
            for (final assignment in taskAssignments)
              {
                'assignee': assignment.assignee,
                'assignee_user_id': assignment.assigneeUserId,
                'description': assignment.description,
                'rubric': assignment.rubric,
                'formatting_rules': assignment.formattingRules,
                'content_format': assignment.contentFormat,
                'required_file_count': assignment.requiredFileCount,
                'submission_criteria': assignment.submissionCriteria,
              },
          ],
        );
        await _loadRemoteData(forceRefresh: true);
        if (!mounted) return;
        setState(() {
          _selectedProject = _activeProjects
              .where((project) => project.remoteId == remoteId)
              .firstOrNull;
          _selectedNavIndex = 2;
          _savingGroup = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _savingGroup = false;
          _loadError = error.toString();
        });
        ToastService.showError(
          _text(
            'Could not create the group: $error',
            'Không thể tạo nhóm: $error',
          ),
        );
      }
      return;
    }

    setState(() {
      _createdInvites.add(
        _InviteCardData(
          id: _nextGroupId++,
          inviterName: _selectedAssignee!,
          members: List.unmodifiable(
            _invitedMembers.where((member) => member.isNotEmpty),
          ),
          groupName: groupName,
          subject: _groupSubjectText,
          className: _classNameController.text.trim(),
          topic: _topicController.text.trim(),
          deadline: _deadlineController.text.trim(),
          taskAssignments: taskAssignments,
          aiDetectionEnabled: _aiDetectionEnabled,
        ),
      );
      _selectedNavIndex = 1;
    });
  }

  Future<void> _declineInvite(_InviteCardData invite) async {
    await _respondToInvite(invite, 'declined');
  }

  Future<void> _acceptInvite(_InviteCardData invite) async {
    await _respondToInvite(invite, 'accepted');
  }

  Future<void> _respondToInvite(_InviteCardData invite, String status) async {
    if (_usesRemoteGroups) {
      final repository = _repository;
      final remoteId = invite.remoteId;
      if (repository == null || remoteId == null) return;
      if (!_inviteResponsesInProgress.add(remoteId)) return;
      try {
        await repository.updateInviteStatus(groupId: remoteId, status: status);
        await _loadRemoteData(forceRefresh: true);
        if (!mounted) return;
        setState(() {
          _selectedProject = status == 'accepted'
              ? _activeProjects
                    .where((project) => project.remoteId == remoteId)
                    .firstOrNull
              : null;
          _selectedNavIndex = status == 'accepted' ? 2 : 1;
        });
        final acceptedProject = _selectedProject;
        if (acceptedProject != null) {
          await _loadProjectFilesSafely(acceptedProject);
        }
      } catch (error) {
        if (!mounted) return;
        ToastService.showError(
          _text(
            'Could not update the invitation: $error',
            'Không thể cập nhật lời mời: $error',
          ),
        );
      } finally {
        _inviteResponsesInProgress.remove(remoteId);
      }
      return;
    }
    setState(() {
      invite.status = status;
      if (status == 'accepted') {
        _activeProjects.add(invite);
        _selectedProject = null;
        _selectedNavIndex = 2;
      }
    });
  }
}
