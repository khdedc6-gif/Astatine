import 'package:flutter/material.dart';

import 'package:astatine_dashboard/core/notifications/toast.dart';
import 'package:astatine_dashboard/core/ui/discord_ui.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';
import 'package:astatine_dashboard/core/ui/hover_ripple.dart';
import 'package:astatine_dashboard/core/ui/smooth_mouse_scroll_controller.dart';

import 'chat_screen.dart';
import 'classroom_service.dart';

class ClassroomDetailScreen extends StatefulWidget {
  const ClassroomDetailScreen({
    super.key,
    required this.classroomId,
    required this.userRoleInApp,
  });

  final String classroomId;
  final String userRoleInApp;

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> {
  DiscordUiColors get _colors => DiscordUiColors.of(context);

  final _channelScrollController = SmoothMouseScrollController();
  Map<String, dynamic>? _classroom;
  List<Map<String, dynamic>> _channels = const [];
  String? _loadError;
  bool _isLoading = true;
  bool _isCreatingChannel = false;

  bool get _canCreateChannels => const {
    'teacher',
    'developer',
  }.contains(widget.userRoleInApp.toLowerCase());

  @override
  void dispose() {
    _channelScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadClassroom();
  }

  Future<void> _loadClassroom() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        ClassroomService.getClassroom(widget.classroomId),
        ClassroomService.getChannels(widget.classroomId),
      ]);
      if (!mounted) return;
      setState(() {
        _classroom = results[0] as Map<String, dynamic>;
        _channels = results[1] as List<Map<String, dynamic>>;
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

  Future<void> _showCreateChannelSheet() async {
    final draft = await showModalBottomSheet<_ChannelDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _CreateChannelSheet(),
    );
    if (draft == null || !mounted) return;

    setState(() => _isCreatingChannel = true);
    try {
      await ClassroomService.createChannel(
        widget.classroomId,
        draft.name,
        draft.isPrivate,
        draft.allowedRoles,
      );
      await _loadClassroom();
      if (mounted) ToastService.showSuccess('Channel created.');
    } catch (error) {
      if (mounted) ToastService.showError(error.toString());
    } finally {
      if (mounted) setState(() => _isCreatingChannel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.panel,
        foregroundColor: _colors.text,
        surfaceTintColor: Colors.transparent,
        title: Text(_classroom?['name'] as String? ?? 'Classroom'),
        actions: [
          if (_canCreateChannels)
            IconButton(
              key: const Key('create-channel-action'),
              tooltip: 'Create channel',
              onPressed: _isCreatingChannel ? null : _showCreateChannelSheet,
              icon: _isCreatingChannel
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: _buildBody(),
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
                onPressed: _loadClassroom,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClassroom,
      child: _channels.isEmpty
          ? ListView(
              controller: _channelScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 180),
                Icon(Icons.tag, size: 42, color: _colors.muted),
                SizedBox(height: 12),
                Center(
                  child: Text(
                    'No channels yet',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            )
          : ListView.separated(
              controller: _channelScrollController,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              itemCount: _channels.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final channel = _channels[index];
                final channelId = channel['id']?.toString() ?? '';
                final channelName = channel['name'] as String? ?? 'channel';
                final isPrivate = channel['is_private'] as bool? ?? false;

                return HoverRipple(
                  borderRadius: BorderRadius.circular(10),
                  color: _colors.accent,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: _colors.panel,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: _colors.border),
                    ),
                    child: ListTile(
                      key: Key('channel-$channelId'),
                      leading: Icon(
                        isPrivate ? Icons.lock_outline : Icons.tag,
                        color: _colors.muted,
                      ),
                      title: Text(
                        channelName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: isPrivate
                          ? const Text('Private channel')
                          : null,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: channelId.isEmpty
                          ? null
                          : () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => ChatScreen(
                                  channelId: channelId,
                                  channelName: channelName,
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ChannelDraft {
  const _ChannelDraft({
    required this.name,
    required this.isPrivate,
    required this.allowedRoles,
  });

  final String name;
  final bool isPrivate;
  final String allowedRoles;
}

class _CreateChannelSheet extends StatefulWidget {
  const _CreateChannelSheet();

  @override
  State<_CreateChannelSheet> createState() => _CreateChannelSheetState();
}

class _CreateChannelSheetState extends State<_CreateChannelSheet> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPrivate = false;
  String _allowedRoles = 'all';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      _ChannelDraft(
        name: _nameController.text.trim(),
        isPrivate: _isPrivate,
        allowedRoles: _allowedRoles,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create channel',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const Key('channel-name-input'),
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Channel name',
                hintText: 'e.g. homework',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a channel name.'
                  : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private channel'),
              value: _isPrivate,
              onChanged: (value) => setState(() {
                _isPrivate = value;
                _allowedRoles = value ? 'teacher_only' : 'all';
              }),
            ),
            DropdownButtonFormField<String>(
              initialValue: _allowedRoles,
              decoration: const InputDecoration(
                labelText: 'Allowed roles',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: GlideSelect(
                    selected: _allowedRoles == 'all',
                    child: const Text('All members'),
                  ),
                ),
                DropdownMenuItem(
                  value: 'teacher_only',
                  child: GlideSelect(
                    selected: _allowedRoles == 'teacher_only',
                    child: const Text('Teachers only'),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _allowedRoles = value);
              },
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('channel-create-submit'),
              onPressed: _submit,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create channel'),
            ),
          ],
        ),
      ),
    );
  }
}
