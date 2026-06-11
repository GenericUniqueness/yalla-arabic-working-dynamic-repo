class Course {
  final int id;
  final String title;
  final String description;
  final String level;
  final List<Lesson> lessons;
  final int totalDurationSeconds;

  Course({required this.id, required this.title, required this.description, required this.level, required this.lessons, this.totalDurationSeconds = 0});
}

class Lesson {
  final int id;
  final int courseId;
  final String title;
  final List<LessonType> availableTypes;

  Lesson({required this.id, required this.courseId, required this.title, required this.availableTypes});
}

enum LessonType { mainStory, vocabulary, miniStory, conversation, pov, commentary }

extension LessonTypeExtension on LessonType {
  String get displayName {
    switch (this) {
      case LessonType.mainStory: return 'Main Story';
      case LessonType.vocabulary: return 'Vocabulary';
      case LessonType.miniStory: return 'Mini Story';
      case LessonType.conversation: return 'Conversation';
      case LessonType.pov: return 'POV Story';
      case LessonType.commentary: return 'Commentary';
    }
  }

  String get assetFolder {
    switch (this) {
      case LessonType.mainStory: return 'main_story';
      case LessonType.vocabulary: return 'vocabulary';
      case LessonType.miniStory: return 'mini_story';
      case LessonType.conversation: return 'conversation';
      case LessonType.pov: return 'pov';
      case LessonType.commentary: return 'commentary';
    }
  }
}
