import 'package:flutter/material.dart';

import '../game/models.dart';
import '../localization/languages.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import 'result_share_data.dart';

/// Fixed 4:5 canvas. Capturing at 3x produces a 1080 x 1350 PNG.
class ResultShareCard extends StatelessWidget {
  const ResultShareCard({
    super.key,
    required this.data,
    required this.language,
  });
  final ResultShareData data;
  final String language;

  @override
  Widget build(BuildContext context) {
    final strings = Strings(language);
    final daily = data.mode == GameMode.daily;
    final accent = daily && data.rank == 1 ? streakAmber : energyCyan;
    final direction = AppLanguages.isRtl(language)
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: SizedBox(
        width: 360,
        height: 450,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gameBackground, Color(0xFF10233D), Color(0xFF17163D)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -85,
                right: -70,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: violet.withValues(alpha: .12),
                        blurRadius: 100,
                        spreadRadius: 45,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            gradient: const LinearGradient(
                              colors: [energyCyan, violet],
                            ),
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: gameBackground,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.t('brand'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.t(daily ? 'shareDailyTitle' : 'shareRushTitle'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (daily) ...[
                      const SizedBox(height: 4),
                      Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(data.challengeDate!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (data.playerName != null)
                      Text(
                        daily
                            ? data.playerName!
                            : strings
                                  .t('shareScored')
                                  .replaceAll('{name}', data.playerName!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 19,
                        ),
                      )
                    else if (!daily)
                      Text(
                        strings.t('shareMyScore'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    Text(
                      '${data.score}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 80,
                        height: 1.02,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      strings.t(daily ? 'yourBest' : 'score'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    if (!daily && data.isNewBest) ...[
                      const SizedBox(height: 5),
                      Text(
                        strings.t('newBest'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: streakAmber,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (daily)
                      Row(
                        children: [
                          Expanded(
                            child: _ShareMetric(
                              label: data.rank == null
                                  ? strings.t('rankingUnavailable')
                                  : strings.t('currentRank'),
                              value: data.rank == null ? '—' : '#${data.rank}',
                              valueColor: data.rank == 1
                                  ? streakAmber
                                  : energyCyan,
                              ltrValue: data.rank != null,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _ShareMetric(
                              label: strings.t('todayHighest'),
                              value: data.highestScore?.toString() ?? '—',
                              valueColor: violet,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      Text(
                        '${strings.t('best')}: ${data.personalBest}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _ShareMetric(
                              label: strings.t('accuracy'),
                              value: '${data.accuracy}%',
                              valueColor: energyCyan,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _ShareMetric(
                              label: strings.t('bestStreak'),
                              value: '×${data.bestStreak}',
                              valueColor: violet,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    Text(
                      strings.t(daily ? 'shareDailyInvite' : 'shareRushInvite'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      height: 2,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [energyCyan, violet]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareMetric extends StatelessWidget {
  const _ShareMetric({
    required this.label,
    required this.value,
    required this.valueColor,
    this.ltrValue = false,
  });
  final String label;
  final String value;
  final Color valueColor;
  final bool ltrValue;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 67),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withValues(alpha: .1)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Directionality(
          textDirection: ltrValue
              ? TextDirection.ltr
              : Directionality.of(context),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
        ),
      ],
    ),
  );
}
