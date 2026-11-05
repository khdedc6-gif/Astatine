import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';

@immutable
class ReleaseNote {
  const ReleaseNote({
    required this.id,
    required this.version,
    required this.releasedAt,
    required this.features,
    required this.improvements,
    required this.fixes,
  });

  factory ReleaseNote.fromMap(Map<String, dynamic> map) => ReleaseNote(
    id: map['id'].toString(),
    version: map['version'].toString(),
    releasedAt: DateTime.parse(map['released_at'].toString()),
    features: map['features']?.toString() ?? '',
    improvements: map['improvements']?.toString() ?? '',
    fixes: map['fixes']?.toString() ?? '',
  );

  final String id;
  final String version;
  final DateTime releasedAt;
  final String features;
  final String improvements;
  final String fixes;
}

abstract interface class ReleaseNotesStore {
  Future<bool> isDeveloper();
  Future<List<ReleaseNote>> loadVersions();
  Future<ReleaseNote> createVersion();
  Future<ReleaseNote> saveVersion(ReleaseNote note);
  Future<void> deleteVersion(String id);
}

class SupabaseReleaseNotesStore implements ReleaseNotesStore {
  SupabaseReleaseNotesStore({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _table = 'app_release_notes';

  @override
  Future<bool> isDeveloper() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client
        .from('users')
        .select('is_dev')
        .eq('id', user.id)
        .maybeSingle();
    return row?['is_dev'] == true;
  }

  @override
  Future<List<ReleaseNote>> loadVersions() async {
    final rows = await _client
        .from(_table)
        .select('id, version, released_at, features, improvements, fixes')
        .order('released_at', ascending: false)
        .order('created_at', ascending: false);
    return rows
        .map((row) => ReleaseNote.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<ReleaseNote> createVersion() async {
    final result = await _client.rpc('admin_create_release_note');
    if (result is! Map) {
      throw StateError('Unexpected response from admin_create_release_note.');
    }
    return ReleaseNote.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  Future<ReleaseNote> saveVersion(ReleaseNote note) async {
    final result = await _client
        .from(_table)
        .update({
          'version': note.version,
          'released_at': _dateOnly(note.releasedAt),
          'features': note.features,
          'improvements': note.improvements,
          'fixes': note.fixes,
        })
        .eq('id', note.id)
        .select('id, version, released_at, features, improvements, fixes')
        .single();
    return ReleaseNote.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  Future<void> deleteVersion(String id) async {
    await _client.rpc(
      'admin_delete_release_note',
      params: {'p_release_note_id': id},
    );
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class UpdateLogDialog extends StatefulWidget {
  const UpdateLogDialog({super.key, required this.store, this.palette});

  final ReleaseNotesStore store;
  final AstatinePalette? palette;

  @override
  State<UpdateLogDialog> createState() => _UpdateLogDialogState();
}

class _UpdateLogDialogState extends State<UpdateLogDialog> {
  final _featuresController = TextEditingController();
  final _improvementsController = TextEditingController();
  final _fixesController = TextEditingController();
  final _versionController = TextEditingController();

  List<ReleaseNote> _versions = [];
  ReleaseNote? _selected;
  DateTime? _releaseDate;
  bool _isDeveloper = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _featuresController.dispose();
    _improvementsController.dispose();
    _fixesController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isDeveloper = await widget.store.isDeveloper();
      final versions = await widget.store.loadVersions();
      if (!mounted) return;
      setState(() {
        _isDeveloper = isDeveloper;
        _versions = versions;
        _select(versions.isEmpty ? null : versions.first, notify: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không thể tải nhật ký cập nhật: $error';
      });
    }
  }

  void _select(ReleaseNote? note, {bool notify = true}) {
    void update() {
      _selected = note;
      _featuresController.text = note?.features ?? '';
      _improvementsController.text = note?.improvements ?? '';
      _fixesController.text = note?.fixes ?? '';
      _versionController.text = note?.version ?? '';
      _releaseDate = note?.releasedAt;
    }

    if (notify) {
      setState(update);
    } else {
      update();
    }
  }

  Future<void> _createVersion() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final version = await widget.store.createVersion();
      if (!mounted) return;
      setState(() {
        _versions = [version, ..._versions];
        _select(version, notify: false);
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Không thể tạo phiên bản mới: $error';
      });
    }
  }

  Future<void> _saveVersion() async {
    final selected = _selected;
    if (selected == null || !_isDeveloper || _saving) return;
    final versionName = _versionController.text.trim();
    if (versionName.isEmpty) {
      setState(() => _error = 'Tên phiên bản không được để trống.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.store.saveVersion(
        ReleaseNote(
          id: selected.id,
          version: versionName,
          releasedAt: _releaseDate ?? selected.releasedAt,
          features: _featuresController.text.trim(),
          improvements: _improvementsController.text.trim(),
          fixes: _fixesController.text.trim(),
        ),
      );
      if (!mounted) return;
      final updatedVersions = [
        for (final version in _versions)
          if (version.id == updated.id) updated else version,
      ]..sort((left, right) => right.releasedAt.compareTo(left.releasedAt));
      setState(() {
        _versions = updatedVersions;
        _select(updated, notify: false);
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Không thể lưu thay đổi: $error';
      });
    }
  }

  Future<void> _pickReleaseDate() async {
    final initialDate = _releaseDate ?? _selected?.releasedAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày cập nhật phiên bản',
    );
    if (picked != null && mounted) {
      setState(() => _releaseDate = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _deleteVersion() async {
    final selected = _selected;
    if (selected == null || !_isDeveloper || _saving) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa phiên bản?'),
        content: Text(
          'Bạn có chắc muốn xóa ${selected.version} khỏi nhật ký cập nhật? '
          'Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('update-log-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa phiên bản'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.deleteVersion(selected.id);
      if (!mounted) return;
      final remaining = _versions
          .where((version) => version.id != selected.id)
          .toList();
      setState(() {
        _versions = remaining;
        _select(remaining.isEmpty ? null : remaining.first, notify: false);
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Không thể xóa phiên bản: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        widget.palette ??
        Theme.of(context).extension<AstatinePalette>() ??
        AstatinePalette.dark;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 720;
    final width = (size.width - 32).clamp(0.0, 1120.0);
    final height = (size.height - 32).clamp(0.0, 760.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        key: const Key('update-log-dialog'),
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: palette.card,
            child: Column(
              children: [
                _buildHeader(palette, compact),
                Expanded(
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: palette.accent,
                          ),
                        )
                      : _error != null && _versions.isEmpty
                      ? _buildLoadError(palette)
                      : compact
                      ? Column(
                          children: [
                            _buildCompactVersionList(palette),
                            Expanded(child: _buildContent(palette)),
                          ],
                        )
                      : Row(
                          children: [
                            SizedBox(
                              width: 248,
                              child: _buildVersionSidebar(palette),
                            ),
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: palette.border,
                            ),
                            Expanded(child: _buildContent(palette)),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AstatinePalette palette, bool compact) => Container(
    padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 18, 16, 16),
    decoration: BoxDecoration(
      color: palette.background.withValues(alpha: 0.65),
      border: Border(bottom: BorderSide(color: palette.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhật ký cập nhật (Update Log)',
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 17 : 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isDeveloper
                    ? 'Quản lý các phiên bản và nội dung phát hành'
                    : 'Lịch sử thay đổi của Astatine',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.secondaryText),
              ),
            ],
          ),
        ),
        if (_isDeveloper && _selected != null) ...[
          const SizedBox(width: 8),
          IconButton(
            key: const Key('update-log-delete'),
            tooltip: 'Xóa phiên bản',
            onPressed: _saving ? null : _deleteVersion,
            color: Theme.of(context).colorScheme.error,
            icon: const Icon(Icons.delete_outline_rounded),
            visualDensity: VisualDensity.compact,
          ),
          FilledButton.icon(
            key: const Key('update-log-save'),
            onPressed: _saving ? null : _saveVersion,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 17),
            label: Text(compact ? 'Lưu' : 'Lưu thay đổi'),
          ),
        ],
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Đóng',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.close_rounded, color: palette.secondaryText),
        ),
      ],
    ),
  );

  Widget _buildVersionSidebar(AstatinePalette palette) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'PHIÊN BẢN',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.secondaryText,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_isDeveloper)
              IconButton(
                key: const Key('update-log-add-version'),
                tooltip: 'Thêm phiên bản mới',
                onPressed: _saving ? null : _createVersion,
                icon: Icon(Icons.add_rounded, color: palette.accent),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
      if (_isDeveloper)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _createVersion,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Thêm phiên bản mới'),
          ),
        ),
      Expanded(
        child: _versions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'Chưa có phiên bản nào.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.secondaryText),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                itemCount: _versions.length,
                itemBuilder: (context, index) =>
                    _buildVersionTile(_versions[index], palette),
              ),
      ),
    ],
  );

