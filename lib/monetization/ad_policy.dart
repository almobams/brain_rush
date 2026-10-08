import '../game/models.dart';
import 'ad_diagnostics.dart';

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
  }) =>
      blockedReason(
        mode: mode,
        normalGames: normalGames,
        lastShownGame: lastShownGame,
        now: now,
        lastShownAt: lastShownAt,
        premium: premium,
      ) ==
      null;

  /// The same policy decision used by eligibility and debug diagnostics.
  String? blockedReason({
    required GameMode mode,
    required int normalGames,
    required int lastShownGame,
    required DateTime now,
    DateTime? lastShownAt,
    required bool premium,
  }) {
    if (premium) return 'Remove Ads owned';
    if (mode == GameMode.daily && !dailyInterstitials) {
      return 'Daily Challenge is ad-free';
    }
    if (normalGames < firstEligibleGame) return 'first two normal games';
    if (normalGames - lastShownGame < everyGames) {
      return 'normal-game interval not reached';
    }
    if (lastShownAt != null && now.difference(lastShownAt) < cooldown) {
      return 'two-minute cooldown';
    }
    return null;
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
    adDebugLog('game completed: mode=${mode.name}, normalGames=$normalGames');
  }

  bool eligible(GameMode mode, bool premium, DateTime now) => policy.eligible(
    mode: mode,
    normalGames: normalGames,
    lastShownGame: lastShownGame,
    now: now,
    lastShownAt: lastShownAt,
    premium: premium,
  );
  String? blockedReason(GameMode mode, bool premium, DateTime now) =>
      policy.blockedReason(
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
