import 'package:flutter/material.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';

class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child, required this.label});

  final Widget child;
  final String label;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _animationsEnabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsEnabled = !MediaQuery.disableAnimationsOf(context);
    if (animationsEnabled == _animationsEnabled) return;
    _animationsEnabled = animationsEnabled;
    if (_animationsEnabled) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    return Semantics(
      container: true,
      liveRegion: true,
      label: widget.label,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            final progress = _animationsEnabled ? _controller.value : 0.5;
            final start = -1.5 + progress * 3;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(start, -0.3),
                end: Alignment(start + 1.2, 0.3),
                colors: [
                  Colors.transparent,
                  palette.accent.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
                stops: const [0.2, 0.5, 0.8],
              ).createShader(bounds),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = 10,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    final color = Color.alphaBlend(
      palette.accent.withValues(alpha: 0.08),
      palette.card,
    );
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ClassroomListSkeleton extends StatelessWidget {
  const ClassroomListSkeleton({super.key, this.label = 'Loading classrooms'});

  final String label;

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    label: label,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        const spacing = 16.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: List.generate(
              6,
              (_) =>
                  SizedBox(width: cardWidth, child: _ClassroomCardSkeleton()),
            ),
          ),
        );
      },
    ),
  );
}

class _ClassroomCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SkeletonBlock(width: 42, height: 42, radius: 14),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBlock(width: 150, height: 14, radius: 7),
                  SizedBox(height: 8),
                  SkeletonBlock(width: 92, height: 10, radius: 5),
                ],
              ),
            ),
            const SkeletonBlock(width: 24, height: 24, radius: 12),
          ],
        ),
        const SizedBox(height: 22),
        const SkeletonBlock(height: 12, radius: 6),
        const SizedBox(height: 9),
        const SkeletonBlock(width: 180, height: 12, radius: 6),
      ],
    ),
  );
}

class ClassroomChannelsSkeleton extends StatelessWidget {
  const ClassroomChannelsSkeleton({
    super.key,
    this.label = 'Đang tải kênh lớp học',
    this.count = 6,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    label: label,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: count,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(
          children: [
            SkeletonBlock(width: 18, height: 18, radius: 9),
            SizedBox(width: 10),
            Expanded(child: SkeletonBlock(height: 12, radius: 6)),
          ],
        ),
      ),
    ),
  );
}

class ClassroomChannelCardsSkeleton extends StatelessWidget {
  const ClassroomChannelCardsSkeleton({
    super.key,
    this.label = 'Đang tải kênh lớp học',
    this.count = 5,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    label: label,
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      itemCount: count,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            const SkeletonBlock(width: 38, height: 38, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBlock(
                    width: index.isEven ? 136 : 104,
                    height: 13,
                    radius: 7,
                  ),
                  const SizedBox(height: 8),
                  const SkeletonBlock(width: 92, height: 10, radius: 5),
                ],
              ),
            ),
            const SkeletonBlock(width: 18, height: 18, radius: 9),
          ],
        ),
      ),
    ),
  );
}

class ClassroomChatSkeleton extends StatelessWidget {
  const ClassroomChatSkeleton({
    super.key,
    this.label = 'Đang tải lớp học và kênh chat',
  });

