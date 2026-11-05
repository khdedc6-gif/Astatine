import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:astatine_dashboard/features/dashboard/achievement_center.dart';

bool _failLeaderboardRequest = false;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/get_coin_leaderboard')) {
          if (_failLeaderboardRequest) {
            return http.Response(
              jsonEncode({'message': 'Test request failure'}),
              500,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            jsonEncode([
              {'user_id': 'student-1', 'full_name': 'An Nguyễn', 'coin': 48500},
              {'user_id': 'student-2', 'full_name': 'Minh Tuệ', 'coin': 42100},
              {
                'user_id': 'student-3',
                'full_name': 'Hương Giang',
                'coin': 39800,
              },
              {'user_id': 'student-4', 'full_name': 'Lan Trần', 'coin': 31200},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });

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
      final map = {'coin': '2500'};

      final user = LeaderboardUser.fromMap(map);
      expect(user.userId, '');
      expect(user.fullName, 'Thành viên Astatine');
      expect(user.coin, 2500);
      expect(user.avatarUrl, null);
    });
  });

  group('AchievementCenterScreen widget tests', () {
    testWidgets('hardcoded achievement progress starts at zero', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AchievementCenterScreen(isVietnamese: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0%'), findsNWidgets(15));
      expect(find.text('100%'), findsNothing);
    });

    testWidgets('COIN leaderboard shows a retry state instead of fake ranks', (
      WidgetTester tester,
    ) async {
      _failLeaderboardRequest = true;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AchievementCenterScreen(isVietnamese: true)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bảng Xếp Hạng COIN'));
      await tester.pumpAndSettle();

      expect(find.text('Bảng xếp hạng chưa tải được'), findsOneWidget);
      expect(find.text('Alex Nguyen'), findsNothing);
      expect(find.text('Tải lại'), findsOneWidget);
      _failLeaderboardRequest = false;
    });

    testWidgets('COIN leaderboard presents live rankings in the new layout', (
      WidgetTester tester,
    ) async {
      _failLeaderboardRequest = false;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AchievementCenterScreen(isVietnamese: true)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bảng Xếp Hạng COIN'));
      await tester.pumpAndSettle();

      expect(find.text('ĐƯỜNG ĐUA COIN'), findsOneWidget);
      expect(find.text('DẪN ĐẦU BẢNG XẾP HẠNG'), findsOneWidget);
      expect(find.text('An Nguyễn'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Lan Trần'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Lan Trần'), findsOneWidget);
      expect(find.text('48.500'), findsOneWidget);
    });

    testWidgets('AchievementCenterScreen renders in Vietnamese mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AchievementCenterScreen(isVietnamese: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('THÀNH TỰU & XẾP HẠNG'), findsOneWidget);
      expect(find.text('Mốc Thành Tựu'), findsOneWidget);
      expect(find.text('Bảng Xếp Hạng COIN'), findsOneWidget);
    });

    testWidgets('AchievementCenterScreen renders in English mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AchievementCenterScreen(isVietnamese: false)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACHIEVEMENTS & LEADERBOARD CENTER'), findsOneWidget);
      expect(find.text('Milestones'), findsOneWidget);
      expect(find.text('COIN Leaderboard'), findsOneWidget);
    });
  });
}
