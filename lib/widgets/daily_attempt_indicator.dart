import 'package:flutter/material.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';

/// A compact view of completed Daily attempts, independent of retry access.
class DailyAttemptIndicator extends StatelessWidget {
  const DailyAttemptIndicator({
    super.key,
    required this.attemptsUsed,
    this.compact = false,
  });

  final int attemptsUsed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final used = attemptsUsed.clamp(0, 3);
    final theme = Theme.of(context);
    final label = Text(
      context.tr('attemptsTodayLabel'),
      style: compact ? theme.textTheme.bodySmall : theme.textTheme.titleSmall,
    );
    final meter = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 3; index++) ...[
          if (index > 0) SizedBox(width: compact ? 4 : 5),
          Container(
            key: Key('dailyAttemptSegment$index'),
            width: compact ? 17 : 22,
            height: compact ? 8 : 9,
            decoration: BoxDecoration(
              color: index < used
                  ? (index.isEven ? energyCyan : violet)
                  : theme.colorScheme.onSurface.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
        SizedBox(width: compact ? 7 : 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            '$used/3',
            key: const Key('dailyAttemptFraction'),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
    return Semantics(
      label: context.tr('attemptsUsedSemantics').replaceAll('{count}', '$used'),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 210
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, const SizedBox(height: 6), meter],
                )
              : Row(
                  children: [
                    Expanded(child: label),
                    const SizedBox(width: 8),
                    meter,
                  ],
                ),
        ),
      ),
    );
  }
}
