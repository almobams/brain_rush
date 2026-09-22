enum GameMode { rush, daily }

enum QuestionType { larger, arithmetic, parity, sequence, fraction }

class FractionValue implements Comparable<FractionValue> {
  const FractionValue(this.numerator, this.denominator)
    : assert(denominator > 0),
      assert(numerator >= 0);

  final int numerator;
  final int denominator;

  @override
  int compareTo(FractionValue other) =>
      numerator * other.denominator - other.numerator * denominator;

  bool isEquivalentTo(FractionValue other) => compareTo(other) == 0;

  String get label => '$numerator/$denominator';

  @override
  bool operator ==(Object other) =>
      other is FractionValue &&
      numerator == other.numerator &&
      denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);
}

class AnswerChoice {
  const AnswerChoice.number(int value) : number = value, fraction = null;
  const AnswerChoice.fraction(FractionValue value)
    : fraction = value,
      number = null;

  final int? number;
  final FractionValue? fraction;

  String get label => number?.toString() ?? fraction!.label;

  @override
  bool operator ==(Object other) =>
      other is AnswerChoice &&
      number == other.number &&
      fraction == other.fraction;

  @override
  int get hashCode => Object.hash(number, fraction);
}

class BrainQuestion {
  const BrainQuestion({
    required this.id,
    required this.type,
    required this.questionText,
    required this.expression,
    required this.answers,
    required this.correctAnswerIndex,
    required this.difficulty,
  });
  final String id, questionText, expression;
  final QuestionType type;
  final List<AnswerChoice> answers;
  final int correctAnswerIndex, difficulty;
}

class QuestionResult {
  const QuestionResult(
    this.questionId,
    this.questionType,
    this.wasCorrect,
    this.responseTime,
    this.scoreAwarded,
  );
  final String questionId;
  final QuestionType questionType;
  final bool wasCorrect;
  final Duration responseTime;
  final int scoreAwarded;
}

class GameSession {
  const GameSession({
    required this.id,
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.score,
    required this.bestStreak,
    required this.results,
  });
  final String id;
  final GameMode mode;
  final DateTime startedAt, endedAt;
  final int score, bestStreak;
  final List<QuestionResult> results;
  int get correctAnswers => results.where((r) => r.wasCorrect).length;
  int get wrongAnswers => results.length - correctAnswers;
  double get accuracy =>
      results.isEmpty ? 0 : correctAnswers / results.length * 100;
  Duration get averageResponseTime => Duration(
    milliseconds: results.isEmpty
        ? 0
        : results.fold<int>(0, (v, r) => v + r.responseTime.inMilliseconds) ~/
              results.length,
  );
}

class DailyChallengeResult {
  const DailyChallengeResult(
    this.date,
    this.score,
    this.correct,
    this.wrong,
    this.completed,
  );
  final String date;
  final int score, correct, wrong;
  final bool completed;
  Map<String, dynamic> toJson() => {
    'date': date,
    'score': score,
    'correct': correct,
    'wrong': wrong,
    'completed': completed,
  };
  factory DailyChallengeResult.fromJson(Map<String, dynamic> j) =>
      DailyChallengeResult(
        j['date'] as String,
        j['score'] as int,
        j['correct'] as int,
        j['wrong'] as int,
        j['completed'] as bool,
      );
}

class PlayerStats {
  int totalGames = 0,
      bestScore = 0,
      totalScore = 0,
      totalCorrect = 0,
      totalWrong = 0,
      longestStreak = 0,
      dailyStreak = 0,
      totalXp = 0;
  String? lastPlayedDate;
  double get accuracy => totalCorrect + totalWrong == 0
      ? 0
      : totalCorrect / (totalCorrect + totalWrong) * 100;
  double get averageScore => totalGames == 0 ? 0 : totalScore / totalGames;
  Map<String, dynamic> toJson() => {
    'totalGames': totalGames,
    'bestScore': bestScore,
    'totalScore': totalScore,
    'totalCorrect': totalCorrect,
    'totalWrong': totalWrong,
    'longestStreak': longestStreak,
    'dailyStreak': dailyStreak,
    'totalXp': totalXp,
    'lastPlayedDate': lastPlayedDate,
  };
  factory PlayerStats.fromJson(Map<String, dynamic> j) => PlayerStats()
    ..totalGames = j['totalGames'] as int? ?? 0
    ..bestScore = j['bestScore'] as int? ?? 0
    ..totalScore = j['totalScore'] as int? ?? 0
    ..totalCorrect = j['totalCorrect'] as int? ?? 0
    ..totalWrong = j['totalWrong'] as int? ?? 0
    ..longestStreak = j['longestStreak'] as int? ?? 0
    ..dailyStreak = j['dailyStreak'] as int? ?? 0
    ..totalXp = j['totalXp'] as int? ?? 0
    ..lastPlayedDate = j['lastPlayedDate'] as String?;
  PlayerStats();
}

String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
