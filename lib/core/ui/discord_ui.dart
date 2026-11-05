import 'package:flutter/material.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';

abstract final class DiscordPalette {
  static const background = Color(0xFF0D0F14);
  static const panel = Color(0xFF181A22);
  static const card = Color(0xFF20232E);
  static const accent = Color(0xFF3B82F6);
  static const border = Color(0xFF3F424D);
  static const text = Color(0xFFF2F3F5);
  static const muted = Color(0xFFB9BBC2);
  static const hint = Color(0xFF6B7280);
}

@immutable
class DiscordUiColors {
  const DiscordUiColors({
    required this.background,
    required this.panel,
    required this.card,
    required this.accent,
    required this.border,
    required this.text,
    required this.muted,
    required this.hint,
    required this.onAccent,
  });

  final Color background;
  final Color panel;
  final Color card;
  final Color accent;
  final Color border;
  final Color text;
  final Color muted;
  final Color hint;
  final Color onAccent;

  static const dark = DiscordUiColors(
    background: DiscordPalette.background,
    panel: DiscordPalette.panel,
    card: DiscordPalette.card,
    accent: DiscordPalette.accent,
    border: DiscordPalette.border,
    text: DiscordPalette.text,
    muted: DiscordPalette.muted,
    hint: DiscordPalette.hint,
    onAccent: Colors.white,
  );

  static DiscordUiColors of(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    return DiscordUiColors(
      background: palette.background,
      panel: palette.card,
      card: palette.input,
      accent: palette.accent,
      border: palette.border,
      text: palette.primaryText,
      muted: palette.secondaryText,
      hint: palette.secondaryText,
      onAccent: palette.accentText,
    );
  }
}

class DiscordDialog extends StatelessWidget {
  const DiscordDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.content,
    this.actions = const [],
    this.scrollable = true,
    this.maxWidth = 560,
  });

  final Widget title;
  final String? subtitle;
  final Widget content;
  final List<Widget> actions;
  final bool scrollable;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = DiscordUiColors.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border.withValues(alpha: 0.55)),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DefaultTextStyle.merge(
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                child: title,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              Flexible(
                fit: FlexFit.loose,
                child: scrollable
                    ? SingleChildScrollView(child: content)
                    : content,
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DiscordCheckbox extends StatelessWidget {
  const DiscordCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = DiscordUiColors.of(context);
    return Semantics(
      checked: value,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: value ? colors.accent : colors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: value ? colors.accent : colors.border),
          ),
          alignment: Alignment.center,
          child: value
              ? Icon(Icons.check_rounded, color: colors.onAccent, size: 14)
              : null,
        ),
      ),
    );
  }
}

class DiscordSwitch extends StatelessWidget {
  const DiscordSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = DiscordUiColors.of(context);
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          width: 40,
          height: 22,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? colors.accent : colors.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DiscordChoiceTile extends StatelessWidget {
  const DiscordChoiceTile({
    super.key,
    required this.selected,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final Widget title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DiscordUiColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: colors.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.accent : colors.border,
                  width: selected ? 5 : 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GlideSelect(selected: selected, child: title),
            ),
          ],
        ),
      ),
    );
  }
}
