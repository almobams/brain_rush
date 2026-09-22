import '../game/models.dart';

class AdPolicy {
  const AdPolicy({
    this.firstEligibleGame = 3,
    this.everyGames = 3,
    this.cooldown = const Duration(minutes: 2),
    this.dailyInterstitials = false,
  });
  final int firstEligibleGame, everyGames;
  final Duration cooldown;
  final bool dailyInterstitials;

  bool eligible({
    required GameMode mode,
    required int normalGames,
    required int lastShownGame,
    required DateTime now,
    DateTime? lastShownAt,
    required bool premium,
  }) {
    if (premium || (mode == GameMode.daily && !dailyInterstitials)) {
      return false;
    }
    if (normalGames < firstEligibleGame ||
        normalGames - lastShownGame < everyGames) {
      return false;
    }
    return lastShownAt == null || now.difference(lastShownAt) >= cooldown;
  }
}

class AdSchedule {
  AdSchedule({
    this.normalGames = 0,
    this.lastShownGame = 0,
    this.lastShownAt,
    this.policy = const AdPolicy(),
  });
  int normalGames, lastShownGame;
  DateTime? lastShownAt;
  final AdPolicy policy;
  void completed(GameMode mode) {
    if (mode == GameMode.rush) normalGames++;
  }

  bool eligible(GameMode mode, bool premium, DateTime now) => policy.eligible(
    mode: mode,
    normalGames: normalGames,
    lastShownGame: lastShownGame,
    now: now,
    lastShownAt: lastShownAt,
    premium: premium,
  );
  void shown(DateTime now) {
    lastShownGame = normalGames;
    lastShownAt = now;
  }
}
