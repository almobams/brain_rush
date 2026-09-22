import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:brain_rush/game/controller.dart';
import 'package:brain_rush/game/generators.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/localization/strings.dart';

int number(AnswerChoice answer) => answer.number!;

void main() {
  test('Generators produce unique, solvable answers across 6000 questions', () {
    final engine = QuestionEngine(seed: 42);
    for (var i = 0; i < 6000; i++) {
      final q = engine.next(i % 3);
      expect(q.answers.toSet().length, q.answers.length);
      expect(q.correctAnswerIndex, inInclusiveRange(0, q.answers.length - 1));
      final answer = q.answers[q.correctAnswerIndex];
      switch (q.type) {
        case QuestionType.larger:
          final values = q.answers.map(number);
          expect(
            number(answer),
            q.questionText == 'larger'
                ? values.reduce(max)
                : values.reduce(min),
          );
        case QuestionType.parity:
          final odd = q.questionText == 'odd';
          expect(q.answers.where((n) => number(n).isOdd == odd).length, 1);
          expect(number(answer).isOdd, odd);
        case QuestionType.arithmetic:
          final parts = q.expression.split(' ');
          final a = int.parse(parts[0]), b = int.parse(parts[2]);
          expect(number(answer), parts[1] == '×' ? a * b : a + b);
        case QuestionType.sequence:
          final ns = q.expression.split(' · ').take(4).map(int.parse).toList();
          expect(number(answer), ns.last + ns[1] - ns[0]);
        case QuestionType.fraction:
          final fractions = q.answers
              .map((answer) => answer.fraction!)
              .toList();
          final smaller =
              q.questionText == 'smaller' ||
              q.questionText == 'fractionSmaller';
          final expected = smaller
              ? fractions.reduce((a, b) => a.compareTo(b) < 0 ? a : b)
              : fractions.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
          expect(answer.fraction, expected);
      }
    }
  });

  test('Number comparison supports larger and smaller prompts', () {
    final random = Random(7);
    final larger = const ComparisonGenerator(chooseLarger: true)
        .generate(random, 0, 'larger');
    final smaller = const ComparisonGenerator(chooseLarger: false)
        .generate(random, 0, 'smaller');
    expect(larger.questionText, 'larger');
    expect(
      number(larger.answers[larger.correctAnswerIndex]),
      larger.answers.map(number).reduce(max),
    );
    expect(smaller.questionText, 'smaller');
    expect(
      number(smaller.answers[smaller.correctAnswerIndex]),
      smaller.answers.map(number).reduce(min),
    );
  });

  test('English and Arabic localize both comparison directions', () {
    expect(Strings('en').t('larger'), 'Which is larger?');
    expect(Strings('en').t('smaller'), 'Which is smaller?');
    expect(Strings('ar').t('larger'), 'أيهما أكبر؟');
    expect(Strings('ar').t('smaller'), 'أيهما أصغر؟');
  });

  for (final difficulty in [0, 1, 2]) {
    test('Difficulty $difficulty fractions are valid and exact', () {
      final random = Random(100 + difficulty);
      for (var i = 0; i < 500; i++) {
        final question = FractionGenerator(chooseLarger: i.isEven)
            .generate(random, difficulty, 'fraction-$i');
        final fractions = question.answers
            .map((answer) => answer.fraction!)
            .toList();
        expect(fractions, hasLength(2));
        expect(fractions.every((value) => value.denominator > 0), true);
        expect(fractions[0].isEquivalentTo(fractions[1]), false);
        expect(question.answers.toSet(), hasLength(2));
        final comparison = fractions[0].compareTo(fractions[1]);
        final expected = i.isEven
            ? (comparison > 0 ? 0 : 1)
            : (comparison < 0 ? 0 : 1);
        expect(question.correctAnswerIndex, expected);
        expect(question.difficulty, difficulty);
      }
    });
  }

  test('Fraction generator varies larger and smaller localized prompts', () {
    final random = Random(8);
    final larger = const FractionGenerator(chooseLarger: true)
        .generate(random, 1, 'larger');
    final smaller = const FractionGenerator(chooseLarger: false)
        .generate(random, 1, 'smaller');
    expect(['larger', 'fractionLarger'], contains(larger.questionText));
    expect(['smaller', 'fractionSmaller'], contains(smaller.questionText));
    expect(Strings('ar').t('fractionLarger'), 'أي الكسرين أكبر؟');
    expect(Strings('ar').t('fractionSmaller'), 'أي الكسرين أصغر؟');
  });

  test('Rational comparison uses exact cross multiplication', () {
    const fiveEighths = FractionValue(5, 8);
    const twoThirds = FractionValue(2, 3);
    const equivalent = FractionValue(10, 16);
    expect(fiveEighths.compareTo(twoThirds), lessThan(0));
    expect(fiveEighths.isEquivalentTo(equivalent), true);
  });

  test('Configured question mix includes every category at target weights', () {
    final engine = QuestionEngine(seed: 91);
    final counts = <QuestionType, int>{};
    for (var i = 0; i < 20; i++) {
      final type = engine.next(i % 3).type;
      counts[type] = (counts[type] ?? 0) + 1;
    }
    expect(counts, {
      QuestionType.larger: 4,
      QuestionType.arithmetic: 5,
      QuestionType.parity: 3,
      QuestionType.sequence: 4,
      QuestionType.fraction: 4,
    });
  });
  test('Daily date seed and complete question order are stable', () {
    final seed = QuestionEngine.dailySeed(DateTime(2026, 9, 19));
    final a = QuestionEngine(seed: seed), b = QuestionEngine(seed: seed);
    for (var i = 0; i < 100; i++) {
      final x = a.next((i ~/ 12).clamp(0, 2)),
          y = b.next((i ~/ 12).clamp(0, 2));
      expect(x.expression, y.expression);
      expect(x.answers, y.answers);
      expect(x.correctAnswerIndex, y.correctAnswerIndex);
      expect(x.type, y.type);
    }
    expect(seed, isNot(QuestionEngine.dailySeed(DateTime(2026, 9, 20))));
  });
  test('Scoring thresholds and configurable base scoring', () {
    const policy = ScoringPolicy();
    expect([0, 2, 3, 5, 6, 9, 10, 20].map(policy.multiplier), [
      1,
      1,
      2,
      2,
      3,
      3,
      4,
      4,
    ]);
    expect(const ScoringPolicy(streakBonuses: false).award(20), 1);
  });
  test('Full 60-second session locks input, scores streaks and ends once', () {
    var elapsed = Duration.zero;
    final game = GameController(mode: GameMode.rush, elapsed: () => elapsed);
    addTearDown(game.dispose);
    expect(game.answer(0), false);
    game.start(schedule: false);
    for (var i = 0; i < 10; i++) {
      elapsed += const Duration(seconds: 1);
      expect(game.answer(game.question.correctAnswerIndex), true);
      expect(game.answer(game.question.correctAnswerIndex), false);
      elapsed += GameController.feedbackDuration;
      game.tick();
    }
    expect(game.score, 24);
    expect(game.multiplier, 4);
    expect(game.bestStreak, 10);
    expect(
      game.answer(
        (game.question.correctAnswerIndex + 1) % game.question.answers.length,
      ),
      true,
    );
    expect(game.streak, 0);
    expect(game.score, 24);
    elapsed = const Duration(seconds: 60);
    expect(game.answer(0), false);
    game.tick();
    expect(game.finished, true);
    expect(game.remaining, 0);
    expect(game.session.results.length, 11);
    expect(game.session.correctAnswers, 10);
    expect(game.session.wrongAnswers, 1);
    expect(
      game.session.endedAt.difference(game.session.startedAt),
      GameController.duration,
    );
    game.tick();
    expect(game.session.results.length, 11);
  });
  test('Deadline rejects even unlocked input and catches background time', () {
    var elapsed = Duration.zero;
    final game = GameController(mode: GameMode.rush, elapsed: () => elapsed)
      ..start(schedule: false);
    addTearDown(game.dispose);
    elapsed = const Duration(seconds: 75);
    expect(game.answer(game.question.correctAnswerIndex), false);
    expect(game.finished, true);
    expect(game.score, 0);
  });
  test('Rush difficulty advances at 15 and 35 seconds', () {
    var elapsed = Duration.zero;
    final game = GameController(mode: GameMode.rush, elapsed: () => elapsed)
      ..start(schedule: false);
    addTearDown(game.dispose);
    for (final seconds in [15, 35]) {
      game.answer(game.question.correctAnswerIndex);
      elapsed = Duration(seconds: seconds);
      game.tick();
      expect(
        game.question.difficulty,
        game.question.type == QuestionType.fraction
            ? (seconds < 20
                  ? 0
                  : seconds < 45
                  ? 1
                  : 2)
            : (seconds == 15 ? 1 : 2),
      );
    }
  });

  test('Fractions follow early, middle, and final rush time bands', () {
    for (final (seconds, expected) in [(5, 0), (25, 1), (50, 2)]) {
      var elapsed = Duration.zero;
      final game = GameController(mode: GameMode.rush, elapsed: () => elapsed)
        ..start(schedule: false);
      game.answer(game.question.correctAnswerIndex);
      elapsed = Duration(seconds: seconds);
      game.tick();
      var attempts = 0;
      while (game.question.type != QuestionType.fraction && attempts < 20) {
        game.answer(game.question.correctAnswerIndex);
        elapsed += GameController.feedbackDuration;
        game.tick();
        attempts++;
      }
      expect(game.question.type, QuestionType.fraction);
      expect(game.question.difficulty, expected);
      game.dispose();
    }
  });
}
