class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  const QuizQuestion(this.question, this.options, this.correctIndex);
}

const List<QuizQuestion> kQuizBank = [
  QuizQuestion('What planet is known as the Red Planet?',
      ['Venus', 'Mars', 'Jupiter', 'Saturn'], 1),
  QuizQuestion('How many continents are there on Earth?',
      ['5', '6', '7', '8'], 2),
  QuizQuestion('What is the largest mammal?',
      ['Elephant', 'Blue Whale', 'Giraffe', 'Hippo'], 1),
  QuizQuestion('Which language runs Flutter apps?',
      ['Kotlin', 'Swift', 'Dart', 'Java'], 2),
  QuizQuestion('What is the capital of Japan?',
      ['Seoul', 'Beijing', 'Bangkok', 'Tokyo'], 3),
  QuizQuestion('How many sides does a hexagon have?',
      ['5', '6', '7', '8'], 1),
  QuizQuestion('Which gas do plants absorb?',
      ['Oxygen', 'Nitrogen', 'Carbon Dioxide', 'Hydrogen'], 2),
  QuizQuestion('What is the smallest prime number?',
      ['0', '1', '2', '3'], 2),
  QuizQuestion('Who painted the Mona Lisa?',
      ['Van Gogh', 'Da Vinci', 'Picasso', 'Monet'], 1),
  QuizQuestion('What is the chemical symbol for gold?',
      ['Gd', 'Go', 'Au', 'Ag'], 2),
  QuizQuestion('Which ocean is the largest?',
      ['Atlantic', 'Indian', 'Arctic', 'Pacific'], 3),
  QuizQuestion('How many minutes are in a full day?',
      ['1000', '1440', '2400', '720'], 1),
  QuizQuestion('What is H2O commonly known as?',
      ['Salt', 'Water', 'Oxygen', 'Acid'], 1),
  QuizQuestion('Which is the fastest land animal?',
      ['Lion', 'Cheetah', 'Horse', 'Leopard'], 1),
  QuizQuestion('What year did the first iPhone launch?',
      ['2005', '2007', '2009', '2010'], 1),
  QuizQuestion('How many strings does a standard guitar have?',
      ['4', '5', '6', '7'], 2),
];
