const List<String> kSketchWords = [
  'apple', 'rocket', 'guitar', 'castle', 'dragon', 'pizza', 'rainbow',
  'island', 'robot', 'butterfly', 'mountain', 'camera', 'penguin', 'cactus',
  'anchor', 'balloon', 'lighthouse', 'sandwich', 'umbrella', 'volcano',
  'dolphin', 'wizard', 'tornado', 'cupcake', 'skateboard', 'snowman',
];

String pickSketchWord(int seed) => kSketchWords[seed.abs() % kSketchWords.length];
