import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:astatine_dashboard/core/notifications/toast.dart';
import 'package:astatine_dashboard/core/ui/discord_ui.dart';

import 'classroom_detail.dart';
import 'classroom_service.dart';

class ClassroomDashboardScreen extends StatefulWidget {
  const ClassroomDashboardScreen({super.key});

  @override
  State<ClassroomDashboardScreen> createState() =>
      _ClassroomDashboardScreenState();
}

class _ClassroomDashboardScreenState extends State<ClassroomDashboardScreen> {
  DiscordUiColors get _colors => DiscordUiColors.of(context);

  final _classNameController = TextEditingController();
  final _classCodeController = TextEditingController();
  List<Map<String, dynamic>> _classrooms = const [];
  String? _userRole;
  String? _loadError;
  bool _isLoading = true;
  bool _isWorking = false;

  bool get _isStudent => _userRole?.toLowerCase() == 'student';
  bool get _canManage =>
      const {'teacher', 'developer'}.contains(_userRole?.toLowerCase());

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _classCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final role = await ClassroomService.getUserRole();
      final classrooms = await ClassroomService.getMyClassrooms();
      if (!mounted) return;
      setState(() {
        _userRole = role?.toLowerCase();
        _classrooms = classrooms;
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

  Future<void> _showCreateClassDialog() async {
    _classNameController.clear();
    final formKey = GlobalKey<FormState>();
    final className = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create a class'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('class-name-input'),
            controller: _classNameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Class name',
              hintText: 'e.g. Chemistry 10A',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a class name.'
                : null,
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(dialogContext)
                    .pop(_classNameController.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('create-class-submit'),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(dialogContext)
                    .pop(_classNameController.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (className == null || !mounted) return;

    setState(() => _isWorking = true);
    try {
      final code = await ClassroomService.createClassroom(className);
      await _loadDashboard();
      if (!mounted) return;
      await _showClassCodeDialog(code);
    } catch (error) {
      if (mounted) ToastService.showError(error.toString());
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _showClassCodeDialog(String code) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, color: Color(0xFF16845B)),
        title: const Text('Class created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this code with students so they can join.'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _colors.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                code,
                key: const Key('created-class-code'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!mounted || !dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              ToastService.showSuccess('Class code copied.');
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy code'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _showJoinClassDialog() async {
    _classCodeController.clear();
    final formKey = GlobalKey<FormState>();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join a class'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('class-code-input'),
            controller: _classCodeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Class code',
              hintText: '6-character code',
              counterText: '',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value == null ||
                    !RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(value.trim())
                ? 'Enter a valid 6-character code.'
                : null,
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(dialogContext)
                    .pop(_classCodeController.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('join-class-submit'),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(dialogContext)
                    .pop(_classCodeController.text.trim());
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || !mounted) return;

    setState(() => _isWorking = true);
    try {
      await ClassroomService.joinClassroom(code);
      await _loadDashboard();
      if (mounted) {
        ToastService.showSuccess('You joined the class.');
      }
    } catch (error) {
      if (mounted) ToastService.showError(error.toString());
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Map<String, dynamic>? _classroomFromMembership(
    Map<String, dynamic> membership,
  ) {
    final classroom = membership['classrooms'];
    if (classroom is Map<String, dynamic>) return classroom;
    if (classroom is Map) return Map<String, dynamic>.from(classroom);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.panel,
        foregroundColor: _colors.text,
        surfaceTintColor: Colors.transparent,
        title: const Text('My classrooms'),
        actions: [
          if (_canManage)
            IconButton(
              key: const Key('join-class-action'),
              tooltip: 'Join a class',
              onPressed: _isWorking ? null : _showJoinClassDialog,
              icon: const Icon(Icons.link_rounded),
            ),
          if (_userRole != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Chip(
                  label: Text(_userRole!),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _isStudent || _canManage
          ? FloatingActionButton.extended(
              key: ValueKey(_isStudent ? 'join-class-fab' : 'create-class-fab'),
              onPressed: _isWorking
                  ? null
                  : _isStudent
                  ? _showJoinClassDialog
                  : _showCreateClassDialog,
              icon: _isWorking
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _colors.onAccent,
                      ),
                    )
                  : Icon(_isStudent ? Icons.login_rounded : Icons.add_rounded),
              label: Text(_isStudent ? 'Join Class' : 'Create Class'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 36),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_classrooms.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 180),
            Icon(Icons.class_outlined, size: 48, color: _colors.muted),
            SizedBox(height: 14),
            Center(
              child: Text(
                'No classrooms yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(height: 6),
            Center(
              child: Text(
                'Create a class or join one with a code.',
                style: TextStyle(color: _colors.muted),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        itemCount: _classrooms.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final membership = _classrooms[index];
          final classroom = _classroomFromMembership(membership);
          if (classroom == null) return const SizedBox.shrink();

          final classroomId = classroom['id']?.toString() ?? '';
          final name = classroom['name'] as String? ?? 'Untitled class';
          final memberRole = membership['role_in_class'] as String? ?? 'member';
          return Card(
            margin: EdgeInsets.zero,
            color: _colors.panel,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _colors.border),
            ),
            child: ListTile(
              key: Key('classroom-$classroomId'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: _colors.accent.withValues(alpha: 0.18),
                foregroundColor: _colors.accent,
                child: Icon(Icons.class_outlined),
              ),
              title: Text(
                name,
                style: TextStyle(
                  color: _colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Role: $memberRole',
                style: TextStyle(color: _colors.muted),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: classroomId.isEmpty
                  ? null
                  : () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => ClassroomDetailScreen(
                            classroomId: classroomId,
                            userRoleInApp: _userRole ?? 'student',
                          ),
                        ),
                      );
                      if (mounted) _loadDashboard();
                    },
            ),
          );
        },
      ),
    );
  }
}
