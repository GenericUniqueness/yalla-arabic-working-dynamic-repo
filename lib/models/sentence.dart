class SentenceData {
  final int id;
  final String english;
  final String arabic;
  final double startTime;
  final double endTime;

  SentenceData({
    required this.id,
    required this.english,
    required this.arabic,
    required this.startTime,
    required this.endTime,
  });

  factory SentenceData.fromJson(Map<String, dynamic> json, {int fallbackId = 0}) {
    return SentenceData(
      id: (json['id'] as num?)?.toInt() ?? fallbackId,
      english: json['english'] ?? json['text'] ?? '',
      arabic: json['arabic'] ?? json['ara'] ?? '',
      startTime: ((json['start_time'] ?? json['start']) as num?)?.toDouble() ?? 0.0,
      endTime: ((json['end_time'] ?? json['end']) as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LessonContent {
  final String lessonTitle;
  final List<SentenceData> sentences;

  LessonContent({required this.lessonTitle, required this.sentences});

  factory LessonContent.fromJson(dynamic json) {
    final List<dynamic> rawList;
    final String title;
    if (json is List) {
      rawList = json;
      title = '';
    } else {
      rawList = (json['sentences'] as List);
      title = json['lesson_title'] ?? '';
    }
    final sentences = rawList.asMap().entries
        .map((e) => SentenceData.fromJson(e.value as Map<String, dynamic>, fallbackId: e.key))
        .toList();
    return LessonContent(lessonTitle: title, sentences: sentences);
  }
}
