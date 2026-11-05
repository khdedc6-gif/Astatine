import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';

AstatinePalette _paletteOf(BuildContext context) =>
    (Theme.of(context).extensions[AstatinePalette] as AstatinePalette?) ??
    AstatinePalette.dark;

class AchievementCenterScreen extends StatefulWidget {
  const AchievementCenterScreen({super.key, required this.isVietnamese});
  final bool isVietnamese;
  @override
  State<AchievementCenterScreen> createState() =>
      _AchievementCenterScreenState();
}

class _AchievementCenterScreenState extends State<AchievementCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _paletteOf(context);
    final vi = widget.isVietnamese;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: p.border.withValues(alpha: 0.4)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vi
                          ? 'THÀNH TỰU & XẾP HẠNG'
                          : 'ACHIEVEMENTS & LEADERBOARD CENTER',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: p.canvasText,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      vi ? 'Theo dõi mốc tiến trình cá nhân và bảng xếp hạng' : 'Track your personal milestone progress and COIN rankings',
                      style: TextStyle(fontSize: 12, color: p.secondaryText),
                    ),
                  ],
                ),
              ),
              const Gap(16),
              Container(
                height: 40,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: p.card.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.border.withValues(alpha: 0.5)),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.accent.withValues(alpha: 0.6)),
                  ),
                  labelColor: p.accent,
                  unselectedLabelColor: p.secondaryText,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events_rounded, size: 15),
                            const Gap(6),
                            Text(vi ? 'Mốc Thành Tựu' : 'Milestones'),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.leaderboard_rounded, size: 15),
                            const Gap(6),
                            Text(
                              vi ? 'Bảng Xếp Hạng COIN' : 'COIN Leaderboard',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _AchievementsTab(isVietnamese: vi, palette: p),
              _CoinLeaderboardTab(isVietnamese: vi, palette: p),
            ],
          ),
        ),
      ],
    );
  }
}

class _AchievementItem {
  const _AchievementItem({
    required this.name,
    required this.target,
    required this.progress,
  }) : unlocked = false;
  final String name;
  final String target;
  final double progress;
  final bool unlocked;
}

const _coinTree = [
  _AchievementItem(name: 'Thành tích 1', target: '10k Coin', progress: 0.0),
  _AchievementItem(name: 'Thành tích 2', target: '20k Coin', progress: 0.0),
  _AchievementItem(name: 'Thành tích 3', target: '30k Coin', progress: 0.0),
  _AchievementItem(name: 'Thành tích 4', target: '40k Coin', progress: 0.0),
  _AchievementItem(name: 'Thành tích 5', target: '50k Coin', progress: 0.0),
];

const _expTree = [
  _AchievementItem(name: 'Thành tích 1', target: '5k EXP', progress: 0.0),
  _AchievementItem(name: 'Thành tích 2', target: '10k EXP', progress: 0.0),
  _AchievementItem(name: 'Thành tích 3', target: '20k EXP', progress: 0.0),
  _AchievementItem(name: 'Thành tích 4', target: '35k EXP', progress: 0.0),
  _AchievementItem(name: 'Thành tích 5', target: '60k EXP', progress: 0.0),
];

const _hoursTree = [
  _AchievementItem(name: 'Thành tích 1', target: '100 Giờ', progress: 0.0),
  _AchievementItem(name: 'Thành tích 2', target: '300 Giờ', progress: 0.0),
  _AchievementItem(name: 'Thành tích 3', target: '500 Giờ', progress: 0.0),
  _AchievementItem(name: 'Thành tích 4', target: '800 Giờ', progress: 0.0),
  _AchievementItem(name: 'Thành tích 5', target: '1000 Giờ', progress: 0.0),
];

class _AchievementsTab extends StatelessWidget {
  const _AchievementsTab({required this.isVietnamese, required this.palette});
  final bool isVietnamese;
  final AstatinePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressTree(
            label: isVietnamese ? '🪙  TIẾN TRÌNH COIN' : '🪙  COIN MILESTONES',
            items: _coinTree,
            palette: p,
            isVietnamese: isVietnamese,
          ),
          const Gap(28),
          _ProgressTree(
            label: isVietnamese ? '⚡  TIẾN TRÌNH EXP' : '⚡  EXP MILESTONES',
            items: _expTree,
            palette: p,
            isVietnamese: isVietnamese,
          ),
          const Gap(28),
          _ProgressTree(
            label: isVietnamese
                ? '📚  TIẾN TRÌNH THỜI GIAN HỌC'
                : '📚  STUDY HOURS MILESTONES',
            items: _hoursTree,
            palette: p,
            isVietnamese: isVietnamese,
          ),
        ],
      ),
    );
  }
}

