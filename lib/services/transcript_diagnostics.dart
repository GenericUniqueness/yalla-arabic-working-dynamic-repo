import 'package:flutter/foundation.dart';

import '../models/sentence.dart';
import 'content_source_config.dart';

class TranscriptDiagnostics {
  static const double largeGapSeconds = 12;
  static const double compressedWordsPerSecond = 8;
  static const double suspiciousFirstStartSeconds = 1.5;

  static void logLesson({
    required LessonContent? content,
    required String sourcePath,
    Duration? audioDuration,
  }) {
    if (!ContentSourceConfig.transcriptDebugEnabled || content == null) return;

    final sentences = content.sentences;
    if (sentences.isEmpty) {
      _log(sourcePath, 'missing transcript: no sentence entries loaded');
      return;
    }

    final first = sentences.first;
    if (first.startTime > suspiciousFirstStartSeconds) {
      _log(
        sourcePath,
        'suspicious beginning offset: first entry starts at '
        '${first.startTime.toStringAsFixed(2)}s',
      );
    }

    SentenceData? previous;
    for (var i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      final text = sentence.english.trim();
      final duration = sentence.endTime - sentence.startTime;

      if (text.isEmpty) {
        _log(sourcePath, 'missing transcript line: entry $i has empty text');
      }

      if (sentence.endTime > 0 && sentence.endTime <= sentence.startTime) {
        _log(
          sourcePath,
          'invalid timestamp: entry $i ends at '
          '${sentence.endTime.toStringAsFixed(2)}s before/at start '
          '${sentence.startTime.toStringAsFixed(2)}s',
        );
      }

      if (previous != null) {
        final gap = sentence.startTime - previous.endTime;
        if (gap > largeGapSeconds) {
          _log(
            sourcePath,
            'large timestamp gap: ${gap.toStringAsFixed(2)}s before entry $i',
          );
        }
        if (sentence.startTime < previous.endTime) {
          _log(
            sourcePath,
            'overlapping timestamps: entry ${i - 1} ends at '
            '${previous.endTime.toStringAsFixed(2)}s, entry $i starts at '
            '${sentence.startTime.toStringAsFixed(2)}s',
          );
        }
      }

      final wordCount = _wordCount(text);
      if (duration > 0 && wordCount >= 8) {
        final wordsPerSecond = wordCount / duration;
        if (wordsPerSecond > compressedWordsPerSecond) {
          _log(
            sourcePath,
            'compressed timing: entry $i has $wordCount words in '
            '${duration.toStringAsFixed(2)}s '
            '(${wordsPerSecond.toStringAsFixed(1)} words/sec)',
          );
        }
      }

      previous = sentence;
    }

    if (audioDuration != null && audioDuration.inMilliseconds > 0) {
      final lastEnd = sentences.last.endTime;
      final tailGap = audioDuration.inMilliseconds / 1000.0 - lastEnd;
      if (tailGap > largeGapSeconds) {
        _log(
          sourcePath,
          'large final transcript gap: ${tailGap.toStringAsFixed(2)}s after '
          'last entry',
        );
      }
    }
  }

  static int _wordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  static void _log(String sourcePath, String message) {
    debugPrint('[TranscriptDiagnostics] $sourcePath: $message');
  }
}
