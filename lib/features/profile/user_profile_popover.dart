import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';

import '../classroom/chat_screen.dart';
import '../classroom/classroom_service.dart';
import 'user_profile_store.dart';

Future<void> showUserProfilePopover(
  BuildContext context, {
  required String userId,
  String languageCode = 'vi',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: UserProfilePopover(userId: userId, languageCode: languageCode),
    ),
  );
}

class UserProfilePopover extends StatefulWidget {
  const UserProfilePopover({
    super.key,
    required this.userId,
    this.languageCode = 'vi',
  });

  final String userId;
  final String languageCode;

  @override
  State<UserProfilePopover> createState() => _UserProfilePopoverState();
}

class _UserProfilePopoverState extends State<UserProfilePopover> {
  List<Map<String, dynamic>> _equippedItems = const [];
  RealtimeChannel? _inventoryChannel;
  bool _loadingItems = true;
  bool _openingConversation = false;
  int _inventoryRevision = 0;
  String? _itemLoadError;
  String? _conversationError;

  AstatinePalette get _palette =>
      Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;

  bool get _vietnamese => widget.languageCode == 'vi';

  String _label(String english, String vietnamese) =>
      _vietnamese ? vietnamese : english;

  @override
  void initState() {
    super.initState();
    UserProfileStore.instance.watchUser(widget.userId);
    _watchEquippedItems();
    _loadEquippedItems();
  }

