import 'dart:async';

import 'package:flutter/material.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';

import 'user_profile_popover.dart';
import 'user_profile_store.dart';

class UserProfileAvatar extends StatefulWidget {
  const UserProfileAvatar({
    super.key,
    required this.userId,
    required this.radius,
    this.fallbackText,
    this.backgroundColor,
    this.languageCode = 'vi',
  });

  final String? userId;
  final double radius;
  final String? fallbackText;
  final Color? backgroundColor;
  final String languageCode;

  @override
  State<UserProfileAvatar> createState() => _UserProfileAvatarState();
}

class _UserProfileAvatarState extends State<UserProfileAvatar> {
  @override
  void initState() {
    super.initState();
    _watchUser();
  }

  @override
  void didUpdateWidget(covariant UserProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _watchUser();
  }

  void _watchUser() {
    final userId = widget.userId;
    if (userId != null && userId.isNotEmpty) {
      unawaited(UserProfileStore.instance.watchUser(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    if (userId == null || userId.isEmpty) {
      return _buildAvatar(null);
    }

    return AnimatedBuilder(
      animation: UserProfileStore.instance,
      builder: (context, _) =>
          _buildAvatar(UserProfileStore.instance.profileFor(userId)),
    );
  }

  Widget _buildAvatar(Map<String, dynamic>? profile) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    final name = (profile?['full_name'] as String?)?.trim();
    final fallback = widget.fallbackText?.trim();
    final initial = (name?.isNotEmpty == true ? name : fallback)
        ?.characters
        .firstOrNull
        ?.toUpperCase();
    final avatarUrl = (profile?['avatar_url'] as String?)?.trim();

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showUserProfilePopover(
          context,
          userId: widget.userId!,
          languageCode: widget.languageCode,
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.accent.withValues(alpha: 0.68)),
              boxShadow: [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.16),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: SizedBox.square(
              dimension: widget.radius * 2,
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: widget.backgroundColor ?? palette.input,
                      child: Center(child: _buildFallback(initial, palette)),
                    ),
                    if (avatarUrl?.isNotEmpty == true)
                      Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        // Limit decode size to display dimensions to save GPU memory.
                        cacheWidth: (widget.radius * 4).toInt(),
                        cacheHeight: (widget.radius * 4).toInt(),
                        // ignore: unnecessary_underscores
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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

  Widget _buildFallback(String? initial, AstatinePalette palette) {
    if (initial == null || initial.isEmpty) {
      return Icon(
        Icons.person_outline_rounded,
        color: palette.accent,
        size: widget.radius,
      );
    }
    return Text(
      initial,
      style: TextStyle(
        color: palette.accent,
        fontWeight: FontWeight.w700,
        fontSize: widget.radius * 0.72,
      ),
    );
  }
}