  Widget _buildCompactVersionList(AstatinePalette palette) => SizedBox(
    height: 78,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _versions.length + (_isDeveloper ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        if (_isDeveloper && index == 0) {
          return ActionChip(
            key: const Key('update-log-add-version-compact'),
            avatar: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Thêm phiên bản'),
            onPressed: _saving ? null : _createVersion,
          );
        }
        final note = _versions[index - (_isDeveloper ? 1 : 0)];
        final selected = note.id == _selected?.id;
        return ChoiceChip(
          label: Text(note.version),
          selected: selected,
          onSelected: (_) => _select(note),
          selectedColor: palette.accent.withValues(alpha: 0.18),
          labelStyle: TextStyle(
            color: selected ? palette.accent : palette.primaryText,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        );
      },
    ),
  );

  Widget _buildVersionTile(ReleaseNote note, AstatinePalette palette) {
    final selected = note.id == _selected?.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected
            ? palette.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('release-version-${note.id}'),
          onTap: () => _select(note),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 16,
                  color: selected ? palette.accent : palette.secondaryText,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.version,
                        style: TextStyle(
                          color: selected
                              ? palette.accent
                              : palette.primaryText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(note.releasedAt),
                        style: TextStyle(
                          color: palette.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AstatinePalette palette) {
    final selected = _selected;
    if (selected == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                color: palette.secondaryText,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                _isDeveloper
                    ? 'Tạo phiên bản mới để bắt đầu ghi nhật ký.'
                    : 'Chưa có nhật ký cập nhật.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('update-log-content-scroll'),
            padding: const EdgeInsets.fromLTRB(24, 2, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildReleaseMetadata(selected, palette),
                const SizedBox(height: 16),
                _buildSection(
                  palette: palette,
                  title: 'Tính năng mới',
                  hint: 'Mô tả các tính năng mới trong phiên bản này...',
                  icon: Icons.auto_awesome_outlined,
                  controller: _featuresController,
                  value: selected.features,
                ),
                const SizedBox(height: 14),
                _buildSection(
                  palette: palette,
                  title: 'Cải tiến',
                  hint: 'Mô tả các cải tiến...',
                  icon: Icons.trending_up_rounded,
                  controller: _improvementsController,
                  value: selected.improvements,
                ),
                const SizedBox(height: 14),
                _buildSection(
                  palette: palette,
                  title: 'Sửa lỗi',
                  hint: 'Mô tả các lỗi đã được khắc phục...',
                  icon: Icons.build_outlined,
                  controller: _fixesController,
                  value: selected.fixes,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReleaseMetadata(ReleaseNote selected, AstatinePalette palette) {
    final formattedDate = _formatDate(_releaseDate ?? selected.releasedAt);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 480;
        final versionField = _isDeveloper
            ? TextField(
                key: const Key('update-log-version-field'),
                controller: _versionController,
                maxLength: 32,
                style: TextStyle(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
                decoration: InputDecoration(
                  labelText: 'Phiên bản',
                  counterText: '',
                  filled: true,
                  fillColor: palette.background.withValues(alpha: 0.52),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.accent, width: 1.4),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.version,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: palette.primaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Phát hành $formattedDate',
                    style: TextStyle(color: palette.secondaryText),
                  ),
                ],
              );

        final dateControl = _isDeveloper
            ? OutlinedButton.icon(
                key: const Key('update-log-release-date'),
                onPressed: _saving ? null : _pickReleaseDate,
                icon: const Icon(Icons.calendar_month_outlined, size: 17),
                label: Text(formattedDate),
              )
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact) ...[
              versionField,
              if (dateControl != null) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: dateControl),
              ],
            ] else
              Row(
                children: [
                  Expanded(child: versionField),
                  if (dateControl != null) ...[
                    const SizedBox(width: 12),
                    dateControl,
                  ],
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildSection({
    required AstatinePalette palette,
    required String title,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.background.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: palette.accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isDeveloper)
            TextField(
              key: ValueKey('update-log-field-$title'),
              controller: controller,
              minLines: 3,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: TextStyle(color: palette.primaryText, height: 1.5),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: palette.secondaryText.withValues(alpha: 0.82),
                ),
                filled: true,
                fillColor: palette.card,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.accent, width: 1.4),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: SelectableText(
                value.isEmpty ? 'Chưa có nội dung.' : value,
                style: TextStyle(
                  color: value.isEmpty
                      ? palette.secondaryText
                      : palette.primaryText,
                  height: 1.55,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadError(AstatinePalette palette) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Không thể tải dữ liệu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.primaryText),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}
