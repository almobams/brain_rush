import 'dart:math';

import 'models.dart';

abstract interface class QuestionGenerator {
  BrainQuestion generate(Random random, int difficulty, String id);
}

List<AnswerChoice> choices(Random r, int correct) {
  final values = <int>{correct};
  while (values.length < 4) {
    final v = correct + r.nextInt(11) - 5;
    if (v >= 0) values.add(v);
  }
  final answers = values.map(AnswerChoice.number).toList();
  answers.shuffle(r);
  return answers;
}

class ComparisonGenerator implements QuestionGenerator {
  const ComparisonGenerator({this.chooseLarger});

  final bool? chooseLarger;

  @override
  BrainQuestion generate(Random r, int difficulty, String id) {
    final larger = chooseLarger ?? r.nextBool();
    final a = r.nextInt(20 + difficulty * 35) + 1;
    final b = a + 1 + r.nextInt(12);
    final answers = [AnswerChoice.number(a), AnswerChoice.number(b)]
      ..shuffle(r);
    return BrainQuestion(
      id: id,
      type: QuestionType.larger,
      questionText: larger ? 'larger' : 'smaller',
      expression: '',
      answers: answers,
      correctAnswerIndex: answers.indexOf(AnswerChoice.number(larger ? b : a)),
      difficulty: difficulty,
    );
  }
}

class LargerGenerator extends ComparisonGenerator {
  const LargerGenerator() : super(chooseLarger: true);
}

class ArithmeticGenerator implements QuestionGenerator {
  @override
  BrainQuestion generate(Random r, int difficulty, String id) {
    final multiply = difficulty > 0 && r.nextBool();
    final a = r.nextInt(multiply ? 9 : 10 + difficulty * 15) + 2;
    final b = r.nextInt(multiply ? 9 : 10 + difficulty * 10) + 2;
    final correct = multiply ? a * b : a + b;
    final answers = choices(r, correct);
    return BrainQuestion(
      id: id,
      type: QuestionType.arithmetic,
      questionText: 'solve',
      expression: '$a ${multiply ? '×' : '+'} $b = ?',
      answers: answers,
      correctAnswerIndex: answers.indexOf(AnswerChoice.number(correct)),
      difficulty: difficulty,
    );
  }
}

class ParityGenerator implements QuestionGenerator {
  @override
  BrainQuestion generate(Random r, int difficulty, String id) {
    final odd = r.nextBool();
    final base = r.nextInt(10 + difficulty * 15) * 2 + 2;
    final correct = base + (odd ? 1 : 0);
    final answers = [
      correct,
      base + 2 + (odd ? 0 : 1),
      base + 4 + (odd ? 0 : 1),
      base + 6 + (odd ? 0 : 1),
    ].map(AnswerChoice.number).toList()..shuffle(r);
    return BrainQuestion(
      id: id,
      type: QuestionType.parity,
      questionText: odd ? 'odd' : 'even',
      expression: '',
      answers: answers,
      correctAnswerIndex: answers.indexOf(AnswerChoice.number(correct)),
      difficulty: difficulty,
    );
  }
}

class SequenceGenerator implements QuestionGenerator {
  @override
  BrainQuestion generate(Random r, int difficulty, String id) {
    final step = 2 + r.nextInt(difficulty == 0 ? 2 : 4);
    final start = 1 + r.nextInt(5 + difficulty * 8);
    final correct = start + step * 4;
    final answers = choices(r, correct);
    return BrainQuestion(
      id: id,
      type: QuestionType.sequence,
      questionText: 'sequence',
      expression:
          '${List.generate(4, (i) => start + i * step).join(' · ')} · ?',
      answers: answers,
      correctAnswerIndex: answers.indexOf(AnswerChoice.number(correct)),
      difficulty: difficulty,
    );
  }
}

class FractionGenerator implements QuestionGenerator {
  const FractionGenerator({this.chooseLarger});

  final bool? chooseLarger;

  static const _easyFamiliar = <List<FractionValue>>[
    [FractionValue(1, 2), FractionValue(1, 4)],
    [FractionValue(1, 3), FractionValue(1, 2)],
    [FractionValue(1, 4), FractionValue(3, 4)],
  ];
  static const _mediumPairs = <List<FractionValue>>[
    [FractionValue(2, 3), FractionValue(3, 4)],
    [FractionValue(3, 5), FractionValue(2, 3)],
    [FractionValue(2, 5), FractionValue(3, 7)],
    [FractionValue(3, 8), FractionValue(1, 2)],
    [FractionValue(4, 5), FractionValue(5, 7)],
  ];
  static const _hardPairs = <List<FractionValue>>[
    [FractionValue(5, 8), FractionValue(2, 3)],
    [FractionValue(4, 7), FractionValue(3, 5)],
    [FractionValue(5, 7), FractionValue(3, 4)],
    [FractionValue(7, 9), FractionValue(4, 5)],
    [FractionValue(5, 6), FractionValue(6, 7)],
  ];

