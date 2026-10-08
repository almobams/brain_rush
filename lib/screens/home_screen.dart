import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/store.dart';
import '../game/models.dart';
import '../localization/strings.dart';
import '../localization/languages.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/effects.dart';
import '../backend/daily_ranking_service.dart';
import '../monetization/purchase_service.dart';
import '../widgets/daily_rank_panel.dart';
import '../widgets/daily_attempt_indicator.dart';
import 'game_screen.dart';
import 'secondary_screens.dart';
import 'premium_screen.dart';

void openScreen(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshRank();
    });
  }

  void _refreshRank() {
    final result = ref.read(storeProvider).daily[dateKey(DateTime.now())];
    if (result != null) {
      unawaited(ref.read(dailyRankingProvider).refresh(result));
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      nextDay.difference(now) + const Duration(seconds: 1),
      () {
        if (mounted) setState(() {});
        _scheduleMidnightRefresh();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleMidnightRefresh();
      _refreshRank();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final ranking = ref.watch(dailyRankingProvider);
    final purchases = ref.watch(purchaseServiceProvider);
    final text = Theme.of(context).textTheme;
    final compact = MediaQuery.sizeOf(context).height < 700;
    final today = store.daily[dateKey(DateTime.now())];
    final attemptsUsed = store.dailyStatus(DateTime.now()).attemptsUsed;
    final startButton = Pulse(
      child: GamePrimaryButton(
        label: context.tr('start'),
        onPressed: () =>
            openScreen(context, const GameScreen(mode: GameMode.rush)),
      ),
    );
    return RushScaffold(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, compact ? 8 : 20, 24, 24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: mint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('eyebrow'),
                    style: text.labelSmall?.copyWith(letterSpacing: 1.7),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('settings'),
                  onPressed: () => openScreen(context, const SettingsScreen()),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            SizedBox(height: compact ? 0 : 8),
            BrainEmblem(size: compact ? 100 : 150),
            SizedBox(height: compact ? 0 : 8),
            Text(
              context.tr('sixty'),
              style: text.titleLarge?.copyWith(
                letterSpacing: AppLanguages.isRtl(store.language) ? 0 : 5,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              context.tr('brand'),
              textAlign: TextAlign.center,
              style: text.displaySmall?.copyWith(
                fontSize: compact ? 38 : 46,
                letterSpacing: AppLanguages.isRtl(store.language) ? 0 : -2,
              ),
            ),
            if (store.playerName != null) ...[
              const SizedBox(height: 6),
              Text(
                context
                    .tr('readyNamed')
                    .replaceAll('{name}', store.playerName!),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(color: energyCyan),
              ),
            ],
            SizedBox(height: compact ? 12 : 18),
            LevelProgress(totalXp: store.stats.totalXp),
            SizedBox(height: compact ? 12 : 18),
            startButton,
            const SizedBox(height: 6),
            Text(context.tr('sixty'), style: text.labelSmall),
            SizedBox(height: compact ? 14 : 24),
            BrainCard(
              padding: const EdgeInsets.all(16),
              accent: violet,
              child: InkWell(
                onTap: () => openScreen(context, const DailyScreen()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: violet),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('daily'),
                            style: text.titleMedium,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (today != null) ...[
                      DailyRankPanel(
                        rank: ranking.rankFor(today.date),
                        localBest: today.score,
                        loading: ranking.loadingFor(today.date),
                        unavailable: ranking.unavailableFor(today.date),
                        playerName: store.playerName,
                        compact: true,
                        embedded: true,
                      ),
                      const SizedBox(height: 8),
                    ],
                    DailyAttemptIndicator(
                      attemptsUsed: attemptsUsed,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: context.tr('best'),
                    value: '${store.stats.bestScore}',
                    icon: Icons.emoji_events_outlined,
                    color: mint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: context.tr('dailyStreak'),
                    value: Strings.of(context)
                        .dayCount(store.currentDailyStreak),
                    icon: Icons.local_fire_department_outlined,
                    color: streakAmber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                key: const Key('homeStatsShortcut'),
                onPressed: () => openScreen(context, const StatisticsScreen()),
                icon: const Icon(Icons.bar_chart_rounded),
                label: Text(context.tr('statistics')),
              ),
            ),
            if (!purchases.owned) ...[
              const SizedBox(height: 14),
              BrainCard(
                key: const Key('homeRemoveAds'),
                padding: const EdgeInsets.all(16),
                child: InkWell(
                  onTap: () => openScreen(context, const PremiumScreen()),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: violet),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('premium'),
                              style: text.titleMedium,
                            ),
                            Text(
                              context.tr('premiumDetail'),
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('explore'),
                        style: text.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (store.saveFailed)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(context.tr('saveError')),
              ),
          ],
        ),
      ),
    );
  }
}
