import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/store.dart';
import '../game/models.dart';
import '../game/progression.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/daily_attempt_indicator.dart';
import 'game_screen.dart';
import '../monetization/ad_service.dart';
import '../monetization/purchase_service.dart';
import 'premium_screen.dart';
import '../backend/daily_ranking_service.dart';
import '../widgets/daily_rank_panel.dart';
import '../localization/languages.dart';
import 'onboarding_screen.dart';
import '../reminders/daily_reminder_service.dart';
import '../reminders/reminder_strings.dart';
import '../sharing/result_share_data.dart';
import '../sharing/result_share_service.dart';
import '../support/help_support_section.dart';

class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({super.key});
  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;
  bool _requestingReward = false;
  bool _sharing = false;
  String? _messageKey;

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
    final now = DateTime.now();
    final result = ref.read(storeProvider).daily[dateKey(now)];
    if (result != null) {
      unawaited(ref.read(dailyRankingProvider).refresh(result));
    }
  }

  Future<void> _shareToday() async {
    if (_sharing) return;
    final date = dateKey(DateTime.now());
    final result = ref.read(storeProvider).daily[date];
    if (result == null || !result.completed || result.attemptsUsed == 0) {
      return;
    }
    setState(() => _sharing = true);
    try {
      final ranking = ref.read(dailyRankingProvider);
      await ranking.refreshRankOnly(result);
      if (!mounted || dateKey(DateTime.now()) != date) return;
      final store = ref.read(storeProvider);
      final latest = store.daily[date];
      if (latest == null || !latest.completed || latest.attemptsUsed == 0) {
        return;
      }
      await ref
          .read(resultShareServiceProvider)
          .share(
            context,
            ResultShareData.daily(
              result: latest,
              rank: ranking.rankFor(date),
              playerName: store.playerName,
            ),
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('shareUnavailable'))));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      nextDay.difference(now) + const Duration(seconds: 1),
      () {
        if (mounted) setState(() => _messageKey = null);
        _scheduleMidnightRefresh();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _messageKey = null);
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

  void _openGame() => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => const GameScreen(mode: GameMode.daily),
    ),
  );

  Future<void> _startOrUnlock() async {
    if (_requestingReward) return;
    final now = DateTime.now();
    final store = ref.read(storeProvider);
    final purchases = ref.read(purchaseServiceProvider);
    if (store.canStartDaily(now, removeAdsOwned: purchases.owned)) {
      _openGame();
      return;
    }
    if (store.dailyStatus(now).attemptsRemaining == 0) return;
    if (purchases.loading) {
      setState(() => _messageKey = 'purchaseChecking');
      return;
    }
    setState(() {
      _requestingReward = true;
      _messageKey = null;
    });
    final earned = await ref.read(adServiceProvider).showRewarded();
    if (!mounted) return;
    if (dateKey(DateTime.now()) != dateKey(now)) {
      setState(() {
        _requestingReward = false;
        _messageKey = null;
      });
      return;
    }
    final unlocked = earned && await store.unlockDailyRetry(now);
    if (!mounted) return;
    setState(() {
      _requestingReward = false;
      _messageKey = unlocked
          ? null
          : ref.read(adServiceProvider).rewardedReady
          ? 'retryNotEarned'
          : 'adUnavailable';
    });
    if (unlocked) _openGame();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final purchases = ref.watch(purchaseServiceProvider);
    final ads = ref.watch(adServiceProvider);
    final ranking = ref.watch(dailyRankingProvider);
    final now = DateTime.now();
    final result = store.daily[dateKey(now)];
    final status = store.dailyStatus(now);
    final remaining = status.attemptsRemaining;
    final canStart = store.canStartDaily(now, removeAdsOwned: purchases.owned);
    final needsReward =
        status.attemptsUsed > 0 && !canStart && !purchases.owned;
    final text = Theme.of(context).textTheme;
    final compact = MediaQuery.sizeOf(context).height < 700;
    return RushScaffold(
      title: context.tr('daily'),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, compact ? 12 : 24, 20, 24),
        child: Column(
          children: [
            Text(
              MaterialLocalizations.of(context).formatMediumDate(now),
              textAlign: TextAlign.center,
              style: text.headlineMedium,
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              context.tr('dailyDetail'),
              textAlign: TextAlign.center,
              style: text.bodyLarge,
            ),
            SizedBox(height: compact ? 16 : 22),
            DailyAttemptIndicator(attemptsUsed: status.attemptsUsed),
            if (result != null) ...[
              SizedBox(height: compact ? 16 : 22),
              DailyRankPanel(
                rank: ranking.rankFor(dateKey(now)),
                localBest: result.score,
                loading: ranking.loadingFor(dateKey(now)),
                unavailable: ranking.unavailableFor(dateKey(now)),
                playerName: store.playerName,
                onRefresh: _refreshRank,
              ),
              if (result.completed && result.attemptsUsed > 0) ...[
                SizedBox(height: compact ? 8 : 12),
                OutlinedButton.icon(
                  key: const Key('shareDailyResultButton'),
                  onPressed: _sharing ? null : _shareToday,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(context.tr('share')),
                ),
              ],
            ],
            SizedBox(height: compact ? 20 : 28),
            if (remaining > 0) ...[
              if (status.attemptsUsed > 0) ...[
                Text(context.tr('retryDaily'), style: text.titleMedium),
                const SizedBox(height: 12),
              ],
              GamePrimaryButton(
                label: context.tr(
                  status.attemptsUsed == 0
                      ? 'playDaily'
                      : needsReward
                      ? 'watchAdToRetry'
                      : 'replayDaily',
                ),
                onPressed: _requestingReward ? null : _startOrUnlock,
              ),
              if (needsReward && !ads.rewardedReady) ...[
                const SizedBox(height: 12),
                Text(
                  context.tr('adUnavailable'),
                  textAlign: TextAlign.center,
                  style: text.bodySmall,
                ),
              ],
            ] else
              Text(context.tr('newChallengeTomorrow'), style: text.bodySmall),
            if (_messageKey != null) ...[
              const SizedBox(height: 12),
              Text(
                context.tr(_messageKey!),
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider), stats = store.stats;
    final values = <(String, String, IconData)>[
      ('totalGames', '${stats.totalGames}', Icons.sports_esports_outlined),
      ('best', '${stats.bestScore}', Icons.emoji_events_outlined),
      (
        'average',
        stats.averageScore.toStringAsFixed(1),
        Icons.insights_rounded,
      ),
      ('accuracy', '${stats.accuracy.round()}%', Icons.track_changes_rounded),
      ('correctCount', '${stats.totalCorrect}', Icons.check_circle_outline),
      ('wrongCount', '${stats.totalWrong}', Icons.cancel_outlined),
      (
        'longest',
        '${stats.longestStreak}',
        Icons.local_fire_department_outlined,
      ),
      (
        'dailyStreak',
        '${store.currentDailyStreak}',
        Icons.calendar_today_outlined,
      ),
      (
        'level',
        '${const XpPolicy().levelFor(stats.totalXp)}',
        Icons.bolt_rounded,
      ),
      ('totalXp', '${stats.totalXp}', Icons.auto_awesome_rounded),
    ];
    return RushScaffold(
      title: context.tr('statistics'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('statsSubtitle'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < values.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var j = 0; j < 2; j++) ...[
                      if (j > 0) const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: context.tr(values[i + j].$1),
                          value: values[i + j].$2,
                          icon: values[i + j].$3,
                          color: (i + j).isEven ? mint : violet,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final ads = ref.watch(adServiceProvider);
    final purchases = ref.watch(purchaseServiceProvider);
    final reminders = ref.watch(dailyReminderServiceProvider);
    final reminderCopy = ReminderStrings(store.language);
    return RushScaffold(
      title: context.tr('settings'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(context.tr('language')),
            BrainCard(
              padding: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(context.tr('language')),
                subtitle: Text(
                  AppLanguages.all
                      .firstWhere((language) => language.code == store.language)
                      .nativeName,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LanguageSelectionScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(context.tr('playerName')),
            BrainCard(
              padding: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(context.tr('playerName')),
                subtitle: Text(
                  store.playerName ?? context.tr('playerNameHint'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PlayerNameSettingsScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            BrainCard(
              padding: const EdgeInsets.all(8),
              child: SwitchListTile(
                key: const Key('dailyReminderToggle'),
                title: Text(reminderCopy.t('setting')),
                subtitle: Text(reminderCopy.t('optInBody')),
                value: reminders.enabled,
                onChanged: reminders.platform.supported
                    ? (value) async {
                        if (value) {
                          final enabled = await reminders.enable();
                          if (!enabled && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(reminderCopy.t('disabled')),
                              ),
                            );
                          }
                        } else {
                          await reminders.disable();
                        }
                      }
                    : null,
              ),
            ),
            SectionHeader(context.tr('theme')),
            BrainCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (final mode in ThemeMode.values)
                    ListTile(
                      title: Text(context.tr(mode.name)),
                      leading: Icon(
                        mode == ThemeMode.dark
                            ? Icons.dark_mode_outlined
                            : mode == ThemeMode.light
                            ? Icons.light_mode_outlined
                            : Icons.brightness_auto_outlined,
                      ),
                      trailing: store.themeMode == mode
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        store.themeMode = mode;
                        store.save();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            BrainCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(context.tr('sound')),
                    subtitle: Text(context.tr('soundHint')),
                    value: store.sound,
                    onChanged: (value) {
                      store.sound = value;
                      store.save();
                    },
                  ),
                  SwitchListTile(
                    title: Text(context.tr('haptics')),
                    value: store.haptics,
                    onChanged: (value) {
                      store.haptics = value;
                      store.save();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(context.tr('removeAds')),
            BrainCard(
              key: const Key('settingsPurchaseSection'),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    purchases.owned
                        ? context.tr('adFreeActive')
                        : context.tr('oneTimePurchase'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (!purchases.owned) ...[
                    const SizedBox(height: 8),
                    Text(
                      purchases.loading
                          ? context.tr('loadingPurchase')
                          : purchases.price ??
                                context.tr('purchaseUnavailable'),
                    ),
                    const SizedBox(height: 14),
                    GamePrimaryButton(
                      key: const Key('settingsPurchaseButton'),
                      label: context.tr('removeAds'),
                      onPressed:
                          purchases.loading ||
                              purchases.price == null ||
                              purchases.pending
                          ? null
                          : purchases.buy,
                    ),
                    if (purchases.pending)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(context.tr('purchasePending')),
                      ),
                  ],
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      key: const Key('restorePurchasesButton'),
                      onPressed: () => restorePurchasesWithFeedback(
                        context,
                        ref.read(purchaseServiceProvider),
                      ),
                      child: Text(context.tr('restore')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (ads.privacyChoicesAvailable)
              ListTile(
                title: Text(context.tr('privacyChoices')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: ads.showPrivacyChoices,
              ),
            const SizedBox(height: 24),
            HelpSupportSection(language: store.language),
          ],
        ),
      ),
    );
  }
}
