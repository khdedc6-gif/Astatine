import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astatine_dashboard/features/dashboard/achievement_center.dart';

void main() {
  group('LeaderboardUser tests', () {
    test('LeaderboardUser.fromMap parses correctly', () {
      final map = {
        'user_id': 'user-123',
        'full_name': 'Test User',
        'coin': 1500,
        'avatar_url': 'https://example.com/avatar.png',
      };

      final user = LeaderboardUser.fromMap(map);
      expect(user.userId, 'user-123');
      expect(user.fullName, 'Test User');
      expect(user.coin, 1500);
      expect(user.avatarUrl, 'https://example.com/avatar.png');
    });

    test('LeaderboardUser.fromMap handles string coin and missing fields', () {
      final map = {
        'coin': '2500',
      };

      final user = LeaderboardUser.fromMap(map);
      expect(user.userId, '');
      expect(user.fullName, 'Thành viên Astatine');
      expect(user.coin, 2500);
      expect(user.avatarUrl, null);
    });
  });

  group('AchievementCenterScreen widget tests', () {
    testWidgets('AchievementCenterScreen renders in Vietnamese mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AchievementCenterScreen(isVietnamese: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRUNG TÂM THÀNH TỰU & VINH DANH'), findsOneWidget);
      expect(find.text('Mốc Thành Tựu'), findsOneWidget);
      expect(find.text('Bảng Xếp Hạng COIN'), findsOneWidget);
    });

    testWidgets('AchievementCenterScreen renders in English mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AchievementCenterScreen(isVietnamese: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACHIEVEMENTS & LEADERBOARD CENTER'), findsOneWidget);
      expect(find.text('Milestones'), findsOneWidget);
      expect(find.text('COIN Leaderboard'), findsOneWidget);
    });
  });
}

