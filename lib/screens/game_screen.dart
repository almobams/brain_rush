import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/store.dart';
import '../core/feedback_service.dart';
import '../game/controller.dart';
import '../game/models.dart';
import '../game/progression.dart';
import '../localization/strings.dart';
import '../widgets/game_panels.dart';
import '../widgets/components.dart';
import '../widgets/effects.dart';
import 'results_screen.dart';

final gameFactoryProvider = Provider<GameController Function(GameMode)>(
  (ref) =>
      (mode) => GameController(mode: mode),
);

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.mode});
  final GameMode mode;
  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  late final GameController game = ref.read(gameFactoryProvider)(widget.mode);
  bool navigating = false, allowExit = false, dialogOpen = false;
  int lastCountdown = 11;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        feedback.play(FeedbackCue.tap);
        game.start();
      }
    });
  }

  FeedbackService get feedback {
    final store = ref.read(storeProvider);
    return FeedbackService(haptics: store.haptics, sound: store.sound);
  }

  void _update() {
    if (!mounted) return;
    if (game.remaining.ceil() <= 10 && game.remaining.ceil() < lastCountdown) {
      lastCountdown = game.remaining.ceil();
      if (lastCountdown <= 3 || lastCountdown == 10) {
        feedback.play(FeedbackCue.countdown);
      }
    }
    if (game.finished && !navigating) {
      navigating = true;
      if (dialogOpen) {
        Navigator.of(context).pop(false);
        dialogOpen = false;
      }
      _finish();
    }
    setState(() {});
  }

  Future<void> _finish() async {
    final store = ref.read(storeProvider);
    final ProgressAward award = await store.record(game.session);
    if (!mounted) return;
    feedback.play(
      award.rankChanged || award.leveledUp
          ? FeedbackCue.levelUp
          : award.isNewBest
          ? FeedbackCue.achievement
          : FeedbackCue.timeUp,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ResultsScreen(session: game.session, award: award),
          ),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) game.tick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.removeListener(_update);
    game.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (dialogOpen) return;
    dialogOpen = true;
    final quit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('leave')),
        content: Text(context.tr('leaveBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('keepPlaying')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('quit')),
          ),
        ],
      ),
    );
    dialogOpen = false;
    if (quit == true && mounted && !navigating) {
      setState(() => allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = game.question;
    final correct = game.selected == q.correctAnswerIndex;
    return PopScope(
      canPop: allowExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !navigating) leave();
      },
      child: RushScaffold(
        title: context.tr(
          widget.mode == GameMode.daily ? 'dailyRound' : 'round',
        ),
        leading: IconButton(
          tooltip: context.tr('quit'),
          icon: const Icon(Icons.close_rounded),
          onPressed: leave,
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: IgnorePointer(child: AmbientEnergy())),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 650;
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        compact ? 4 : 20,
                        20,
                        compact ? 4 : 12,
                      ),
                      child: GameHud(game: game),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          compact ? 0 : 12,
                          20,
                          12,
                        ),
                        child: Column(
                          children: [
                            QuestionPanel(
                              question: q,
                              selected: game.selected,
                              compact: compact,
                            ),
                            AnswerFeedback(game: game, compact: compact),
                            for (
                              var row = 0;
                              row < (q.answers.length / 2).ceil();
                              row++
                            )
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    for (var col = 0; col < 2; col++) ...[
                                      if (col > 0) const SizedBox(width: 10),
                                      if (row * 2 + col < q.answers.length)
                                        Expanded(
                                          child: AnswerButton(
                                            value: q.answers[row * 2 + col],
                                            compact: compact,
                                            locked: game.locked,
                                            correct:
                                                game.locked &&
                                                q.correctAnswerIndex ==
                                                    row * 2 + col,
                                            wrong:
                                                game.selected ==
                                                    row * 2 + col &&
                                                !correct,
                                            onTap: () {
                                              if (game.answer(row * 2 + col)) {
                                                feedback.play(
                                                  game.selected !=
                                                          q.correctAnswerIndex
                                                      ? FeedbackCue.incorrect
                                                      : game.streakIncreased
                                                      ? FeedbackCue.streak
                                                      : game.lightning
                                                      ? FeedbackCue.fast
                                                      : FeedbackCue.correct,
                                                );
                                              }
                                            },
                                          ),
                                        )
                                      else
                                        const Spacer(),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
