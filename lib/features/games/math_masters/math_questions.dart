import 'dart:math';

/// A single arithmetic question with four answer options.
class MathQuestion {
  final String prompt;
  final int answer;
  final List<int> options;
  final int correctIndex;

  const MathQuestion({
    required this.prompt,
    required this.answer,
    required this.options,
    required this.correctIndex,
  });
}

/// Deterministically builds the same [count] questions for every player in a
/// match (seeded by the match id) so the contest is fair.
List<MathQuestion> buildMathQuestions(int seed, int count) {
  final rng = Random(seed);
  final questions = <MathQuestion>[];
  for (var i = 0; i < count; i++) {
    final type = rng.nextInt(4); // +, -, x, mixed
    late int a, b, answer;
    late String op;
    switch (type) {
      case 0:
        a = rng.nextInt(40) + 10;
        b = rng.nextInt(40) + 10;
        op = '+';
        answer = a + b;
        break;
      case 1:
        a = rng.nextInt(50) + 30;
        b = rng.nextInt(a - 5) + 1;
        op = '−';
        answer = a - b;
        break;
      case 2:
        a = rng.nextInt(11) + 2;
        b = rng.nextInt(11) + 2;
        op = '×';
        answer = a * b;
        break;
      default:
        a = rng.nextInt(9) + 2;
        b = rng.nextInt(9) + 2;
        final c = rng.nextInt(9) + 2;
        op = '×+';
        answer = a * b + c;
        questions.add(_withOptions('$a × $b + $c', answer, rng));
        continue;
    }
    questions.add(_withOptions('$a $op $b', answer, rng));
  }
  return questions;
}

MathQuestion _withOptions(String prompt, int answer, Random rng) {
  final options = <int>{answer};
  while (options.length < 4) {
    final delta = rng.nextInt(12) + 1;
    final candidate = rng.nextBool() ? answer + delta : answer - delta;
    if (candidate >= 0) options.add(candidate);
  }
  final shuffled = options.toList()..shuffle(rng);
  return MathQuestion(
    prompt: prompt,
    answer: answer,
    options: shuffled,
    correctIndex: shuffled.indexOf(answer),
  );
}
