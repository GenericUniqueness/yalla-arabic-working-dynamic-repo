enum ReviewMode { english, arabic }

class ReviewQuestion {
  final String wordKey;
  final String displayWord;
  final String? phonetic;
  final String correctAnswer;
  final List<String> choices; // up to 5, shuffled once at build time
  final int correctIndex;
  final ReviewMode mode;
  final Map<String, dynamic> entry;
  final String? cefrLevel;

  const ReviewQuestion({
    required this.wordKey,
    required this.displayWord,
    this.phonetic,
    required this.correctAnswer,
    required this.choices,
    required this.correctIndex,
    required this.mode,
    required this.entry,
    this.cefrLevel,
  });
}

class ReviewSession {
  final List<ReviewQuestion> questions;
  final String? cefrFilter;
  final Map<String, int> levelBreakdown;
  final String? fillNote;
  int _currentIndex = 0;
  final List<bool> _answers = [];

  ReviewSession(
    this.questions, {
    this.cefrFilter,
    this.levelBreakdown = const {},
    this.fillNote,
  });

  bool get isEmpty => questions.isEmpty;
  int get total => questions.length;
  int get currentIndex => _currentIndex;
  bool get isComplete => _currentIndex >= questions.length;

  ReviewQuestion get current => questions[_currentIndex];

  // Returns true if the answer was correct. Advances to next question.
  bool answer(int choiceIndex) {
    final correct = choiceIndex == current.correctIndex;
    _answers.add(correct);
    _currentIndex++;
    return correct;
  }

  int get correctCount => _answers.where((b) => b).length;

  List<String> get missedKeys {
    final missed = <String>[];
    for (var i = 0; i < _answers.length; i++) {
      if (!_answers[i]) missed.add(questions[i].wordKey);
    }
    return missed;
  }

  List<ReviewQuestion> get missedQuestions {
    final missed = <ReviewQuestion>[];
    for (var i = 0; i < _answers.length; i++) {
      if (!_answers[i]) missed.add(questions[i]);
    }
    return missed;
  }

  List<String> get allWordKeys => questions.map((q) => q.wordKey).toList();
}
