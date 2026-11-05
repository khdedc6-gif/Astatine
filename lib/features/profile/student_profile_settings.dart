import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/notifications/toast.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';
import 'package:astatine_dashboard/features/profile/user_profile_store.dart';

class StudentProfileSettingsScreen extends StatefulWidget {
  const StudentProfileSettingsScreen({
    super.key,
    required this.isVietnamese,
    this.userName = 'User',
    this.userEmail = '',
    this.userRole = 'Guest',
    this.subscriptionTier = 'FREE',
    required this.onLanguageChanged,
    this.languageCode,
    this.onLanguageCodeChanged,
    required this.selectedTheme,
    required this.onThemeChanged,
  });

  final bool isVietnamese;
  final String userName;
  final String userEmail;
  final String userRole;
  final String subscriptionTier;
  final ValueChanged<bool> onLanguageChanged;
  final String? languageCode;
  final ValueChanged<String>? onLanguageCodeChanged;
  final String selectedTheme;
  final ValueChanged<String> onThemeChanged;

  @override
  State<StudentProfileSettingsScreen> createState() =>
      _StudentProfileSettingsScreenState();
}

class _StudentProfileSettingsScreenState
    extends State<StudentProfileSettingsScreen> {
  bool _liveBackground = true;
  bool _animations = true;
  bool _notifications = true;
  bool _performanceOptimization = false;
  bool _autoAcceptInvites = false;
  String _graphicsQuality = 'Medium';
  final TextEditingController _supportController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();
  final TextEditingController _bannerUrlController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  List<Map<String, dynamic>> _inventory = [];
  bool _isLoadingProfile = true;
  bool _isSavingProfile = false;
  bool _isUploadingImage = false;
  bool _canRetryProfileLoad = false;
  String? _profileLoadError;

  bool get _vi => widget.isVietnamese;
  AstatinePalette get _palette =>
      Theme.of(context).extension<AstatinePalette>() ??
      AstatinePalette.forName(widget.selectedTheme);
  Color get _cyan => _palette.accent;
  Color get _screenBackground => _palette.background;
  Color get _muted => _palette.secondaryText;
  String get _languageCode => widget.languageCode ?? (_vi ? 'vi' : 'en');
  bool get _canUseNeon =>
      const {'PRO', 'ULTRA'}.contains(widget.subscriptionTier.toUpperCase());

  String _text(String english, String vietnamese, {String? chinese}) =>
      _languageCode == 'zh'
      ? chinese ?? english
      : _vi
      ? vietnamese
      : english;

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.userName;
    _loadProfile();
  }

  void _changeLanguage(String value) {
    final languageCode = switch (value) {
      'Tiếng Việt' => 'vi',
      '中文' => 'zh',
      _ => 'en',
    };
    final onLanguageCodeChanged = widget.onLanguageCodeChanged;
    if (onLanguageCodeChanged != null) {
      onLanguageCodeChanged(languageCode);
    } else {
      widget.onLanguageChanged(languageCode == 'vi');
    }
  }

  @override
  void dispose() {
    _supportController.dispose();
    _fullNameController.dispose();
    _classNameController.dispose();
    _avatarUrlController.dispose();
    _bannerUrlController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _profileLoadError = _text(
            'You need to sign in to edit your profile.',
            'Bạn cần đăng nhập để chỉnh sửa hồ sơ.',
          );
          _isLoadingProfile = false;
        });
        return;
      }
      _canRetryProfileLoad = true;
      final profile = await client
          .from('profiles')
          .select('id, full_name, class_name, avatar_url, banner_url, bio')
          .eq('id', user.id)
          .maybeSingle();
      final inventory = await client
          .from('user_inventory')
          .select('id, user_id, item_name, item_type, icon_url, is_equipped')
          .eq('user_id', user.id);
      if (!mounted) return;
      setState(() {
        _fullNameController.text =
            (profile?['full_name'] as String?) ?? widget.userName;
        _classNameController.text = (profile?['class_name'] as String?) ?? '';
        _avatarUrlController.text = (profile?['avatar_url'] as String?) ?? '';
        _bannerUrlController.text = (profile?['banner_url'] as String?) ?? '';
        _bioController.text = (profile?['bio'] as String?) ?? '';
        _inventory = inventory
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _profileLoadError = null;
        _isLoadingProfile = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileLoadError = _text(
          'Could not load your profile: $error',
          'Không thể tải hồ sơ: $error',
        );
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      _showProfileMessage(
        _text(
          'You need to sign in before saving.',
          'Bạn cần đăng nhập trước khi lưu.',
        ),
        isError: true,
      );
      return;
    }
    if (_fullNameController.text.trim().isEmpty) {
      _showProfileMessage(
        _text('Full name is required.', 'Vui lòng nhập họ và tên.'),
        isError: true,
      );
      return;
    }

    setState(() => _isSavingProfile = true);
    try {
      await client.from('profiles').upsert({
        'id': user.id,
        'full_name': _fullNameController.text.trim(),
        'class_name': _classNameController.text.trim(),
        'avatar_url': _avatarUrlController.text.trim(),
        'banner_url': _bannerUrlController.text.trim(),
        'bio': _bioController.text.trim(),
      });
      UserProfileStore.instance.applyProfile({
        'id': user.id,
        'full_name': _fullNameController.text.trim(),
        'class_name': _classNameController.text.trim(),
        'avatar_url': _avatarUrlController.text.trim(),
        'banner_url': _bannerUrlController.text.trim(),
        'bio': _bioController.text.trim(),
      });

      for (final item in _inventory) {
        await client
            .from('user_inventory')
            .update({'is_equipped': item['is_equipped'] == true})
            .eq('id', item['id'] as String)
            .eq('user_id', user.id);
      }

      if (!mounted) return;
      _showProfileMessage(
        _text('Profile updated successfully!', 'Đã cập nhật hồ sơ thành công!'),
      );
    } catch (error) {
      if (!mounted) return;
      _showProfileMessage(
        _text(
          'Could not save your profile: $error',
          'Không thể lưu hồ sơ: $error',
        ),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  void _showProfileMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Colors.red.shade800
              : const Color(0xFF087D88),
        ),
      );
  }

  Future<void> _editImageUrl(TextEditingController controller) async {
    final urlController = TextEditingController(text: controller.text);
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _palette.card,
        title: Text(
          _text('Image URL', 'URL hình ảnh'),
          style: TextStyle(color: _palette.primaryText),
        ),
        content: TextField(
          controller: urlController,
          keyboardType: TextInputType.url,
          autofocus: true,
          style: TextStyle(color: _palette.primaryText),
          decoration: InputDecoration(
            hintText: 'https://...',
            hintStyle: TextStyle(color: _palette.secondaryText),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_text('Cancel', 'Hủy')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, urlController.text),
            child: Text(_text('Apply', 'Áp dụng')),
          ),
        ],
      ),
    );
    urlController.dispose();
    if (!mounted || url == null) return;
    final trimmedUrl = url.trim();
    if (trimmedUrl.isNotEmpty) {
      final parsedUrl = Uri.tryParse(trimmedUrl);
      if (parsedUrl == null ||
          !parsedUrl.hasAuthority ||
          !{'http', 'https'}.contains(parsedUrl.scheme)) {
        _showProfileMessage(
          _text(
            'Enter a valid HTTP(S) URL.',
            'Vui lòng nhập URL HTTP(S) hợp lệ.',
          ),
          isError: true,
        );
        return;
      }
    }
    setState(() => controller.text = trimmedUrl);
  }

  Future<void> _pickAndUploadImage(
    TextEditingController controller,
    String imageKind,
  ) async {
    if (_isUploadingImage) return;
    setState(() => _isUploadingImage = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (!mounted || files.isEmpty) return;
      final image = files.single;
      final bytes = await image.readAsBytes();
      if (!mounted) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw StateError(
          _text(
            'You need to sign in to upload an image.',
            'Bạn cần đăng nhập để tải ảnh lên.',
          ),
        );
      }
      final extension = image.extension?.toLowerCase() ?? 'jpg';
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
      final path =
          '${user.id}/$imageKind-${DateTime.now().microsecondsSinceEpoch}.$extension';

      await Supabase.instance.client.storage
          .from('profile-assets')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      final publicUrl = Supabase.instance.client.storage
          .from('profile-assets')
          .getPublicUrl(path);
      if (!mounted) return;
      setState(() => controller.text = publicUrl);
    } catch (error) {
      if (mounted) {
        _showProfileMessage(
          _text(
            'Could not upload the image: $error',
            'Không thể tải ảnh lên: $error',
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _screenBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          return Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 116),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1220),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPageHeading(),
                          const SizedBox(height: 22),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 440,
                                  child: _buildProfileEditor(),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    children: [
                                      _buildDisplayPanel(),
                                      const SizedBox(height: 18),
                                      _buildGeneralPanel(),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _buildProfileEditor(),
                            const SizedBox(height: 18),
                            _buildDisplayPanel(),
                            const SizedBox(height: 18),
                            _buildGeneralPanel(),
                          ],
                          const SizedBox(height: 24),
                          _buildFooterStatus(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(right: 24, bottom: 20, child: _buildSupportButton()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPageHeading() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _cyan.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _cyan.withValues(alpha: 0.3)),
          ),
          child: Icon(Icons.manage_accounts_outlined, color: _cyan),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text('STUDENT PROFILE  /  SETTINGS', 'HỒ SƠ  /  CÀI ĐẶT'),
                style: TextStyle(
                  color: _cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _text('Student Profile and Settings', 'Hồ sơ & Cài đặt'),
                style: TextStyle(
                  color: _palette.canvasText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width >= 700)
          _statusChip(
            Icons.shield_outlined,
            _text('ACCOUNT SECURE', 'TÀI KHOẢN AN TOÀN'),
            _cyan,
          ),
      ],
    );
  }

  Widget _buildProfileEditor() {
    return _GlassPanel(
      palette: _palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            Icons.badge_outlined,
            _text('Personal information', 'Thông tin cá nhân'),
            'IDENTITY / 01',
          ),
          const SizedBox(height: 18),
          if (_isLoadingProfile)
            Center(child: CircularProgressIndicator(color: _cyan))
          else ...[
            if (_profileLoadError != null) ...[
              Text(
                _profileLoadError!,
                style: TextStyle(color: Colors.red.shade300, fontSize: 12),
              ),
              if (_canRetryProfileLoad)
                TextButton.icon(
                  onPressed: _isLoadingProfile
                      ? null
                      : () {
                          setState(() {
                            _isLoadingProfile = true;
                            _profileLoadError = null;
                          });
                          _loadProfile();
                        },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(_text('Retry loading', 'Thử tải lại')),
                ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _fullNameController,
                  builder: (context, value, _) => Expanded(
                    child: Text(
                      value.text.trim().isEmpty
                          ? widget.userName
                          : value.text.trim(),
                      key: const Key('profile-display-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _palette.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _statusChip(
                  Icons.verified_outlined,
                  _text('ACCOUNT', 'TÀI KHOẢN'),
                  _cyan,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _profileDataRow(
              Icons.mail_outline,
              _text('Email', 'Email'),
              widget.userEmail.isEmpty ? '—' : widget.userEmail,
            ),
            _profileDataRow(
              Icons.school_outlined,
              _text('Role', 'Vai trò'),
              widget.userRole,
              last: true,
              valueKey: const Key('profile-role'),
            ),
            const SizedBox(height: 10),
            _buildBannerEditor(),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final avatar = _buildAvatarEditor();
                final fields = Column(
                  children: [
                    _profileTextField(
                      controller: _fullNameController,
                      label: _text('Full name', 'Họ và Tên'),
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    _profileTextField(
                      controller: _classNameController,
                      label: _text('Class', 'Lớp'),
                      hint: '11A1',
                      icon: Icons.school_outlined,
                    ),
                  ],
                );
                final identity = compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [avatar, const SizedBox(height: 16), fields],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          avatar,
                          const SizedBox(width: 20),
                          Expanded(child: fields),
                        ],
                      );
                return Transform.translate(
                  offset: const Offset(0, -14),
                  child: identity,
                );
              },
            ),
            const SizedBox(height: 16),
            _profileTextField(
              controller: _bioController,
              label: _text('Bio', 'Tiểu sử'),
              icon: Icons.notes_rounded,
              minLines: 3,
              maxLines: 3,
              maxLength: 150,
            ),
            const SizedBox(height: 22),
            _sectionHeading(
              Icons.workspace_premium_outlined,
              _text('EQUIPPED BADGES & ITEMS', 'DANH HIỆU & VẬT PHẨM DÙNG KÈM'),
              '',
            ),
            const SizedBox(height: 14),
            if (_inventory.isEmpty)
              Text(
                _text(
                  'No items in your inventory yet.',
                  'Chưa có vật phẩm nào.',
                ),
                style: TextStyle(color: _muted, fontSize: 12),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in _inventory) _buildInventoryItem(item),
                ],
              ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isSavingProfile ||
                        _isUploadingImage ||
                        _profileLoadError != null
                    ? null
                    : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cyan,
                  foregroundColor: _palette.accentText,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSavingProfile
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _palette.accentText,
                        ),
                      )
                    : Text(
                        _text('SAVE UPDATES', 'LƯU CẬP NHẬT'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _profileDataRow(
    IconData icon,
    String label,
    String value, {
    bool last = false,
    Key? valueKey,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _palette.border.withValues(alpha: 0.55),
                ),
              ),
            ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _muted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(label, style: TextStyle(color: _muted, fontSize: 10)),
          ),
          Text(
            value,
            key: valueKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _palette.primaryText,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerEditor() {
    final imageUrl = _bannerUrlController.text.trim();
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isEmpty
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_palette.input, _cyan.withValues(alpha: 0.2)],
                      ),
                    ),
                    child: Icon(
                      Icons.landscape_outlined,
                      color: _cyan,
                      size: 42,
                    ),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: _palette.input,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: _muted,
                        size: 36,
                      ),
                    ),
                  ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _imageActions(_bannerUrlController, 'banner'),
          ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Text(
              _text('PROFILE BANNER', 'ẢNH BÌA HỒ SƠ'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                shadows: [Shadow(blurRadius: 8, color: Colors.black)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarEditor() {
    final imageUrl = _avatarUrlController.text.trim();
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _palette.input,
              shape: BoxShape.circle,
              border: Border.all(color: _cyan, width: 2),
              boxShadow: _palette.glowEnabled
                  ? [
                      BoxShadow(
                        color: _cyan.withValues(alpha: 0.25),
                        blurRadius: 14,
                      ),
                    ]
                  : const [],
            ),
            child: ClipOval(
              child: imageUrl.isEmpty
                  ? Icon(Icons.person_outline_rounded, color: _cyan, size: 42)
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.person_outline_rounded,
                        color: _cyan,
                        size: 42,
                      ),
                    ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _imageActions(_avatarUrlController, 'avatar', compact: true),
          ),
        ],
      ),
    );
  }

  Widget _imageActions(
    TextEditingController controller,
    String imageKind, {
    bool compact = false,
  }) {
    return PopupMenuButton<String>(
      tooltip: _text('Change image', 'Đổi ảnh'),
      color: _palette.card,
      onSelected: (action) {
        if (action == 'url') {
          _editImageUrl(controller);
        } else {
          _pickAndUploadImage(controller, imageKind);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'url',
          child: Text(_text('Enter image URL', 'Nhập URL ảnh')),
        ),
        PopupMenuItem(
          value: 'file',
          child: Text(_text('Choose from device', 'Chọn ảnh từ thiết bị')),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xE6101824),
          borderRadius: BorderRadius.circular(compact ? 20 : 8),
          border: Border.all(color: _cyan.withValues(alpha: 0.75)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              compact ? Icons.edit_rounded : Icons.camera_alt_outlined,
              color: _cyan,
              size: 15,
            ),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                _text('Change banner', 'Đổi Banner'),
                style: TextStyle(color: _palette.primaryText, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _profileTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int minLines = 1,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      style: TextStyle(color: _palette.primaryText, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: _muted, fontSize: 12),
        hintStyle: TextStyle(color: _muted.withValues(alpha: 0.8)),
        prefixIcon: maxLines == 1 ? Icon(icon, color: _cyan, size: 19) : null,
        filled: true,
        fillColor: _palette.input.withValues(alpha: 0.75),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _cyan.withValues(alpha: 0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _cyan.withValues(alpha: 0.9)),
        ),
      ),
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    final equipped = item['is_equipped'] == true;
    final name = item['item_name'] as String? ?? 'Item';
    final iconUrl = item['icon_url'] as String?;
    final itemType = item['item_type'] as String? ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => item['is_equipped'] = !equipped),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minWidth: 130, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: equipped ? _cyan.withValues(alpha: 0.1) : _palette.input,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: equipped ? _cyan : _palette.border,
            width: equipped ? 1.5 : 1,
          ),
          boxShadow: equipped && _palette.glowEnabled
              ? [BoxShadow(color: _cyan.withValues(alpha: 0.2), blurRadius: 12)]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconUrl != null && iconUrl.trim().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  iconUrl,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    itemType == 'title'
                        ? Icons.title_rounded
                        : Icons.workspace_premium_outlined,
                    color: equipped ? _cyan : _muted,
                    size: 22,
                  ),
                ),
              )
            else
              Icon(
                itemType == 'title'
                    ? Icons.title_rounded
                    : Icons.workspace_premium_outlined,
                color: equipped ? _cyan : _muted,
                size: 22,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _palette.primaryText,
                  fontSize: 11,
                  fontWeight: equipped ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (equipped) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, color: _cyan, size: 15),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayPanel() {
    return _GlassPanel(
      palette: _palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            Icons.display_settings_outlined,
            _text(
              'Display & visual effects',
              'Hiển thị & Hiệu ứng',
              chinese: '显示与视觉效果',
            ),
            '',
          ),
          const SizedBox(height: 14),
          _dropdownRow(
            Icons.dark_mode_outlined,
            _text('Theme', 'Giao diện', chinese: '主题'),
            _canUseNeon || widget.selectedTheme != 'Neon'
                ? widget.selectedTheme
                : 'Dark',
            [
              'Campus',
              'Dark',
              if (_canUseNeon) 'Neon',
              'Matcha Latte',
              'Pink',
              'Light',
              'Brown',
            ],
            widget.onThemeChanged,
          ),
          if (!_canUseNeon)
            Padding(
              padding: const EdgeInsets.only(left: 30, bottom: 6),
              child: Text(
                _text(
                  'Neon theme requires a Pro or Ultra account.',
                  'Giao diện Neon chỉ dành cho tài khoản Pro hoặc Ultra.',
                  chinese: '霓虹主题仅限 Pro 或 Ultra 账户使用。',
                ),
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ),
          const SizedBox(height: 8),
          _dropdownRow(
            Icons.translate_rounded,
            _text('Language', 'Ngôn ngữ', chinese: '语言'),
            switch (_languageCode) {
              'vi' => 'Tiếng Việt',
              'zh' => '中文',
              _ => 'English',
            },
            const ['Tiếng Việt', 'English', '中文'],
            _changeLanguage,
          ),
          const SizedBox(height: 8),
          _buildThemePreview(),
          _switchRow(
            Icons.blur_on_outlined,
            _text('Live Background', 'Điện tử nền'),
            _liveBackground,
            (value) => setState(() => _liveBackground = value),
          ),
          _dropdownRow(
            Icons.graphic_eq_outlined,
            _text('Graphics Quality', 'Chất lượng đồ họa'),
            _graphicsQuality,
            const ['Low', 'Medium', 'High'],
            (value) => setState(() => _graphicsQuality = value),
          ),
          _switchRow(
            Icons.animation_outlined,
            _text(' Animations', 'Hoạt ảnh '),
            _animations,
            (value) => setState(() => _animations = value),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _palette.background.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _text('THEME PREVIEW', 'XEM TRƯỚC CHỦ ĐỀ'),
            style: TextStyle(
              color: _palette.canvasMutedText,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _themeSwatch('BG', _palette.background),
              _themeSwatch('CARD', _palette.card),
              _themeSwatch('GLOW', _palette.accent),
              _themeSwatch('TEXT', _palette.canvasText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _themeSwatch(String label, Color color) {
    final isTextSwatch = label == 'TEXT';
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: Key('theme-swatch-$label'),
            height: 28,
            decoration: BoxDecoration(
              color: isTextSwatch ? _palette.background : color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _palette.accent.withValues(alpha: 0.7)),
            ),
            alignment: Alignment.center,
            child: isTextSwatch
                ? Text(
                    'Aa',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: _palette.canvasMutedText,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralPanel() {
    return _GlassPanel(
      palette: _palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            Icons.tune_rounded,
            _text('General & system', 'Cài đặt chung & Hệ thống'),
            '',
          ),
          const SizedBox(height: 14),
          _switchRow(
            Icons.notifications_none_rounded,
            _text('Notifications', 'Thông báo'),
            _notifications,
            (value) => setState(() => _notifications = value),
          ),
          _switchRow(
            Icons.speed_rounded,
            _text('Performance Optimization', 'Siêu tối ưu'),
            _performanceOptimization,
            (value) => setState(() => _performanceOptimization = value),
          ),
          _switchRow(
            Icons.group_add_outlined,
            _text('Auto-accept Group Invites', 'Tự động chấp nhận lời mời'),
            _autoAcceptInvites,
            (value) => setState(() => _autoAcceptInvites = value),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _showTerms,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, color: _muted, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _text('Terms & Conditions', 'Điều khoản & Thỏa thuận'),
                      style: const TextStyle(
                        color: Color(0xFFD9E6EE),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: _cyan, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownRow(
    IconData icon,
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: _muted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: _palette.primaryText, fontSize: 12),
            ),
          ),
          GlideSelect<String>.dropdown(
            value: value,
            options: [
              for (final option in options)
                GlideSelectOption(value: option, label: option),
            ],
            onChanged: (selection) {
              if (selection != null) onChanged(selection);
            },
          ),
        ],
      ),
    );
  }

  Widget _switchRow(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _palette.border.withValues(alpha: 0.55),
                ),
              ),
            ),
      child: Row(
        children: [
          Icon(icon, color: _muted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: _palette.primaryText, fontSize: 12),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: _cyan.withValues(alpha: 0.55),
            activeThumbColor: _palette.accent,
            inactiveTrackColor: _palette.border,
            inactiveThumbColor: _palette.secondaryText,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(IconData icon, String title, String code) {
    return Row(
      children: [
        Icon(icon, color: _cyan, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _palette.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          code,
          style: TextStyle(
            color: _palette.secondaryText,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterStatus() {
    return Row(
      children: [
        Icon(Icons.sync_rounded, color: _cyan, size: 14),
        const SizedBox(width: 7),
        Text(
          _text(
            'Preferences active for this session',
            'Tùy chọn đang áp dụng trong phiên này',
          ),
          style: TextStyle(color: _palette.canvasMutedText, fontSize: 10),
        ),
        const Spacer(),
        Text(
          'ASTATINE EDU  /  SECURE SESSION',
          style: TextStyle(
            color: _palette.canvasMutedText,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildSupportButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _palette.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _cyan.withValues(alpha: 0.76)),
        boxShadow: _palette.glowEnabled
            ? [BoxShadow(color: _cyan.withValues(alpha: 0.16), blurRadius: 12)]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: _showSupportDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.support_agent_rounded, color: _cyan, size: 20),
                const SizedBox(width: 9),
                Text(
                  _text('Support & Report Issue', 'Hỗ trợ & Báo cáo sự cố'),
                  style: TextStyle(
                    color: _palette.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTerms() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _palette.card,
        title: Text(_text('Terms & Conditions', 'Điều khoản & Thỏa thuận')),
        content: Text(
          _text(
            'Use AstatineEdu respectfully, protect your account credentials, and follow your school guidelines when collaborating or sharing work.',
            'Sử dụng AstatineEdu đúng mục đích, bảo vệ thông tin tài khoản và tuân thủ hướng dẫn của nhà trường khi cộng tác hoặc chia sẻ bài làm.',
          ),
          style: TextStyle(color: _palette.secondaryText, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _palette.accent),
            child: Text(_text('Close', 'Đóng')),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _palette.card,
        title: Row(
          children: [
            Icon(Icons.support_agent_rounded, color: _cyan),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _text('Support & report', 'Hỗ trợ & báo cáo sự cố'),
                style: TextStyle(color: _palette.primaryText, fontSize: 17),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: _supportController,
          minLines: 3,
          maxLines: 5,
          style: TextStyle(color: _palette.primaryText),
          decoration: InputDecoration(
            hintText: _text('Describe the issue...', 'Mô tả sự cố...'),
            hintStyle: TextStyle(color: _palette.secondaryText),
            filled: true,
            fillColor: _palette.input,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _palette.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _palette.accent),
            child: Text(_text('Close', 'Đóng')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _palette.accent,
              foregroundColor: _palette.accentText,
            ),
            onPressed: () {
              Navigator.pop(context);
              ToastService.showSuccess(
                _text(
                  'Your report is ready to send.',
                  'Báo cáo đã sẵn sàng để gửi.',
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 15),
            label: Text(_text('Prepare report', 'Chuẩn bị báo cáo')),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, required this.palette});

  final Widget child;
  final AstatinePalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
        boxShadow: palette.glowEnabled
            ? [
                BoxShadow(
                  color: const Color(0x16000000),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}
