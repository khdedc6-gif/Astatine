import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BrandingAssetSlot {
  loginBackground(
    column: 'login_background_url',
    scaleColumn: 'login_background_scale',
    xColumn: 'login_background_x',
    yColumn: 'login_background_y',
    storagePath: 'login-background',
    label: 'Login screen',
  ),
  overviewIllustration(
    column: 'overview_illustration_url',
    scaleColumn: 'overview_illustration_scale',
    xColumn: 'overview_illustration_x',
    yColumn: 'overview_illustration_y',
    storagePath: 'overview-illustration',
    label: 'Overview illustration',
  );

  const BrandingAssetSlot({
    required this.column,
    required this.scaleColumn,
    required this.xColumn,
    required this.yColumn,
    required this.storagePath,
    required this.label,
  });

  final String column;
  final String scaleColumn;
  final String xColumn;
  final String yColumn;
  final String storagePath;
  final String label;
}

@immutable
class BrandingImageSetting {
  const BrandingImageSetting({
    required this.url,
    this.scale = 1,
    this.x = 0,
    this.y = 0,
  });

  final String url;
  final double scale;
  final double x;
  final double y;
}

@immutable
class BrandingImageFile {
  const BrandingImageFile({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

typedef AppBrandingAssetsLoader =
    Future<Map<BrandingAssetSlot, BrandingImageSetting>> Function();
typedef AppBrandingImagePicker = Future<BrandingImageFile?> Function();
typedef AppBrandingImageUploader = Future<String?> Function(
  BrandingAssetSlot slot,
  BrandingImageFile file,
  BrandingImageSetting crop,
);

class BrandingNetworkImage extends StatelessWidget {
  const BrandingNetworkImage({
    super.key,
    required this.setting,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final BrandingImageSetting setting;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Transform.scale(
      scale: setting.scale,
      child: SizedBox.expand(
        child: Image.network(
          setting.url,
          fit: fit,
          alignment: Alignment(setting.x, setting.y),
          errorBuilder: errorBuilder,
        ),
      ),
    ),
  );
}

abstract final class AppBrandingAssets {
  static const _bucket = 'app-branding-assets';
  static const _maxFileSize = 8 * 1024 * 1024;
  static const _contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static const _selectColumns =
      'login_background_url, login_background_scale, login_background_x, '
      'login_background_y, overview_illustration_url, '
      'overview_illustration_scale, overview_illustration_x, '
      'overview_illustration_y';

  static final ValueNotifier<Map<BrandingAssetSlot, BrandingImageSetting>>
  current = ValueNotifier(const {});

  static Future<Map<BrandingAssetSlot, BrandingImageSetting>> load() async {
    final row = await Supabase.instance.client
        .from('app_branding_assets')
        .select(_selectColumns)
        .eq('id', 1)
        .maybeSingle();

    final assets = <BrandingAssetSlot, BrandingImageSetting>{};
    for (final slot in BrandingAssetSlot.values) {
      final url = row?[slot.column]?.toString().trim();
      if (url != null && url.isNotEmpty) {
        assets[slot] = BrandingImageSetting(
          url: url,
          scale: _number(row?[slot.scaleColumn], 1).clamp(1, 3),
          x: _number(row?[slot.xColumn], 0).clamp(-1, 1),
          y: _number(row?[slot.yColumn], 0).clamp(-1, 1),
        );
      }
    }
    return Map.unmodifiable(assets);
  }

  static double _number(Object? value, double fallback) =>
      value is num ? value.toDouble() : fallback;

  static void publish(Map<BrandingAssetSlot, BrandingImageSetting> assets) {
    current.value = Map.unmodifiable(assets);
  }

  static Future<BrandingImageFile?> pickImage() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (files.isEmpty) return null;
    if (files.length != 1) {
      throw StateError('Select exactly one image.');
    }

    final file = files.single;
    final extension = file.extension?.toLowerCase();
    if (extension == null || !_contentTypes.containsKey(extension)) {
      throw StateError('Use a JPG, PNG, or WebP image.');
    }
    final size = await file.length();
    if (size == null) {
      throw StateError('The selected image size could not be read.');
    }
    if (size > _maxFileSize) {
      throw StateError('Image must be 8 MB or smaller.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('The selected image could not be read.');
    }
    return BrandingImageFile(bytes: bytes, name: file.name);
  }

  static Future<String> upload(
    BrandingAssetSlot slot,
    BrandingImageFile file,
    BrandingImageSetting crop,
  ) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in with a developer account first.');
    }

    final account = await client
        .from('users')
        .select('is_dev')
        .eq('id', user.id)
        .maybeSingle();
    if (account?['is_dev'] != true) {
      throw StateError('Developer access is required to upload app visuals.');
    }

    final extension = file.name.split('.').last.toLowerCase();
    final contentType = _contentTypes[extension];
    if (contentType == null) {
      throw StateError('Use a JPG, PNG, or WebP image.');
    }
    if (file.bytes.isEmpty) {
      throw StateError('The selected image could not be read.');
    }

    final storage = client.storage.from(_bucket);
    await storage.uploadBinary(
      slot.storagePath,
      file.bytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        contentType: contentType,
        upsert: true,
      ),
    );

    final publicUrl = storage.getPublicUrl(slot.storagePath);
    final versionedUrl =
        '$publicUrl?v=${DateTime.now().microsecondsSinceEpoch}';
    try {
      final updated = await client
          .from('app_branding_assets')
          .update({
            slot.column: versionedUrl,
            slot.scaleColumn: crop.scale,
            slot.xColumn: crop.x,
            slot.yColumn: crop.y,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'updated_by': user.id,
          })
          .eq('id', 1)
          .select('id')
          .maybeSingle();
      if (updated == null) {
        throw StateError('The app branding settings row was not updated.');
      }
    } catch (error) {
      throw StateError(
        'The image uploaded, but its app setting could not be saved: $error',
      );
    }

    current.value = Map.unmodifiable({
      ...current.value,
      slot: BrandingImageSetting(
        url: versionedUrl,
        scale: crop.scale,
        x: crop.x,
        y: crop.y,
      ),
    });
    return versionedUrl;
  }
}