  List<FractionValue> _easyPair(Random r) {
    if (r.nextInt(3) == 0) {
      return List.of(_easyFamiliar[r.nextInt(_easyFamiliar.length)]);
    }
    if (r.nextBool()) {
      final denominator = 3 + r.nextInt(6);
      final a = 1 + r.nextInt(denominator - 1);
      var b = 1 + r.nextInt(denominator - 1);
      while (b == a) {
        b = 1 + r.nextInt(denominator - 1);
      }
      return [FractionValue(a, denominator), FractionValue(b, denominator)];
    }
    final numerator = 1 + r.nextInt(3);
    final minimumDenominator = numerator + 1;
    final a = minimumDenominator + r.nextInt(8 - minimumDenominator + 1);
    var b = minimumDenominator + r.nextInt(8 - minimumDenominator + 1);
    while (b == a) {
      b = minimumDenominator + r.nextInt(8 - minimumDenominator + 1);
    }
    return [FractionValue(numerator, a), FractionValue(numerator, b)];
  }

  @override
  BrainQuestion generate(Random r, int difficulty, String id) {
    final larger = chooseLarger ?? r.nextBool();
    final source = difficulty <= 0
        ? _easyPair(r)
        : List.of(
            (difficulty == 1 ? _mediumPairs : _hardPairs)[r.nextInt(
              difficulty == 1 ? _mediumPairs.length : _hardPairs.length,
            )],
          );
    assert(source[0].denominator > 0 && source[1].denominator > 0);
    assert(!source[0].isEquivalentTo(source[1]));
    final correct = larger
        ? (source[0].compareTo(source[1]) > 0 ? source[0] : source[1])
        : (source[0].compareTo(source[1]) < 0 ? source[0] : source[1]);
    final useSpecificPrompt = r.nextBool();
    source.shuffle(r);
    final answers = source.map(AnswerChoice.fraction).toList();
    return BrainQuestion(
      id: id,
      type: QuestionType.fraction,
      questionText: useSpecificPrompt
          ? (larger ? 'fractionLarger' : 'fractionSmaller')
          : (larger ? 'larger' : 'smaller'),
      expression: '',
      answers: answers,
      correctAnswerIndex: answers.indexOf(AnswerChoice.fraction(correct)),
      difficulty: difficulty.clamp(0, 2),
    );
  }
}

class QuestionEngine {
  QuestionEngine({int? seed}) : random = Random(seed) {
    _refillBag();
  }
  final Random random;
  static const distribution = <QuestionType, int>{
    QuestionType.larger: 20,
    QuestionType.arithmetic: 25,
    QuestionType.parity: 15,
    QuestionType.sequence: 20,
    QuestionType.fraction: 20,
  };
  final generators = <QuestionType, QuestionGenerator>{
    QuestionType.larger: const ComparisonGenerator(),
    QuestionType.arithmetic: ArithmeticGenerator(),
    QuestionType.parity: ParityGenerator(),
    QuestionType.sequence: SequenceGenerator(),
    QuestionType.fraction: const FractionGenerator(),
  };
  final List<QuestionType> _bag = [];
  QuestionType? _lastType;
  int index = 0;

  void _refillBag() {
    for (final entry in distribution.entries) {
      _bag.addAll(List.filled(entry.value ~/ 5, entry.key));
    }
    _bag.shuffle(random);
  }

  BrainQuestion next(int difficulty, {int? fractionDifficulty}) {
    if (_bag.isEmpty) _refillBag();
    if (_bag.length > 1 && _bag.last == _lastType) {
      final swapIndex = _bag.indexWhere((type) => type != _lastType);
      if (swapIndex >= 0) {
        final replacement = _bag[swapIndex];
        _bag[swapIndex] = _bag.last;
        _bag[_bag.length - 1] = replacement;
      }
    }
    final type = _bag.removeLast();
    _lastType = type;
    return generators[type]!.generate(
      random,
      type == QuestionType.fraction
          ? fractionDifficulty ?? difficulty
          : difficulty,
      'q${index++}',
    );
  }

  static int dailySeed(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;
}
