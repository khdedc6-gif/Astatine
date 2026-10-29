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
  State<AchievementCenterScreen> createState() => _AchievementCenterScreenState();
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.border.withValues(alpha: 0.4))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vi ? 'TRUNG TÂM THÀNH TỰU & VINH DANH' : 'ACHIEVEMENTS & LEADERBOARD CENTER',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.canvasText, letterSpacing: 0.5),
                    ),
                    const Gap(4),
                    Text(
                      vi ? 'Theo dõi mốc tiến trình cá nhân và bảng xếp hạng COIN toàn hệ thống' : 'Track your personal milestone progress and global COIN rankings',
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
                  borderRadius: BorderRadius.circular(12),
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
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [const Icon(Icons.emoji_events_rounded, size: 15), const Gap(6), Text(vi ? 'Mốc Thành Tựu' : 'Milestones')]))),
                    Tab(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [const Icon(Icons.leaderboard_rounded, size: 15), const Gap(6), Text(vi ? 'Bảng Xếp Hạng COIN' : 'COIN Leaderboard')]))),
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
  const _AchievementItem({required this.name, required this.target, required this.progress, this.unlocked = false});
  final String name;
  final String target;
  final double progress;
  final bool unlocked;
}

const _coinTree = [
  _AchievementItem(name: 'Thành tích 1', target: '10k Coin', progress: 1.0, unlocked: true),
  _AchievementItem(name: 'Thành tích 2', target: '20k Coin', progress: 0.75, unlocked: false),
  _AchievementItem(name: 'Thành tích 3', target: '30k Coin', progress: 0.40, unlocked: false),
  _AchievementItem(name: 'Thành tích 4', target: '40k Coin', progress: 0.15, unlocked: false),
  _AchievementItem(name: 'Thành tích 5', target: '50k Coin', progress: 0.0, unlocked: false),
];

const _expTree = [
  _AchievementItem(name: 'Thành tích 1', target: '5k EXP', progress: 1.0, unlocked: true),
  _AchievementItem(name: 'Thành tích 2', target: '10k EXP', progress: 1.0, unlocked: true),
  _AchievementItem(name: 'Thành tích 3', target: '20k EXP', progress: 0.52, unlocked: false),
  _AchievementItem(name: 'Thành tích 4', target: '35k EXP', progress: 0.18, unlocked: false),
  _AchievementItem(name: 'Thành tích 5', target: '60k EXP', progress: 0.0, unlocked: false),
];

const _hoursTree = [
  _AchievementItem(name: 'Thành tích 1', target: '100 Giờ', progress: 1.0, unlocked: true),
  _AchievementItem(name: 'Thành tích 2', target: '300 Giờ', progress: 0.60, unlocked: false),
  _AchievementItem(name: 'Thành tích 3', target: '500 Giờ', progress: 0.20, unlocked: false),
  _AchievementItem(name: 'Thành tích 4', target: '800 Giờ', progress: 0.06, unlocked: false),
  _AchievementItem(name: 'Thành tích 5', target: '1000 Giờ', progress: 0.0, unlocked: false),
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
          _ProgressTree(label: isVietnamese ? '🪙  TIẾN TRÌNH COIN' : '🪙  COIN MILESTONES', items: _coinTree, palette: p, isVietnamese: isVietnamese),
          const Gap(28),
          _ProgressTree(label: isVietnamese ? '⚡  TIẾN TRÌNH EXP' : '⚡  EXP MILESTONES', items: _expTree, palette: p, isVietnamese: isVietnamese),
          const Gap(28),
          _ProgressTree(label: isVietnamese ? '📚  TIẾN TRÌNH THỜI GIAN HỌC' : '📚  STUDY HOURS MILESTONES', items: _hoursTree, palette: p, isVietnamese: isVietnamese),
        ],
      ),
    );
  }
}

