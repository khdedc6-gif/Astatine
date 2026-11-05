import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AstatinePalette extends ThemeExtension<AstatinePalette> {
  const AstatinePalette({
    required this.background,
    required this.card,
    required this.input,
    required this.border,
    required this.accent,
    required this.accentText,
    required this.primaryText,
    required this.secondaryText,
    required this.canvasText,
    required this.canvasMutedText,
    required this.cream,
    required this.glowEnabled,
  });

  final Color background;
  final Color card;
  final Color input;
  final Color border;
  final Color accent;
  final Color accentText;
  final Color primaryText;
  final Color secondaryText;
  final Color canvasText;
  final Color canvasMutedText;
  final Color cream;
  final bool glowEnabled;

  static const dark = AstatinePalette(
    background: Color(0xFF09090B),
    card: Color(0xFF18181B),
    input: Color(0xFF27272A),
    border: Color(0xFF27272A),
    accent: Color(0xFFFAFAFA),
    accentText: Color(0xFF000000),
    primaryText: Color(0xFFFAFAFA),
    secondaryText: Color(0xFFA1A1AA),
    canvasText: Color(0xFFFAFAFA),
    canvasMutedText: Color(0xFFA1A1AA),
    cream: Color(0xFFF4EBDD),
    glowEnabled: false,
  );

  static const neon = AstatinePalette(
    background: Color(0xFF080D16),
    card: Color(0xCC111827),
    input: Color(0xFF0B1420),
    border: Color(0xFF20364A),
    accent: Color(0xFF41E7F5),
    accentText: Color(0xFF06131C),
    primaryText: Color(0xFFEAF8FF),
    secondaryText: Color(0xFF91A9BD),
    canvasText: Color(0xFFEAF8FF),
    canvasMutedText: Color(0xFF91A9BD),
    cream: Color(0xFFF4EBDD),
    glowEnabled: true,
  );

  static const matcha = AstatinePalette(
    background: Color(0xFF6B9750),
    card: Color(0xFFE8E7D9),
    input: Color(0xFFF3F0E5),
    border: Color(0xFFBECBB8),
    accent: Color(0xFF256D3D),
    accentText: Color(0xFFFFFFFF),
    primaryText: Color(0xFF26352B),
    secondaryText: Color(0xFF5C6C5D),
    canvasText: Color(0xFF20331D),
    canvasMutedText: Color(0xFF385334),
    cream: Color(0xFFF2EBDD),
    glowEnabled: false,
  );

  static const pink = AstatinePalette(
    background: Color(0xFF281726),
    card: Color(0xFF392339),
    input: Color(0xFF21131F),
    border: Color(0xFF704363),
    accent: Color(0xFFFF65A3),
    accentText: Color(0xFF2B1020),
    primaryText: Color(0xFFFFF1F7),
    secondaryText: Color(0xFFD3B4C7),
    canvasText: Color(0xFFFFF1F7),
    canvasMutedText: Color(0xFFD3B4C7),
    cream: Color(0xFFF5E8DF),
    glowEnabled: true,
  );

  static const light = AstatinePalette(
    background: Color(0xFFF4F6F8),
    card: Color(0xFFFFFFFF),
    input: Color(0xFFE9EEF4),
    border: Color(0xFFCAD5E2),
    accent: Color(0xFF0066FF),
    accentText: Color(0xFFFFFFFF),
    primaryText: Color(0xFF182230),
    secondaryText: Color(0xFF5E6B7A),
    canvasText: Color(0xFF182230),
    canvasMutedText: Color(0xFF5E6B7A),
    cream: Color(0xFFF4EBDD),
    glowEnabled: false,
  );

  static const campus = AstatinePalette(
    background: Color(0xFFEEF2FF),
    card: Color(0xFFFFFFFF),
    input: Color(0xFFEBEEF8),
    border: Color(0xFFC7D2FE),
    accent: Color(0xFF4F46E5),
    accentText: Color(0xFFFFFFFF),
    primaryText: Color(0xFF1E1B4B),
    secondaryText: Color(0xFF475569),
    canvasText: Color(0xFF1E1B4B),
    canvasMutedText: Color(0xFF475569),
    cream: Color(0xFFFFF7E7),
    glowEnabled: false,
  );

  static const brown = AstatinePalette(
    background: Color(0xFF1E1410),
    card: Color(0xFFF0E2D0),
    input: Color(0xFFFAF1E5),
    border: Color(0xFFD5B99C),
    accent: Color(0xFFA64F1E),
    accentText: Color(0xFFFFFFFF),
    primaryText: Color(0xFF39251A),
    secondaryText: Color(0xFF765E4A),
    canvasText: Color(0xFFFFF2E4),
    canvasMutedText: Color(0xFFDFC9B2),
    cream: Color(0xFFF5E6D4),
    glowEnabled: false,
  );

  static const themeNames = [
    'Campus',
    'Dark',
    'Neon',
    'Matcha Latte',
    'Pink',
    'Light',
    'Brown',
  ];

  static AstatinePalette forName(String name) => switch (name) {
    'Campus' => campus,
    'Neon' => neon,
    'Matcha Latte' => matcha,
    'Pink' => pink,
    'Light' => light,
    'Brown' => brown,
    _ => dark,
  };

  static ThemeData themeData(String name) {
    final palette = forName(name);
    final isMonochromeDark = name == 'Dark';
    final isCampus = name == 'Campus';
    final interactiveSurface = isMonochromeDark
        ? const Color(0xFF3F3F46)
        : palette.accent.withValues(alpha: 0.12);
    final errorColor = isMonochromeDark
        ? palette.secondaryText
        : const Color(0xFFFF7285);
    final brightness = name == 'Light' || isCampus
        ? Brightness.light
        : Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: palette.accent,
          brightness: brightness,
          surface: palette.background,
        ).copyWith(
          primary: palette.accent,
          onPrimary: palette.accentText,
          primaryContainer: isMonochromeDark ? palette.card : null,
          onPrimaryContainer: isMonochromeDark ? palette.primaryText : null,
          secondary: palette.accent,
          onSecondary: palette.accentText,
          secondaryContainer: isMonochromeDark ? interactiveSurface : null,
          onSecondaryContainer: isMonochromeDark ? palette.primaryText : null,
          surface: palette.background,
          onSurface: palette.canvasText,
          onSurfaceVariant: palette.secondaryText,
          outline: palette.border,
          error: errorColor,
          onError: isMonochromeDark ? palette.accentText : null,
        );
    final interFamily = GoogleFonts.inter().fontFamily;
    final bodyFamily = isCampus ? 'Comic Neue' : interFamily;
    final orbitronFamily = GoogleFonts.orbitron().fontFamily;
    final headingFamily = isCampus ? 'Baloo 2' : orbitronFamily;
    final rajdhaniFamily = GoogleFonts.rajdhani().fontFamily;
    final firaCodeFamily = GoogleFonts.firaCode().fontFamily;
    final baseTextTheme = ThemeData(brightness: brightness).textTheme.apply(
      fontFamily: bodyFamily,
      bodyColor: palette.primaryText,
      displayColor: palette.canvasText,
    );
    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontFamily: headingFamily,
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: palette.canvasText,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontFamily: headingFamily,
        fontSize: 45,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: palette.canvasText,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontFamily: headingFamily,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: palette.canvasText,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontFamily: headingFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: palette.canvasText,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontFamily: headingFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: palette.canvasText,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontFamily: headingFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: palette.canvasText,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontFamily: isCampus ? headingFamily : rajdhaniFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: palette.primaryText,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontFamily: isCampus ? headingFamily : rajdhaniFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: palette.primaryText,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontFamily: firaCodeFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: palette.secondaryText,
      ),
    );
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      brightness: brightness,
      colorScheme: colorScheme,
      splashColor: palette.accent.withValues(alpha: 0.24),
      highlightColor: palette.accent.withValues(alpha: 0.12),
      hoverColor: interactiveSurface,
      textTheme: textTheme,
      fontFamily: bodyFamily,
      primaryColor: palette.accent,
      scaffoldBackgroundColor: palette.background,
      cardColor: palette.card,
      dividerColor: palette.border,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.canvasText,
        surfaceTintColor: Colors.transparent,
        shape: isMonochromeDark
            ? Border(bottom: BorderSide(color: palette.border))
            : null,
        titleTextStyle: TextStyle(
          fontFamily: headingFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: palette.canvasText,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: isMonochromeDark || isCampus ? 2 : 0,
        shadowColor: isMonochromeDark
            ? Colors.black.withValues(alpha: 0.3)
            : palette.accent.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isMonochromeDark
                ? palette.border
                : palette.border.withValues(alpha: 0.75),
            width: isCampus ? 2 : 1,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.card,
        indicatorColor: isMonochromeDark
            ? interactiveSurface
            : palette.accent.withValues(alpha: 0.18),
        selectedIconTheme: IconThemeData(color: palette.accent),
        unselectedIconTheme: IconThemeData(color: palette.secondaryText),
        selectedLabelTextStyle: TextStyle(color: palette.primaryText),
        unselectedLabelTextStyle: TextStyle(color: palette.secondaryText),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: palette.card,
        indicatorColor: isMonochromeDark
            ? interactiveSurface
            : palette.accent.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.accent
                : palette.secondaryText,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? palette.primaryText
                : palette.secondaryText,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: isMonochromeDark ? 16 : null,
        shadowColor: isMonochromeDark
            ? Colors.black.withValues(alpha: 0.38)
            : null,
        titleTextStyle: TextStyle(
          fontFamily: interFamily,
          color: palette.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          fontFamily: interFamily,
          color: palette.primaryText,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border.withValues(alpha: 0.8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.input,
        hintStyle: TextStyle(color: palette.secondaryText),
        labelStyle: TextStyle(color: palette.secondaryText),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isMonochromeDark
                ? palette.border
                : palette.border.withValues(alpha: 0.8),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isMonochromeDark
                ? palette.border
                : palette.border.withValues(alpha: 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.accentText,
              disabledBackgroundColor: palette.border,
              disabledForegroundColor: palette.secondaryText,
              elevation: 0,
              shadowColor: palette.accent.withValues(alpha: 0.42),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: TextStyle(
                fontFamily: interFamily,
                fontWeight: FontWeight.w700,
              ),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (!isMonochromeDark) return palette.accent;
                if (states.contains(WidgetState.disabled)) {
                  return palette.border;
                }
                if (states.contains(WidgetState.pressed)) {
                  return const Color(0xFFD4D4D8);
                }
                if (states.contains(WidgetState.hovered)) {
                  return const Color(0xFFE4E4E7);
                }
                return palette.accent;
              }),
              elevation: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.hovered) ? 4 : 0,
              ),
              shadowColor: WidgetStatePropertyAll(
                palette.accent.withValues(alpha: 0.35),
              ),
            ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.accentText,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: TextStyle(
                fontFamily: interFamily,
                fontWeight: FontWeight.w700,
              ),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (!isMonochromeDark) return palette.accent;
                if (states.contains(WidgetState.disabled)) {
                  return palette.border;
                }
                if (states.contains(WidgetState.pressed)) {
                  return const Color(0xFFD4D4D8);
                }
                if (states.contains(WidgetState.hovered)) {
                  return const Color(0xFFE4E4E7);
                }
                return palette.accent;
              }),
              overlayColor: WidgetStatePropertyAll(
                isMonochromeDark
                    ? const Color(0xFF3F3F46).withValues(alpha: 0.12)
                    : palette.accent.withValues(alpha: 0.12),
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primaryText,
          backgroundColor: Colors.transparent,
          overlayColor: isMonochromeDark
              ? interactiveSurface.withValues(alpha: 0.45)
              : palette.accent.withValues(alpha: 0.12),
          side: BorderSide(color: palette.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          overlayColor: isMonochromeDark
              ? interactiveSurface.withValues(alpha: 0.35)
              : palette.accent.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.secondaryText,
        textColor: palette.primaryText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.card,
        selectedColor: isMonochromeDark
            ? interactiveSurface
            : palette.accent.withValues(alpha: 0.26),
        checkmarkColor: isMonochromeDark
            ? palette.primaryText
            : palette.accentText,
        side: BorderSide(color: palette.border.withValues(alpha: 0.8)),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: palette.primaryText),
        secondaryLabelStyle: TextStyle(color: palette.accent),
      ),
      tabBarTheme: TabBarThemeData(
        indicator: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: palette.primaryText,
        unselectedLabelColor: palette.secondaryText,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return palette.accent.withValues(alpha: 0.24);
          }
          if (states.contains(WidgetState.hovered)) {
            return palette.accent.withValues(alpha: 0.12);
          }
          return null;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.card,
        indicatorColor: isMonochromeDark
            ? interactiveSurface
            : palette.accent.withValues(alpha: 0.18),
        elevation: isMonochromeDark ? 2 : 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.accent
                : palette.secondaryText,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? palette.primaryText
                : palette.secondaryText,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? palette.secondaryText.withValues(alpha: 0.55)
                : states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.pressed) ||
                      states.contains(WidgetState.focused)
                ? palette.primaryText
                : palette.secondaryText,
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return interactiveSurface.withValues(alpha: 0.7);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return interactiveSurface.withValues(alpha: 0.45);
            }
            return null;
          }),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? palette.primaryText
                : palette.secondaryText,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? palette.accent.withValues(alpha: 0.22)
                : palette.card,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? palette.accent.withValues(alpha: 0.72)
                  : palette.border,
            ),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return palette.accent.withValues(alpha: 0.24);
            }
            if (states.contains(WidgetState.hovered)) {
              return palette.accent.withValues(alpha: 0.12);
            }
            return null;
          }),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border.withValues(alpha: 0.65),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.border.withValues(alpha: 0.5),
        circularTrackColor: palette.border.withValues(alpha: 0.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.card,
        contentTextStyle: TextStyle(color: palette.primaryText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : palette.secondaryText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent.withValues(alpha: 0.42)
              : palette.border,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.accent,
        thumbColor: palette.accent,
        inactiveTrackColor: palette.border,
        overlayColor: palette.glowEnabled
            ? palette.accent.withValues(alpha: 0.15)
            : palette.accent.withValues(alpha: 0.08),
      ),
    );
  }

  @override
  AstatinePalette copyWith({
    Color? background,
    Color? card,
    Color? input,
    Color? border,
    Color? accent,
    Color? accentText,
    Color? primaryText,
    Color? secondaryText,
    Color? canvasText,
    Color? canvasMutedText,
    Color? cream,
    bool? glowEnabled,
  }) => AstatinePalette(
    background: background ?? this.background,
    card: card ?? this.card,
    input: input ?? this.input,
    border: border ?? this.border,
    accent: accent ?? this.accent,
    accentText: accentText ?? this.accentText,
    primaryText: primaryText ?? this.primaryText,
    secondaryText: secondaryText ?? this.secondaryText,
    canvasText: canvasText ?? this.canvasText,
    canvasMutedText: canvasMutedText ?? this.canvasMutedText,
    cream: cream ?? this.cream,
    glowEnabled: glowEnabled ?? this.glowEnabled,
  );

  @override
  AstatinePalette lerp(ThemeExtension<AstatinePalette>? other, double t) {
    if (other is! AstatinePalette) return this;
    return AstatinePalette(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      input: Color.lerp(input, other.input, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      canvasText: Color.lerp(canvasText, other.canvasText, t)!,
      canvasMutedText: Color.lerp(canvasMutedText, other.canvasMutedText, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      glowEnabled: t < 0.5 ? glowEnabled : other.glowEnabled,
    );
  }
}
