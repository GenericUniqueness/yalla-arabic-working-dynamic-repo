import 'dart:math';

class GrammarCategory {
  final String id;
  final String displayName;
  final String displayNameAr;
  final String icon;
  final List<String> topicIds;

  const GrammarCategory({
    required this.id,
    required this.displayName,
    required this.displayNameAr,
    required this.icon,
    required this.topicIds,
  });

  factory GrammarCategory.fromJson(Map<String, dynamic> json) {
    return GrammarCategory(
      id: _requiredString(json, 'id'),
      displayName: _requiredString(json, 'displayName'),
      displayNameAr: _requiredString(json, 'displayNameAr'),
      icon: _stringOr(json['icon'], 'school'),
      topicIds: _stringList(json['topicIds']),
    );
  }
}

class GrammarTopic {
  final String id;
  final String category;
  final String titleEn;
  final String titleAr;
  final String level;
  final String explanationEn;
  final String explanationAr;
  final List<GrammarComparison> arabicComparison;
  final List<GrammarMistake> commonMistakes;
  final List<GrammarQuestion> questions;

  const GrammarTopic({
    required this.id,
    required this.category,
    required this.titleEn,
    required this.titleAr,
    required this.level,
    required this.explanationEn,
    required this.explanationAr,
    required this.arabicComparison,
    required this.commonMistakes,
    required this.questions,
  });

  factory GrammarTopic.fromJson(Map<String, dynamic> json) {
    return GrammarTopic(
      id: _requiredString(json, 'id'),
      category: _requiredString(json, 'category'),
      titleEn: _requiredString(json, 'titleEn'),
      titleAr: _requiredString(json, 'titleAr'),
      level: _requiredString(json, 'level'),
      explanationEn: _requiredString(json, 'explanationEn'),
      explanationAr: _requiredString(json, 'explanationAr'),
      arabicComparison: _mapList(
        json['arabicComparison'],
        GrammarComparison.fromJson,
      ),
      commonMistakes: _mapList(
        json['commonMistakes'],
        GrammarMistake.fromJson,
      ),
      questions: _mapList(json['questions'], GrammarQuestion.fromJson),
    );
  }
}

class GrammarComparison {
  final String arabicStructure;
  final String arabicLiteral;
  final String englishCorrect;

  const GrammarComparison({
    required this.arabicStructure,
    required this.arabicLiteral,
    required this.englishCorrect,
  });

  factory GrammarComparison.fromJson(Map<String, dynamic> json) {
    return GrammarComparison(
      arabicStructure: _requiredString(json, 'arabicStructure'),
      arabicLiteral: _requiredString(json, 'arabicLiteral'),
      englishCorrect: _requiredString(json, 'englishCorrect'),
    );
  }
}

class GrammarMistake {
  final String wrong;
  final String correct;
  final String explanationEn;
  final String explanationAr;

  const GrammarMistake({
    required this.wrong,
    required this.correct,
    required this.explanationEn,
    required this.explanationAr,
  });

  factory GrammarMistake.fromJson(Map<String, dynamic> json) {
    return GrammarMistake(
      wrong: _requiredString(json, 'wrong'),
      correct: _requiredString(json, 'correct'),
      explanationEn: _requiredString(json, 'explanationEn'),
      explanationAr: _requiredString(json, 'explanationAr'),
    );
  }
}

enum GrammarQuestionType {
  multipleChoice,
  chooseCorrectSentence,
  fillBlankWithOptions,
  fixTheMistake,
  sentenceOrder,
  meaningMatch,
}

extension GrammarQuestionTypeValue on GrammarQuestionType {
  String get value {
    switch (this) {
      case GrammarQuestionType.multipleChoice:
        return 'multiple_choice';
      case GrammarQuestionType.chooseCorrectSentence:
        return 'choose_correct_sentence';
      case GrammarQuestionType.fillBlankWithOptions:
        return 'fill_blank_with_options';
      case GrammarQuestionType.fixTheMistake:
        return 'fix_the_mistake';
      case GrammarQuestionType.sentenceOrder:
        return 'sentence_order';
      case GrammarQuestionType.meaningMatch:
        return 'meaning_match';
    }
  }
}

