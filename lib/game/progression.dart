import 'models.dart';

class XpPolicy {
  const XpPolicy({
    this.session = 12,
    this.perCorrect = 2,
    this.newBest = 20,
    this.dailyCompletion = 15,
  });

  final int session, perCorrect, newBest, dailyCompletion;

  int earned(
    GameSession game, {
    required bool isNewBest,
    bool firstDailyCompletion = true,
  }) =>
      session +
      game.correctAnswers * perCorrect +
      (isNewBest ? newBest : 0) +
      (game.mode == GameMode.daily && firstDailyCompletion
          ? dailyCompletion
          : 0);

  // The short early levels make progress visible after almost every round.
  int requiredForLevel(int level) => 80 + (level - 1) * 20;

  int levelStart(int level) =>
      (level - 1) * 80 + (level - 1) * (level - 2) * 10;

  int levelFor(int totalXp) {
    var level = 1;
    while (totalXp >= levelStart(level + 1)) {
      level++;
    }
    return level;
  }

  String rankKey(int level) => switch (level) {
    <= 2 => 'rankWarmUp',
    <= 5 => 'rankQuickThinker',
    <= 9 => 'rankSharpMind',
    <= 14 => 'rankBrainRacer',
    <= 19 => 'rankLightningMind',
    _ => 'rankBrainMaster',
  };
}

class ProgressAward {
  const ProgressAward({
    required this.earnedXp,
    required this.previousXp,
    required this.totalXp,
    required this.isNewBest,
    required this.previousBest,
  });

  final int earnedXp, previousXp, totalXp, previousBest;
  final bool isNewBest;

  int get previousLevel => const XpPolicy().levelFor(previousXp);
  int get level => const XpPolicy().levelFor(totalXp);
  bool get leveledUp => level > previousLevel;
  bool get rankChanged =>
      const XpPolicy().rankKey(level) !=
      const XpPolicy().rankKey(previousLevel);
}
