// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:ui' show PointerDeviceKind;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/core/ui/ui_motion.dart';
import 'package:astatine_dashboard/features/auth/authentication.dart';
import 'package:astatine_dashboard/features/classroom/classroom_chat.dart';
import 'package:astatine_dashboard/features/classroom/dashboard_columns.dart';
import 'package:astatine_dashboard/features/community/study_group.dart';
import 'package:astatine_dashboard/features/community/study_group_repository.dart';
import 'package:astatine_dashboard/features/chemistry/virtual_lab.dart';
import 'package:astatine_dashboard/main.dart';
import 'package:astatine_dashboard/features/dashboard/main_dashboard.dart';
import 'package:astatine_dashboard/core/ui/search_bar.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://yjfcmixhjqcfpbigmgps.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlqZmNtaXhoanFjZnBiaWdtZ3BzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA4NjE1MzIsImV4cCI6MjEwNjQzNzUzMn0.w0uQ_HhEZCvI5YvbVM3l_RrfE2LV392QkZfLVgCVaaw',
      );
    } catch (_) {}
  });

  testWidgets('classroom switcher follows the selected language', (
    tester,
  ) async {
    Widget buildSwitcher(bool isVietnamese) => MaterialApp(
      home: Scaffold(
        body: TopBarClassroomSwitcher(
          currentUserId: 'user-1',
          memberships: const [],
          selectedClassroomId: null,
          isVietnamese: isVietnamese,
          onSelect: (_) {},
          onAdd: () {},
        ),
      ),
    );

    await tester.pumpWidget(buildSwitcher(true));
    expect(find.text('Lớp học'), findsOneWidget);
    expect(find.text('Chưa tham gia lớp nào'), findsOneWidget);

    await tester.pumpWidget(buildSwitcher(false));
    expect(find.text('Classrooms'), findsOneWidget);
    expect(find.text('No classes'), findsOneWidget);
  });

  testWidgets('dashboard cards follow the selected language', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    expect(
      find.byKey(const Key('subscription-styled-user-name')),
      findsOneWidget,
    );
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Bài tập & Trắc nghiệm'), findsOneWidget);

    await tester.tap(find.text('EN').last);
    await tester.pumpAndSettle();
    expect(find.text('Other apps'), findsOneWidget);
    expect(find.text('Assignments & Quiz'), findsOneWidget);
  });

  testWidgets('subscription account opens pricing plans with tier theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    expect(find.text('AST FREE ACCOUNT'), findsOneWidget);
    await tester.tap(find.byKey(const Key('subscription-account-pricing')));
    await tester.pumpAndSettle();

    expect(find.text('Chọn gói Astatine'), findsOneWidget);
    expect(find.text('FREE'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('ULTRA'), findsOneWidget);
    expect(find.text('Phổ biến nhất'), findsOneWidget);
    expect(find.text('490 AST'), findsOneWidget);
    expect(find.text('1190 AST'), findsOneWidget);
    expect(find.text('Dùng miễn phí'), findsOneWidget);
    expect(find.text('Nâng cấp PRO'), findsOneWidget);
    expect(find.text('Nâng cấp ULTRA'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('PRO').first).style?.color,
      const Color(0xFFBB65E7),
    );
    expect(
      tester.widget<Text>(find.text('ULTRA').first).style?.color,
      const Color(0xFFFFC400),
    );
  });

  testWidgets('pricing plans scroll without overflow on a short narrow view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    await tester.tap(find.byKey(const Key('subscription-account-pricing')));
    await tester.pumpAndSettle();

    expect(find.text('Chọn gói Astatine'), findsOneWidget);
    expect(find.text('FREE'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('ULTRA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch input clears the custom mouse cursor', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BlueCursorOverlay(child: SizedBox.expand())),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(50, 50));
    await mouse.moveTo(const Offset(60, 60));
    await tester.pump();
    expect(find.byKey(const Key('app-blue-cursor')), findsOneWidget);

    final touch = await tester.startGesture(
      const Offset(70, 70),
      kind: PointerDeviceKind.touch,
    );
    await touch.up();
    await tester.pump();
    expect(find.byKey(const Key('app-blue-cursor')), findsNothing);

    await mouse.moveTo(const Offset(80, 80));
    await tester.pump();
    expect(find.byKey(const Key('app-blue-cursor')), findsNothing);
    await mouse.removePointer();

    await tester.pump(const Duration(milliseconds: 601));
    final returnedMouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await returnedMouse.addPointer(location: const Offset(90, 90));
    await returnedMouse.moveTo(const Offset(100, 100));
    await tester.pump();
    expect(find.byKey(const Key('app-blue-cursor')), findsOneWidget);
    await returnedMouse.removePointer();
  });

  testWidgets('left-edge swipes keep the dashboard navigation visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));

    final touch = await tester.startGesture(
      const Offset(4, 150),
      kind: PointerDeviceKind.touch,
    );
    await touch.moveBy(const Offset(80, 0));
    await touch.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('focus-navigation-panel'))).dx,
      0,
    );
    expect(
      find.byKey(const Key('dashboard-fullscreen-toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('focus-mode-toggle')), findsNothing);
  });

  testWidgets('dashboard app loads the main screen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await _signIn(tester);

    expect(find.text('Astatine'), findsOneWidget);
    expect(find.text('Studio'), findsNothing);
    expect(find.text('Chào mừng trở lại, User!'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-quick-start')), findsOneWidget);
    expect(find.text('BẮT ĐẦU NHANH'), findsOneWidget);
  });

  testWidgets('Assignments shows database empty states without seeded data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    await tester.tap(find.text('Bài tập').last);
    await tester.pumpAndSettle();

    expect(find.text('Bài tập của bạn'), findsOneWidget);
    expect(find.text('Chat với Giáo Viên'), findsNothing);
    expect(find.text('Nhiệm vụ hôm nay'), findsNothing);
    expect(find.text('Hiện tại chưa có bài tập nào.'), findsOneWidget);
    expect(find.byKey(const Key('daily-activity-progress')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('daily-activity-progress'))).height,
      lessThan(60),
    );
    expect(find.text('Balanced Equations'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Assignments fills the narrow view without chat overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    await tester.tap(find.text('Bài tập').last);
    await tester.pumpAndSettle();

    expect(find.text('Bài tập của bạn'), findsOneWidget);
    expect(find.text('Chat với Giáo Viên'), findsNothing);
    expect(find.text('Nhiệm vụ hôm nay'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating Gemini is hidden in Settings', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    expect(find.byKey(const Key('floating-gemini-bubble')), findsOneWidget);
    await tester.tap(find.text('Cài đặt').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('floating-gemini-bubble')), findsNothing);
  });

  testWidgets('sidebar opens Achievements and Market pages', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));

    final achievementsPosition = tester.getCenter(find.text('Thành tựu').last);
    final marketPosition = tester.getCenter(find.text('Chợ').last);
    final settingsPosition = tester.getCenter(find.text('Cài đặt').last);
    expect(achievementsPosition.dy, lessThan(marketPosition.dy));
    expect(marketPosition.dy, lessThan(settingsPosition.dy));
    expect(find.byKey(const Key('left-navigation-scrollbar')), findsNothing);

    await tester.tap(find.text('Thành tựu').last);
    await tester.pumpAndSettle();
    expect(find.text('Màn hình đang phát triển: "Thành tựu"'), findsOneWidget);

    await tester.tap(find.text('Chợ').last);
    await tester.pumpAndSettle();
    expect(find.text('Màn hình đang phát triển: "Chợ"'), findsOneWidget);
  });

  testWidgets('sidebar scrollbar appears only on a short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('left-navigation-scrollbar')), findsOneWidget);
    expect(
      tester
          .widget<Scrollbar>(find.byKey(const Key('left-navigation-scrollbar')))
          .thumbVisibility,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact dashboard keeps its rail and content in bounds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('focus-navigation-panel')), findsOneWidget);
    expect(find.byTooltip('Bài tập'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard fits the 1440 by 900 workspace viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop sidebar collapses to an interactive icon rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    await tester.pumpAndSettle();

    final sidebar = find.byKey(const Key('focus-navigation-panel'));
    expect(tester.getSize(sidebar).width, 260);

    await tester.tap(find.byKey(const Key('sidebar-collapse-toggle')));
    await tester.pumpAndSettle();

    expect(tester.getSize(sidebar).width, 88);
    expect(find.byKey(const Key('focus-mode-toggle')), findsNothing);
    expect(
      find.byKey(const Key('dashboard-fullscreen-toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('sidebar-profile-avatar')), findsOneWidget);
    expect(
      find.byKey(const Key('compact-subscription-account')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dashboard-nav-4')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('dashboard-nav-4')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('sidebar-collapse-toggle')));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 260);
  });

  testWidgets('dashboard cards reveal on scroll and nav indicator slides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    await tester.pumpAndSettle();

    final indicator = find.byKey(const Key('navigation-selection-indicator'));
    final initialIndicatorTop = tester
        .widget<AnimatedPositioned>(indicator)
        .top!;
    await tester.tap(find.byKey(const Key('dashboard-nav-4')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedPositioned>(indicator).top,
      closeTo(initialIndicatorTop + 52 * 4, 0.1),
    );

    await tester.tap(find.byKey(const Key('dashboard-nav-0')));
    await tester.pumpAndSettle();
    final lastCard = find.byType(BentoCard).last;
    final cardOpacity = find
        .ancestor(of: lastCard, matching: find.byType(Opacity))
        .first;
    final initialOpacity = tester.widget<Opacity>(cardOpacity).opacity;
    final initialCardTop = tester.getTopLeft(lastCard).dy;
    await tester.drag(
      find.byKey(const Key('dashboard-content-scroll')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(lastCard).dy, lessThan(initialCardTop));
    expect(
      tester.widget<Opacity>(cardOpacity).opacity,
      greaterThan(initialOpacity),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('classroom chat shell does not render seeded channels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ClassroomChatScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('#announcements'), findsNothing);
    expect(find.text('#general-chat'), findsNothing);
    expect(find.text('Member list'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings opens profile, changes language, and shows support', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await _signIn(
      tester,
      profileLoader: () async => const AuthUserProfile(
        displayName: 'Demo Student',
        email: 'demo@example.com',
        role: 'student',
      ),
    );
    await tester.tap(find.text('Cài đặt').last);
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ & Cài đặt'), findsOneWidget);
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('Hiển thị & Hiệu ứng'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-display-name'))).data,
      'Demo Student',
    );
    expect(find.text('demo@example.com'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-role'))).data,
      'Học sinh',
    );
    expect(find.text('Đoàn Nguyên Khánh'), findsNothing);

    final themeDropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>).first,
    );
    expect(themeDropdown.items!.map((item) => item.value).toList(), [
      'Campus',
      'Dark',
      'Matcha Latte',
      'Pink',
      'Light',
      'Brown',
    ]);
    expect(
      find.text('Giao diện Neon chỉ dành cho tài khoản Pro hoặc Ultra.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Tiếng Việt').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(find.text('Personal information'), findsOneWidget);
    expect(find.text('General & system'), findsOneWidget);

    await tester.tap(find.text('Campus').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matcha Latte').last);
    await tester.pumpAndSettle();
    final backgroundSwatch = tester.widget<Container>(
      find.byKey(const Key('theme-swatch-BG')),
    );
    final cardSwatch = tester.widget<Container>(
      find.byKey(const Key('theme-swatch-CARD')),
    );
    final glowSwatch = tester.widget<Container>(
      find.byKey(const Key('theme-swatch-GLOW')),
    );
    final textSwatch = tester.widget<Container>(
      find.byKey(const Key('theme-swatch-TEXT')),
    );
    expect(
      (backgroundSwatch.decoration! as BoxDecoration).color,
      const Color(0xFF6B9750),
    );
    expect(
      (cardSwatch.decoration! as BoxDecoration).color,
      const Color(0xFFE8E7D9),
    );
    expect(
      (glowSwatch.decoration! as BoxDecoration).color,
      const Color(0xFF256D3D),
    );
    expect(
      (textSwatch.decoration! as BoxDecoration).color,
      const Color(0xFF6B9750),
    );
    final matchaTheme = Theme.of(
      tester.element(find.byKey(const Key('theme-swatch-BG'))),
    );
    expect(matchaTheme.scaffoldBackgroundColor, const Color(0xFF6B9750));
    expect(matchaTheme.extension<AstatinePalette>()!.glowEnabled, isFalse);

    expect(AstatinePalette.brown.card, const Color(0xFFF0E2D0));
    expect(AstatinePalette.brown.accent, const Color(0xFFA64F1E));
    expect(AstatinePalette.brown.glowEnabled, isFalse);

    await tester.tap(find.text('Support & Report Issue'));
    await tester.pumpAndSettle();
    expect(find.text('Support & report'), findsOneWidget);
    expect(find.text('Describe the issue...'), findsOneWidget);
  });

  testWidgets('dashboard and sidebar open the 3D virtual lab', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await _signIn(tester);

    await tester.tap(find.text('Phòng thí nghiệm 3D').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-navigation-edge')), findsNothing);
    expect(
      find.text('Sự phụ thuộc của cường độ dòng điện vào hiệu điện thế'),
      findsOneWidget,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tổng quan'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-search')), findsOneWidget);
    await tester.tap(find.text('Phòng thí nghiệm'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-search')), findsNothing);
    expect(find.byKey(const Key('focus-navigation-edge')), findsNothing);
    expect(
      find.text('Sự phụ thuộc của cường độ dòng điện vào hiệu điện thế'),
      findsOneWidget,
    );
    await mouse.removePointer();
  });

  testWidgets('virtual lab expands lessons and searches relevant results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigations = <int>[];
    await tester.pumpWidget(
      MaterialApp(home: VirtualLabScreen(onNavigate: navigations.add)),
    );

    const hiddenLesson = 'Thấu kính hội tụ và cách tạo ảnh trên màn chắn';
    expect(find.text(hiddenLesson), findsNothing);
    await tester.enterText(find.byKey(const Key('virtual-lab-search')), 'a');
    await tester.pumpAndSettle();
    final results = find.byKey(const Key('lab-search-results'));
    expect(
      find.descendant(of: results, matching: find.byType(InkWell)),
      findsNWidgets(5),
    );

    await tester.enterText(
      find.byKey(const Key('virtual-lab-search')),
      'thau kinh hoi tu',
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: results,
        matching: find.byIcon(Icons.menu_book_outlined),
      ),
      findsAtLeastNWidgets(1),
    );
    await tester.tap(find.text(hiddenLesson));
    await tester.pumpAndSettle();
    expect(find.text(hiddenLesson), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('virtual-lab-search')),
      'classroom chat',
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: results,
        matching: find.byIcon(Icons.view_in_ar_outlined),
      ),
      findsAtLeastNWidgets(1),
    );
    await tester.tap(find.text('Classroom Chat'));
    await tester.pumpAndSettle();
    expect(navigations, [1]);
  });

  testWidgets('virtual lab opens a localized laboratory workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VirtualLabScreen(isVietnamese: true)),
    );

    await tester.tap(find.byKey(const Key('open-laboratory')));
    await tester.pumpAndSettle();
    expect(find.text('Phòng thí nghiệm'), findsOneWidget);
    expect(find.text('Phòng Vật lý'), findsNWidgets(2));

    await tester.pumpWidget(
      const MaterialApp(home: VirtualLabScreen(isVietnamese: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Laboratory'), findsOneWidget);
    expect(find.text('Physics Lab'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('laboratory-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-laboratory')), findsOneWidget);
  });

  testWidgets('search results overlay without moving following content', (
    tester,
  ) async {
    final items = [
      for (var index = 0; index < 6; index++)
        LabSearchItem(
          title: 'Lesson $index',
          subtitle: 'Physics',
          searchText: 'lesson physics $index',
          type: LabSearchItemType.lesson,
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LabSearchBar(items: items, onSelected: (_) {}),
              Container(
                key: const Key('content-below-search'),
                height: 100,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );

    final content = find.byKey(const Key('content-below-search'));
    final originalTop = tester.getTopLeft(content).dy;
    await tester.enterText(
      find.byKey(const Key('virtual-lab-search')),
      'lesson',
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(content).dy, originalTop);
    expect(
      find.descendant(
        of: find.byKey(const Key('lab-search-results')),
        matching: find.byType(InkWell),
      ),
      findsNWidgets(5),
    );
  });

  testWidgets('dashboard search opens Project Hub', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await _signIn(tester);

    final searchField = find.byKey(const Key('dashboard-search-input'));
    await tester.enterText(searchField, 'project hub');
    await tester.pumpAndSettle();

    final results = find.byKey(const Key('lab-search-results'));
    final projectHubResult = find.descendant(
      of: results,
      matching: find.text('Không gian dự án'),
    );
    expect(projectHubResult, findsOneWidget);
    await tester.tap(projectHubResult);
    await tester.pumpAndSettle();

    expect(find.text('Tạo nhóm học tập & dự án'), findsOneWidget);
  });

  testWidgets('dashboard search opens the matching Virtual Lab lesson', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await _signIn(tester);

    final searchField = find.byKey(const Key('dashboard-search-input'));
    await tester.enterText(searchField, 'thau kinh hoi tu');
    await tester.pumpAndSettle();

    const lesson = 'Thấu kính hội tụ và cách tạo ảnh trên màn chắn';
    final lessonResult = find.descendant(
      of: find.byKey(const Key('lab-search-results')),
      matching: find.text(lesson),
    );
    expect(lessonResult, findsOneWidget);
    await tester.tap(lessonResult);
    await tester.pumpAndSettle();

    expect(find.text(lesson), findsOneWidget);
    expect(find.text('Vật lý'), findsWidgets);
    expect(find.byKey(const Key('focus-navigation-edge')), findsNothing);
  });

  testWidgets('login rejects incorrect credentials', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(
      find.byKey(const Key('login-username')),
      'AstatineTest',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'wrong');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-error')), findsOneWidget);
    expect(find.text('Astatine'), findsOneWidget);
  });

  testWidgets('signup submits profile details and selected role', (
    tester,
  ) async {
    String? registeredEmail;
    String? registeredName;
    String? registeredRole;

    await tester.pumpWidget(
      MyApp(
        registrar:
            ({
              required email,
              required password,
              required fullName,
              required role,
            }) async {
              registeredEmail = email;
              registeredName = fullName;
              registeredRole = role;
              return null;
            },
      ),
    );
    await tester.tap(find.text('Mới dùng Astatine? Tạo tài khoản'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('signup-full-name')),
      'An Nguyen',
    );
    await tester.enterText(
      find.byKey(const Key('signup-email')),
      'an@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signup-password')),
      'secret123',
    );
    await tester.tap(find.byKey(const Key('signup-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giáo viên').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(registeredEmail, 'an@example.com');
    expect(registeredName, 'An Nguyen');
    expect(registeredRole, 'teacher');
    expect(
      find.text('Đăng ký thành công. Kiểm tra email để xác nhận tài khoản.'),
      findsOneWidget,
    );
  });

  testWidgets('app fullscreen control replaces the old focus mode icon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainLayoutScreen()));
    await tester.pumpAndSettle();

    final appName = find.text('Astatine');
    final systemName = find.text('LEARNING SYSTEM');
    expect(appName, findsOneWidget);
    expect(systemName, findsOneWidget);
    expect(
      find.byKey(const Key('dashboard-fullscreen-toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('focus-mode-toggle')), findsNothing);
    expect(
      tester.getCenter(find.byKey(const Key('dashboard-fullscreen-toggle'))).dx,
      lessThan(tester.getCenter(appName).dx),
    );
    expect(
      tester.getCenter(systemName).dy,
      greaterThan(tester.getCenter(appName).dy),
    );
    expect(find.byKey(const Key('dashboard-search')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('focus-navigation-panel'))).dx,
      0,
    );
  });

  testWidgets('login language toggle translates the form', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('ĐỊA CHỈ EMAIL'), findsOneWidget);
    expect(find.text('MẬT KHẨU'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('blue cursor appears while the mouse is over the app', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await _signIn(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(120, 120));
    await mouse.moveTo(const Offset(140, 140));
    await tester.pump();

    expect(find.byKey(const Key('app-blue-cursor')), findsOneWidget);

    await mouse.removePointer();
    await tester.pump();
    expect(find.byKey(const Key('app-blue-cursor')), findsNothing);
  });

  testWidgets('Project Hub opens the study group screen and returns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await _signIn(tester);
    await tester.ensureVisible(find.text('Không gian dự án'));
    await tester.tap(find.text('Không gian dự án'));
    await tester.pumpAndSettle();

    expect(find.text('Tạo nhóm học tập & dự án'), findsOneWidget);
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại, User!'), findsOneWidget);
  });

  testWidgets('study group form supports subjects, invitees, and assignees', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: CreateWorkspaceScreen(isVietnamese: true)),
    );

    expect(find.text('Chọn môn học'), findsOneWidget);
    expect(find.text('Nhập nội dung'), findsOneWidget);

    await tester.tap(find.byKey(const Key('subject-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lịch sử & Địa lí').last);
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử & Địa lí'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-invitee')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-option-B')));
    await tester.tap(find.text('Thêm thành viên đã chọn'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-chip-B')), findsOneWidget);

    await tester.tap(find.byKey(const Key('assignee-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();

    final contentFormat = find.byKey(const Key('content-format-dropdown'));
    await tester.tap(contentFormat);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ảnh').last);
    await tester.pumpAndSettle();
    expect(find.text('Ảnh'), findsOneWidget);

    await tester.tap(find.byTooltip('Tăng số lượng'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('quantity-input')))
          .controller
          ?.text,
      '2',
    );
    await tester.enterText(
      find.byKey(const Key('criteria-description-input')),
      'Đúng yêu cầu',
    );

    await tester.tap(find.byKey(const Key('deadline-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn hạn hoàn thành nhóm'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Tạo nhóm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('study group invitations use selected classroom members', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dataSource = _FakeStudyGroupDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CreateWorkspaceScreen(
          isVietnamese: true,
          currentUserName: 'Owner',
          currentUserId: 'owner-id',
          dataSource: dataSource,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addMembers = tester.widget<IconButton>(
      find.byKey(const Key('add-invitee')),
    );
    expect(addMembers.onPressed, isNull);

    await tester.tap(find.byKey(const Key('class-name-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10A').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(find.byKey(const Key('add-invitee'))).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('add-invitee')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('invite-member-search')), 'B');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-option-B')), findsOneWidget);
    expect(find.byKey(const Key('invite-option-A')), findsNothing);
    await tester.tap(find.byKey(const Key('invite-option-B')));
    await tester.tap(find.text('Thêm thành viên đã chọn'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('subject-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hóa học').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('topic-input')), 'Dự án nhóm');
    await tester.tap(find.byKey(const Key('assignee-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-description-input')),
      'Nhiệm vụ của B',
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo nhóm'));
    await tester.pumpAndSettle();
    expect(dataSource.createdGroupId, 'group-1');
    expect(dataSource.createdInviteeIds, ['invitee-id']);
    expect(dataSource.createdTasks.single['description'], 'Nhiệm vụ của B');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        home: CreateWorkspaceScreen(
          isVietnamese: true,
          currentUserName: 'B',
          currentUserId: 'invitee-id',
          dataSource: dataSource,
          filePicker: () async => [_TestPlatformFile('group-report.pdf')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lời mời'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-card-0')), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(dataSource.invitationStatus, 'accepted');
    expect(find.text('Dự án nhóm'), findsWidgets);
    expect(find.text('Nhiệm vụ của B'), findsWidgets);
    expect(find.byKey(const Key('accepted-project-list')), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Tải tệp lên'));
    await tester.pumpAndSettle();
    expect(dataSource.uploadedGroupFiles, hasLength(1));
    expect(find.text('group-report.pdf'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        home: CreateWorkspaceScreen(
          isVietnamese: true,
          currentUserName: 'Owner',
          currentUserId: 'owner-id',
          dataSource: dataSource,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chi tiết'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-card-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiến độ thành viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-progress-row-0-b')));
    await tester.pumpAndSettle();
    expect(find.text('group-report.pdf'), findsOneWidget);
    await tester.tap(find.byTooltip('Tải xuống'));
    await tester.pumpAndSettle();
    expect(dataSource.downloadCount, 1);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('study group keeps task descriptions per assignee', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: CreateWorkspaceScreen(isVietnamese: true)),
    );

    await tester.tap(find.byKey(const Key('add-invitee')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-option-A')));
    await tester.tap(find.byKey(const Key('invite-option-B')));
    await tester.tap(find.text('Thêm thành viên đã chọn'));
    await tester.pumpAndSettle();

    final descriptionField = find.byKey(const Key('task-description-input'));
    await tester.enterText(descriptionField, 'Nhiệm vụ của A');
    await tester.tap(find.byKey(const Key('content-format-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quantity-input')), '4');
    await tester.enterText(
      find.byKey(const Key('criteria-description-input')),
      'Tiêu chí của A',
    );

    Future<void> selectAssignee(String name) async {
      await tester.tap(find.byKey(const Key('assignee-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const Key('assignee-dropdown')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('assignee-option-A')),
        matching: find.byIcon(Icons.check),
      ),
      findsAtLeastNWidgets(1),
    );
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(descriptionField).controller!.text, '');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('quantity-input')))
          .controller
          ?.text,
      '1',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('criteria-description-input')),
          )
          .controller
          ?.text,
      '',
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('content-format-dropdown')),
          )
          .initialValue,
      isNull,
    );
    await tester.enterText(descriptionField, 'Nhiệm vụ của B');

    await selectAssignee('A');
    expect(
      tester.widget<TextField>(descriptionField).controller!.text,
      'Nhiệm vụ của A',
    );
    await selectAssignee('B');
    expect(
      tester.widget<TextField>(descriptionField).controller!.text,
      'Nhiệm vụ của B',
    );
  });

  testWidgets('invites create separate compact cards and scroll vertically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: CreateWorkspaceScreen(isVietnamese: true)),
    );

    await tester.tap(find.text('Lời mời'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có lời mời nào'), findsOneWidget);
    expect(find.byKey(const Key('invite-list')), findsNothing);
    expect(find.text('TASK ASSIGNMENT'), findsNothing);
    expect(find.text('WORKSPACE RULES'), findsNothing);

    await tester.tap(find.text('Tạo lời mời'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subject-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hóa học').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('topic-input')),
      'Phản ứng axit-bazơ 1',
    );

    await tester.tap(find.byKey(const Key('add-invitee')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-option-A')));
    await tester.tap(find.text('Thêm thành viên đã chọn'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-description-input')),
      'Chuẩn bị tóm tắt chuẩn độ 1',
    );

    Future<void> createInvite() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo nhóm'));
      await tester.pumpAndSettle();
    }

    await createInvite();
    expect(find.byKey(const Key('invite-card-0')), findsOneWidget);
    expect(find.text('Bạn chưa có lời mời nào'), findsNothing);
    expect(find.text('Phản ứng axit-bazơ 1'), findsOneWidget);
    expect(find.textContaining('Chuẩn bị tóm tắt chuẩn độ 1'), findsOneWidget);

    await tester.tap(find.text('Tạo nhóm').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subject-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vật lý').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('topic-input')),
      'Phản ứng axit-bazơ 2',
    );
    await tester.enterText(
      find.byKey(const Key('task-description-input')),
      'Chuẩn bị tóm tắt chuẩn độ 2',
    );
    await createInvite();

    await tester.tap(find.text('Tạo nhóm').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subject-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toán').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('topic-input')),
      'Phản ứng axit-bazơ 3',
    );
    await tester.enterText(
      find.byKey(const Key('task-description-input')),
      'Chuẩn bị tóm tắt chuẩn độ 3',
    );
    await createInvite();

    expect(find.text('Phản ứng axit-bazơ 1'), findsOneWidget);
    expect(find.text('Phản ứng axit-bazơ 2'), findsOneWidget);
    expect(find.text('Phản ứng axit-bazơ 3'), findsOneWidget);
    expect(find.textContaining('Chuẩn bị tóm tắt chuẩn độ 1'), findsWidgets);
    expect(find.textContaining('Chuẩn bị tóm tắt chuẩn độ 2'), findsWidgets);
    expect(find.textContaining('Chuẩn bị tóm tắt chuẩn độ 3'), findsWidgets);

    tester.view.physicalSize = const Size(1500, 600);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite-card-0')), findsOneWidget);
    expect(find.byKey(const Key('invite-card-1')), findsOneWidget);
    expect(find.text('Vật lý'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('invite-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-card-2')), findsOneWidget);
    expect(find.text('Toán'), findsOneWidget);
    expect(find.byKey(const Key('invite-scrollbar')), findsOneWidget);
    expect(
      tester
          .widget<Scrollbar>(find.byKey(const Key('invite-scrollbar')))
          .thumbVisibility,
      isTrue,
    );
    expect(find.text('TASK ASSIGNMENT'), findsNothing);
    expect(find.text('WORKSPACE RULES'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'decline removes an invite and accept preserves its project data',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var filePickCount = 0;
      String? requestedGeminiQuestion;
      String? requestedGeminiInterface;
      await tester.pumpWidget(
        MaterialApp(
          home: CreateWorkspaceScreen(
            isVietnamese: true,
            currentUserName: 'B',
            geminiRequest:
                ({required userQuestion, required interfaceName}) async {
                  requestedGeminiQuestion = userQuestion;
                  requestedGeminiInterface = interfaceName;
                  return 'Gemini group answer';
                },
            filePicker: () async {
              filePickCount++;
              if (filePickCount == 1) return [_TestPlatformFile('report.pdf')];
              if (filePickCount == 2) {
                return [_UnreadablePlatformFile('broken.mp4')];
              }
              return [_TestPlatformFile('voice.mp3')];
            },
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('group-name-input')),
        'Nhóm Axit',
      );
      await tester.enterText(find.byKey(const Key('class-name-input')), '10A');
      await tester.tap(find.byKey(const Key('subject-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hóa học').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('topic-input')),
        'Tạo dự án nhóm',
      );
      await tester.tap(find.byKey(const Key('add-invitee')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-option-A')));
      await tester.tap(find.byKey(const Key('invite-option-B')));
      await tester.tap(find.text('Thêm thành viên đã chọn'));
      await tester.pumpAndSettle();

      Future<void> selectAssignee(String name) async {
        await tester.tap(find.byKey(const Key('assignee-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name).last);
        await tester.pumpAndSettle();
      }

      await tester.enterText(
        find.byKey(const Key('task-description-input')),
        'Phân tích mẫu',
      );
      await tester.tap(find.byKey(const Key('content-format-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Video').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quantity-input')), '3');
      await tester.enterText(
        find.byKey(const Key('criteria-description-input')),
        'Có kết quả và nguồn',
      );
      await tester.enterText(
        find.byKey(const Key('task-rubric-input')),
        'Đủ ba bước phân tích',
      );
      await tester.enterText(
        find.byKey(const Key('formatting-rules-input')),
        'Tối đa 5 trang',
      );

      await selectAssignee('B');
      await tester.enterText(
        find.byKey(const Key('task-description-input')),
        'Tổng hợp kết luận',
      );
      await tester.tap(find.byKey(const Key('content-format-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ảnh').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quantity-input')), '2');
      await tester.enterText(
        find.byKey(const Key('criteria-description-input')),
        'Nêu rõ giới hạn',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo nhóm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-card-0')), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(find.text('CHI TIẾT PROJECT HUB'), findsOneWidget);
      expect(find.byKey(const Key('accepted-project-list')), findsOneWidget);
      expect(find.byKey(const Key('project-card-0')), findsOneWidget);
      expect(find.text('Nhóm Axit'), findsOneWidget);
      expect(find.text('Lớp: 10A'), findsOneWidget);
      expect(find.text('Môn học: Hóa học'), findsOneWidget);
      expect(find.text('Chủ đề: Tạo dự án nhóm'), findsOneWidget);
      expect(find.text('Hướng dẫn nhiệm vụ'), findsNothing);

      await tester.tap(find.byKey(const Key('project-card-0')));
      await tester.pumpAndSettle();

      expect(find.text('Môn học'), findsOneWidget);
      expect(find.text('Hóa học'), findsOneWidget);
      expect(find.text('Lớp'), findsOneWidget);
      expect(find.text('10A'), findsOneWidget);
      expect(find.text('Chủ đề dự án'), findsOneWidget);
      expect(find.text('Tạo dự án nhóm'), findsOneWidget);
      expect(find.text('A: Phân tích mẫu'), findsNothing);
      expect(find.text('Hướng dẫn nhiệm vụ'), findsOneWidget);
      expect(find.text('Tổng hợp kết luận'), findsWidgets);
      expect(find.text('Đủ ba bước phân tích'), findsNothing);
      expect(find.text('Tối đa 5 trang'), findsNothing);
      expect(find.text('Tiêu chí đánh giá'), findsOneWidget);
      expect(find.text('Nêu rõ giới hạn'), findsOneWidget);
      expect(find.text('Quy tắc định dạng'), findsOneWidget);
      expect(find.text('Ảnh'), findsOneWidget);
      expect(find.text('Submitted files: 0 / 2'), findsNothing);
      expect(find.text('0 / 2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('upload-files-0-B')));
      await tester.pumpAndSettle();
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('Thành công'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);

      await tester.tap(find.text('Tiến độ thành viên'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('member-progress-row-0-a')), findsOneWidget);
      expect(find.byKey(const Key('member-progress-row-0-b')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('member-progress-value-0-a')))
            .data,
        contains('0 / 3'),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('member-progress-value-0-b')))
            .data,
        contains('1 / 2'),
      );

      await tester.tap(find.byKey(const Key('member-progress-row-0-b')));
      await tester.pumpAndSettle();
      expect(find.text('Bài nộp của B'), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('Tài liệu'), findsOneWidget);
      expect(find.byTooltip('Xem tệp'), findsOneWidget);
      expect(find.byTooltip('Tải xuống'), findsOneWidget);
      await tester.tap(find.byTooltip('Xem tệp'));
      await tester.pumpAndSettle();
      expect(find.text('Xem tệp').last, findsOneWidget);
      expect(find.text('report.pdf').last, findsOneWidget);
      await tester.tap(find.text('Đóng').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Không gian cá nhân'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('upload-files-0-B')));
      await tester.pumpAndSettle();
      expect(find.text('broken.mp4'), findsOneWidget);
      expect(find.text('Lỗi'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);

      await tester.tap(find.text('Trò chuyện nhóm'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chat-input-0')),
        '@Gemini Gợi ý cách chia việc',
      );
      await tester.tap(find.byKey(const Key('chat-send-0')));
      await tester.pumpAndSettle();
      expect(requestedGeminiQuestion, 'Gợi ý cách chia việc');
      expect(requestedGeminiInterface, 'Nhóm Axit');
      expect(find.text('Gemini group answer'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('chat-input-0')),
        'Họp nhóm lúc 3 giờ nhé.',
      );
      await tester.tap(find.byKey(const Key('chat-send-0')));
      await tester.pumpAndSettle();
      expect(find.text('Họp nhóm lúc 3 giờ nhé.'), findsOneWidget);
      expect(find.text('B'), findsWidgets);
      expect(find.text('Trưởng nhóm · Bạn'), findsNWidgets(2));
      expect(find.byKey(const Key('chat-time-0-0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-attach-0')));
      await tester.pumpAndSettle();
      expect(find.text('voice.mp3'), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);

      await tester.tap(find.text('Lời mời'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-list')), findsNothing);
      expect(find.text('Bạn chưa có lời mời nào'), findsOneWidget);

      await tester.tap(find.text('Tạo nhóm').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo nhóm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-list')), findsNothing);
      expect(find.text('Bạn chưa có lời mời nào'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('study group data is cached and file metadata loads on demand', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dataSource = _FakeStudyGroupDataSource()
      ..createdGroupId = 'group-1'
      ..createdGroup = {
        'id': 'group-1',
        'classroom_id': 'class-1',
        'class_name': '10A',
        'created_by': 'owner-id',
        'group_name': 'Study group',
        'subject': 'Math',
        'topic': 'Algebra',
        'deadline': '2026-10-24',
        'task_assignments': const [],
        'ai_detection_enabled': false,
      };
    await tester.pumpWidget(
      MaterialApp(
        home: CreateWorkspaceScreen(
          currentUserName: 'Owner',
          currentUserId: 'owner-id',
          dataSource: dataSource,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(dataSource.classroomLoadCount, 1);
    expect(dataSource.workspaceLoadCount, 1);
    expect(dataSource.groupFileLoadCount, 0);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-card-0')));
    await tester.pumpAndSettle();
    expect(dataSource.groupFileLoadCount, 1);

    await tester.tap(find.text('Invites'));
    await tester.pumpAndSettle();
    expect(dataSource.classroomLoadCount, 1);
    expect(dataSource.workspaceLoadCount, 1);
    expect(dataSource.groupFileLoadCount, 1);

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refreshIndicator.onRefresh();
    await tester.pumpAndSettle();
    expect(dataSource.classroomLoadCount, 2);
    expect(dataSource.workspaceLoadCount, 2);
  });

  testWidgets('Project Hub inherits Vietnamese dashboard language', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await _signIn(tester);
    await tester.ensureVisible(find.text('Không gian dự án'));
    await tester.tap(find.text('Không gian dự án'));
    await tester.pumpAndSettle();

    expect(find.text('Tạo nhóm học tập & dự án'), findsOneWidget);
    expect(find.text('MÔN HỌC'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Tạo nhóm'), findsOneWidget);
  });
}

Future<void> _signIn(
  WidgetTester tester, {
  UserProfileLoader? profileLoader,
}) async {
  await tester.pumpWidget(
    MyApp(authenticator: _successfulSignIn, profileLoader: profileLoader),
  );
  await tester.enterText(
    find.byKey(const Key('login-username')),
    'student@example.com',
  );
  await tester.enterText(find.byKey(const Key('login-password')), '123');
  await tester.tap(find.text('Đăng nhập'));
  await tester.pumpAndSettle();
}

Future<String?> _successfulSignIn({
  required String email,
  required String password,
}) async => null;

final class _FakeStudyGroupDataSource implements StudyGroupDataSource {
  String? createdGroupId;
  String invitationStatus = 'pending';
  List<String> createdInviteeIds = const [];
  Map<String, dynamic> createdGroup = const {};
  List<Map<String, dynamic>> createdTasks = const [];
  final List<Map<String, dynamic>> uploadedGroupFiles = [];
  int classroomLoadCount = 0;
  int workspaceLoadCount = 0;
  int groupFileLoadCount = 0;
  int downloadCount = 0;

  @override
  Future<List<StudyGroupClassroom>> loadClassrooms(String userId) async {
    classroomLoadCount++;
    return const [StudyGroupClassroom(id: 'class-1', name: '10A')];
  }

  @override
  Future<List<StudyGroupMember>> loadClassroomMembers(
    String classroomId,
  ) async => const [
    StudyGroupMember(id: 'owner-id', name: 'Owner'),
    StudyGroupMember(id: 'member-a-id', name: 'A'),
    StudyGroupMember(id: 'invitee-id', name: 'B'),
  ];

  @override
  Future<List<StudyGroupWorkspace>> loadWorkspaces(String userId) async {
    workspaceLoadCount++;
    final groupId = createdGroupId;
    if (groupId == null || (userId != 'owner-id' && userId != 'invitee-id')) {
      return const [];
    }
    final status = userId == 'owner-id' ? 'accepted' : invitationStatus;
    if (status == 'declined') return const [];
    return [
      StudyGroupWorkspace(
        group: createdGroup,
        membershipStatus: status,
        members: [
          const {'user_id': 'owner-id', 'name': 'Owner', 'status': 'accepted'},
          {'user_id': 'invitee-id', 'name': 'B', 'status': invitationStatus},
        ],
      ),
    ];
  }

  @override
  Future<String> createGroup({
    required String classroomId,
    required String groupName,
    required String className,
    required String subject,
    required String topic,
    required String deadline,
    required bool aiDetectionEnabled,
    required List<String> invitedUserIds,
    required List<Map<String, dynamic>> taskAssignments,
  }) async {
    createdGroupId = 'group-1';
    createdInviteeIds = invitedUserIds;
    createdTasks = taskAssignments;
    createdGroup = {
      'id': createdGroupId,
      'classroom_id': classroomId,
      'class_name': className,
      'created_by': 'owner-id',
      'group_name': groupName,
      'subject': subject,
      'topic': topic,
      'deadline': deadline,
      'task_assignments': taskAssignments,
      'ai_detection_enabled': aiDetectionEnabled,
    };
    return createdGroupId!;
  }

  @override
  Future<void> updateInviteStatus({
    required String groupId,
    required String status,
  }) async {
    invitationStatus = status;
  }

  @override
  Future<List<Map<String, dynamic>>> loadGroupFiles(String groupId) async {
    groupFileLoadCount++;
    return uploadedGroupFiles
        .where((file) => file['group_id'] == groupId)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> uploadGroupFile({
    required String groupId,
    required String uploaderUserId,
    required String? assigneeUserId,
    required String fileName,
    required String? mimeType,
    required Uint8List bytes,
  }) async {
    final file = <String, dynamic>{
      'id': 'file-${uploadedGroupFiles.length + 1}',
      'group_id': groupId,
      'uploaded_by': uploaderUserId,
      'assignee_user_id': assigneeUserId,
      'storage_path': '$groupId/$uploaderUserId/$fileName',
      'file_name': fileName,
      'mime_type': mimeType,
      'size_bytes': bytes.length,
      'created_at': DateTime.now().toIso8601String(),
    };
    uploadedGroupFiles.add(file);
    return file;
  }

  @override
  Future<Uint8List> downloadGroupFile(String storagePath) async {
    downloadCount++;
    return Uint8List.fromList([1, 2, 3]);
  }
}

base class _TestPlatformFile extends PlatformFile {
  _TestPlatformFile(this.name);

  @override
  final String name;

  @override
  Uri get uri => Uri.parse('file:///test/$name');

  @override
  int? lengthSync() => 3;

  @override
  Future<int?> length() async => 3;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList([1, 2, 3]);

  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream.value(Uint8List.fromList([1, 2, 3]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnreadablePlatformFile extends _TestPlatformFile {
  _UnreadablePlatformFile(super.name);

  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream.error(StateError('Could not read file'));
}
