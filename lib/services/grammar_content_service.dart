import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/grammar_models.dart';

class GrammarContentService {
  static const _indexPath = 'assets/grammar/grammar_index.json';
  static final Map<String, GrammarTopic> _topicCache = {};
  static List<GrammarCategory>? _categoryCache;

  static Future<List<GrammarCategory>> loadIndex() async {
    final cached = _categoryCache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_indexPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Grammar index must be a JSON object.');
    }
    final categoriesRaw = decoded['categories'];
    if (categoriesRaw is! List) {
      throw const FormatException('Grammar index categories must be a list.');
    }
    final categories = categoriesRaw
        .whereType<Map>()
        .map((item) => GrammarCategory.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
    _categoryCache = categories;
    return categories;
  }

  static Future<GrammarTopic> loadTopic(String topicId) async {
    final cached = _topicCache[topicId];
    if (cached != null) return cached;

    final raw =
        await rootBundle.loadString('assets/grammar/topics/$topicId.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException('Grammar topic $topicId must be a JSON object.');
    }
    final topic = GrammarTopic.fromJson(Map<String, dynamic>.from(decoded));
    _topicCache[topicId] = topic;
    return topic;
  }

  static Future<List<GrammarTopic>> loadTopicsForCategory(
    GrammarCategory category,
  ) async {
    final topics = <GrammarTopic>[];
    for (final topicId in category.topicIds) {
      topics.add(await loadTopic(topicId));
    }
    return topics;
  }

  static Future<List<GrammarTopic>> loadAllTopics() async {
    final categories = await loadIndex();
    final topicIds = <String>{};
    for (final category in categories) {
      topicIds.addAll(category.topicIds);
    }

    final topics = <GrammarTopic>[];
    for (final topicId in topicIds) {
      topics.add(await loadTopic(topicId));
    }
    return topics;
  }

  static Future<List<GrammarQuestion>> loadQuestionsForWeakTags(
    List<String> weakTags,
  ) async {
    if (weakTags.isEmpty) return const [];
    final tagSet = weakTags.toSet();
    final topics = await loadAllTopics();
    final questions = <GrammarQuestion>[];
    for (final topic in topics) {
      questions.addAll(
        topic.questions
            .where((q) => q.weakTag != null && tagSet.contains(q.weakTag)),
      );
    }
    return questions;
  }

  static void clearCache() {
    _categoryCache = null;
    _topicCache.clear();
  }
}
