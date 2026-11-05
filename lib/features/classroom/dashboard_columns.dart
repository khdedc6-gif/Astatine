import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/ui/discord_ui.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';

typedef DashboardColumnBuilder = Widget Function(BuildContext context);

enum _ChatHeaderAction { channels, members, pinned, notifications, settings }

typedef DashboardMessageBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> message,
  String? currentUserId,
);

class TopBarClassroomSwitcher extends StatefulWidget {
  const TopBarClassroomSwitcher({
    super.key,
    required this.currentUserId,
    required this.memberships,
    required this.selectedClassroomId,
    required this.isVietnamese,
    this.languageCode,
    required this.onSelect,
    required this.onAdd,
  });

  final String currentUserId;
  final List<Map<String, dynamic>> memberships;
  final String? selectedClassroomId;
  final bool isVietnamese;
  final String? languageCode;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final VoidCallback onAdd;

  @override
  State<TopBarClassroomSwitcher> createState() =>
      _TopBarClassroomSwitcherState();
}

class _TopBarClassroomSwitcherState extends State<TopBarClassroomSwitcher> {
  Map<String, dynamic>? _classroomFrom(Map<String, dynamic> membership) {
    final value = membership['classrooms'];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _text(String english, String vietnamese) {
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

  @override
  Widget build(BuildContext context) {
    final colors = DiscordUiColors.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.panel, colors.background],
        ),
        border: Border(
          bottom: BorderSide(color: colors.accent.withValues(alpha: 0.22)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.accent.withValues(alpha: 0.2),
                  colors.accent.withValues(alpha: 0.07),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.school_outlined, color: colors.accent, size: 18),
          ),
          const SizedBox(width: 9),
          Text(
            _text('Classrooms', 'Lớp học'),
            style: TextStyle(
              color: colors.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: widget.memberships.isEmpty
                ? Text(
                    _text('No classes', 'Chưa tham gia lớp nào'),
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.memberships.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 7),
                    itemBuilder: (context, index) {
                      final membership = widget.memberships[index];
                      final classroom = _classroomFrom(membership);
                      if (classroom == null) return const SizedBox.shrink();
                      final id = classroom['id']?.toString();
                      final selected = id == widget.selectedClassroomId;
                      return Center(
                        child: ChoiceChip(
                          key: ValueKey('top-class-$id'),
                          label: GlideSelect(
                            selected: selected,
                            child: Text(
                              classroom['name']?.toString() ??
                                  _text('Class', 'Lớp'),
                            ),
                          ),
                          selected: selected,
                          selectedColor: colors.accent,
                          backgroundColor: colors.card,
                          labelStyle: TextStyle(
                            color: selected ? colors.onAccent : colors.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: selected
                                ? colors.accent.withValues(alpha: 0.62)
                                : colors.border,
                          ),
                          onSelected: (_) => widget.onSelect(classroom),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: _text('Add class', 'Tạo hoặc tham gia lớp'),
            onPressed: widget.onAdd,
            style: IconButton.styleFrom(
              backgroundColor: colors.card,
              foregroundColor: colors.accent,
              fixedSize: const Size(36, 36),
            ),
            icon: const Icon(Icons.add_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class ChannelSidebar extends StatefulWidget {
  const ChannelSidebar({
    super.key,
    required this.selectedClassroomId,
    required this.builder,
    required this.filterChannels,
    required this.onChannelsChanged,
  });

  final String? selectedClassroomId;
  final DashboardColumnBuilder builder;
  final List<Map<String, dynamic>> Function(List<Map<String, dynamic>>)
  filterChannels;
  final ValueChanged<List<Map<String, dynamic>>> onChannelsChanged;

  @override
  State<ChannelSidebar> createState() => _ChannelSidebarState();
}

class _ChannelSidebarState extends State<ChannelSidebar> {
  @override
  void initState() {
    super.initState();
    _createChannelStream();
  }

  Stream<List<Map<String, dynamic>>>? _channelStream;
  String? _lastEmittedSignature;

  void _createChannelStream() {
    final classroomId = widget.selectedClassroomId;
    _lastEmittedSignature = null;
    _channelStream = classroomId == null
        ? null
        : Supabase.instance.client
              .from('channels')
              .stream(primaryKey: ['id'])
              .eq('classroom_id', classroomId)
              .order('name');
  }

  @override
  void didUpdateWidget(covariant ChannelSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedClassroomId != widget.selectedClassroomId) {
      _createChannelStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _channelStream;
    if (stream == null) return widget.builder(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('channel-stream-${widget.selectedClassroomId}'),
      stream: stream,
      builder: (context, snapshot) {
        final rows = snapshot.data?.map(Map<String, dynamic>.from).toList();
        if (rows != null) {
          final visible = widget.filterChannels(rows);
          final signature = visible
              .map((channel) => '${channel['id']}:${channel['name']}')
              .join('|');
          if (signature != _lastEmittedSignature) {
            _lastEmittedSignature = signature;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onChannelsChanged(visible);
            });
          }
        }
        return widget.builder(context);
      },
    );
  }
}

class ChatAreaWorkspace extends StatefulWidget {
  const ChatAreaWorkspace({
    super.key,
    required this.selectedChannelId,
    required this.channelName,
    this.isVietnamese = false,
    this.languageCode,
    required this.currentUserId,
    required this.compact,
    required this.showMembers,
    required this.availableWidth,
    required this.notificationsEnabled,
    required this.canSend,
    required this.isSending,
    required this.onSend,
    required this.onToggleNotifications,
    required this.onToggleMembers,
    required this.onShowMembers,
    required this.onShowChannels,
    required this.onPinnedMessages,
    required this.onChannelSettings,
    required this.onScanNotebook,
    required this.onAttachHomework,
    required this.messageBuilder,
  });

  final String selectedChannelId;
  final String channelName;
  final bool isVietnamese;
  final String? languageCode;
  final String? currentUserId;
  final bool compact;
  final bool showMembers;
  final double availableWidth;
  final bool notificationsEnabled;
  final bool canSend;
  final bool isSending;
  final ValueChanged<String> onSend;
  final VoidCallback onToggleNotifications;
  final VoidCallback onToggleMembers;
  final VoidCallback onShowMembers;
  final VoidCallback onShowChannels;
  final VoidCallback onPinnedMessages;
  final VoidCallback onChannelSettings;
  final VoidCallback? onScanNotebook;
  final VoidCallback? onAttachHomework;
  final DashboardMessageBuilder messageBuilder;

  @override
  State<ChatAreaWorkspace> createState() => _ChatAreaWorkspaceState();
}

class _ChatAreaWorkspaceState extends State<ChatAreaWorkspace> {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Stream<List<Map<String, dynamic>>>? _messageStream;
  String? _lastMessageSignature;
  String _searchQuery = '';
  bool _searching = false;

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

  @override
  void initState() {
    super.initState();
    _createMessageStream();
  }

  void _createMessageStream() {
    _messageStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('channel_id', widget.selectedChannelId)
        .order('created_at', ascending: true);
    _lastMessageSignature = null;
  }

  @override
  void didUpdateWidget(covariant ChatAreaWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedChannelId != widget.selectedChannelId) {
      _createMessageStream();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  void _send() {
    final content = _messageController.text.trim();
    if (!widget.canSend || widget.isSending || content.isEmpty) return;
    _messageController.clear();
    setState(() {});
    widget.onSend(content);
  }

  void _insertEmoji() {
    final value = _messageController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final next = value.text.replaceRange(start, end, '🙂');
    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + 2),
    );
    setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = DiscordUiColors.of(context);
    final tiny = widget.availableWidth < 480;
    return Column(
      children: [
        Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 19),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.panel, colors.background],
            ),
            border: Border(
              bottom: BorderSide(color: colors.accent.withValues(alpha: 0.2)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.24),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.tag, size: 18, color: colors.accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _searching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: colors.text, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: _textLabel(
                            'Search messages in this channel',
                            'Tìm tin nhắn trong kênh này',
                          ),
                          hintStyle: TextStyle(color: colors.muted),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value.toLowerCase()),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.channelName,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                      ),
              ),
              IconButton(
                tooltip: _searching
                    ? _textLabel('Close search', 'Đóng tìm kiếm')
                    : _textLabel('Search', 'Tìm kiếm'),
                onPressed: _toggleSearch,
                icon: Icon(
                  _searching ? Icons.close_rounded : Icons.search_rounded,
                  color: colors.muted,
                  size: 19,
                ),
              ),
              if (!widget.compact)
                IconButton(
                  tooltip: _textLabel('Pinned messages', 'Tin nhắn đã ghim'),
                  onPressed: widget.onPinnedMessages,
                  icon: Icon(Icons.push_pin_outlined, color: colors.muted),
                ),
              if (widget.compact && !tiny)
                IconButton(
                  tooltip: _textLabel('Channels', 'Kênh'),
                  onPressed: widget.onShowChannels,
                  icon: Icon(Icons.menu_rounded, color: colors.muted),
                ),
              if (!tiny)
                IconButton(
                  tooltip: widget.showMembers
                      ? _textLabel('Hide members', 'Ẩn thành viên')
                      : _textLabel('Show members', 'Hiện thành viên'),
                  onPressed: widget.availableWidth < 1120
                      ? widget.onShowMembers
                      : widget.onToggleMembers,
                  icon: Icon(
                    Icons.people_alt_outlined,
                    color: widget.showMembers ? colors.accent : colors.muted,
                    size: 19,
                  ),
                ),
              if (!widget.compact)
                IconButton(
                  tooltip: widget.notificationsEnabled
                      ? _textLabel('Mute notifications', 'Tắt thông báo')
                      : _textLabel('Enable notifications', 'Bật thông báo'),
                  onPressed: widget.onToggleNotifications,
                  icon: Icon(
                    widget.notificationsEnabled
                        ? Icons.notifications_none_rounded
                        : Icons.notifications_off_outlined,
                    color: colors.muted,
                    size: 19,
                  ),
                ),
              if (!widget.compact)
                IconButton(
                  tooltip: _textLabel('Channel settings', 'Cài đặt kênh'),
                  onPressed: widget.onChannelSettings,
                  icon: Icon(Icons.tune_rounded, color: colors.muted, size: 19),
                ),
              if (widget.compact)
                PopupMenuButton<_ChatHeaderAction>(
                  tooltip: _textLabel('More channel actions', 'Tác vụ khác'),
                  icon: Icon(Icons.more_horiz_rounded, color: colors.muted),
                  onSelected: (action) {
                    switch (action) {
                      case _ChatHeaderAction.channels:
                        widget.onShowChannels();
                      case _ChatHeaderAction.members:
                        widget.availableWidth < 1120
                            ? widget.onShowMembers()
                            : widget.onToggleMembers();
                      case _ChatHeaderAction.pinned:
                        widget.onPinnedMessages();
                      case _ChatHeaderAction.notifications:
                        widget.onToggleNotifications();
                      case _ChatHeaderAction.settings:
                        widget.onChannelSettings();
                    }
                  },
                  itemBuilder: (context) => [
                    if (tiny)
                      PopupMenuItem(
                        value: _ChatHeaderAction.channels,
                        child: _headerMenuItem(
                          colors,
                          Icons.menu_rounded,
                          _textLabel('Channels', 'Kênh'),
                        ),
                      ),
                    if (tiny)
                      PopupMenuItem(
                        value: _ChatHeaderAction.members,
                        child: _headerMenuItem(
                          colors,
                          Icons.people_alt_outlined,
                          _textLabel('Class members', 'Thành viên'),
                        ),
                      ),
                    PopupMenuItem(
                      value: _ChatHeaderAction.pinned,
                      child: _headerMenuItem(
                        colors,
                        Icons.push_pin_outlined,
                        _textLabel('Pinned messages', 'Tin nhắn đã ghim'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _ChatHeaderAction.notifications,
                      child: _headerMenuItem(
                        colors,
                        widget.notificationsEnabled
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_none_rounded,
                        widget.notificationsEnabled
                            ? _textLabel('Mute notifications', 'Tắt thông báo')
                            : _textLabel(
                                'Enable notifications',
                                'Bật thông báo',
                              ),
                      ),
                    ),
                    PopupMenuItem(
                      value: _ChatHeaderAction.settings,
                      child: _headerMenuItem(
                        colors,
                        Icons.tune_rounded,
                        _textLabel('Channel settings', 'Cài đặt kênh'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: colors.background,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              key: ValueKey('chat-stream-${widget.selectedChannelId}'),
              stream: _messageStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      _textLabel(
                        'Could not load messages. Check channel access and Realtime settings.',
                        'Không thể tải tin nhắn. Hãy kiểm tra quyền truy cập kênh và cài đặt Realtime.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.muted),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final allMessages = snapshot.data ?? const [];
                final signature = allMessages.isEmpty
                    ? 'empty'
                    : '${allMessages.length}:${allMessages.last['id']}';
                if (_lastMessageSignature != signature) {
                  _lastMessageSignature = signature;
                  _scrollToBottom();
                }
                final messages = allMessages.where((message) {
                  return _searchQuery.isEmpty ||
                      (message['content']?.toString().toLowerCase().contains(
                            _searchQuery,
                          ) ??
                          false);
                }).toList();
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? _textLabel(
                              'No messages yet. Start the conversation.',
                              'Chưa có tin nhắn. Hãy bắt đầu trò chuyện.',
                            )
                          : _textLabel(
                              'No matching messages.',
                              'Không tìm thấy tin nhắn phù hợp.',
                            ),
                      style: TextStyle(color: colors.muted),
                    ),
                  );
                }
                return ListView.builder(
                  key: const Key('discord-message-list'),
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => widget.messageBuilder(
                    context,
                    messages[index],
                    widget.currentUserId,
                  ),
                );
              },
            ),
          ),
        ),
        _buildComposer(colors),
      ],
    );
  }

  Widget _buildComposer(DiscordUiColors colors) => Container(
    padding: const EdgeInsets.fromLTRB(17, 10, 17, 13),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.background, colors.panel],
      ),
      border: Border(
        top: BorderSide(color: colors.accent.withValues(alpha: 0.18)),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.canSend)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: colors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _textLabel(
                      'You do not have permission to chat in this channel.',
                      'Bạn không có quyền trò chuyện trong kênh này.',
                    ),
                    style: TextStyle(color: colors.muted, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ActionChip(
              avatar: Icon(
                Icons.document_scanner_outlined,
                size: 15,
                color: colors.accent,
              ),
              label: Text(
                _textLabel('Scan Notebook (AI)', 'Quét vở (AI)'),
                style: TextStyle(fontSize: 10),
              ),
              onPressed: widget.canSend ? widget.onScanNotebook : null,
              backgroundColor: colors.card,
              side: BorderSide(color: colors.border),
              visualDensity: VisualDensity.compact,
            ),
            ActionChip(
              avatar: Icon(
                Icons.attach_file_rounded,
                size: 15,
                color: colors.accent,
              ),
              label: Text(
                _textLabel('Attach Homework', 'Đính kèm bài tập'),
                style: TextStyle(fontSize: 10),
              ),
              onPressed: widget.canSend ? widget.onAttachHomework : null,
              backgroundColor: colors.card,
              side: BorderSide(color: colors.border),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: widget.canSend,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                style: TextStyle(color: colors.text, fontSize: 12),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: widget.languageCode == 'zh'
                      ? '发送消息到 #${widget.channelName}...'
                      : _textLabel(
                          'Message #${widget.channelName}...',
                          'Nhắn tin #${widget.channelName}...',
                        ),
                  hintStyle: TextStyle(color: colors.hint, fontSize: 11),
                  filled: true,
                  fillColor: colors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: colors.accent.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            IconButton(
              tooltip: _textLabel('Insert emoji', 'Chèn biểu tượng cảm xúc'),
              onPressed: widget.canSend ? _insertEmoji : null,
              icon: Icon(Icons.emoji_emotions_outlined, color: colors.muted),
            ),
            const SizedBox(width: 3),
            SizedBox(
              height: 39,
              child: FilledButton(
                key: const Key('discord-send-message'),
                onPressed:
                    !widget.canSend ||
                        widget.isSending ||
                        _messageController.text.trim().isEmpty
                    ? null
                    : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: widget.isSending
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onAccent,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 17),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _headerMenuItem(DiscordUiColors colors, IconData icon, String label) =>
      Row(
        children: [
          Icon(icon, size: 17, color: colors.muted),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: colors.text)),
        ],
      );
}

class MemberListSidebar extends StatefulWidget {
  const MemberListSidebar({
    super.key,
    required this.selectedClassroomId,
    required this.builder,
  });

  final String? selectedClassroomId;
  final DashboardColumnBuilder builder;

  @override
  State<MemberListSidebar> createState() => _MemberListSidebarState();
}

class _MemberListSidebarState extends State<MemberListSidebar> {
  @override
  Widget build(BuildContext context) => widget.builder(context);
}
