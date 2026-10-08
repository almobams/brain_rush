import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/store.dart';
import '../monetization/ad_service.dart';
import '../monetization/ad_diagnostics.dart';
import '../monetization/purchase_service.dart';
import '../game/models.dart';
import '../game/progression.dart';
import '../localization/strings.dart';
import '../localization/languages.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/effects.dart';
import '../backend/daily_ranking_service.dart';
import '../widgets/daily_rank_panel.dart';
import '../sharing/result_share_data.dart';
import '../sharing/result_share_service.dart';
import 'game_screen.dart';
import 'secondary_screens.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, required this.session, required this.award});
  final GameSession session;
  final ProgressAward award;
  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool leaving = false;
  bool sharing = false;

  Future<void> _share() async {
    if (sharing) return;
    setState(() => sharing = true);
    try {
      final store = ref.read(storeProvider);
      final dailyResult = widget.session.mode == GameMode.daily
          ? store.daily[dateKey(widget.session.startedAt)]
          : null;
      final data = widget.session.mode == GameMode.daily
          ? ResultShareData.daily(
              result: dailyResult!,
              rank:
                  ref
                      .read(dailyRankingProvider)
                      .unavailableFor(dailyResult.date)
                  ? null
                  : ref.read(dailyRankingProvider).rankFor(dailyResult.date),
              playerName: store.playerName,
            )
          : ResultShareData.rush(
              session: widget.session,
              award: widget.award,
              personalBest: store.stats.bestScore,
              playerName: store.playerName,
            );
      await ref.read(resultShareServiceProvider).share(context, data);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('shareUnavailable'))));
      }
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  Future<void> _leave(VoidCallback destination) async {
    if (leaving) return;
    leaving = true;
    final store = ref.read(storeProvider);
    final premium = ref.read(purchaseServiceProvider).owned;
    final reason = store.adSchedule.blockedReason(
      widget.session.mode,
      premium,
      DateTime.now(),
    );
    adDebugLog(
      'Results exit: mode=${widget.session.mode.name}, '
      'normalGames=${store.adSchedule.normalGames}, '
      'lastShownGame=${store.adSchedule.lastShownGame}, '
      'previousAdShown=${store.adSchedule.lastShownAt != null}, '
      'premium=$premium, eligible=${reason == null}'
      '${reason == null ? '' : ', reason=$reason'}',
    );
    if (reason == null) {
      final shown = await ref.read(adServiceProvider).showInterstitial();
      if (shown) await store.markInterstitialShown(DateTime.now());
    } else {
      adDebugLog('interstitial show skipped: $reason');
    }
    if (mounted) destination();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session, award = widget.award;
    final text = Theme.of(context).textTheme;
    final store = ref.watch(storeProvider);
    final dailyResult = session.mode == GameMode.daily
        ? store.daily[dateKey(session.startedAt)]
        : null;
    final ranking = session.mode == GameMode.daily
        ? ref.watch(dailyRankingProvider)
        : null;
    final compact = MediaQuery.sizeOf(context).height < 700;
    final fastAnswers = session.results
        .where(
          (result) =>
              result.wasCorrect &&
              result.responseTime < const Duration(milliseconds: 1400),
        )
        .length;
    final comparison = award.isNewBest
        ? award.previousBest == 0
              ? context.tr('firstBest')
              : '${context.tr('beatBest')} ${session.score - award.previousBest}'
        : session.score == award.previousBest
        ? context.tr('matchedBest')
        : '${context.tr('pointsToBest')} ${award.previousBest - session.score}';

    return RushScaffold(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, compact ? 12 : 24, 20, 24),
            child: Column(
              children: [
                Text(
                  context.tr('timesUp'),
                  style: text.titleLarge?.copyWith(
                    letterSpacing: AppLanguages.isRtl(store.language) ? 0 : 3,
                  ),
                ),
                SizedBox(height: compact ? 8 : 16),
                BrainCard(
                  accent: award.isNewBest ? streakAmber : energyCyan,
                  padding: EdgeInsets.all(compact ? 14 : 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        if (award.isNewBest)
                          Text(
                            store.playerName == null
                                ? context.tr('newBest')
                                : context
                                      .tr('newBestNamed')
                                      .replaceAll('{name}', store.playerName!),
                            style: text.labelLarge?.copyWith(
                              color: streakAmber,
                            ),
                          ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: session.score.toDouble()),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 600),
                          builder: (context, value, _) => Text(
                            '${value.round()}',
                            style: text.displayLarge?.copyWith(
                              fontSize: compact ? 68 : 88,
                              color: energyCyan,
                              height: 1.1,
                              fontFeatures: [
                                const FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          context.tr(
                            session.mode == GameMode.daily
                                ? 'currentAttemptScore'
                                : 'points',
                          ),
                          style: text.labelMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          comparison,
                          textAlign: TextAlign.center,
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: compact ? 10 : 16),
                if (dailyResult != null) ...[
                  DailyRankPanel(
                    rank: ranking!.rankFor(dailyResult.date),
                    localBest: dailyResult.score,
                    loading: ranking.loadingFor(dailyResult.date),
                    unavailable: ranking.unavailableFor(dailyResult.date),
                    playerName: store.playerName,
                    onRefresh: () => unawaited(ranking.refresh(dailyResult)),
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 10 : 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _ResultMetric(
                        context.tr('accuracy'),
                        '${session.accuracy.round()}%',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ResultMetric(
                        context.tr('bestStreak'),
                        '×${session.bestStreak}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ResultMetric(
                        context.tr('fastAnswers'),
                        '$fastAnswers',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 16),
                if (award.leveledUp)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      award.rankChanged
                          ? '${context.tr('newRank')} · ${context.tr(const XpPolicy().rankKey(award.level))}'
                          : context.tr('levelUp'),
                      style: text.titleMedium?.copyWith(color: streakAmber),
                    ),
                  ),
                Text(
                  '+${award.earnedXp} ${context.tr('xp')}',
                  style: text.headlineMedium?.copyWith(color: energyCyan),
                ),
                const SizedBox(height: 8),
                LevelProgress(
                  totalXp: award.totalXp,
                  previousXp: award.previousXp,
                ),
                if (dailyResult != null) ...[
                  SizedBox(height: compact ? 8 : 12),
                  Text(
                    dailyResult.attemptsRemaining == 0
                        ? context.tr('allAttemptsUsed')
                        : dailyResult.attemptsRemaining == 1
                        ? context.tr('oneAttemptLeft')
                        : context.tr('twoAttemptsLeft'),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                ],
                SizedBox(height: compact ? 14 : 22),
                if (session.mode != GameMode.daily ||
                    (dailyResult?.attemptsRemaining ?? 0) > 0)
                  GamePrimaryButton(
                    label: context.tr(
                      session.mode == GameMode.daily ? 'retryDaily' : 'again',
                    ),
                    icon: Icons.replay_rounded,
                    onPressed: leaving
                        ? null
                        : () => _leave(
                            () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) => session.mode == GameMode.daily
                                    ? const DailyScreen()
                                    : const GameScreen(mode: GameMode.rush),
                              ),
                            ),
                          ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('shareResultButton'),
                    onPressed: sharing ? null : _share,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(context.tr('share')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: energyCyan,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(
                        color: energyCyan.withValues(alpha: .55),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: TextButton(
                        onPressed: leaving
                            ? null
                            : () => _leave(
                                () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const DailyScreen(),
                                  ),
                                ),
                              ),
                        child: Text(context.tr('daily')),
                      ),
                    ),
                    Flexible(
                      child: TextButton(
                        onPressed: leaving
                            ? null
                            : () => _leave(
                                () =>
                                    Navigator.of(context)
                                        .popUntil((route) => route.isFirst),
                              ),
                        child: Text(context.tr('home')),
                      ),
                    ),
                  ],
                ),
                if (store.saveFailed) Text(context.tr('saveError')),
              ],
            ),
          ),
          if (award.isNewBest) const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => BrainCard(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
    child: Column(
      children: [
        FittedBox(
          child: Text(value, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}