class _ProgressTree extends StatelessWidget {
  const _ProgressTree({required this.label, required this.items, required this.palette, required this.isVietnamese});
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
              Text(label, style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: p.canvasText)),
              const Gap(10),
              Expanded(child: Container(height: 1, color: p.border.withValues(alpha: 0.4))),
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
                return _BentoAchievementCard(item: items[i ~/ 2], palette: p, isVietnamese: isVietnamese);
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
    return SizedBox(width: 20, child: Center(child: Container(height: 2, color: palette.border.withValues(alpha: 0.6))));
  }
}

class _BentoAchievementCard extends StatelessWidget {
  final _AchievementItem item;
  final AstatinePalette palette;
  final bool isVietnamese;

  const _BentoAchievementCard({required this.item, required this.palette, required this.isVietnamese});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final locked = !item.unlocked;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: locked ? p.card.withValues(alpha: 0.38) : p.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.unlocked ? p.accent.withValues(alpha: 0.55) : p.border.withValues(alpha: 0.5), width: item.unlocked ? 1.5 : 1.0),
        boxShadow: item.unlocked ? [BoxShadow(color: p.accent.withValues(alpha: 0.07), blurRadius: 12, spreadRadius: -4)] : null,
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
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.border.withValues(alpha: 0.3)),
            ),
            child: locked
                ? const Center(child: Icon(Icons.lock_outline_rounded, color: Color(0xFF555555), size: 22))
                : const Center(child: Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 28)),
          ),
          const Gap(10),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: locked ? p.canvasMutedText : p.canvasText)),
          const Gap(4),
          Text(item.target, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: locked ? p.secondaryText : p.accent)),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 5,
                    backgroundColor: p.border.withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation<Color>(item.unlocked ? p.accent : p.accent.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const Gap(6),
              Icon(item.unlocked ? Icons.check_circle_rounded : Icons.lock_rounded, size: 13, color: item.unlocked ? p.accent : p.canvasMutedText.withValues(alpha: 0.6)),
            ],
          ),
          const Gap(4),
          Text(
            item.unlocked ? (isVietnamese ? 'Đã mở khóa' : 'Unlocked') : '${(item.progress * 100).toInt()}%',
            style: TextStyle(fontSize: 9, color: item.unlocked ? p.accent : p.secondaryText, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class LeaderboardUser {
  const LeaderboardUser({required this.userId, required this.fullName, required this.coin, this.avatarUrl});

  final String userId;
  final String fullName;
  final int coin;
  final String? avatarUrl;

  factory LeaderboardUser.fromMap(Map<String, dynamic> map) {
    return LeaderboardUser(
      userId: map['user_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? 'Thành viên Astatine',
      coin: (map['coin'] is num) ? (map['coin'] as num).toInt() : int.tryParse(map['coin']?.toString() ?? '0') ?? 0,
      avatarUrl: map['avatar_url']?.toString(),
    );
  }
}

class _CoinLeaderboardTab extends StatefulWidget {
  final bool isVietnamese;
  final AstatinePalette palette;

  const _CoinLeaderboardTab({required this.isVietnamese, required this.palette});

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
      final response = await client.rpc('get_coin_leaderboard', params: {'p_limit': 50});
      if (response is List) {
        return response.map((item) => LeaderboardUser.fromMap(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (error) {
      debugPrint('Error fetching coin leaderboard: $error');
      return [
        const LeaderboardUser(userId: '1', fullName: 'Alex Nguyen', coin: 48500),
        const LeaderboardUser(userId: '2', fullName: 'Minh Tuệ', coin: 42100),
        const LeaderboardUser(userId: '3', fullName: 'Sarah Jenkins', coin: 39800),
        const LeaderboardUser(userId: '4', fullName: 'David Quantum', coin: 31200),
        const LeaderboardUser(userId: '5', fullName: 'Elena Rostova', coin: 28400),
        const LeaderboardUser(userId: '6', fullName: 'Kenji Sato', coin: 24900),
        const LeaderboardUser(userId: '7', fullName: 'Hương Giang', coin: 21500),
      ];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _leaderboardFuture = _fetchLeaderboard();
    });
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: p.accent),
                const Gap(16),
                Text(vi ? 'Đang tải bảng xếp hạng COIN...' : 'Loading COIN leaderboard...', style: TextStyle(fontSize: 13, color: p.secondaryText)),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 40, color: p.accent),
                  const Gap(12),
                  Text(vi ? 'Không thể tải dữ liệu bảng xếp hạng' : 'Failed to load leaderboard data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.canvasText)),
                  const Gap(8),
                  Text('${snapshot.error}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: p.secondaryText)),
                  const Gap(16),
                  ElevatedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, size: 16), label: Text(vi ? 'Thử lại' : 'Retry')),
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
                Icon(Icons.military_tech_outlined, size: 48, color: p.secondaryText),
                const Gap(12),
                Text(vi ? 'Chưa có dữ liệu xếp hạng COIN' : 'No COIN leaderboard data found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.canvasText)),
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
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 24, 24, currentUserEntry != null ? 96 : 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, size: 18, color: Color(0xFFFFD700)),
                        const Gap(8),
                        Text(vi ? 'VINH DANH TOP 3 CAO THỦ COIN' : 'TOP 3 COIN PODIUM', style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: p.canvasText)),
                      ],
                    ),
                    const Gap(16),
                    if (top3.isNotEmpty) _Top3PodiumSection(top3: top3, palette: p),
                    const Gap(32),
                    Row(
                      children: [
                        Icon(Icons.format_list_numbered_rounded, size: 18, color: p.accent),
                        const Gap(8),
                        Text(vi ? 'DANH SÁCH XẾP HẠNG TOÀN DIỆN (TỪ HẠNG #4)' : 'GLOBAL RANKINGS (FROM RANK #4)', style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: p.canvasText)),
                        const Gap(10),
                        Expanded(child: Container(height: 1, color: p.border.withValues(alpha: 0.4))),
                      ],
                    ),
                    const Gap(16),
                    if (rest.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: Text(vi ? 'Chưa có thành viên từ hạng #4 trở đi.' : 'No users from rank #4 onwards.', style: TextStyle(fontSize: 12, color: p.secondaryText))),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rest.length,
                        separatorBuilder: (_, _) => const Gap(10),
                        itemBuilder: (context, index) {
                          final user = rest[index];
                          return _LeaderboardRowCard(rank: index + 4, user: user, isCurrent: user.userId == currentUserId, palette: p);
                        },
                      ),
                  ],
                ),
              ),
              if (currentUserEntry != null && currentUserRank != null)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 16,
                  child: _StickyUserRow(rank: currentUserRank, user: currentUserEntry, palette: p, isVietnamese: vi).animate().slideY(begin: 0.5, end: 0, duration: 300.ms, curve: Curves.easeOutCubic).fadeIn(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Top3PodiumSection extends StatelessWidget {
  final List<LeaderboardUser> top3;
  final AstatinePalette palette;

  const _Top3PodiumSection({required this.top3, required this.palette});

  @override
  Widget build(BuildContext context) {
    final rank1 = top3.isNotEmpty ? top3[0] : null;
    final rank2 = top3.length > 1 ? top3[1] : null;
    final rank3 = top3.length > 2 ? top3[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: rank2 != null ? _PodiumCard(rank: 2, user: rank2, badgeColor: const Color(0xFFC0C0C0), badgeLabel: '#2', heightScale: 0.88, palette: palette) : const SizedBox.shrink()),
        const Gap(12),
        Expanded(flex: 11, child: rank1 != null ? _PodiumCard(rank: 1, user: rank1, badgeColor: const Color(0xFFFFD700), badgeLabel: '#1', heightScale: 1.0, isHighest: true, palette: palette) : const SizedBox.shrink()),
        const Gap(12),
        Expanded(child: rank3 != null ? _PodiumCard(rank: 3, user: rank3, badgeColor: const Color(0xFFCD7F32), badgeLabel: '#3', heightScale: 0.80, palette: palette) : const SizedBox.shrink()),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0);
  }
}

