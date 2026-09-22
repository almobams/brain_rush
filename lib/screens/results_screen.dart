import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/store.dart';
import '../monetization/ad_service.dart';
import '../monetization/purchase_service.dart';
import '../game/models.dart';
import '../game/progression.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/effects.dart';
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

  Future<void> _leave(VoidCallback destination) async {
    if (leaving) return;
    leaving = true;
    final store = ref.read(storeProvider);
    final premium = ref.read(purchaseServiceProvider).owned;
    if (store.adSchedule.eligible(
      widget.session.mode,
      premium,
      DateTime.now(),
    )) {
      final shown = await ref.read(adServiceProvider).showInterstitial();
      if (shown) await store.markInterstitialShown(DateTime.now());
    }
    if (mounted) destination();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session, award = widget.award;
    final text = Theme.of(context).textTheme;
    final store = ref.watch(storeProvider);
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
                    letterSpacing: store.language == 'ar' ? 0 : 3,
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
                            context.tr('newBest'),
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
                        Text(context.tr('points'), style: text.labelMedium),
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
                SizedBox(height: compact ? 14 : 22),
                GamePrimaryButton(
                  label: context.tr('again'),
                  icon: Icons.replay_rounded,
                  onPressed: leaving
                      ? null
                      : () => _leave(
                          () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => GameScreen(mode: session.mode),
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