class _ProgressTree extends StatelessWidget {
  const _ProgressTree({
    required this.label,
    required this.items,
    required this.palette,
    required this.isVietnamese,
  });
  final String label;
  final List<_AchievementItem> items;
  final AstatinePalette palette;
  final bool isVietnamese;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: p.canvasText,
                ),
              ),
              const Gap(10),
              Expanded(
                child: Container(
                  height: 1,
                  color: p.border.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(items.length * 2 - 1, (i) {
                if (i.isOdd) return _ConnectorLine(palette: p);
                return _BentoAchievementCard(
                  item: items[i ~/ 2],
                  palette: p,
                  isVietnamese: isVietnamese,
                );
              }),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 80.ms);
  }
}

class _ConnectorLine extends StatelessWidget {
  const _ConnectorLine({required this.palette});
  final AstatinePalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Center(
        child: Container(
          height: 2,
          color: palette.border.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _BentoAchievementCard extends StatelessWidget {
  final _AchievementItem item;
  final AstatinePalette palette;
  final bool isVietnamese;

  const _BentoAchievementCard({
    required this.item,
    required this.palette,
    required this.isVietnamese,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final locked = !item.unlocked;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: locked
            ? p.card.withValues(alpha: 0.38)
            : p.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.unlocked
              ? p.accent.withValues(alpha: 0.55)
              : p.border.withValues(alpha: 0.5),
          width: item.unlocked ? 1.5 : 1.0,
        ),
        boxShadow: item.unlocked
            ? [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.07),
                  blurRadius: 12,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFF000000),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.border.withValues(alpha: 0.3)),
            ),
            child: locked
                ? const Center(
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF555555),
                      size: 22,
                    ),
                  )
                : const Center(
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFFFD700),
                      size: 28,
                    ),
                  ),
          ),
          const Gap(10),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: locked ? p.canvasMutedText : p.canvasText,
            ),
          ),
          const Gap(4),
          Text(
            item.target,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: locked ? p.secondaryText : p.accent,
            ),
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 5,
                    backgroundColor: p.border.withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      item.unlocked
                          ? p.accent
                          : p.accent.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const Gap(6),
              Icon(
                item.unlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
                size: 13,
                color: item.unlocked
                    ? p.accent
                    : p.canvasMutedText.withValues(alpha: 0.6),
              ),
            ],
          ),
          const Gap(4),
          Text(
            item.unlocked
                ? (isVietnamese ? 'Đã mở khóa' : 'Unlocked')
                : '${(item.progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 9,
              color: item.unlocked ? p.accent : p.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class LeaderboardUser {
  const LeaderboardUser({
    required this.userId,
    required this.fullName,
    required this.coin,
    this.avatarUrl,
  });

  final String userId;
  final String fullName;
  final int coin;
  final String? avatarUrl;

  factory LeaderboardUser.fromMap(Map<String, dynamic> map) {
    return LeaderboardUser(
      userId: map['user_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? 'Thành viên Astatine',
      coin: (map['coin'] is num)
          ? (map['coin'] as num).toInt()
          : int.tryParse(map['coin']?.toString() ?? '0') ?? 0,
      avatarUrl: map['avatar_url']?.toString(),
    );
  }
}

class _CoinLeaderboardTab extends StatefulWidget {
  final bool isVietnamese;
  final AstatinePalette palette;

  const _CoinLeaderboardTab({
    required this.isVietnamese,
    required this.palette,
  });

  @override
  State<_CoinLeaderboardTab> createState() => _CoinLeaderboardTabState();
}

class _CoinLeaderboardTabState extends State<_CoinLeaderboardTab> {
  late Future<List<LeaderboardUser>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = _fetchLeaderboard();
  }

  Future<List<LeaderboardUser>> _fetchLeaderboard() async {
    try {
      final client = Supabase.instance.client;
      final response = await client.rpc(
        'get_coin_leaderboard',
        params: {'p_limit': 50},
      );
      if (response is List) {
        return response
            .map(
              (item) => LeaderboardUser.fromMap(item as Map<String, dynamic>),
            )
            .toList();
      }
      throw StateError('get_coin_leaderboard returned an invalid response.');
    } catch (error) {
      debugPrint('Error fetching coin leaderboard: $error');
      rethrow;
    }
  }

  Future<void> _refresh() async {
    final request = _fetchLeaderboard();
    setState(() {
      _leaderboardFuture = request;
    });
    try {
      await request;
    } catch (_) {
      // FutureBuilder displays the request error and the retry action.
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final vi = widget.isVietnamese;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return FutureBuilder<List<LeaderboardUser>>(
      future: _leaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _LeaderboardLoading(
            palette: p,
            label: vi ? 'Đang tải bảng xếp hạng COIN' : 'Loading COIN rankings',
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 40, color: p.accent),
                  const Gap(12),
                  Text(
                    vi
                        ? 'Bảng xếp hạng chưa tải được'
                        : 'Leaderboard could not be loaded',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.canvasText,
                    ),
                  ),
                  const Gap(8),
                  const Gap(16),
                  ElevatedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(vi ? 'Tải lại' : 'Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.military_tech_outlined,
                  size: 48,
                  color: p.secondaryText,
                ),
                const Gap(12),
                Text(
                  vi ? 'Chưa có dữ liệu xếp hạng COIN' : 'No COIN rankings yet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: p.canvasText,
                  ),
                ),
              ],
            ),
          );
        }

        final top3 = users.take(3).toList();
        final rest = users.skip(3).toList();

        int? currentUserRank;
        LeaderboardUser? currentUserEntry;
        if (currentUserId != null) {
          for (int i = 0; i < users.length; i++) {
            if (users[i].userId == currentUserId) {
              currentUserRank = i + 1;
              currentUserEntry = users[i];
              break;
            }
          }
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          color: p.accent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _LeaderboardOverview(
                    palette: p,
                    isVietnamese: vi,
                    entriesCount: users.length,
                    currentUserRank: currentUserRank,
                    currentUser: currentUserEntry,
                  ),
                  const Gap(24),
                  _LeaderboardSectionHeader(
                    icon: Icons.workspace_premium_rounded,
                    title: vi ? 'DẪN ĐẦU BẢNG XẾP HẠNG' : 'THE COIN LEADERS',
                    subtitle: vi
                        ? 'Ba vị trí cao nhất hiện tại'
                        : 'The top three right now',
                    palette: p,
                  ),
                  const Gap(14),
                  _Top3PodiumSection(top3: top3, palette: p, isVietnamese: vi),
                  const Gap(28),
                  _LeaderboardSectionHeader(
                    icon: Icons.format_list_numbered_rounded,
                    title: vi ? 'BẢNG XẾP HẠNG' : 'RANKINGS',
                    subtitle: vi
                        ? 'Tối đa 50 người có số dư COIN cao nhất'
                        : 'Up to 50 members with the highest COIN balance',
                    palette: p,
                  ),
                  const Gap(12),
                  if (rest.isEmpty)
                    _LeaderboardShortList(palette: p, isVietnamese: vi)
                  else
                    for (var index = 0; index < rest.length; index++) ...[
                      _LeaderboardRowCard(
                        rank: index + 4,
                        user: rest[index],
                        isCurrent: rest[index].userId == currentUserId,
                        palette: p,
                        isVietnamese: vi,
                      ),
                      if (index != rest.length - 1) const Gap(8),
                    ],
                  if (currentUserEntry != null && currentUserRank != null) ...[
                    const Gap(24),
                    _StickyUserRow(
                      rank: currentUserRank,
                      user: currentUserEntry,
                      palette: p,
                      isVietnamese: vi,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LeaderboardOverview extends StatelessWidget {
  const _LeaderboardOverview({
    required this.palette,
    required this.isVietnamese,
    required this.entriesCount,
    required this.currentUserRank,
    required this.currentUser,
  });

  final AstatinePalette palette;
  final bool isVietnamese;
  final int entriesCount;
  final int? currentUserRank;
  final LeaderboardUser? currentUser;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          palette.card,
          Color.alphaBlend(palette.accent.withValues(alpha: 0.1), palette.card),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: palette.border.withValues(alpha: 0.7)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.toll_rounded, color: palette.accent, size: 23),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVietnamese ? 'ĐƯỜNG ĐUA COIN' : 'COIN LEADERBOARD',
                    style: TextStyle(
                      color: palette.secondaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Gap(3),
                  Text(
                    isVietnamese
                        ? 'Vinh danh người dẫn đầu'
                        : 'The top earners',
                    style: TextStyle(
                      color: palette.canvasText,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Gap(20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _LeaderboardStat(
              icon: Icons.groups_rounded,
              label: isVietnamese ? 'ĐANG XẾP HẠNG' : 'RANKED MEMBERS',
              value: '$entriesCount',
              palette: palette,
            ),
            _LeaderboardStat(
              icon: Icons.flag_rounded,
              label: isVietnamese ? 'HẠNG CỦA BẠN' : 'YOUR RANK',
              value: currentUserRank == null ? '—' : '#$currentUserRank',
              palette: palette,
              emphasized: true,
            ),
          ],
        ),
        if (currentUser != null) ...[
          const Gap(14),
          Row(
            children: [
              Icon(
                Icons.account_circle_outlined,
                size: 16,
                color: palette.secondaryText,
              ),
              const Gap(7),
              Expanded(
                child: Text(
                  currentUser!.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Gap(8),
              Icon(Icons.toll_rounded, size: 15, color: palette.accent),
              const Gap(5),
              Text(
                _formatCoinBalance(
                  currentUser!.coin,
                  isVietnamese: isVietnamese,
                ),
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _LeaderboardStat extends StatelessWidget {
  const _LeaderboardStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.palette,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final AstatinePalette palette;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 140),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: emphasized
          ? palette.accent.withValues(alpha: 0.12)
          : palette.background.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
        color: emphasized
            ? palette.accent.withValues(alpha: 0.35)
            : palette.border.withValues(alpha: 0.65),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: emphasized ? palette.accent : palette.secondaryText,
        ),
        const Gap(9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: palette.secondaryText,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const Gap(2),
            Text(
              value,
              style: TextStyle(
                color: emphasized ? palette.accent : palette.canvasText,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _LeaderboardSectionHeader extends StatelessWidget {
  const _LeaderboardSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.palette,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AstatinePalette palette;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: palette.accent),
      ),
      const Gap(10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: palette.canvasText,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
            const Gap(3),
            Text(
              subtitle,
              style: TextStyle(color: palette.secondaryText, fontSize: 11),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LeaderboardShortList extends StatelessWidget {
  const _LeaderboardShortList({
    required this.palette,
    required this.isVietnamese,
  });

  final AstatinePalette palette;
  final bool isVietnamese;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    decoration: BoxDecoration(
      color: palette.card.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: palette.border.withValues(alpha: 0.6)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.auto_awesome_outlined,
          color: palette.secondaryText,
          size: 19,
        ),
        const Gap(10),
        Expanded(
          child: Text(
            isVietnamese
                ? 'Bảng xếp hạng sẽ sôi động hơn khi có thêm thành viên.'
                : 'The rankings will grow as more members join.',
            style: TextStyle(color: palette.secondaryText, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _LeaderboardLoading extends StatelessWidget {
  const _LeaderboardLoading({required this.palette, required this.label});

  final AstatinePalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    final shimmer = palette.accent.withValues(alpha: 0.08);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                label: label,
                child: ExcludeSemantics(
                  child: Container(
                    height: 128,
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              const Gap(18),
              Row(
                children: List.generate(
                  3,
                  (_) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: 144,
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(shimmer, palette.card),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
              const Gap(18),
              for (var index = 0; index < 4; index++) ...[
                Container(
                  height: 62,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(shimmer, palette.card),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const Gap(9),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatCoinBalance(int balance, {required bool isVietnamese}) {
  final digits = balance.abs().toString();
  final separator = isVietnamese ? '.' : ',';
  final formatted = StringBuffer();
  if (balance < 0) formatted.write('-');
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      formatted.write(separator);
    }
    formatted.write(digits[index]);
  }
  return formatted.toString();
}

class _Top3PodiumSection extends StatelessWidget {
  final List<LeaderboardUser> top3;
  final AstatinePalette palette;
  final bool isVietnamese;

  const _Top3PodiumSection({
    required this.top3,
    required this.palette,
    required this.isVietnamese,
  });

  @override
  Widget build(BuildContext context) {
    final rank1 = top3.isNotEmpty ? top3[0] : null;
    final rank2 = top3.length > 1 ? top3[1] : null;
    final rank3 = top3.length > 2 ? top3[2] : null;

    final podium = [
      (rank: 2, user: rank2, color: const Color(0xFFC0C0C0)),
      (rank: 1, user: rank1, color: const Color(0xFFFFD36A)),
      (rank: 3, user: rank3, color: const Color(0xFFCD9A72)),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < podium.length; index++) ...[
          if (index > 0) const Gap(9),
          Expanded(
            child: podium[index].user == null
                ? const SizedBox.shrink()
                : _PodiumCard(
                    rank: podium[index].rank,
                    user: podium[index].user!,
                    badgeColor: podium[index].color,
                    isHighest: podium[index].rank == 1,
                    palette: palette,
                    isVietnamese: isVietnamese,
                  ),
          ),
        ],
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final int rank;
  final LeaderboardUser user;
  final Color badgeColor;
  final AstatinePalette palette;
  final bool isVietnamese;
  final bool isHighest;

  const _PodiumCard({
    required this.rank,
    required this.user,
    required this.badgeColor,
    required this.palette,
    required this.isVietnamese,
    this.isHighest = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      decoration: BoxDecoration(
        color: isHighest
            ? Color.alphaBlend(badgeColor.withValues(alpha: 0.1), p.card)
            : p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighest
              ? badgeColor.withValues(alpha: 0.65)
              : p.border.withValues(alpha: 0.5),
          width: isHighest ? 1.7 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: p.canvasText,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const Gap(12),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.border,
              border: Border.all(color: badgeColor, width: 1.8),
            ),
            child: ClipOval(
              child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? Image.network(
                      user.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _buildInitialsAvatar(user.fullName, p),
                    )
                  : _buildInitialsAvatar(user.fullName, p),
            ),
          ),
          const Gap(10),
          Text(
            user.fullName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: p.canvasText,
            ),
          ),
          const Gap(8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.toll_rounded, size: 13, color: badgeColor),
                const Gap(4),
                Text(
                  _formatCoinBalance(user.coin, isVietnamese: isVietnamese),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: p.canvasText,
                  ),
                ),
              ],
            ),
          ),
          const Gap(3),
          Text(
            isVietnamese ? 'COIN' : 'COIN',
            style: TextStyle(
              color: p.secondaryText,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(String name, AstatinePalette p) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: isHighest ? 22 : 16,
          fontWeight: FontWeight.w800,
          color: p.canvasText,
        ),
      ),
    );
  }
}

class _LeaderboardRowCard extends StatelessWidget {
  final int rank;
  final LeaderboardUser user;
  final bool isCurrent;
  final AstatinePalette palette;
  final bool isVietnamese;

  const _LeaderboardRowCard({
    required this.rank,
    required this.user,
    required this.isCurrent,
    required this.palette,
    required this.isVietnamese,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: isCurrent
            ? Color.alphaBlend(p.accent.withValues(alpha: 0.1), p.card)
            : p.card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: isCurrent
              ? p.accent.withValues(alpha: 0.6)
              : p.border.withValues(alpha: 0.55),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCurrent
                  ? p.accent.withValues(alpha: 0.18)
                  : p.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isCurrent ? p.accent : p.secondaryText,
              ),
            ),
          ),
          const Gap(11),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.border,
              border: Border.all(color: p.border.withValues(alpha: 0.8)),
            ),
            child: ClipOval(
              child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? Image.network(
                      user.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _initials(user.fullName, p),
                    )
                  : _initials(user.fullName, p),
            ),
          ),
          const Gap(11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: p.canvasText,
                  ),
                ),
                if (isCurrent) ...[
                  const Gap(3),
                  Text(
                    isVietnamese ? 'BẠN ĐANG Ở ĐÂY' : 'YOUR POSITION',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: p.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap(8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.toll_rounded, size: 15, color: p.accent),
              const Gap(5),
              Text(
                _formatCoinBalance(user.coin, isVietnamese: isVietnamese),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: p.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initials(String name, AstatinePalette p) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: p.canvasText,
        ),
      ),
    );
  }
}

class _StickyUserRow extends StatelessWidget {
  final int rank;
  final LeaderboardUser user;
  final AstatinePalette palette;
  final bool isVietnamese;

  const _StickyUserRow({
    required this.rank,
    required this.user,
    required this.palette,
    required this.isVietnamese,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.accent, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: p.accent.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111111),
              ),
            ),
          ),
          const Gap(12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.border),
            child: ClipOval(
              child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? Image.network(
                      user.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _initials(user.fullName, p),
                    )
                  : _initials(user.fullName, p),
            ),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isVietnamese ? 'Xếp hạng của bạn' : 'Your Ranking',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: p.secondaryText,
                  ),
                ),
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: p.canvasText,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 13)),
              const Gap(6),
              Text(
                '${user.coin}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: p.accent,
                ),
              ),
              const Gap(2),
              Text(
                'Coin',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: p.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initials(String name, AstatinePalette p) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: p.canvasText,
        ),
      ),
    );
  }
}
