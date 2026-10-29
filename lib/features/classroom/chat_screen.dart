import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/notifications/toast.dart';
import 'package:astatine_dashboard/core/ui/discord_ui.dart';
import 'package:astatine_dashboard/core/ui/smooth_mouse_scroll_controller.dart';
import 'package:astatine_dashboard/features/profile/user_profile_avatar.dart';
import 'package:astatine_dashboard/features/profile/subscription_name_effect.dart';

import 'classroom_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.channelId,
    this.directConversationId,
    this.privateConversationId,
    this.classroomGroupId,
    this.classroomGroupClassroomId,
    this.channelName = '',
    this.embedded = false,
    this.darkTheme = false,
    this.languageCode = 'en',
    this.assignmentChat = false,
    this.teacherView = false,
  }) : assert(
         channelId != null ||
             directConversationId != null ||
             privateConversationId != null ||
             classroomGroupId != null,
       ),
       assert(classroomGroupId == null || classroomGroupClassroomId != null);

  final String? channelId;
  final String? directConversationId;
  final String? privateConversationId;
  final String? classroomGroupId;
  final String? classroomGroupClassroomId;
  final String channelName;
  final bool embedded;
  final bool darkTheme;
  final String languageCode;
  final bool assignmentChat;
  final bool teacherView;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const int _messagePageSize = 30;
  static const String _messageColumns = 'id, sender_id, content, created_at';

  final _messageController = TextEditingController();
  final _scrollController = SmoothMouseScrollController();
  final List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _realtimeChannel;
  bool _isSending = false;
  bool _isLoading = true;
  bool _isLoadingOlder = false;
  bool _hasOlderMessages = true;
  String? _loadError;
  int _feedGeneration = 0;

  SupabaseClient get _supabase => Supabase.instance.client;
  DiscordUiColors get _colors =>
      widget.darkTheme ? DiscordUiColors.dark : DiscordUiColors.of(context);
  Color get _background => _colors.background;
  Color get _surface => _colors.panel;
  Color get _card => _colors.card;
  Color get _secondaryText => _colors.muted;

  String _text(String english) => AppLocalizations.translateInline(
    english,
    languageCode: widget.languageCode,
  );

  String _label(String english, String vietnamese) {
    if (widget.languageCode == 'zh') return _text(english);
    return widget.languageCode == 'vi' ? vietnamese : english;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _removeRealtimeChannel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _startMessageFeed();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId ||
        oldWidget.directConversationId != widget.directConversationId ||
        oldWidget.privateConversationId != widget.privateConversationId ||
        oldWidget.classroomGroupId != widget.classroomGroupId) {
      _startMessageFeed();
    }
  }

  String get _messageTable => widget.classroomGroupId != null
      ? 'classroom_seating_messages'
      : widget.privateConversationId != null
      ? 'direct_messages'
      : widget.directConversationId != null
      ? 'teacher_student_messages'
      : 'messages';

  String get _messageFilterColumn => widget.classroomGroupId != null
      ? 'seating_column_id'
      : widget.privateConversationId != null || widget.directConversationId != null
      ? 'conversation_id'
      : 'channel_id';

  String get _messageFilterValue =>
      widget.classroomGroupId ??
      widget.privateConversationId ??
      widget.directConversationId ??
      widget.channelId!;

  void _startMessageFeed() {
    final generation = ++_feedGeneration;
    _removeRealtimeChannel();
    _messages.clear();
    _isLoading = true;
    _isLoadingOlder = false;
    _hasOlderMessages = true;
    _loadError = null;

    final channel = _supabase.channel(
      'chat:$_messageTable:$_messageFilterValue',
    );
    _realtimeChannel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _messageTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: _messageFilterColumn,
            value: _messageFilterValue,
          ),
          callback: (payload) => _handleRealtimeInsert(payload, generation),
        )
        .subscribe();
    unawaited(_loadInitialMessages(generation));
  }

  void _removeRealtimeChannel() {
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) unawaited(_supabase.removeChannel(channel));
  }

  Future<List<Map<String, dynamic>>> _queryMessages({
    String? createdBefore,
  }) async {
    final query = _supabase
        .from(_messageTable)
        .select(_messageColumns)
        .eq(_messageFilterColumn, _messageFilterValue);
    final rows = createdBefore == null
        ? await query
              .order('created_at', ascending: false)
              .range(0, _messagePageSize - 1)
        : await query
              .lt('created_at', createdBefore)
              .order('created_at', ascending: false)
              .range(0, _messagePageSize - 1);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> _loadInitialMessages(int generation) async {
    try {
      final rows = await _queryMessages();
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        _mergeMessages(rows);
        _isLoading = false;
        _hasOlderMessages = rows.length == _messagePageSize;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  void _handleRealtimeInsert(
    PostgresChangePayload payload,
    int generation,
  ) {
    if (!mounted ||
        generation != _feedGeneration ||
        payload.newRecord.isEmpty) {
      return;
    }
    final message = Map<String, dynamic>.from(payload.newRecord);
    final shouldScroll = !_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent -
                _scrollController.position.pixels <
            120;
    setState(() => _mergeMessages([message]));
    if (shouldScroll) _scrollToBottom();
  }

  void _mergeMessages(Iterable<Map<String, dynamic>> incoming) {
    final byId = <String, Map<String, dynamic>>{
      for (final message in _messages) message['id'].toString(): message,
    };
    for (final message in incoming) {
      final id = message['id']?.toString();
      if (id != null) byId[id] = message;
    }
    _messages
      ..clear()
      ..addAll(byId.values)
      ..sort((left, right) {
        final leftTime = DateTime.tryParse(left['created_at']?.toString() ?? '');
        final rightTime = DateTime.tryParse(
          right['created_at']?.toString() ?? '',
        );
        if (leftTime == null || rightTime == null) {
          return left['id'].toString().compareTo(right['id'].toString());
        }
        final timeOrder = leftTime.compareTo(rightTime);
        return timeOrder != 0
            ? timeOrder
            : left['id'].toString().compareTo(right['id'].toString());
      });
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 100) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoading ||
        _isLoadingOlder ||
        !_hasOlderMessages ||
        _messages.isEmpty) {
      return;
    }
    final generation = _feedGeneration;
    final oldestCreatedAt = _messages.first['created_at']?.toString();
    if (oldestCreatedAt == null) return;

    _isLoadingOlder = true;
    final oldMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldPixels = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    try {
      final olderRows = await _queryMessages(createdBefore: oldestCreatedAt);
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        _mergeMessages(olderRows);
        _hasOlderMessages = olderRows.length == _messagePageSize;
        _isLoadingOlder = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final addedExtent =
            _scrollController.position.maxScrollExtent - oldMaxExtent;
        _scrollController.jumpTo(oldPixels + addedExtent);
      });
    } catch (error) {
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        _isLoadingOlder = false;
        _loadError = error.toString();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;
    if (content.length > 2000) {
      ToastService.showError(
        _label(
          'Messages must be 2,000 characters or fewer.',
          'Tin nhắn không được vượt quá 2.000 ký tự.',
        ),
      );
      return;
    }

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final conversationId = widget.directConversationId;
      final privateConversationId = widget.privateConversationId;
      final classroomGroupId = widget.classroomGroupId;
      if (classroomGroupId != null) {
        await ClassroomService.sendClassroomSeatingMessage(
          classroomId: widget.classroomGroupClassroomId!,
          seatingColumnId: classroomGroupId,
          content: content,
        );
      } else if (privateConversationId != null) {
        await ClassroomService.sendDirectMessage(
          privateConversationId,
          content,
        );
      } else if (conversationId != null) {
        await ClassroomService.sendTeacherStudentMessage(
          conversationId,
          content,
        );
      } else {
        await ClassroomService.sendMessage(widget.channelId!, content);
      }
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        ToastService.showError(
          widget.languageCode == 'zh'
              ? AppLocalizations.t('errors.unexpected', languageCode: 'zh')
              : 'Message could not be sent: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final conversation = Column(
      children: [
        if (widget.assignmentChat) _buildAssignmentChatNotice(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null && _messages.isEmpty
              ? Center(
                  child: Text(
                    _text(
                      'Could not load messages. Check your connection and access permissions.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _secondaryText),
                  ),
                )
              : _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          color: _colors.accent.withValues(alpha: 0.8),
                          size: 28,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          _label(
                            'No messages yet. Start the conversation.',
                            'Chưa có tin nhắn. Hãy bắt đầu cuộc trò chuyện.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _secondaryText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isMine = message['sender_id'] == currentUserId;
                    return _MessageBubble(
                      content: message['content'] as String? ?? '',
                      createdAt: message['created_at'] as String?,
                      senderId: message['sender_id']?.toString(),
                      isMine: isMine,
                      colors: _colors,
                      assignmentChat: widget.assignmentChat,
                      languageCode: widget.languageCode,
                    );
                  },
                ),
        ),
        _buildComposer(),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(color: _background, child: conversation);
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.classroomGroupId != null
                  ? widget.channelName
                  : widget.privateConversationId != null
                  ? _label('Direct message', 'Tin nhắn riêng')
                  : widget.directConversationId != null
                  ? _label('Teacher messages', 'Tin nhắn với giáo viên')
                  : widget.channelName,
              style: TextStyle(
                color: _colors.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.classroomGroupId != null
                  ? _label('Private column group', 'Nhóm chat riêng của cột')
                  : widget.privateConversationId != null
                  ? _label('Private conversation', 'Trò chuyện riêng tư')
                  : _label('Classroom channel', 'Kênh lớp học'),
              style: TextStyle(color: _secondaryText, fontSize: 11),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _colors.border),
        ),
      ),
      body: conversation,
    );
  }

  Widget _buildAssignmentChatNotice() => Container(
    margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: _colors.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _colors.accent.withValues(alpha: 0.16)),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, color: _colors.accent, size: 15),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            _label(
              widget.teacherView
                  ? 'Only you and the student can see these messages.'
                  : 'Only you and your teacher can see these messages.',
              widget.teacherView
                  ? 'Chỉ bạn và học sinh mới xem được tin nhắn này.'
                  : 'Chỉ bạn và giáo viên mới xem được tin nhắn này.',
            ),
            style: TextStyle(color: _secondaryText, fontSize: 10, height: 1.3),
          ),
        ),
      ],
    ),
  );

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _colors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLength: 2000,
                buildCounter:
                    (context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                style: TextStyle(color: _colors.text),
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: widget.assignmentChat
                      ? widget.teacherView
                            ? _label(
                                'Reply to your student...',
                                'Trả lời học sinh...',
                              )
                            : _label(
                                'Message your teacher...',
                                'Nhắn tin cho giáo viên...',
                              )
                      : _label('Write a message...', 'Viết tin nhắn...'),
                  hintStyle: TextStyle(color: _secondaryText),
                  filled: true,
                  fillColor: _card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _colors.border.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: 42,
              child: IconButton.filled(
                tooltip: _label('Send message', 'Gửi tin nhắn'),
                onPressed: _isSending || _messageController.text.trim().isEmpty
                    ? null
                    : _sendMessage,
                iconSize: 18,
                style: IconButton.styleFrom(
                  backgroundColor: _colors.accent,
                  disabledBackgroundColor: _colors.border,
                  foregroundColor: _colors.onAccent,
                ),
                icon: _isSending
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _colors.onAccent,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.content,
    required this.createdAt,
    required this.senderId,
    required this.isMine,
    required this.colors,
    required this.assignmentChat,
    required this.languageCode,
  });

  final String content;
  final String? createdAt;
  final String? senderId;
  final bool isMine;
  final DiscordUiColors colors;
  final bool assignmentChat;
  final String languageCode;

  String? get _timeLabel {
    final dateTime = DateTime.tryParse(createdAt ?? '')?.toLocal();
    if (dateTime == null) return null;
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _senderLabel(String english, String vietnamese) => languageCode == 'vi'
      ? vietnamese
      : AppLocalizations.translateInline(english, languageCode: languageCode);

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? colors.accent
        : assignmentChat
        ? colors.panel
        : colors.card;
    final foregroundColor = isMine ? colors.onAccent : colors.text;

    return Padding(
      padding: EdgeInsets.only(
        bottom: assignmentChat ? 8 : 12,
        left: 12,
        right: 12,
      ),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            UserProfileAvatar(
              userId: senderId,
              radius: 14,
              fallbackText: 'U',
              languageCode: languageCode,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Align(
              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(assignmentChat ? 16 : 18),
                      topRight: Radius.circular(assignmentChat ? 16 : 18),
                      bottomLeft: Radius.circular(
                        isMine ? (assignmentChat ? 16 : 18) : 5,
                      ),
                      bottomRight: Radius.circular(
                        isMine ? 5 : (assignmentChat ? 16 : 18),
                      ),
                    ),
                    boxShadow: isMine
                        ? const []
                        : const [
                            BoxShadow(
                              color: Color(0x0C182235),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      assignmentChat ? 12 : 14,
                      assignmentChat ? 9 : 10,
                      assignmentChat ? 12 : 14,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: SubscriptionUserName(
                              userId: senderId,
                              fallbackName: isMine
                                  ? _senderLabel('You', 'Bạn')
                                  : _senderLabel('User', 'Người dùng'),
                              defaultColor: foregroundColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            content,
                            style: TextStyle(
                              color: foregroundColor,
                              fontSize: assignmentChat ? 13 : 14,
                              height: 1.35,
                            ),
                          ),
                        ),
                        if (_timeLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _timeLabel!,
                            style: TextStyle(
                              color: isMine
                                  ? colors.onAccent.withValues(alpha: 0.75)
                                  : colors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            UserProfileAvatar(
              userId: senderId,
              radius: 14,
              fallbackText: 'Me',
              languageCode: languageCode,
            ),
          ],
        ],
      ),
    );
  }
}