class GrammarQuestion {
  final String id;
  final GrammarQuestionType type;
  final String prompt;
  final String? promptAr;
  final List<String> options;
  final int? correctIndex;
  final String? wrongSentence;
  final List<String> words;
  final List<int> correctOrder;
  final List<GrammarMeaningPair> pairs;
  final String explanation;
  final String? arabicNote;
  final String? weakTag;

  const GrammarQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    this.promptAr,
    this.options = const [],
    this.correctIndex,
    this.wrongSentence,
    this.words = const [],
    this.correctOrder = const [],
    this.pairs = const [],
    required this.explanation,
    this.arabicNote,
    this.weakTag,
  });

  factory GrammarQuestion.fromJson(Map<String, dynamic> json) {
    return GrammarQuestion(
      id: _requiredString(json, 'id'),
      type: _parseQuestionType(_requiredString(json, 'type')),
      prompt: _requiredString(json, 'prompt'),
      promptAr: _optionalString(json['promptAr']),
      options: _stringList(json['options']),
      correctIndex: _optionalInt(json['correctIndex']),
      wrongSentence: _optionalString(json['wrongSentence']),
      words: _stringList(json['words']),
      correctOrder: _intList(json['correctOrder']),
      pairs: _mapList(json['pairs'], GrammarMeaningPair.fromJson),
      explanation: _requiredString(json, 'explanation'),
      arabicNote: _optionalString(json['arabicNote']),
      weakTag: _optionalString(json['weakTag']),
    );
  }

  bool get usesOptions =>
      type == GrammarQuestionType.multipleChoice ||
      type == GrammarQuestionType.chooseCorrectSentence ||
      type == GrammarQuestionType.fillBlankWithOptions ||
      type == GrammarQuestionType.fixTheMistake;

  String get correctAnswerText {
    if (usesOptions &&
        correctIndex != null &&
        correctIndex! >= 0 &&
        correctIndex! < options.length) {
      return options[correctIndex!];
    }
    if (type == GrammarQuestionType.sentenceOrder) {
      return correctOrder
          .where((i) => i >= 0 && i < words.length)
          .map((i) => words[i])
          .join(' ');
    }
    if (type == GrammarQuestionType.meaningMatch) {
      return pairs.map((p) => '${p.left} = ${p.right}').join(', ');
    }
    return '';
  }

  /// Returns a copy with MCQ options shuffled and `correctIndex` updated.
  /// For non-MCQ questions (no options / no correctIndex) returns `this`.
  GrammarQuestion withShuffledOptions(Random rng) {
    if (!usesOptions || correctIndex == null || options.isEmpty) return this;
    final correct = options[correctIndex!];
    final shuffled = List<String>.from(options)..shuffle(rng);
    return GrammarQuestion(
      id: id,
      type: type,
      prompt: prompt,
      promptAr: promptAr,
      options: shuffled,
      correctIndex: shuffled.indexOf(correct),
      wrongSentence: wrongSentence,
      words: words,
      correctOrder: correctOrder,
      pairs: pairs,
      explanation: explanation,
      arabicNote: arabicNote,
      weakTag: weakTag,
    );
  }
}

class GrammarMeaningPair {
  final String left;
  final String right;

  const GrammarMeaningPair({
    required this.left,
    required this.right,
  });

  factory GrammarMeaningPair.fromJson(Map<String, dynamic> json) {
    return GrammarMeaningPair(
      left: _requiredString(json, 'left'),
      right: _requiredString(json, 'right'),
    );
  }
}

class TopicProgress {
  final int lastScore;
  final int lastTotal;
  final int lastAttemptEpoch;
  final int bestScore;
  final int attemptCount;

  const TopicProgress({
    required this.lastScore,
    required this.lastTotal,
    required this.lastAttemptEpoch,
    required this.bestScore,
    required this.attemptCount,
  });

