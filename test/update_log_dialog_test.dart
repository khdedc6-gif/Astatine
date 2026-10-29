import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/features/dashboard/main_dashboard.dart';
import 'package:astatine_dashboard/features/dashboard/update_log_dialog.dart';

void main() {
  testWidgets('regular users can browse versions but cannot edit', (
    tester,
  ) async {
    final store = _FakeReleaseNotesStore(isDev: false);
    await _openDialog(tester, store);

    expect(find.text('Nhật ký cập nhật (Update Log)'), findsOneWidget);
    expect(find.text('v1.2.0'), findsWidgets);
    expect(find.text('Đã thêm bảng điều khiển.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('update-log-save')), findsNothing);
    expect(find.byKey(const Key('update-log-add-version')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('release-version-v1-old')));
    await tester.pumpAndSettle();
    expect(find.text('Tối ưu tốc độ tải.'), findsOneWidget);
    expect(find.text('v1.1.0'), findsWidgets);
  });

  testWidgets('developers can create a version, edit sections, and save', (
    tester,
  ) async {
    final store = _FakeReleaseNotesStore(isDev: true);
    await _openDialog(tester, store);

    await tester.tap(find.byKey(const Key('update-log-add-version')));
    await tester.pumpAndSettle();

    expect(store.created, isTrue);
    expect(find.text('v1.3.0'), findsWidgets);
    expect(find.byType(TextField), findsNWidgets(4));
    await tester.tap(find.byKey(const Key('update-log-release-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('update-log-field-Tính năng mới')),
      'Workspace mới',
    );
    await tester.enterText(
      find.byKey(const ValueKey('update-log-field-Cải tiến')),
      'Tăng tốc khởi động',
    );
    await tester.enterText(
      find.byKey(const ValueKey('update-log-field-Sửa lỗi')),
      'Sửa lỗi đồng bộ',
    );
    await tester.enterText(
      find.byKey(const Key('update-log-version-field')),
      'v2.0.0',
    );
    await tester.tap(find.byKey(const Key('update-log-save')));
    await tester.pumpAndSettle();

    expect(store.saved?.version, 'v2.0.0');
    expect(store.saved?.releasedAt, DateTime(2026, 10, 20));
    expect(store.saved?.features, 'Workspace mới');
    expect(store.saved?.improvements, 'Tăng tốc khởi động');
    expect(store.saved?.fixes, 'Sửa lỗi đồng bộ');
  });

  testWidgets('developers must confirm before deleting a release version', (
    tester,
  ) async {
    final store = _FakeReleaseNotesStore(isDev: true);
    await _openDialog(tester, store);

    await tester.tap(find.byKey(const Key('update-log-delete')));
    await tester.pumpAndSettle();
    expect(store.deletedIds, isEmpty);
    expect(find.text('Xóa phiên bản?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('update-log-delete-confirm')));
    await tester.pumpAndSettle();

    expect(store.deletedIds, ['v1']);
    expect(find.text('v1.2.0'), findsNothing);
    expect(find.byKey(const Key('update-log-delete')), findsOneWidget);
  });

  testWidgets('update log adapts to a narrow viewport without overflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    await _openDialog(tester, _FakeReleaseNotesStore(isDev: true));

    expect(find.byKey(const Key('update-log-dialog')), findsOneWidget);
    expect(find.byKey(const Key('update-log-content-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'overview header opens the update log in place of language controls',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      final store = _FakeReleaseNotesStore(isDev: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: AstatinePalette.themeData('Campus'),
          home: MainLayoutScreen(updateLogStore: store),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dashboard-update-log-button')),
        findsOneWidget,
      );
      expect(find.text('English'), findsNothing);
      await tester.tap(find.byKey(const Key('dashboard-update-log-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('update-log-dialog')), findsOneWidget);
      expect(find.text('Nhật ký cập nhật (Update Log)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openDialog(WidgetTester tester, ReleaseNotesStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AstatinePalette.themeData('Campus'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => UpdateLogDialog(
                  store: store,
                  palette: AstatinePalette.campus,
                ),
              ),
              child: const Text('Open update log'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open update log'));
  await tester.pumpAndSettle();
}

class _FakeReleaseNotesStore implements ReleaseNotesStore {
  _FakeReleaseNotesStore({required this.isDev});

  final bool isDev;
  bool created = false;
  ReleaseNote? saved;
  final deletedIds = <String>[];
  final notes = [
    ReleaseNote(
      id: 'v1',
      version: 'v1.2.0',
      releasedAt: DateTime(2026, 10, 18),
      features: 'Đã thêm bảng điều khiển.',
      improvements: 'Tối ưu giao diện.',
      fixes: 'Sửa lỗi đăng nhập.',
    ),
    ReleaseNote(
      id: 'v1-old',
      version: 'v1.1.0',
      releasedAt: DateTime(2026, 10, 10),
      features: 'Thêm phòng học.',
      improvements: 'Tối ưu tốc độ tải.',
      fixes: 'Sửa lỗi đồng bộ.',
    ),
  ];

  @override
  Future<bool> isDeveloper() async => isDev;

  @override
  Future<List<ReleaseNote>> loadVersions() async => List.of(notes);

  @override
  Future<ReleaseNote> createVersion() async {
    created = true;
    final note = ReleaseNote(
      id: 'v1-new',
      version: 'v1.3.0',
      releasedAt: DateTime(2026, 10, 18),
      features: '',
      improvements: '',
      fixes: '',
    );
    notes.insert(0, note);
    return note;
  }

  @override
  Future<ReleaseNote> saveVersion(ReleaseNote note) async {
    saved = note;
    return note;
  }

  @override
  Future<void> deleteVersion(String id) async {
    deletedIds.add(id);
    notes.removeWhere((note) => note.id == id);
  }
}
