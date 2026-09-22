import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrainEmblem extends StatefulWidget {
  const BrainEmblem({super.key, this.size = 180});
  final double size;
  @override
  State<BrainEmblem> createState() => _BrainEmblemState();
}

class _BrainEmblemState extends State<BrainEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) => Transform.translate(
      offset: Offset(
        0,
        MediaQuery.disableAnimationsOf(context)
            ? 0
            : math.sin(controller.value * math.pi) * 5,
      ),
      child: child,
    ),
    child: SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _EmblemPainter(),
        child: Center(
          child: Container(
            width: widget.size * .57,
            height: widget.size * .57,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [energyCyan, Color(0xFF387BA7), Color(0xFF6756BC)],
              ),
              boxShadow: [
                BoxShadow(
                  color: energyCyan.withValues(alpha: .22),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.bolt_rounded,
              color: gameBackground,
              size: widget.size * .43,
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final p = Paint()
      ..color = energyCyan.withValues(alpha: .22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, size.width * .45, p);
    canvas.drawCircle(center, size.width * .36, p);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + .35;
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * size.width * .45,
        i == 0 ? 5 : 3,
        Paint()..color = i.isEven ? energyCyan : violet,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AmbientEnergy extends StatefulWidget {
  const AmbientEnergy({super.key});
  @override
  State<AmbientEnergy> createState() => _AmbientEnergyState();
}

class _AmbientEnergyState extends State<AmbientEnergy>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat(reverse: true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
    } else if (!controller.isAnimating) {
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        painter: _AmbientPainter(
          MediaQuery.disableAnimationsOf(context) ? .5 : controller.value,
        ),
      ),
    ),
  );
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 12; i++) {
      final x = ((i * 73 + 37) % 100) / 100 * size.width;
      final y = ((i * 47 + 19) % 100) / 100 * size.height;
      final drift = math.sin(progress * math.pi * 2 + i) * 4;
      canvas.drawCircle(
        Offset(x, y + drift),
        i.isEven ? 1.6 : 1.0,
        Paint()..color = energyCyan.withValues(alpha: .05),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class Celebration extends StatefulWidget {
  const Celebration({super.key});
  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        painter: _ConfettiPainter(
          MediaQuery.disableAnimationsOf(context) ? 1 : controller.value,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;
    final random = math.Random(42);
    for (var i = 0; i < 45; i++) {
      final x = random.nextDouble() * size.width;
      final y =
          -80 +
          progress * (size.height + 120) * (.5 + random.nextDouble() * .5);
      final p = Paint()
        ..color = [mint, violet, coral][i % 3].withValues(alpha: 1 - progress);
      canvas.drawCircle(Offset(x, y), 2 + random.nextDouble() * 3, p);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child});
  final Widget child;
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (context, child) => Transform.scale(
      scale: MediaQuery.disableAnimationsOf(context)
          ? 1
          : 1 + controller.value * .012,
      child: child,
    ),
  );
}