  factory TopicProgress.fromJson(Map<String, dynamic> json) {
    return TopicProgress(
      lastScore: _intOr(json['lastScore'], 0),
      lastTotal: _intOr(json['lastTotal'], 0),
      lastAttemptEpoch: _intOr(json['lastAttemptEpoch'], 0),
      bestScore: _intOr(json['bestScore'], 0),
      attemptCount: _intOr(json['attemptCount'], 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'lastScore': lastScore,
        'lastTotal': lastTotal,
        'lastAttemptEpoch': lastAttemptEpoch,
        'bestScore': bestScore,
        'attemptCount': attemptCount,
      };

  double get lastPercent => lastTotal > 0 ? lastScore / lastTotal : 0.0;
}

class GrammarQuestionResult {
  final GrammarQuestion question;
  final bool isCorrect;
  final String selectedAnswer;
  final String correctAnswer;

  const GrammarQuestionResult({
    required this.question,
    required this.isCorrect,
    required this.selectedAnswer,
    required this.correctAnswer,
  });
}

class GrammarSessionResult {
  final GrammarTopic? topic;
  final String titleEn;
  final String titleAr;
  final bool isWeakReview;
  final List<GrammarQuestionResult> results;
  final List<String> newWeakTags;

  const GrammarSessionResult({
    required this.topic,
    required this.titleEn,
    required this.titleAr,
    required this.isWeakReview,
    required this.results,
    required this.newWeakTags,
  });

  int get total => results.length;
  int get correctCount => results.where((r) => r.isCorrect).length;
  double get scoreRatio => total > 0 ? correctCount / total : 0.0;
}

class GrammarSession {
  final GrammarTopic? topic;
  final String titleEn;
  final String titleAr;
  final bool isWeakReview;
  final List<GrammarQuestion> questions;
  final List<GrammarQuestionResult> _results = [];
  final List<String> _newWeakTags = [];
  int currentIndex = 0;

  GrammarSession({
    required this.topic,
    required this.titleEn,
    required this.titleAr,
    required this.questions,
    this.isWeakReview = false,
  });

  GrammarQuestion get current => questions[currentIndex];
  int get total => questions.length;
  bool get isComplete => currentIndex >= questions.length;
  List<GrammarQuestionResult> get results => List.unmodifiable(_results);
  List<String> get newWeakTags => List.unmodifiable(_newWeakTags);

  void answer({
    required bool isCorrect,
    required String selectedAnswer,
    required String correctAnswer,
  }) {
    final question = current;
    _results.add(GrammarQuestionResult(
      question: question,
      isCorrect: isCorrect,
      selectedAnswer: selectedAnswer,
      correctAnswer: correctAnswer,
    ));
    if (!isCorrect && question.weakTag != null) {
      _newWeakTags.add(question.weakTag!);
    }
    currentIndex += 1;
  }

  GrammarSessionResult toResult() {
    return GrammarSessionResult(
      topic: topic,
      titleEn: titleEn,
      titleAr: titleAr,
      isWeakReview: isWeakReview,
      results: List.unmodifiable(_results),
      newWeakTags: List.unmodifiable(_newWeakTags.toSet()),
    );
  }
}

GrammarQuestionType _parseQuestionType(String value) {
  switch (value) {
    case 'multiple_choice':
      return GrammarQuestionType.multipleChoice;
    case 'choose_correct_sentence':
      return GrammarQuestionType.chooseCorrectSentence;
    case 'fill_blank_with_options':
      return GrammarQuestionType.fillBlankWithOptions;
    case 'fix_the_mistake':
      return GrammarQuestionType.fixTheMistake;
    case 'sentence_order':
      return GrammarQuestionType.sentenceOrder;
    case 'meaning_match':
      return GrammarQuestionType.meaningMatch;
    default:
      throw FormatException('Unsupported grammar question type: $value');
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Missing required string field: $key');
}

String _stringOr(dynamic value, String fallback) {
  if (value is String && value.trim().isNotEmpty) return value;
  return fallback;
}

String? _optionalString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

int? _optionalInt(dynamic value) {
  if (value is num) return value.toInt();
  return null;
}

int _intOr(dynamic value, int fallback) {
  if (value is num) return value.toInt();
  return fallback;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

List<int> _intList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<num>().map((item) => item.toInt()).toList();
}

List<T> _mapList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) parse,
) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => parse(Map<String, dynamic>.from(item)))
      .toList();
}
