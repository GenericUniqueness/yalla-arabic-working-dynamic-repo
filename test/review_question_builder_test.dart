import 'package:ez_english_app/models/review_question.dart';
import 'package:ez_english_app/providers/favourites_provider.dart';
import 'package:ez_english_app/services/review_question_builder.dart';
import 'package:ez_english_app/services/word_definition_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WordDefinitionService.load();
  });

  test('saved-word English quiz supplements from the wider dictionary', () {
    final session = ReviewQuestionBuilder.build(
      savedWords: _savedWords(['abandon']),
      mode: ReviewMode.english,
      maxQuestions: 1,
    );

    expect(session.questions, hasLength(1));
    final question = session.questions.single;
    expect(question.mode, ReviewMode.english);
    expect(question.choices, hasLength(5));
    _expectSafeQuestionOptions(question);
  });

  test('saved-word Arabic quiz supplements from the wider dictionary', () {
    final session = ReviewQuestionBuilder.build(
      savedWords: _savedWords(['abandon']),
      mode: ReviewMode.arabic,
      maxQuestions: 1,
    );

    expect(session.questions, hasLength(1));
    final question = session.questions.single;
    expect(question.mode, ReviewMode.arabic);
    expect(question.choices, hasLength(5));
    expect(_containsArabic(question.displayWord), isTrue);
    _expectEnglishChoices(question);
    _expectSafeQuestionOptions(question);
  });

  test('random English quiz uses distractors outside the selected questions',
      () {
    final session = ReviewQuestionBuilder.buildRandom(
      mode: ReviewMode.english,
      maxQuestions: 1,
    );

    expect(session.questions, hasLength(1));
    final question = session.questions.single;
    expect(question.mode, ReviewMode.english);
    expect(question.choices, hasLength(5));
    _expectSafeQuestionOptions(question);
    _expectDistractorOutsideCurrentQuestionSet(session);
  });

  test('filtered random Arabic quiz keeps five safe local choices', () {
    final session = ReviewQuestionBuilder.buildRandom(
      mode: ReviewMode.arabic,
      maxQuestions: 1,
      cefrFilter: 'B1',
    );

    expect(session.cefrFilter, 'B1');
    expect(session.questions, hasLength(1));
    final question = session.questions.single;
    expect(question.mode, ReviewMode.arabic);
    expect(question.choices, hasLength(5));
    expect(_containsArabic(question.displayWord), isTrue);
    _expectEnglishChoices(question);
    _expectSafeQuestionOptions(question);
    _expectDistractorOutsideCurrentQuestionSet(session);
  });

  test('dev Arabic random quiz uses Arabic prompts with English choices', () {
    final session = ReviewQuestionBuilder.buildArabicDevRandom(maxQuestions: 3);

    expect(session.questions, isNotEmpty);
    for (final question in session.questions) {
      expect(question.mode, ReviewMode.arabic);
      expect(question.displayWord.trim(), isNotEmpty);
      expect(_containsArabic(question.displayWord), isTrue);
      expect(question.choices, hasLength(5));
      expect(question.correctAnswer.trim(), isNotEmpty);
      _expectEnglishChoices(question);
      expect(question.choices[question.correctIndex], question.correctAnswer);
      expect(question.choices, isNot(contains(question.displayWord)));
    }
  });
}

List<SavedWordRef> _savedWords(List<String> keys) {
  return [
    for (var i = 0; i < keys.length; i++)
      SavedWordRef(
        key: keys[i],
        savedAt: DateTime.utc(2026, 6, 1, 12, i),
      ),
  ];
}

void _expectSafeQuestionOptions(ReviewQuestion question) {
  expect(question.choices.length, inInclusiveRange(2, 5));
  expect(
      question.correctIndex, inInclusiveRange(0, question.choices.length - 1));

  final normalisedChoices = question.choices.map(_normalise).toList();
  expect(normalisedChoices.toSet(), hasLength(question.choices.length));
  for (final choice in question.choices) {
    expect(choice.trim(), isNotEmpty);
  }

  final normalisedCorrect = _normalise(question.correctAnswer);
  expect(
      _normalise(question.choices[question.correctIndex]), normalisedCorrect);
  expect(
    normalisedChoices.where((choice) => choice == normalisedCorrect),
    hasLength(1),
  );
}

void _expectEnglishChoices(ReviewQuestion question) {
  for (final choice in question.choices) {
    expect(RegExp(r'[A-Za-z]').hasMatch(choice), isTrue);
    expect(_containsArabic(choice), isFalse);
  }
}

void _expectDistractorOutsideCurrentQuestionSet(ReviewSession session) {
  final currentCorrectAnswers =
      session.questions.map((question) => _normalise(question.correctAnswer));
  final currentCorrectSet = currentCorrectAnswers.toSet();
  final hasOutsideDistractor = session.questions.any((question) {
    final normalisedCorrect = _normalise(question.correctAnswer);
    return question.choices.any((choice) {
      final normalisedChoice = _normalise(choice);
      return normalisedChoice != normalisedCorrect &&
          !currentCorrectSet.contains(normalisedChoice);
    });
  });

  expect(hasOutsideDistractor, isTrue);
}

String _normalise(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

bool _containsArabic(String value) {
  return RegExp(r'[\u0600-\u06FF]').hasMatch(value);
}
