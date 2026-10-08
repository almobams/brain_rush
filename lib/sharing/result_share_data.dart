import '../game/models.dart';
import '../game/progression.dart';
import '../backend/daily_ranking_service.dart';

/// Only public result numbers and the optional local display name are used.
class ResultShareData {
  const ResultShareData._({
    required this.mode,
    required this.score,
    required this.playerName,
    this.personalBest,
    this.accuracy,
    this.bestStreak,
    this.isNewBest = false,
    this.challengeDate,
    this.highestScore,
    this.rank,
  });

  factory ResultShareData.rush({
    required GameSession session,
    required ProgressAward award,
    required int personalBest,
    String? playerName,
  }) => ResultShareData._(
    mode: GameMode.rush,
    score: session.score,
    personalBest: personalBest,
    accuracy: session.accuracy.round(),
    bestStreak: session.bestStreak,
    isNewBest: award.isNewBest,
    playerName: playerName,
  );

  factory ResultShareData.daily({
    required DailyChallengeResult result,
    DailyRank? rank,
    String? playerName,
  }) => ResultShareData._(
    mode: GameMode.daily,
    score: result.score,
    challengeDate: DateTime.parse(result.date),
    highestScore: rank?.highestScore,
    rank: rank?.rank,
    playerName: playerName,
  );

  final GameMode mode;
  final int score;
  final int? personalBest;
  final int? accuracy;
  final int? bestStreak;
  final bool isNewBest;
  final DateTime? challengeDate;
  final int? highestScore;
  final int? rank;
  final String? playerName;
}
