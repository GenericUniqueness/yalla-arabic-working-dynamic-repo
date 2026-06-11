import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quiz_models.dart';

class QuizStorageService {
  static const _batchesKey = 'quiz_batches';
  static const _historyKey = 'quiz_history';
  static const _maxHistory = 50;

  static Future<List<QuizBatch>> loadBatches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_batchesKey) ?? [];
    return raw
        .map((s) {
          try {
            return QuizBatch.fromJson(jsonDecode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<QuizBatch>()
        .toList();
  }

  static Future<void> saveBatch(QuizBatch batch) async {
    final prefs = await SharedPreferences.getInstance();
    final batches = await loadBatches();
    batches.removeWhere((b) => b.id == batch.id);
    batches.insert(0, batch);
    await prefs.setStringList(
      _batchesKey,
      batches.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }

  static Future<void> deleteBatch(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final batches = await loadBatches();
    batches.removeWhere((b) => b.id == id);
    await prefs.setStringList(
      _batchesKey,
      batches.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }

  static Future<List<QuizHistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    return raw
        .map((s) {
          try {
            return QuizHistoryEntry.fromJson(jsonDecode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<QuizHistoryEntry>()
        .toList();
  }

  static Future<void> addHistoryEntry(QuizHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    history.insert(0, entry);
    final trimmed = history.take(_maxHistory).toList();
    await prefs.setStringList(
      _historyKey,
      trimmed.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }

  static String newBatchId() => 'b_${DateTime.now().millisecondsSinceEpoch}';

  static String newHistoryId() => 'h_${DateTime.now().millisecondsSinceEpoch}';
}
