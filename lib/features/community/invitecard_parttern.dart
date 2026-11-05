import 'package:flutter/material.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';

class InviteDetailsCard extends StatelessWidget {
  final String inviterName;
  final int totalMembers;
  final String className;
  final String topic;
  final String deadline;
  final String taskDescription;
  final bool compact;
  final String languageCode;
  final VoidCallback? onDecline;
  final VoidCallback? onAccept;

  const InviteDetailsCard({
    super.key,
    this.inviterName = 'User Name',
    this.totalMembers = 8,
    this.className = 'Class Name',
    this.topic = 'Topic',
    this.deadline = 'Date/Time',
    this.taskDescription = 'Brief task description',
    this.compact = false,
    this.languageCode = 'en',
    this.onDecline,
    this.onAccept,
  });

  String _text(String english) =>
      AppLocalizations.translateInline(english, languageCode: languageCode);

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    final cardBgColor = palette.card;
    final innerBoxColor = palette.input;
    final accentBlue = palette.accent;
    final textSecondary = palette.secondaryText;
    final sectionGap = compact ? 12.0 : 24.0;
    final contentPadding = compact ? 12.0 : 16.0;
    final cardPadding = compact ? 14.0 : 20.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: compact ? 12 : 14,
                backgroundColor: accentBlue.withValues(alpha: 0.15),
                child: Text(
                  'A',
                  style: TextStyle(
                    color: palette.accentText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _text('Invited by {name}')
                      .replaceFirst('{name}', inviterName),
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _text('Total Members: {count}')
                    .replaceFirst('{count}', '$totalMembers'),
                style: TextStyle(
                  color: accentBlue,
                  fontSize: compact ? 11 : 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: sectionGap),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 10 : 12),
                decoration: BoxDecoration(
                  color: accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentBlue.withValues(alpha: 0.25)),
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  color: accentBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      className,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: compact ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topic,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: compact ? 13 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: sectionGap),
          Container(
            padding: EdgeInsets.all(contentPadding),
            decoration: BoxDecoration(
              color: innerBoxColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _text('Deadline: {deadline}')
                            .replaceFirst('{deadline}', deadline),
                        style: TextStyle(
                          color: palette.secondaryText,
                          fontSize: compact ? 13 : 14,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: palette.border, height: 1),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      color: textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _text('Your Task: {task}')
                            .replaceFirst('{task}', taskDescription),
                        style: TextStyle(
                          color: palette.secondaryText,
                          fontSize: compact ? 13 : 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: sectionGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onDecline,
                icon: Icon(Icons.close, color: textSecondary, size: 18),
                label: Text(
                  _text('Decline'),
                  style: TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onAccept,
                icon: Icon(Icons.check, color: palette.accentText, size: 18),
                label: Text(
                  _text('Accept'),
                  style: TextStyle(
                    color: palette.accentText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: palette.accentText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
