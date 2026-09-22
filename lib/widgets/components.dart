import 'package:flutter/material.dart';

import '../game/models.dart';
import '../game/progression.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';

class RushScaffold extends StatelessWidget {
  const RushScaffold({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.actions,
  });
  final Widget child;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: title == null
        ? null
        : AppBar(
            title: Text(title!, style: Theme.of(context).textTheme.titleLarge),
            leading: leading,
            actions: actions,
          ),
    body: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(.9, -.85),
          radius: 1.4,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: .055),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(child: _EnergyField()),
                ),
                Material(type: MaterialType.transparency, child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _EnergyField extends StatelessWidget {
  const _EnergyField();
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _EnergyPainter(
      Theme.of(context).brightness == Brightness.dark
          ? energyCyan.withValues(alpha: .08)
          : energyCyan.withValues(alpha: .04),
    ),
  );
}

class _EnergyPainter extends CustomPainter {
  const _EnergyPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var row = 0; row < 11; row++) {
      for (var column = 0; column < 6; column++) {
        canvas.drawCircle(
          Offset((column + .5) * size.width / 6, (row + .5) * size.height / 11),
          row.isEven && column.isEven ? 1.5 : .8,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EnergyPainter oldDelegate) => oldDelegate.color != color;
}

class BrainCard extends StatelessWidget {
  const BrainCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.accent,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(gameRadius),
      border: Border.all(
        color: (accent ?? Theme.of(context).colorScheme.outlineVariant)
            .withValues(alpha: .25),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .05),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class GamePrimaryButton extends StatelessWidget {
  const GamePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      boxShadow: onPressed == null
          ? null
          : [
              BoxShadow(
                color: energyCyan.withValues(alpha: .17),
                blurRadius: 22,
              ),
            ],
    ),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: energyCyan,
          foregroundColor: const Color(0xFF0A2823),
          disabledBackgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          minimumSize: const Size(0, 64),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 22),
          ],
        ),
      ),
    ),
  );
}

class LevelProgress extends StatelessWidget {
  const LevelProgress({super.key, required this.totalXp, this.previousXp});
  final int totalXp;
  final int? previousXp;

  @override
  Widget build(BuildContext context) {
    const policy = XpPolicy();
    final level = policy.levelFor(totalXp);
    final start = policy.levelStart(level);
    final required = policy.requiredForLevel(level);
    final progress = (totalXp - start) / required;
    final initial = previousXp == null
        ? progress
        : ((previousXp! - start) / required).clamp(0.0, 1.0);
    final text = Theme.of(context).textTheme;
    return BrainCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      accent: energyCyan,
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: energyCyan, size: 21),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '${context.tr('level')} $level',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(policy.rankKey(level)),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(color: violet),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: initial, end: progress),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 700),
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: value.clamp(0, 1),
                color: energyCyan,
                backgroundColor: energyCyan.withValues(alpha: .13),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              '${totalXp - start} / $required ${context.tr('xp')}',
              style: text.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = violet,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => BrainCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Theme.of(context).brightness == Brightness.dark
              ? color
              : Theme.of(context).colorScheme.primary,
          size: 22,
        ),
        const SizedBox(height: 14),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}

class AnimatedScore extends StatelessWidget {
  const AnimatedScore(this.score, {super.key, this.large = false});
  final int score;
  final bool large;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180),
    transitionBuilder: (child, animation) =>
        ScaleTransition(scale: animation, child: child),
    child: Text(
      '$score',
      key: ValueKey(score),
      style: large
          ? Theme.of(context).textTheme.displayLarge
          : Theme.of(context).textTheme.headlineMedium,
    ),
  );
}

class StreakIndicator extends StatelessWidget {
  const StreakIndicator(this.multiplier, {super.key});
  final int multiplier;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    transitionBuilder: (child, animation) => ScaleTransition(
      scale: Tween<double>(begin: .85, end: 1).animate(animation),
      child: FadeTransition(opacity: animation, child: child),
    ),
    child: Row(
      key: ValueKey(multiplier),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_fire_department_rounded,
          color: multiplier > 1
              ? const Color(0xFFFFB76B)
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: 23,
        ),
        Text('×$multiplier', style: Theme.of(context).textTheme.headlineMedium),
      ],
    ),
  );
}

class GameTimer extends StatelessWidget {
  const GameTimer(this.remaining, {super.key});
  final double remaining;
  @override
  Widget build(BuildContext context) {
    final color = remaining <= 10
        ? coral
        : remaining <= 20
        ? streakAmber
        : Theme.of(context).colorScheme.primary;
    final seconds = remaining.ceil();
    return Semantics(
      label: '${context.tr('timer')}: $seconds',
      child: SizedBox(
        width: 62,
        height: 62,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: remaining / 60,
                strokeWidth: 5,
                color: color,
                backgroundColor: color.withValues(alpha: .12),
                strokeCap: StrokeCap.round,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$seconds',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontFeatures: [const FontFeature.tabularFigures()],
                      height: 1,
                    ),
                  ),
                  Text(
                    context.tr('secondsShort'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnswerButton extends StatelessWidget {
  const AnswerButton({
    super.key,
    required this.value,
    required this.onTap,
    required this.correct,
    required this.wrong,
    required this.locked,
    this.compact = false,
  });
  final AnswerChoice value;
  final VoidCallback onTap;
  final bool correct, wrong, locked, compact;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = correct
        ? mint
        : wrong
        ? coral
        : scheme.surface;
    final ink = correct || wrong ? const Color(0xFF102A28) : scheme.onSurface;
    return Semantics(
      label:
          '${context.tr('answer')} ${value.label}${correct ? ', ${context.tr('correctAnswer')}' : ''}',
      button: true,
      enabled: !locked,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: correct || wrong
                ? color
                : scheme.outlineVariant.withValues(alpha: .5),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: locked ? null : onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: compact ? 10 : 23,
                horizontal: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: _AnswerValue(value: value, color: ink),
                  ),
                  if (correct || wrong) ...[
                    const SizedBox(width: 10),
                    Icon(
                      correct
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: ink,
                      size: 23,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerValue extends StatelessWidget {
  const _AnswerValue({required this.value, required this.color});

  final AnswerChoice value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = value.fraction;
    if (fraction == null) {
      return Text(
        value.label,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      );
    }
    const style = TextStyle(fontSize: 23, fontWeight: FontWeight.w800);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 42,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${fraction.numerator}',
              key: ValueKey('fraction-numerator-${value.label}'),
              style: style.copyWith(color: color),
            ),
            Container(height: 2, width: 34, color: color),
            Text(
              '${fraction.denominator}',
              key: ValueKey('fraction-denominator-${value.label}'),
              style: style.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
