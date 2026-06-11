import '../models/course.dart';

final List<Course> allCourses = [
  Course(
    id: 1,
    title: 'Main Courses',
    description: 'Private dev Al-Fusha listening lessons.',
    level: 'A1',
    totalDurationSeconds: 1757,
    lessons: [
      Lesson(
        id: 7,
        courseId: 1,
        title: 'Easy Arabic Podcast | about Social Media',
        availableTypes: const [LessonType.mainStory],
      ),
      Lesson(
        id: 10,
        courseId: 1,
        title: 'Arabic Conversation for Beginners #2 | The Family',
        availableTypes: const [LessonType.mainStory],
      ),
    ],
  ),
];
