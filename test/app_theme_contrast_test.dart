import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/features/profile/student_profile_settings.dart';

void main() {
  testWidgets('Neon theme is selectable only for Pro and Ultra accounts', (
    tester,
  ) async {
    Future<List<String?>> themeOptionsFor(String tier) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AstatinePalette.themeData('Dark'),
          home: Scaffold(
            body: StudentProfileSettingsScreen(
              isVietnamese: true,
              subscriptionTier: tier,
              selectedTheme: 'Dark',
              onLanguageChanged: (_) {},
              onThemeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      return tester
          .widget<DropdownButton<String>>(
            find.byType(DropdownButton<String>).first,
          )
          .items!
          .map((item) => item.value)
          .toList();
    }

    expect(await themeOptionsFor('PRO'), contains('Neon'));
    expect(await themeOptionsFor('ULTRA'), contains('Neon'));
    expect(await themeOptionsFor('FREE'), isNot(contains('Neon')));
  });

  test('Dark uses a monochrome palette and white primary actions', () {
    final palette = AstatinePalette.dark;
    final theme = AstatinePalette.themeData('Dark');
    final elevatedStyle = theme.elevatedButtonTheme.style!;
    final filledStyle = theme.filledButtonTheme.style!;
    final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
    final inputBorder =
        theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;

    expect(palette.background, const Color(0xFF09090B));
    expect(palette.card, const Color(0xFF18181B));
    expect(palette.input, const Color(0xFF27272A));
    expect(palette.border, const Color(0xFF27272A));
    expect(palette.accent, const Color(0xFFFAFAFA));
    expect(palette.accentText, const Color(0xFF000000));
    expect(palette.primaryText, const Color(0xFFFAFAFA));
    expect(palette.secondaryText, const Color(0xFFA1A1AA));
    expect(theme.colorScheme.error, palette.secondaryText);
    expect(theme.cardTheme.elevation, greaterThan(0));
    expect(cardShape.side.color, palette.border);
    expect(inputBorder.borderSide.color, palette.border);
    expect(theme.appBarTheme.shape, isA<Border>());
    expect(theme.hoverColor, const Color(0xFF3F3F46));
    expect(elevatedStyle.backgroundColor!.resolve({}), const Color(0xFFFAFAFA));
    expect(elevatedStyle.foregroundColor!.resolve({}), const Color(0xFF000000));
    expect(
      elevatedStyle.backgroundColor!.resolve({WidgetState.hovered}),
      const Color(0xFFE4E4E7),
    );
    expect(filledStyle.backgroundColor!.resolve({}), palette.accent);
    expect(AstatinePalette.dark.glowEnabled, isFalse);
    expect(AstatinePalette.neon.background, const Color(0xFF080D16));
    expect(AstatinePalette.neon.accent, const Color(0xFF41E7F5));
    expect(AstatinePalette.neon.glowEnabled, isTrue);
    expect(AstatinePalette.forName('Neon'), AstatinePalette.neon);
  });

  test(
    'Matcha and Brown action colors remain distinguishable on light cards',
    () {
      for (final entry in {
        'Matcha Latte': AstatinePalette.matcha,
        'Brown': AstatinePalette.brown,
      }.entries) {
        final theme = AstatinePalette.themeData(entry.key);
        final palette = entry.value;

        expect(
          _contrastRatio(palette.accent, palette.accentText),
          greaterThan(4.5),
        );
        expect(theme.textTheme.bodyMedium?.color, palette.primaryText);
        expect(theme.textTheme.titleMedium?.color, palette.primaryText);
        expect(theme.listTileTheme.textColor, palette.primaryText);
        expect(theme.dialogTheme.contentTextStyle?.color, palette.primaryText);
        expect(
          theme.elevatedButtonTheme.style?.foregroundColor?.resolve({}),
          palette.accentText,
        );
      }
    },
  );

  test(
    'Campus theme follows the education design tokens with readable text',
    () {
      final theme = AstatinePalette.themeData('Campus');
      final palette = AstatinePalette.campus;

      expect(theme.brightness, Brightness.light);
      expect(palette.background, const Color(0xFFEEF2FF));
      expect(palette.accent, const Color(0xFF4F46E5));
      expect(
        _contrastRatio(palette.primaryText, palette.background),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(palette.secondaryText, palette.background),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(palette.accentText, palette.accent),
        greaterThan(4.5),
      );
      expect(AstatinePalette.themeNames, contains('Campus'));
      expect(theme.cardTheme.elevation, greaterThan(0));
    },
  );

  test(
    'selection controls use rounded animated indicators and visible ripples',
    () {
      final theme = AstatinePalette.themeData('Matcha Latte');
      final tabIndicator = theme.tabBarTheme.indicator! as BoxDecoration;
      final inputBorder =
          theme.inputDecorationTheme.border! as OutlineInputBorder;
      final segmentedStyle = theme.segmentedButtonTheme.style!;

      expect(theme.chipTheme.shape, isA<StadiumBorder>());
      expect(tabIndicator.borderRadius, BorderRadius.circular(999));
      expect(inputBorder.borderRadius, BorderRadius.circular(16));
      expect(segmentedStyle.shape!.resolve({}), isA<StadiumBorder>());
      expect(
        segmentedStyle.overlayColor!.resolve({WidgetState.pressed})!.a,
        greaterThan(0.2),
      );
      expect(
        theme.tabBarTheme.overlayColor!.resolve({WidgetState.pressed})!.a,
        greaterThan(0.2),
      );
    },
  );
}

double _contrastRatio(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}
