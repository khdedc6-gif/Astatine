import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/features/profile/user_profile_avatar.dart';

void main() {
  testWidgets('profile avatar fallback uses the active theme accent', (
    tester,
  ) async {
    const palette = AstatinePalette.campus;
    await tester.pumpWidget(
      MaterialApp(
        theme: AstatinePalette.themeData('Campus'),
        home: const Scaffold(
          body: UserProfileAvatar(userId: null, radius: 20, fallbackText: 'A'),
        ),
      ),
    );

    final fallback = tester.widget<Text>(find.text('A'));
    expect(fallback.style?.color, palette.accent);
  });
}