  void _watchEquippedItems() {
    _inventoryChannel = Supabase.instance.client
        .channel('profile-inventory-${widget.userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_inventory',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: widget.userId,
          ),
          callback: (payload) {
            _inventoryRevision++;
            final record = payload.eventType == PostgresChangeEvent.delete
                ? payload.oldRecord
                : payload.newRecord;
            final itemId = record['id']?.toString();
            if (itemId == null || !mounted) return;
            setState(() {
              _equippedItems.removeWhere(
                (item) => item['id']?.toString() == itemId,
              );
              if (payload.eventType != PostgresChangeEvent.delete &&
                  record['is_equipped'] == true) {
                _equippedItems.add(Map<String, dynamic>.from(record));
              }
            });
          },
        )
        .subscribe();
  }

  Future<void> _loadEquippedItems() async {
    try {
      final initialRevision = _inventoryRevision;
      final items = await Supabase.instance.client
          .from('user_inventory')
          .select('id, item_name, item_type, icon_url, is_equipped')
          .eq('user_id', widget.userId)
          .eq('is_equipped', true);
      if (!mounted) return;
      setState(() {
        if (_inventoryRevision == initialRevision) {
          _equippedItems = items
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
        _loadingItems = false;
        _itemLoadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingItems = false;
        _itemLoadError = error.toString();
      });
    }
  }

  @override
  void dispose() {
    final channel = _inventoryChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  Future<void> _openDirectMessage() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == widget.userId) {
      setState(() {
        _conversationError = _label(
          'Sign in and select another user to start a direct message.',
          'Đăng nhập và chọn người dùng khác để nhắn tin riêng.',
        );
      });
      return;
    }
    setState(() {
      _openingConversation = true;
      _conversationError = null;
    });
    try {
      final conversationId = await ClassroomService.openDirectConversation(
        widget.userId,
      );
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      navigator.pop();
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            privateConversationId: conversationId,
            languageCode: widget.languageCode,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _conversationError = error.toString();
        _openingConversation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UserProfileStore.instance,
      builder: (context, _) {
        final profile = UserProfileStore.instance.profileFor(widget.userId);
        final profileLoaded = UserProfileStore.instance.isLoadedFor(
          widget.userId,
        );
        final profileError = UserProfileStore.instance.errorFor(widget.userId);
        return Container(
          width: 340,
          constraints: const BoxConstraints(maxWidth: 380, maxHeight: 720),
          decoration: BoxDecoration(
            color: _palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _palette.border),
            boxShadow: [
              BoxShadow(
                color: _palette.accent.withValues(
                  alpha: _palette.glowEnabled ? 0.18 : 0.08,
                ),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBanner(profile),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -35),
                        child: _buildAvatar(profile),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -25),
                        child: _buildIdentity(
                          profile,
                          profileError,
                          isLoading: !profileLoaded && profileError == null,
                        ),
                      ),
                      _buildItems(),
                      const SizedBox(height: 15),
                      _buildBio(profile),
                      if (_conversationError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _conversationError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openingConversation
                              ? null
                              : _openDirectMessage,
                          style: FilledButton.styleFrom(
                            backgroundColor: _palette.accent,
                            foregroundColor: _palette.accentText,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: _openingConversation
                              ? SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _palette.accentText,
                                  ),
                                )
                              : const Icon(Icons.chat_bubble_outline_rounded),
                          label: Text(
                            _label('Message privately', 'Nhắn tin riêng'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
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

  Widget _buildBanner(Map<String, dynamic>? profile) {
    final url = (profile?['banner_url'] as String?)?.trim();
    return SizedBox(
      height: 110,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url?.isNotEmpty == true)
            Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _bannerFallback(),
            )
          else
            _bannerFallback(),
          Positioned(
            top: 10,
            right: 10,
            child: PopupMenuButton<String>(
              tooltip: _label('Profile actions', 'Tùy chọn hồ sơ'),
              color: _palette.card,
              onSelected: (action) {
                if (action == 'copy') {
                  Clipboard.setData(ClipboardData(text: widget.userId));
                } else if (action == 'close') {
                  Navigator.of(context).pop();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'copy',
                  child: Text(
                    _label('Copy user ID', 'Sao chép ID người dùng'),
                    style: TextStyle(color: _palette.primaryText),
                  ),
                ),
                PopupMenuItem(
                  value: 'close',
                  child: Text(
                    _label('Close profile', 'Đóng hồ sơ'),
                    style: TextStyle(color: _palette.primaryText),
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: _palette.canvasText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerFallback() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_palette.background, _palette.input, _palette.card],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.blur_on_rounded,
        size: 30,
        color: _palette.accent.withValues(alpha: 0.45),
      ),
    ),
  );

  Widget _buildAvatar(Map<String, dynamic>? profile) {
    final url = (profile?['avatar_url'] as String?)?.trim();
    final name = (profile?['full_name'] as String?)?.trim();
    return SizedBox(
      width: 82,
      height: 82,
      child: Stack(
        children: [
          Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _palette.card,
              shape: BoxShape.circle,
              border: Border.all(color: _palette.accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _palette.accent.withValues(alpha: 0.24),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: url?.isNotEmpty == true
                  ? Image.network(
                      url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _avatarFallback(name),
                    )
                  : _avatarFallback(name),
            ),
          ),
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: const Color(0xFF3DDC84),
                shape: BoxShape.circle,
                border: Border.all(color: _palette.card, width: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String? name) {
    final initial = name?.isNotEmpty == true
        ? name!.characters.first.toUpperCase()
        : '?';
    return ColoredBox(
      color: _palette.input,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: _palette.accent,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildIdentity(
    Map<String, dynamic>? profile,
    String? profileError, {
    required bool isLoading,
  }) {
    final name = (profile?['full_name'] as String?)?.trim();
    final className = (profile?['class_name'] as String?)?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLoading)
          SizedBox(
            height: 23,
            width: 23,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _palette.accent,
            ),
          )
        else
          Text(
            name?.isNotEmpty == true ? name! : _label('User', 'Người dùng'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _palette.primaryText,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        if (className?.isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.school_outlined, size: 14, color: _palette.accent),
              const SizedBox(width: 5),
              Text(
                className!,
                style: TextStyle(color: _palette.secondaryText, fontSize: 11),
              ),
            ],
          ),
        ],
        if (profileError != null) ...[
          const SizedBox(height: 6),
          Text(
            _label(
              'Profile details could not be loaded.',
              'Không thể tải thông tin hồ sơ.',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItems() {
    final title = _label('EQUIPPED ITEMS', 'VẬT PHẨM ĐANG ĐEO');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _palette.accent,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingItems)
          LinearProgressIndicator(
            minHeight: 2,
            color: _palette.accent,
            backgroundColor: _palette.input,
          )
        else if (_itemLoadError != null)
          Text(
            _label(
              'Could not load equipped items.',
              'Không thể tải vật phẩm đang dùng.',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 10,
            ),
          )
        else if (_equippedItems.isEmpty)
          Text(
            _label('No equipped items.', 'Chưa có vật phẩm đang dùng.'),
            style: TextStyle(color: _palette.secondaryText, fontSize: 10),
          )
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [for (final item in _equippedItems) _buildItemChip(item)],
          ),
      ],
    );
  }

  Widget _buildItemChip(Map<String, dynamic> item) {
    final url = (item['icon_url'] as String?)?.trim();
    final name = item['item_name']?.toString() ?? '';
    final itemType = item['item_type']?.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: _palette.input,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (url?.isNotEmpty == true)
            Image.network(
              url!,
              width: 17,
              height: 17,
              errorBuilder: (_, _, _) => _itemIcon(itemType),
            )
          else
            _itemIcon(itemType),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _palette.primaryText, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemIcon(String? itemType) => Icon(
    itemType == 'title'
        ? Icons.title_rounded
        : itemType == 'frame'
        ? Icons.crop_square_rounded
        : Icons.workspace_premium_rounded,
    color: _palette.accent,
    size: 17,
  );

  Widget _buildBio(Map<String, dynamic>? profile) {
    final bio = (profile?['bio'] as String?)?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _palette.background.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _palette.border),
      ),
      child: Text(
        bio?.isNotEmpty == true
            ? bio!
            : _label('No bio added yet.', 'Chưa có tiểu sử.'),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: _palette.secondaryText, fontSize: 11),
      ),
    );
  }
}