  final String label;

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    label: label,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return Column(
          children: [
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (!compact) ...[
                      const SkeletonBlock(width: 92, height: 16, radius: 8),
                      const SizedBox(width: 20),
                    ],
                    for (var index = 0; index < 3; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      SkeletonBlock(
                        width: index == 1 ? 104 : 82,
                        height: 34,
                        radius: 17,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  if (!compact) ...[
                    const SizedBox(
                      width: 220,
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBlock(width: 126, height: 15),
                                SizedBox(height: 9),
                                SkeletonBlock(width: 88, height: 10),
                              ],
                            ),
                          ),
                          Divider(height: 1),
                          Expanded(
                            child: ClassroomChannelsSkeleton(
                              label: 'Đang tải danh sách kênh',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                  ],
                  const Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SkeletonBlock(width: 138, height: 15),
                          ),
                        ),
                        Expanded(
                          child: ChatMessagesSkeleton(
                            label: 'Đang tải tin nhắn',
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: SkeletonBlock(height: 44, radius: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class ChatMessagesSkeleton extends StatelessWidget {
  const ChatMessagesSkeleton({
    super.key,
    this.label = 'Đang tải tin nhắn',
    this.assignmentChat = false,
    this.count = 5,
  });

  final String label;
  final bool assignmentChat;
  final int count;

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    label: label,
    child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      itemCount: count,
      itemBuilder: (context, index) {
        final isMine = index.isOdd;
        final bubbleWidth = index % 3 == 0 ? 230.0 : 185.0;
        return Padding(
          padding: EdgeInsets.only(
            bottom: assignmentChat ? 18 : 22,
            left: isMine ? 56 : 0,
            right: isMine ? 0 : 56,
          ),
          child: Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMine) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SkeletonBlock(width: 24, height: 24, radius: 12),
                      const SizedBox(width: 8),
                      SkeletonBlock(width: index.isEven ? 88 : 112, height: 10),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Container(
                  constraints: BoxConstraints(
                    maxWidth: bubbleWidth,
                    minWidth: 90,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: assignmentChat ? 12 : 14,
                    vertical: assignmentChat ? 9 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(
                        width: bubbleWidth - 48,
                        height: 11,
                        radius: 6,
                      ),
                      if (index % 2 == 0) ...[
                        const SizedBox(height: 7),
                        SkeletonBlock(
                          width: bubbleWidth * 0.62,
                          height: 11,
                          radius: 6,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class AssignmentCardsSkeleton extends StatelessWidget {
  const AssignmentCardsSkeleton({
    super.key,
    this.label = 'Đang tải bài tập',
    this.count = 4,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    label: label,
    child: ListView.separated(
      padding: const EdgeInsets.only(right: 6, bottom: 3),
      itemCount: count,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(width: index.isEven ? 72 : 94, height: 14),
                      const SizedBox(height: 7),
                      SkeletonBlock(
                        width: index.isEven ? 180 : 145,
                        height: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const SkeletonBlock(width: 62, height: 11),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: SkeletonBlock(width: 132, height: 10, radius: 5),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: SkeletonBlock(width: 100, height: 10, radius: 5),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SkeletonBlock(width: 15, height: 15, radius: 8),
                const SizedBox(width: 6),
                Expanded(
                  child: SkeletonBlock(
                    width: index.isEven ? 118 : 86,
                    height: 10,
                    radius: 5,
                  ),
                ),
                const SkeletonBlock(width: 24, height: 24, radius: 8),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class SeatingChartSkeleton extends StatelessWidget {
  const SeatingChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    label: 'Đang tải sơ đồ chỗ ngồi',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 560
            ? 4
            : 2;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const SkeletonBlock(width: 180, height: 38, radius: 12),
                  const Spacer(),
                  if (constraints.maxWidth >= 500) ...[
                    const SkeletonBlock(width: 88, height: 36, radius: 12),
                    const SizedBox(width: 8),
                  ],
                  const SkeletonBlock(width: 40, height: 38, radius: 12),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: LayoutBuilder(
                    builder: (context, chartConstraints) {
                      final rows = (chartConstraints.maxHeight / 112)
                          .floor()
                          .clamp(2, 5)
                          .toInt();
                      final count = (columns * rows).clamp(4, 25).toInt();
                      return Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        runAlignment: WrapAlignment.spaceEvenly,
                        spacing: 16,
                        runSpacing: 16,
                        children: List.generate(
                          count,
                          (_) => SizedBox(
                            width:
                                ((chartConstraints.maxWidth -
                                            (columns - 1) * 16) /
                                        columns)
                                    .clamp(72, 160)
                                    .toDouble(),
                            child: const _DeskSkeleton(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _DeskSkeleton extends StatelessWidget {
  const _DeskSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: const Column(
      children: [
        SkeletonBlock(width: 34, height: 34, radius: 17),
        SizedBox(height: 9),
        SkeletonBlock(width: 78, height: 10, radius: 5),
        SizedBox(height: 6),
        SkeletonBlock(width: 48, height: 8, radius: 4),
      ],
    ),
  );
}

class FlashcardGridSkeleton extends StatelessWidget {
  const FlashcardGridSkeleton({
    super.key,
    this.label = 'Loading flashcard decks',
  });

  final String label;

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    label: label,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 650
            ? 2
            : 1;
        const spacing = 18.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Padding(
          padding: const EdgeInsets.fromLTRB(40, 30, 40, 40),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: List.generate(
              columns * 2,
              (_) => SizedBox(
                width: cardWidth,
                child: const _FlashcardTileSkeleton(),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _FlashcardTileSkeleton extends StatelessWidget {
  const _FlashcardTileSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBlock(height: 16, radius: 8),
        SizedBox(height: 12),
        SkeletonBlock(width: 180, height: 11, radius: 6),
        SizedBox(height: 28),
        Row(
          children: [
            SkeletonBlock(width: 72, height: 26, radius: 13),
            Spacer(),
            SkeletonBlock(width: 28, height: 28, radius: 14),
          ],
        ),
      ],
    ),
  );
}

class AnalyticsSkeleton extends StatelessWidget {
  const AnalyticsSkeleton({super.key, this.label = 'Loading analytics'});

  final String label;

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    label: label,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        const spacing = 14.0;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(
                  columns,
                  (_) => SizedBox(
                    width: tileWidth,
                    child: Container(
                      height: 98,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SkeletonBlock(width: 90, height: 10, radius: 5),
                          SkeletonBlock(width: 62, height: 22, radius: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 250,
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBlock(width: 150, height: 14, radius: 7),
                    SizedBox(height: 18),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          SkeletonBlock(width: 24, height: 74, radius: 8),
                          SkeletonBlock(width: 24, height: 132, radius: 8),
                          SkeletonBlock(width: 24, height: 96, radius: 8),
                          SkeletonBlock(width: 24, height: 166, radius: 8),
                          SkeletonBlock(width: 24, height: 112, radius: 8),
                          SkeletonBlock(width: 24, height: 148, radius: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SkeletonBlock(height: 60, radius: 14),
              const SizedBox(height: 10),
              const SkeletonBlock(height: 60, radius: 14),
            ],
          ),
        );
      },
    ),
  );
}

class SubjectRatePanelSkeleton extends StatelessWidget {
  const SubjectRatePanelSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    label: 'Đang tải điểm môn học',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonBlock(width: 156, height: 15, radius: 8),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: SkeletonBlock(height: 74, radius: 16)),
            const SizedBox(width: 12),
            const Expanded(child: SkeletonBlock(height: 74, radius: 16)),
          ],
        ),
        const SizedBox(height: 20),
        for (var index = 0; index < 3; index++) ...[
          Row(
            children: [
              const Expanded(
                child: SkeletonBlock(width: 112, height: 11, radius: 6),
              ),
              const SizedBox(width: 12),
              SkeletonBlock(width: index == 1 ? 56 : 40, height: 11, radius: 6),
            ],
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 8),
        const SkeletonBlock(height: 58, radius: 14),
      ],
    ),
  );
}