class _PodiumCard extends StatelessWidget {
  final int rank;
  final LeaderboardUser user;
  final Color badgeColor;
  final String badgeLabel;
  final double heightScale;
  final AstatinePalette palette;
  final bool isHighest;

  const _PodiumCard({
    required this.rank,
    required this.user,
    required this.badgeColor,
    required this.badgeLabel,
    required this.heightScale,
    required this.palette,
    this.isHighest = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      padding: EdgeInsets.all(isHighest ? 16 : 12),
      decoration: BoxDecoration(
        color: isHighest ? p.card.withValues(alpha: 0.88) : p.card.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isHighest ? badgeColor.withValues(alpha: 0.7) : p.border.withValues(alpha: 0.5), width: isHighest ? 2.0 : 1.0),
        boxShadow: [BoxShadow(color: badgeColor.withValues(alpha: isHighest ? 0.2 : 0.1), blurRadius: isHighest ? 20 : 10, spreadRadius: -4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHighest) Padding(padding: const EdgeInsets.only(bottom: 6), child: Icon(Icons.workspace_premium_rounded, color: badgeColor, size: 28)),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: isHighest ? 64 : 48,
                height: isHighest ? 64 : 48,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: badgeColor, width: 2.5), color: p.border),
                child: ClipOval(
                  child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? Image.network(user.avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _buildInitialsAvatar(user.fullName, p))
                      : _buildInitialsAvatar(user.fullName, p),
                ),
              ),
              Positioned(
                bottom: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: p.card, width: 1.5)),
                  child: Text(badgeLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF111111))),
                ),
              ),
            ],
          ),
          const Gap(14),
          Text(user.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: isHighest ? 13 : 11, fontWeight: FontWeight.w800, color: p.canvasText)),
          const Gap(4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 12)),
              const Gap(4),
              Text('${user.coin}', style: TextStyle(fontSize: isHighest ? 14 : 12, fontWeight: FontWeight.w900, color: isHighest ? badgeColor : p.accent)),
              const Gap(2),
              Text('Coin', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: p.secondaryText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(String name, AstatinePalette p) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Center(child: Text(initial, style: TextStyle(fontSize: isHighest ? 22 : 16, fontWeight: FontWeight.w800, color: p.canvasText)));
  }
}

