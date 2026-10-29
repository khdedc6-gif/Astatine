// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _NewsArticle {
  const _NewsArticle({
    required this.title,
    required this.description,
    required this.link,
    this.imageUrl,
  });
  final String title;
  final String description;
  final String link;
  final String? imageUrl;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _stripHtml(String html) {
  final noTags = html.replaceAll(RegExp(r'<[^>]*>'), '');
  return noTags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .trim();
}

String? _articleImageUrl(Map<String, dynamic> item) {
  final enclosure = item['enclosure'];
  final candidates = [
    item['thumbnail']?.toString(),
    if (enclosure is Map) enclosure['link']?.toString(),
    RegExp(
      r'''<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(item['description']?.toString() ?? '')?.group(1),
  ];

  for (final candidate in candidates) {
    final value = candidate?.trim();
    if (value == null || value.isEmpty) continue;
    final uri = Uri.tryParse(value);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return value;
    }
  }
  return null;
}

const _rssApiUrl =
    'https://api.rss2json.com/v1/api.json'
    '?rss_url=https://vnexpress.net/rss/so-hoa.rss';

Future<List<_NewsArticle>> _fetchNews() async {
  final response = await http
      .get(Uri.parse(_rssApiUrl))
      .timeout(const Duration(seconds: 12));
  if (response.statusCode != 200) {
    throw Exception('HTTP');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final items = (data['items'] as List?)?.take(5).toList() ?? [];
  return items.map((item) {
    final raw = item as Map<String, dynamic>;
    return _NewsArticle(
      title: _stripHtml(raw['title']?.toString() ?? ''),
      description: _stripHtml(raw['description']?.toString() ?? ''),
      link: raw['link']?.toString() ?? '',
      imageUrl: _articleImageUrl(raw),
    );
  }).toList();
}

// ---------------------------------------------------------------------------
// MiniNewsTicker (public widget)
// ---------------------------------------------------------------------------

class MiniNewsTicker extends StatefulWidget {
  const MiniNewsTicker({super.key, required this.isVietnamese});
  final bool isVietnamese;

  @override
  State<MiniNewsTicker> createState() => _MiniNewsTickerState();
}

class _MiniNewsTickerState extends State<MiniNewsTicker>
    with SingleTickerProviderStateMixin {
  static const _slideDuration = Duration(milliseconds: 3500);

  List<_NewsArticle> _articles = [];
  bool _loading = true;
  String? _error;
  int _currentIndex = 0;
  int _slideKey = 0;

  late final AnimationController _progressCtrl;
  Timer? _slideTimer;
  Timer? _blinkTimer;
  bool _liveBlinkOn = true;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: _slideDuration);
    _loadNews();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() => _liveBlinkOn = !_liveBlinkOn);
    });
  }

  Future<void> _loadNews() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final articles = await _fetchNews();
      if (!mounted) return;
      setState(() {
        _articles = articles;
        _loading = false;
        _currentIndex = 0;
        _slideKey++;
      });
      if (articles.isNotEmpty) _startSlider();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _startSlider() {
    _slideTimer?.cancel();
    _progressCtrl
      ..stop()
      ..reset()
      ..forward();
    _slideTimer = Timer(_slideDuration, _nextSlide);
  }

  void _nextSlide() {
    if (!mounted || _articles.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _articles.length;
      _slideKey++;
    });
    _startSlider();
  }

  void _goTo(int index) {
    if (index == _currentIndex) return;
    _slideTimer?.cancel();
    setState(() {
      _currentIndex = index;
      _slideKey++;
    });
    _startSlider();
  }

  Future<void> openArticle(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _blinkTimer?.cancel();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    return Container(
      key: const Key('mini-news-ticker'),
      constraints: const BoxConstraints(minHeight: 210, maxHeight: 310),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TickerHeader(
              palette: palette,
              liveBlinkOn: _liveBlinkOn,
              isVietnamese: widget.isVietnamese,
              onRefresh: _loadNews,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                child: _loading
                    ? _SkeletonBody(palette: palette)
                    : _error != null
                    ? _ErrorBody(
                        palette: palette,
                        isVietnamese: widget.isVietnamese,
                        onRetry: _loadNews,
                      )
                    : _articles.isEmpty
                    ? _EmptyBody(
                        palette: palette,
                        isVietnamese: widget.isVietnamese,
                      )
                    : _ArticleBody(
                        article: _articles[_currentIndex],
                        slideKey: _slideKey,
                        palette: palette,
                        isVietnamese: widget.isVietnamese,
                        onOpen: () =>
                            openArticle(_articles[_currentIndex].link),
                      ),
              ),
            ),
            if (!_loading && _error == null && _articles.isNotEmpty) ...[
              _DotsRow(
                count: _articles.length,
                active: _currentIndex,
                palette: palette,
                onTap: _goTo,
              ),
              const Gap(6),
              _ProgressBar(controller: _progressCtrl, palette: palette),
            ] else
              const Gap(14),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TickerHeader
// ---------------------------------------------------------------------------

class _TickerHeader extends StatelessWidget {
  const _TickerHeader({
    required this.palette,
    required this.liveBlinkOn,
    required this.isVietnamese,
    required this.onRefresh,
  });
  final AstatinePalette palette;
  final bool liveBlinkOn;
  final bool isVietnamese;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: palette.background.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(color: palette.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          AnimatedOpacity(
            opacity: liveBlinkOn ? 1.0 : 0.18,
            duration: const Duration(milliseconds: 400),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF00E5FF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x8800E5FF),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          const Gap(8),
          Text(
            isVietnamese ? 'CÔNG NGHỆ & KHOA HỌC' : 'TECH & SCIENCE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF00E5FF),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 9.5,
            ),
          ),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'LIVE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF00E5FF),
                fontWeight: FontWeight.w900,
                fontSize: 8,
                letterSpacing: 1,
              ),
            ),
          ),
          const Spacer(),
          _HeaderButton(
            icon: Icons.refresh_rounded,
            onTap: onRefresh,
            palette: palette,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HeaderButton
// ---------------------------------------------------------------------------

class _HeaderButton extends StatefulWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
    required this.palette,
  });
  final IconData icon;
  final VoidCallback onTap;
  final AstatinePalette palette;

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: _hovered
                ? const Color(0xFF00E5FF)
                : widget.palette.secondaryText,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ArticleBody
// ---------------------------------------------------------------------------

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({
    required this.article,
    required this.slideKey,
    required this.palette,
    required this.isVietnamese,
    required this.onOpen,
  });
  final _NewsArticle article;
  final int slideKey;
  final AstatinePalette palette;
  final bool isVietnamese;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = animation.drive(
          Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: NewsFeedCard(
        key: ValueKey(slideKey),
        title: article.title,
        description: article.description,
        imageUrl: article.imageUrl,
        palette: palette,
        isVietnamese: isVietnamese,
        onTap: onOpen,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NewsFeedCard
// ---------------------------------------------------------------------------

class NewsFeedCard extends StatefulWidget {
  const NewsFeedCard({
    super.key,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.palette,
    required this.isVietnamese,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.contentBottomPadding = 14,
  });
  final String title;
  final String description;
  final String? imageUrl;
  final AstatinePalette palette;
  final bool isVietnamese;
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final double contentBottomPadding;

  @override
  State<NewsFeedCard> createState() => _NewsFeedCardState();
}

class _NewsFeedCardState extends State<NewsFeedCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final description = widget.description;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        label: widget.title,
        hint: description.isEmpty
            ? (widget.isVietnamese ? 'Mở bài viết' : 'Open article')
            : description,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (hovered) {
              if (_hovered != hovered) setState(() => _hovered = hovered);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: widget.palette.card,
                  child: widget.imageUrl == null
                      ? const SizedBox.expand()
                      : Image.network(
                          widget.imageUrl!,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (_, _, _) =>
                              ColoredBox(color: widget.palette.card),
                        ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color.fromRGBO(0, 0, 0, 0.85),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    24,
                    16,
                    widget.contentBottomPadding,
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: SingleChildScrollView(
                      reverse: true,
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                height: 1.25,
                              ),
                            ),
                            if (description.isNotEmpty) ...[
                              const Gap(6),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const Gap(8),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.isVietnamese
                                        ? 'Đọc bài viết'
                                        : 'Read article',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      decoration: _hovered
                                          ? TextDecoration.underline
                                          : TextDecoration.none,
                                      decorationColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const Gap(4),
                                const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_hovered)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x1200E5FF),
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0x8800E5FF)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SkeletonBody + _ShimmerTransform
// ---------------------------------------------------------------------------

class _SkeletonBody extends StatefulWidget {
  const _SkeletonBody({required this.palette});
  final AstatinePalette palette;

  @override
  State<_SkeletonBody> createState() => _SkeletonBodyState();
}

class _SkeletonBodyState extends State<_SkeletonBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(
      begin: -1,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final base = palette.input.withValues(alpha: 0.5);
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final gradient = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.5, 1.0],
          colors: [base, palette.border.withValues(alpha: 0.9), base],
          transform: _ShimmerTransform(_anim.value),
        );
        Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(6),
          ),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              bar(double.infinity, 16),
              bar(double.infinity, 16),
              bar(200, 16),
              const Gap(8),
              bar(double.infinity, 12),
              bar(double.infinity, 12),
              bar(140, 12),
              const Gap(12),
              bar(110, 12),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerTransform extends GradientTransform {
  const _ShimmerTransform(this.value);
  final double value;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * value, 0, 0);
}

// ---------------------------------------------------------------------------
// _ErrorBody
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.palette,
    required this.isVietnamese,
    required this.onRetry,
  });
  final AstatinePalette palette;
  final bool isVietnamese;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
            color: palette.secondaryText.withValues(alpha: 0.5),
            size: 32,
          ),
          const Gap(10),
          Text(
            isVietnamese ? 'Không thể tải bản tin' : 'Unable to load news feed',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: palette.secondaryText),
          ),
          const Gap(8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00E5FF),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(isVietnamese ? 'Thử lại' : 'Retry'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyBody
// ---------------------------------------------------------------------------

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.palette, required this.isVietnamese});
  final AstatinePalette palette;
  final bool isVietnamese;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        isVietnamese ? 'Không có bản tin mới' : 'No news available',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: palette.secondaryText),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DotsRow
// ---------------------------------------------------------------------------

class _DotsRow extends StatelessWidget {
  const _DotsRow({
    required this.count,
    required this.active,
    required this.palette,
    required this.onTap,
  });
  final int count;
  final int active;
  final AstatinePalette palette;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return GestureDetector(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: isActive ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF00E5FF)
                  : palette.border.withValues(alpha: 1.0),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// _ProgressBar
// ---------------------------------------------------------------------------

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.controller, required this.palette});
  final AnimationController controller;
  final AstatinePalette palette;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => SizedBox(
        height: 2.5,
        child: LinearProgressIndicator(
          value: controller.value,
          backgroundColor: palette.border.withValues(alpha: 0.5),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }
}
