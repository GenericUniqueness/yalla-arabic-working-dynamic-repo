import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/course.dart';
import '../../providers/course_provider.dart';
import '../lessons/player_screen.dart';

class QaLessonLauncher extends StatelessWidget {
  final String lessonKey;

  const QaLessonLauncher({super.key, required this.lessonKey});

  @override
  Widget build(BuildContext context) {
    final parsed = _QaLessonKey.tryParse(lessonKey);
    if (parsed == null) {
      return _QaLaunchError(
        lessonKey: lessonKey,
        message:
            'Invalid YALLA_QA_LESSON_KEY. Expected course_XX/lesson_YY/type.',
      );
    }

    final courses = context.watch<CourseProvider>().courses;
    final course = _firstWhereOrNull(courses, (c) => c.id == parsed.courseId);
    if (course == null) {
      return _QaLaunchError(
        lessonKey: lessonKey,
        message: 'No course found for course_${_two(parsed.courseId)}.',
      );
    }

    final lesson =
        _firstWhereOrNull(course.lessons, (l) => l.id == parsed.lessonId);
    if (lesson == null) {
      return _QaLaunchError(
        lessonKey: lessonKey,
        message:
            'No lesson found for course_${_two(parsed.courseId)}/lesson_${_two(parsed.lessonId)}.',
      );
    }

    final type = _firstWhereOrNull(
      lesson.availableTypes,
      (t) => t.assetFolder == parsed.typeFolder,
    );
    if (type == null) {
      return _QaLaunchError(
        lessonKey: lessonKey,
        message:
            'Lesson exists, but type "${parsed.typeFolder}" is not available.',
      );
    }

    debugPrint('QA DIRECT LESSON LAUNCH: $lessonKey');
    return PlayerScreen(lesson: lesson, initialType: type);
  }
}

class _QaLessonKey {
  final int courseId;
  final int lessonId;
  final String typeFolder;

  const _QaLessonKey({
    required this.courseId,
    required this.lessonId,
    required this.typeFolder,
  });

  static _QaLessonKey? tryParse(String value) {
    final match = RegExp(
      r'^course_(\d{2})/lesson_(\d{2})/([a-z_]+)$',
    ).firstMatch(value.trim());
    if (match == null) return null;

    final courseId = int.tryParse(match.group(1)!);
    final lessonId = int.tryParse(match.group(2)!);
    final typeFolder = match.group(3)!;
    if (courseId == null || lessonId == null) return null;

    return _QaLessonKey(
      courseId: courseId,
      lessonId: lessonId,
      typeFolder: typeFolder,
    );
  }
}

class _QaLaunchError extends StatelessWidget {
  final String lessonKey;
  final String message;

  const _QaLaunchError({
    required this.lessonKey,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('QA DIRECT LESSON LAUNCH ERROR: $lessonKey: $message');
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.orangeAccent,
                size: 44,
              ),
              const SizedBox(height: 16),
              const Text(
                'QA lesson launch failed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                lessonKey,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}

String _two(int value) => value.toString().padLeft(2, '0');
