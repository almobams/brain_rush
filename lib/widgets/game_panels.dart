import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../game/models.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import 'components.dart';

class GameHud extends StatelessWidget {
  const GameHud({super.key, required this.game});
  final GameController game;
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    Widget metric(String label, Widget value) => Expanded(
      child: Column(
        children: [
          Text(context.tr(label), textAlign: TextAlign.center, style: style),
          const SizedBox(height: 5),
          FittedBox(fit: BoxFit.scaleDown, child: value),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        metric(
          'score',
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScore(game.score),
              if (game.locked && game.lastAward > 0)
                PositionedDirectional(
                  top: -13,
                  end: -19,
                  child: Text(
                    '+${game.lastAward}',
                    style: style?.copyWith(
                      color: energyCyan,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
        metric('timer', GameTimer(game.remaining)),
        metric('streak', StreakIndicator(game.multiplier)),
      ],
    );
  }
}

class QuestionPanel extends StatelessWidget {
  const QuestionPanel({
    super.key,
    required this.question,
    required this.selected,
    required this.compact,
  });
  final BrainQuestion question;
  final int? selected;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final q = question, text = Theme.of(context).textTheme;
    final answered = selected != null,
        correct = selected == q.correctAnswerIndex;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      // Never show the previous prompt beside the next question's active answers.
      layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .02),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 140),
      child: TweenAnimationBuilder<double>(
        key: ValueKey('${q.id}-$selected'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        builder: (context, value, child) => Transform.translate(
          offset: Offset(
            answered && !correct && !reduced
                ? math.sin(value * math.pi * 6) * (1 - value) * 8
                : 0,
            0,
          ),
          child: Transform.scale(
            scale: answered && correct && !reduced
                ? 1 + math.sin(value * math.pi) * .018
                : 1,
            child: child,
          ),
        ),
        child: BrainCard(
          padding: EdgeInsets.all(compact ? 12 : 28),
          accent: answered
              ? correct
                    ? mint
                    : coral
              : violet,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: violet.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        switch (q.type) {
                          QuestionType.larger => Icons.swap_vert_rounded,
                          QuestionType.arithmetic => Icons.calculate_outlined,
                          QuestionType.parity => Icons.filter_3_rounded,
                          QuestionType.sequence => Icons.arrow_forward_rounded,
                          QuestionType.fraction =>
                            Icons.pie_chart_outline_rounded,
                        },
                        size: 14,
                        color: energyCyan,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          context.tr('type_${q.type.name}'),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            letterSpacing: 1.1,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 8 : 28),
                Text(
                  context.tr(q.questionText),
                  textAlign: TextAlign.center,
                  style: text.headlineMedium?.copyWith(
                    fontSize: compact ? 20 : 28,
                  ),
                ),
                SizedBox(height: compact ? 8 : 24),
                if (q.expression.isNotEmpty)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      q.expression,
                      textAlign: TextAlign.center,
                      style: text.displaySmall?.copyWith(
                        fontSize: q.type == QuestionType.sequence
                            ? compact
                                  ? 22
                                  : 28
                            : compact
                            ? 30
                            : 38,
                      ),
                    ),
                  )
                else
                  Icon(
                    q.type == QuestionType.larger ||
                            q.type == QuestionType.fraction
                        ? Icons.compare_arrows_rounded
                        : Icons.filter_4_rounded,
                    size: compact ? 32 : 52,
                    color: violet,
                  ),
                if (!compact) const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnswerFeedback extends StatelessWidget {
  const AnswerFeedback({super.key, required this.game, required this.compact});
  final GameController game;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final correct = game.selected == game.question.correctAnswerIndex;
    final message = !correct
        ? context.tr('incorrect')
        : game.streakIncreased
        ? '${context.tr('streakCallout')} ×${game.multiplier}'
        : game.lightning
        ? '⚡ ${context.tr('lightning')}'
        : game.fast
        ? '⚡ ${context.tr('fast')}'
        : context.tr('correct');
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = correct
        ? dark
              ? mint
              : const Color(0xFF146C54)
        : dark
        ? coral
        : const Color(0xFFB32B46);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 36 : 58),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Semantics(
            liveRegion: game.locked,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 140),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .15),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: game.locked
                  ? Text(
                      message,
                      key: ValueKey(game.question.id),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: color, fontWeight: FontWeight.w800),
                    )
                  : Text(
                      context.tr('choose'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
