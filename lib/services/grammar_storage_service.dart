import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/grammar_models.dart';

class GrammarStorageService {
  static const _progressPrefix = 'grammar_topic_progress_';
  static const _weakTagsKey = 'grammar_weak_tags';
  static const _weakTopicIdsKey = 'grammar_weak_topic_ids';
  static const _maxWeakTags = 30;

  static Future<void> saveTopicProgress(
    String topicId,
    int score,
    int total,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadTopicProgress(topicId);
    final bestScore = existing == null
        ? score
        : (score > existing.bestScore ? score : existing.bestScore);
    final progress = TopicProgress(
      lastScore: score,
      lastTotal: total,
      lastAttemptEpoch: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      bestScore: bestScore,
      attemptCount: (existing?.attemptCount ?? 0) + 1,
    );
    await prefs.setString(
      '$_progressPrefix$topicId',
      jsonEncode(progress.toJson()),
    );
  }

  static Future<TopicProgress?> loadTopicProgress(String topicId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_progressPrefix$topicId');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return TopicProgress.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, TopicProgress>> loadAllProgress(
    Iterable<String> topicIds,
  ) async {
    final progress = <String, TopicProgress>{};
    for (final topicId in topicIds) {
      final item = await loadTopicProgress(topicId);
      if (item != null) progress[topicId] = item;
    }
    return progress;
  }

  static Future<void> addWeakTags(
    List<String> weakTags, {
    List<String> topicIds = const [],
  }) async {
    final cleanTags = weakTags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    if (cleanTags.isEmpty && topicIds.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = await loadWeakTags();
    final merged = <String>[...current];
    for (final tag in cleanTags) {
      merged.remove(tag);
      merged.add(tag);
    }
    final trimmed = merged.length > _maxWeakTags
        ? merged.sublist(merged.length - _maxWeakTags)
        : merged;
    await prefs.setString(_weakTagsKey, jsonEncode(trimmed));

    final currentTopics = await loadWeakTopicIds();
    final topicSet = <String>{...currentTopics};
    topicSet.addAll(
        topicIds.map((topicId) => topicId.trim()).where((id) => id.isNotEmpty));
    await prefs.setString(_weakTopicIdsKey, jsonEncode(topicSet.toList()));
  }

  static Future<void> clearWeakTag(String weakTag) async {
    final cleanTag = weakTag.trim();
    if (cleanTag.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final tags = await loadWeakTags();
    tags.removeWhere((tag) => tag == cleanTag);
    await prefs.setString(_weakTagsKey, jsonEncode(tags));
  }

  static Future<List<String>> loadWeakTags() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeStringList(prefs.getString(_weakTagsKey));
  }

  static Future<List<String>> loadWeakTopicIds() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeStringList(prefs.getString(_weakTopicIdsKey));
  }

  static Future<void> clearWeakTopicId(String topicId) async {
    final cleanId = topicId.trim();
    if (cleanId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final ids = await loadWeakTopicIds();
    ids.removeWhere((id) => id == cleanId);
    await prefs.setString(_weakTopicIdsKey, jsonEncode(ids));
  }

  static List<String> _decodeStringList(String? raw) {
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
