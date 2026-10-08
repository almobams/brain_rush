import 'package:flutter/material.dart';

import '../backend/daily_ranking_service.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import 'components.dart';

class DailyRankPanel extends StatelessWidget {
  const DailyRankPanel({
    super.key,
    required this.rank,
    required this.localBest,
    required this.loading,
    required this.unavailable,
    this.onRefresh,
    this.compact = false,
    this.embedded = false,
    this.playerName,
  });

  final DailyRank? rank;
  final int localBest;
  final bool loading;
  final bool unavailable;
  final VoidCallback? onRefresh;
  final bool compact;
  final bool embedded;
  final String? playerName;

  @override
  Widget build(BuildContext context) {
    final current = unavailable ? null : rank;
    final text = Theme.of(context).textTheme;
    final number = MaterialLocalizations.of(context);
    final accent = current?.rank == 1 ? streakAmber : energyCyan;
    final scoreRow = Row(
      children: [
        Expanded(
          child: _ScoreColumn(
            label: context.tr('todayHighest'),
            value: current == null
                ? '—'
                : number.formatDecimal(current.highestScore),
            color: energyCyan,
            compact: compact,
          ),
        ),
        Container(
          width: 1,
          height: compact ? 32 : 42,
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: .5),
        ),
        Expanded(
          child: _ScoreColumn(
            label: context.tr('yourBest'),
            value: number.formatDecimal(current?.bestScore ?? localBest),
            color: violet,
            compact: compact,
          ),
        ),
      ],
    );
    final rankLabel = current == null
        ? context.tr(loading ? 'rankingLoading' : 'rankingUnavailable')
        : context.tr('yourRankToday');
    final rankBadge = current == null
        ? Icon(
            Icons.leaderboard_outlined,
            color: accent,
            size: compact ? 28 : 38,
          )
        : Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '#${current.rank}',
              key: const Key('dailyRankBadge'),
              style: (compact ? text.headlineMedium : text.displaySmall)
                  ?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (compact)
          Row(
            children: [
              Container(
                width: 64,
                height: 56,
                alignment: Alignment.center,
                decoration: _badgeDecoration(accent),
                child: rankBadge,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rankLabel,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          )
        else ...[
          Container(
            constraints: const BoxConstraints(minWidth: 88, minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: _badgeDecoration(accent),
            child: rankBadge,
          ),
          const SizedBox(height: 6),
          Text(
            rankLabel,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
        if (current?.rank == 1) ...[
          const SizedBox(height: 4),
          Text(
            playerName == null
                ? context.tr('numberOneToday')
                : context
                      .tr('numberOneNamed')
                      .replaceAll('{name}', playerName!),
            style: text.labelMedium?.copyWith(color: streakAmber),
          ),
        ],
        SizedBox(height: compact ? 10 : 14),
        scoreRow,
        if (onRefresh != null && !loading) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: onRefresh,
            child: Text(context.tr('refreshRank')),
          ),
        ],
      ],
    );
    if (embedded) return content;
    return BrainCard(
      accent: accent,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: SizedBox(width: double.infinity, child: content),
    );
  }

  BoxDecoration _badgeDecoration(Color accent) => BoxDecoration(
    borderRadius: BorderRadius.circular(18),
    gradient: LinearGradient(
      colors: [accent.withValues(alpha: .19), violet.withValues(alpha: .11)],
    ),
    border: Border.all(color: accent.withValues(alpha: .4)),
    boxShadow: [BoxShadow(color: accent.withValues(alpha: .1), blurRadius: 18)],
  );
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({
    required this.label,
    required this.value,
    required this.color,
    required this.compact,
  });

  final String label;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: (compact ? text.titleLarge : text.headlineMedium)?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(label, textAlign: TextAlign.center, style: text.bodySmall),
      ],
    );
  }
}
