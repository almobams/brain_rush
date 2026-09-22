import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'generators.dart';

class ScoringPolicy {
  const ScoringPolicy({this.streakBonuses = true});
  final bool streakBonuses;
  int multiplier(int streak) => streak >= 10
      ? 4
      : streak >= 6
      ? 3
      : streak >= 3
      ? 2
      : 1;
  int award(int streak) => streakBonuses ? multiplier(streak) : 1;
}

class GameController extends ChangeNotifier {
  GameController({
    required this.mode,
    DateTime? date,
    this.policy = const ScoringPolicy(),
    Duration Function()? elapsed,
  }) : startedAt = date ?? DateTime.now(),
       _elapsedOverride = elapsed {
    engine = QuestionEngine(
      seed: mode == GameMode.daily ? QuestionEngine.dailySeed(startedAt) : null,
    );
    question = engine.next(0);
  }
  static const duration = Duration(seconds: 60);
  static const feedbackDuration = Duration(milliseconds: 320);
  final GameMode mode;
  final DateTime startedAt;
  final ScoringPolicy policy;
  final Duration Function()? _elapsedOverride;
  final Stopwatch _watch = Stopwatch();
  late final QuestionEngine engine;
  late BrainQuestion question;
  Timer? _ticker;
  Duration _questionShown = Duration.zero, _answeredAt = Duration.zero;
  bool started = false, finished = false, locked = false;
  int score = 0, streak = 0, bestStreak = 0, lastAward = 0;
  int? selected;
  bool fast = false;
  bool lightning = false, streakIncreased = false;
  final List<QuestionResult> results = [];
  Duration get elapsed => _elapsedOverride?.call() ?? _watch.elapsed;
  double get remaining =>
      (60 - elapsed.inMicroseconds / 1000000).clamp(0, 60).toDouble();
  int get multiplier => policy.multiplier(streak);
  void start({bool schedule = true}) {
    if (started) return;
    started = true;
    _watch.start();
    if (schedule) {
      _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) => tick());
    }
  }

  void tick() {
    if (!started || finished) return;
    if (elapsed >= duration) {
      finished = true;
      locked = true;
      _ticker?.cancel();
      _watch.stop();
      notifyListeners();
      return;
    }
    if (locked && elapsed - _answeredAt >= feedbackDuration) {
      // Daily progression is by question index so response speed cannot change its sequence.
      final difficulty = mode == GameMode.daily
          ? (engine.index ~/ 12).clamp(0, 2)
          : elapsed.inSeconds < 15
          ? 0
          : elapsed.inSeconds < 35
          ? 1
          : 2;
      final fractionDifficulty = mode == GameMode.daily
          ? difficulty
          : elapsed.inSeconds < 20
          ? 0
          : elapsed.inSeconds < 45
          ? 1
          : 2;
      question = engine.next(
        difficulty,
        fractionDifficulty: fractionDifficulty,
      );
      selected = null;
      locked = false;
      _questionShown = elapsed;
    }
    notifyListeners();
  }

  bool answer(int index) {
    if (!started ||
        finished ||
        locked ||
        index < 0 ||
        index >= question.answers.length) {
      return false;
    }
    if (elapsed >= duration) {
      tick();
      return false;
    }
    locked = true;
    selected = index;
    _answeredAt = elapsed;
    final correct = index == question.correctAnswerIndex;
    final response = elapsed - _questionShown;
    final previousMultiplier = multiplier;
    streak = correct ? streak + 1 : 0;
    streakIncreased = correct && multiplier > previousMultiplier;
    if (streak > bestStreak) bestStreak = streak;
    lastAward = correct ? policy.award(streak) : 0;
    score += lastAward;
    fast = correct && response < const Duration(milliseconds: 1400);
    lightning = correct && response < const Duration(milliseconds: 650);
    results.add(
      QuestionResult(question.id, question.type, correct, response, lastAward),
    );
    notifyListeners();
    return true;
  }

  GameSession get session => GameSession(
    id: startedAt.microsecondsSinceEpoch.toString(),
    mode: mode,
    startedAt: startedAt,
    endedAt: startedAt.add(duration),
    score: score,
    bestStreak: bestStreak,
    results: List.unmodifiable(results),
  );
  @override
  void dispose() {
    _ticker?.cancel();
    _watch.stop();
    super.dispose();
  }
}
