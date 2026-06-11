import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/grammar_models.dart';
import '../../providers/theme_provider.dart';
import '../../services/grammar_content_service.dart';
import '../../services/grammar_storage_service.dart';
import 'grammar_practice_screen.dart';
import 'grammar_topic_detail_screen.dart';

class GrammarWeakReviewScreen extends StatefulWidget {
  const GrammarWeakReviewScreen({super.key});

  @override
  State<GrammarWeakReviewScreen> createState() =>
      _GrammarWeakReviewScreenState();
}

class _GrammarWeakReviewScreenState extends State<GrammarWeakReviewScreen> {
  List<String>? _weakTags;
  List<GrammarTopic> _weakTopics = const [];
  List<GrammarQuestion> _weakQuestions = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final weakTags = await GrammarStorageService.loadWeakTags();
      final topics = await GrammarContentService.loadAllTopics();
      final tagSet = weakTags.toSet();
      final weakTopics = topics
          .where((topic) => topic.questions.any(
                (q) => q.weakTag != null && tagSet.contains(q.weakTag),
              ))
          .toList();
      final weakQuestions = <GrammarQuestion>[];
      for (final topic in weakTopics) {
        weakQuestions.addAll(
          topic.questions.where(
            (q) => q.weakTag != null && tagSet.contains(q.weakTag),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _weakTags = weakTags;
        _weakTopics = weakTopics;
        _weakQuestions = weakQuestions;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _clearTag(String tag) async {
    await GrammarStorageService.clearWeakTag(tag);
    if (mounted) _load();
  }

  Future<void> _openTopic(GrammarTopic topic) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GrammarTopicDetailScreen(topic: topic),
      ),
    );
    if (mounted) _load();
  }

  void _startPractice() {
    if (_weakQuestions.isEmpty) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GrammarPracticeScreen(
          questions: _weakQuestions,
          titleEn: 'Weak Points Review',
          titleAr: 'مراجعة نقاط الضعف',
          isWeakReview: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final weakTags = _weakTags;

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        backgroundColor: th.playerBar,
        elevation: 0,
        title:
            Text('Weak Points Review', style: TextStyle(color: th.textPrimary)),
        iconTheme: IconThemeData(color: th.textPrimary),
      ),
      body: _error != null
          ? _ErrorState(th: th, onRetry: _load)
          : weakTags == null
              ? Center(child: CircularProgressIndicator(color: th.accent))
              : weakTags.isEmpty || _weakQuestions.isEmpty
                  ? _EmptyState(th: th)
                  : SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Practise the grammar points you missed.',
                                  style: TextStyle(
                                      color: th.textSub, fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: weakTags
                                      .map(
                                        (tag) => _WeakTagChip(
                                          th: th,
                                          tag: tag,
                                          onClear: () => _clearTag(tag),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: th.accent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: Text(
                                      'Practice ${_weakQuestions.length} weak questions',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    onPressed: _startPractice,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              children: _weakTopics
                                  .map(
                                    (topic) => _WeakTopicRow(
                                      th: th,
                                      topic: topic,
                                      weakCount: topic.questions
                                          .where(
                                            (q) =>
                                                q.weakTag != null &&
                                                weakTags.contains(q.weakTag),
                                          )
                                          .length,
                                      onTap: () => _openTopic(topic),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _WeakTagChip extends StatelessWidget {
  final AppTheme th;
  final String tag;
  final VoidCallback onClear;

  const _WeakTagChip({
    required this.th,
    required this.tag,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag.replaceAll('_', ' '),
            style: TextStyle(
              color: th.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Clear weak point',
            onPressed: onClear,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.close_rounded, color: th.textSub, size: 16),
          ),
        ],
      ),
    );
  }
}

class _WeakTopicRow extends StatelessWidget {
  final AppTheme th;
  final GrammarTopic topic;
  final int weakCount;
  final VoidCallback onTap;

  const _WeakTopicRow({
    required this.th,
    required this.topic,
    required this.weakCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: th.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: th.textSub.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: const Icon(Icons.warning_amber_rounded,
            color: Colors.amber, size: 24),
        title: Text(
          topic.titleEn,
          style: TextStyle(
            color: th.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '$weakCount weak question${weakCount == 1 ? '' : 's'}',
          style: TextStyle(color: th.textSub, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: th.textSub),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppTheme th;

  const _EmptyState({required this.th});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration_rounded, color: th.accent, size: 64),
            const SizedBox(height: 14),
            Text(
              'No weak points',
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete grammar practice to build a review list.',
              textAlign: TextAlign.center,
              style: TextStyle(color: th.textSub, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final AppTheme th;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.th,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: Icon(Icons.refresh_rounded, color: th.accent),
        label: Text('Reload weak points', style: TextStyle(color: th.accent)),
      ),
    );
  }
}
