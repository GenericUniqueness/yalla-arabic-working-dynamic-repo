import 'package:flutter/foundation.dart';

import '../models/course.dart';
import '../data/courses_data.dart';
import 'content_source_config.dart';

/// Thin facade over [allCourses]. Course data is hardcoded in courses_data.dart
/// and never fetched from Firestore. Do not add Firestore loading here — it
/// caused stale-type-mapping bugs after the folder reorganisation.
class CourseService {
  static List<Course> get initialCourses => _withDebugQaCourses(allCourses);

  static Future<List<Course>> load() async {
    return initialCourses;
  }

  static List<Course> _withDebugQaCourses(List<Course> courses) {
    final qaCourse = _debugCourse09QaCourse();
    if (qaCourse == null) return courses;
    if (courses.any((course) => course.id == qaCourse.id)) return courses;
    return [...courses, qaCourse];
  }

  static Course? _debugCourse09QaCourse() {
    if (!kDebugMode) return null;
    if (!ContentSourceConfig.isLocalOverride) return null;
    if (!ContentSourceConfig.qaLessonLaunchEnabled) return null;
    if (!ContentSourceConfig.qaLessonKey.startsWith('course_09/')) return null;
    return Course(
      id: 9,
      title: 'C2 Pronunciation QA',
      description: 'Debug-only local QA course for staged C2 lessons',
      level: 'C2',
      lessons: [
        Lesson(
            id: 1,
            courseId: 9,
            title:
                'Speak American English in 30 Minutes: Advanced Pronunciation Lesson',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 2,
            courseId: 9,
            title: "Don't say these BAD words by accident!",
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 4,
            courseId: 9,
            title:
                '5 Secrets to Having an American English Accent: Advanced Pronunciation Lesson',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 5,
            courseId: 9,
            title: 'Top 14 American Slang: English vocabulary lesson',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 6,
            courseId: 9,
            title:
                'Top 15 Tongue Twisters in English: Advanced Pronunciation Lesson',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 8,
            courseId: 9,
            title: 'Speak With Me: English Speaking Practice',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 10,
            courseId: 9,
            title: 'Speak English Like Me: English Pronunciation Practice',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 12,
            courseId: 9,
            title:
                '45 Minute English Lesson: Vocabulary, Grammar, Pronunciation',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 14,
            courseId: 9,
            title: '8 Fast English Sentences: Can you say them?',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 15,
            courseId: 9,
            title: 'Advanced English Sounds you need to know',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 16,
            courseId: 9,
            title: 'English Pronunciation Test',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 17,
            courseId: 9,
            title: '10 Reductions for Natural English Pronunciation',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 18,
            courseId: 9,
            title: '2 Hour English Test: How will you do?',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 19,
            courseId: 9,
            title: '10 Ways to Improve Your English Pronunciation',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 21,
            courseId: 9,
            title: 'How to Pronounce Negative Contractions',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 22,
            courseId: 9,
            title: 'How to Say BIG NUMBERS in English',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 23,
            courseId: 9,
            title: 'Say the Alphabet: ABC',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 24,
            courseId: 9,
            title: '10 Words You Are Mispronouncing',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 26,
            courseId: 9,
            title: 'How to Pronounce THE: English Pronunciation Lesson',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 28,
            courseId: 9,
            title: 'How to Speak FAST English with Reductions',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 29,
            courseId: 9,
            title: 'How to Speak FAST English',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 30,
            courseId: 9,
            title:
                'Advanced English Conversation: Vocabulary, Phrasal Verb, Pronunciation',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 31,
            courseId: 9,
            title: 'Accent Reduction Class: Speak Natural English',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 32,
            courseId: 9,
            title: 'How to Pronounce TOP 10 English Introductions',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 33,
            courseId: 9,
            title: 'How to pronounce 100 JOBS in English',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 34,
            courseId: 9,
            title: 'Pronounce 33 MOST DIFFICULT English Words',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 35,
            courseId: 9,
            title:
                'How to Pronounce ALL ENGLISH Sounds: American English Lesson',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 37,
            courseId: 9,
            title: 'QUIZ: American VS British English Pronunciation',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 38,
            courseId: 9,
            title: 'Tongue Twisters: English Pronunciation Lesson',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 39,
            courseId: 9,
            title: 'Learn English Like a Native',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 41,
            courseId: 9,
            title:
                '4 Secrets to Having an American English Accent: Advanced Pronunciation Lesson',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 42,
            courseId: 9,
            title: 'Best English Pronunciation Lesson: Speak Fluent English',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 43,
            courseId: 9,
            title:
                'How to Pronounce Contractions: 81 Contractions in American English',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 44,
            courseId: 9,
            title: 'How to Pronounce and Use the Top 33 Phrasal Verbs',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 45,
            courseId: 9,
            title: 'How to Pronounce 100 Most Important Words in English',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 47,
            courseId: 9,
            title:
                'Top 7 FILLER Expressions: Advanced English Vocabulary Lesson',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 57,
            courseId: 9,
            title:
                'Master Class: Vocabulary, Pronunciation, Grammar with Vanessa',
            availableTypes: const [LessonType.mainStory]),
        Lesson(
            id: 59,
            courseId: 9,
            title: 'English Reductions [Advance Pronunciation Practice]',
            availableTypes: const [LessonType.mainStory]),
      ],
    );
  }
}
