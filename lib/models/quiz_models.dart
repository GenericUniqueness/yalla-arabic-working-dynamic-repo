class QuizBatch {
  final String id;
  final String name;
  final List<String> wordKeys;
  final String? cefrFilter;
  final int requestedSize;
  final Map<String, int> levelBreakdown;
  final DateTime createdAt;
  final String mode; // 'english' | 'arabic'

  const QuizBatch({
    required this.id,
    required this.name,
    required this.wordKeys,
    this.cefrFilter,
    required this.requestedSize,
    required this.levelBreakdown,
    required this.createdAt,
    required this.mode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'wordKeys': wordKeys,
        'cefrFilter': cefrFilter,
        'requestedSize': requestedSize,
        'levelBreakdown': levelBreakdown,
        'createdAt': createdAt.toIso8601String(),
        'mode': mode,
      };

  static QuizBatch? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    try {
      final breakdown = <String, int>{};
      final rawBreakdown = raw['levelBreakdown'];
      if (rawBreakdown is Map) {
        rawBreakdown.forEach((k, v) {
          if (k is String) breakdown[k] = (v as num?)?.toInt() ?? 0;
        });
      }
      final keys = (raw['wordKeys'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      return QuizBatch(
        id: raw['id']?.toString() ?? '',
        name: raw['name']?.toString() ?? 'Quiz Batch',
        wordKeys: keys,
        cefrFilter: raw['cefrFilter']?.toString(),
        requestedSize: (raw['requestedSize'] as num?)?.toInt() ?? keys.length,
        levelBreakdown: breakdown,
        createdAt: DateTime.tryParse(raw['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        mode: raw['mode']?.toString() ?? 'english',
      );
    } catch (_) {
      return null;
    }
  }

  String get displayLabel {
    final level = cefrFilter ?? 'All levels';
    final size = wordKeys.length;
    return '$name · $level · $size words';
  }
}

class QuizHistoryEntry {
  final String id;
  final int score;
  final int total;
  final DateTime completedAt;
  final String mode;
  final String? batchId;
  final String? batchName;
  final String? cefrFilter;
  final bool isRandom;

  const QuizHistoryEntry({
    required this.id,
    required this.score,
    required this.total,
    required this.completedAt,
    required this.mode,
    this.batchId,
    this.batchName,
    this.cefrFilter,
    required this.isRandom,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'score': score,
        'total': total,
        'completedAt': completedAt.toIso8601String(),
        'mode': mode,
        if (batchId != null) 'batchId': batchId,
        if (batchName != null) 'batchName': batchName,
        if (cefrFilter != null) 'cefrFilter': cefrFilter,
        'isRandom': isRandom,
      };

  static QuizHistoryEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    try {
      return QuizHistoryEntry(
        id: raw['id']?.toString() ?? '',
        score: (raw['score'] as num?)?.toInt() ?? 0,
        total: (raw['total'] as num?)?.toInt() ?? 0,
        completedAt: DateTime.tryParse(raw['completedAt']?.toString() ?? '') ??
            DateTime.now(),
        mode: raw['mode']?.toString() ?? 'english',
        batchId: raw['batchId']?.toString(),
        batchName: raw['batchName']?.toString(),
        cefrFilter: raw['cefrFilter']?.toString(),
        isRandom: raw['isRandom'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  double get percentage => total > 0 ? score / total : 0.0;

  String get shortLabel {
    final pct = (percentage * 100).round();
    final lvl = cefrFilter != null ? ' · $cefrFilter' : '';
    final src = isRandom ? 'Random$lvl' : (batchName ?? 'Saved words');
    return '$src · $score/$total ($pct%)';
  }
}