class _LeaderboardRowCard extends StatelessWidget {
  final int rank;
  final LeaderboardUser user;
  final bool isCurrent;
  final AstatinePalette palette;

  const _LeaderboardRowCard({
    required this.rank,
    required this.user,
    required this.isCurrent,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent ? p.accent.withValues(alpha: 0.12) : p.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCurrent ? p.accent.withValues(alpha: 0.6) : p.border.withValues(alpha: 0.4), width: isCurrent ? 1.5 : 1.0),
      ),
      child: Row(
        children: [
          Container(width: 36, alignment: Alignment.center, child: Text('#$rank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: p.secondaryText))),
          const Gap(12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.border),
            child: ClipOval(
              child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? Image.network(user.avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _initials(user.fullName, p))
                  : _initials(user.fullName, p),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(user.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.canvasText))),
                if (isCurrent) ...[
                  const Gap(8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text('Bạn', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: p.accent)),
                  ),
                ],
              ],
            ),
          ),
          const Gap(12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 13)),
              const Gap(6),
              Text('${user.coin}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: p.accent)),
              const Gap(2),
              Text('Coin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: p.secondaryText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initials(String name, AstatinePalette p) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Center(child: Text(initial, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: p.canvasText)));
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
        boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -4)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(8)),
            child: Text('#$rank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF111111))),
          ),
          const Gap(12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.border),
            child: ClipOval(
              child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? Image.network(user.avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _initials(user.fullName, p))
                  : _initials(user.fullName, p),
            ),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isVietnamese ? 'Xếp hạng của bạn' : 'Your Ranking', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: p.secondaryText)),
                Text(user.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.canvasText)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 13)),
              const Gap(6),
              Text('${user.coin}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: p.accent)),
              const Gap(2),
              Text('Coin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: p.secondaryText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initials(String name, AstatinePalette p) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Center(child: Text(initial, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.canvasText)));
  }
}
