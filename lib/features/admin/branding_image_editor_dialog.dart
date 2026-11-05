import 'package:flutter/material.dart';

import 'package:astatine_dashboard/core/branding/app_branding_assets.dart';

class BrandingImageEditorDialog extends StatefulWidget {
  const BrandingImageEditorDialog({
    super.key,
    required this.slot,
    required this.file,
    required this.initialSetting,
    required this.onUpload,
  });

  final BrandingAssetSlot slot;
  final BrandingImageFile file;
  final BrandingImageSetting initialSetting;
  final Future<String?> Function(BrandingImageSetting crop) onUpload;

  @override
  State<BrandingImageEditorDialog> createState() =>
      _BrandingImageEditorDialogState();
}

class _BrandingImageEditorDialogState extends State<BrandingImageEditorDialog> {
  late final _scale = ValueNotifier<double>(
    widget.initialSetting.scale.clamp(1, 3),
  );
  late final _x = ValueNotifier<double>(widget.initialSetting.x.clamp(-1, 1));
  late final _y = ValueNotifier<double>(widget.initialSetting.y.clamp(-1, 1));
  bool _uploading = false;
  String? _error;

  BrandingImageSetting get _crop => BrandingImageSetting(
    url: widget.initialSetting.url,
    scale: _scale.value,
    x: _x.value,
    y: _y.value,
  );

  @override
  void dispose() {
    _scale.dispose();
    _x.dispose();
    _y.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await widget.onUpload(_crop);
      if (!mounted) return;
      if (url == null) {
        setState(() {
          _uploading = false;
          _error = 'The upload did not return a published image URL.';
        });
        return;
      }
      Navigator.of(context).pop(url);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 620;
    return Dialog(
      backgroundColor: const Color(0xFF17191F),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Color(0xFF9CDCFE)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Preview ${widget.slot.label.toLowerCase()}',
                      style: const TextStyle(
                        color: Color(0xFFF2F2F2),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close preview',
                    onPressed: _uploading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFCCCCCC),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Adjust the image as it will appear in the app, then publish it.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    _scale.value = 1;
                    _x.value = 0;
                    _y.value = 0;
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 17),
                  label: const Text('Reset framing'),
                ),
              ),
              _buildLivePreview(compact: compact),
              const SizedBox(height: 18),
              ValueListenableBuilder<double>(
                valueListenable: _scale,
                builder: (context, scale, _) => _buildSlider(
                  label: 'Zoom',
                  value: scale,
                  min: 1,
                  max: 3,
                  valueLabel: '${scale.toStringAsFixed(1)}×',
                  onChanged: (value) => _scale.value = value,
                ),
              ),
              ValueListenableBuilder<double>(
                valueListenable: _x,
                builder: (context, x, _) => _buildSlider(
                  label: 'Horizontal',
                  value: x,
                  min: -1,
                  max: 1,
                  valueLabel: _alignmentLabel(x),
                  onChanged: (value) => _x.value = value,
                ),
              ),
              ValueListenableBuilder<double>(
                valueListenable: _y,
                builder: (context, y, _) => _buildSlider(
                  label: 'Vertical',
                  value: y,
                  min: -1,
                  max: 1,
                  valueLabel: _alignmentLabel(y),
                  onChanged: (value) => _y.value = value,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Upload failed: $_error',
                    style: const TextStyle(color: Color(0xFFFF7D8C)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _uploading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    key: const Key('branding-image-publish'),
                    onPressed: _uploading ? null : _save,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(_uploading ? 'Uploading…' : 'Publish image'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreview({required bool compact}) {
    if (widget.slot == BrandingAssetSlot.loginBackground) {
      return _buildLoginPreview(compact: compact);
    }
    return _buildOverviewPreview(compact: compact);
  }

  Widget _buildLoginPreview({required bool compact}) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      height: compact ? 225 : 310,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF18181B)),
          _buildCropImage(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xCC000000),
                  Color(0xF2000000),
                ],
                stops: [0, 0.34, 0.66, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Row(
                  children: [
                    Icon(Icons.science_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Astatine',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  '',
                  style: TextStyle(
                    color: Color(0xFFFFD6B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Học tốt hơn,\\ncùng nhau mỗi ngày.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 20 : 26,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 7),
                  const Text(
                    'Một không gian học tập thân thiện cho lớp học, bài tập và ý tưởng mới.',
                    style: TextStyle(color: Color(0xFFE4E4E7), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildOverviewPreview({required bool compact}) => Container(
    height: compact ? 225 : 310,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF24262E),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF3A3D48)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ASTATINE EDU 2.0',
                style: TextStyle(
                  color: Color(0xFF9CDCFE),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                compact ? 'Welcome back!' : 'Chào mừng trở lại!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 19 : 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ready for an amazing study session today?',
                style: TextStyle(
                  color: Color(0xFFB8B8C2),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 15),
                const Text(
                  'OPEN LAB      VIEW TASKS',
                  style: TextStyle(
                    color: Color(0xFFFFC58F),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: compact ? 112 : 190,
          child: AspectRatio(
            aspectRatio: 220 / 190,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _buildCropImage(),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildCropImage() => LayoutBuilder(
    builder: (context, constraints) => RepaintBoundary(
      child: ListenableBuilder(
        listenable: Listenable.merge([_scale, _x, _y]),
        builder: (context, _) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            _x.value =
                (_x.value -
                        details.delta.dx *
                            2 /
                            constraints.maxWidth /
                            _scale.value)
                    .clamp(-1, 1);
            _y.value =
                (_y.value -
                        details.delta.dy *
                            2 /
                            constraints.maxHeight /
                            _scale.value)
                    .clamp(-1, 1);
          },
          child: ClipRect(
            child: Transform.scale(
              scale: _scale.value,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Image.memory(
                  widget.file.bytes,
                  fit: BoxFit.cover,
                  alignment: Alignment(_x.value, _y.value),
                  errorBuilder: (context, error, stackTrace) {
                    return const ColoredBox(
                      color: Color(0xFF343640),
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFFCCCCCC),
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) => Row(
    children: [
      SizedBox(
        width: 86,
        child: Text(label, style: const TextStyle(color: Color(0xFFE4E4E7))),
      ),
      Expanded(
        child: Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: const Color(0xFF9CDCFE),
        ),
      ),
      SizedBox(
        width: 46,
        child: Text(
          valueLabel,
          textAlign: TextAlign.end,
          style: const TextStyle(color: Color(0xFFB8B8C2)),
        ),
      ),
    ],
  );

  String _alignmentLabel(double value) => switch (value) {
    < -0.5 => 'Start',
    > 0.5 => 'End',
    _ => 'Center',
  };
}
