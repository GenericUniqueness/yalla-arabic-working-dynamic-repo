import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/grammar_models.dart';
import '../../providers/theme_provider.dart';
import '../../services/grammar_content_service.dart';
import '../../services/grammar_storage_service.dart';
import 'grammar_topic_detail_screen.dart';

class GrammarTopicListScreen extends StatefulWidget {
  final GrammarCategory category;

  const GrammarTopicListScreen({
    super.key,
    required this.category,
  });

  @override
  State<GrammarTopicListScreen> createState() => _GrammarTopicListScreenState();
}

class _GrammarTopicListScreenState extends State<GrammarTopicListScreen> {
  List<GrammarTopic>? _topics;
  Map<String, TopicProgress> _progress = const {};
  Set<String> _weakTags = const {};
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final topics =
          await GrammarContentService.loadTopicsForCategory(widget.category);
      final progress =
          await GrammarStorageService.loadAllProgress(widget.category.topicIds);
      final weakTags = await GrammarStorageService.loadWeakTags();
      if (!mounted) return;
      setState(() {
        _topics = topics;
        _progress = progress;
        _weakTags = weakTags.toSet();
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
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

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final topics = _topics;

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        backgroundColor: th.playerBar,
        elevation: 0,
        title: Text(
          widget.category.displayName,
          style: TextStyle(color: th.textPrimary),
        ),
        iconTheme: IconThemeData(color: th.textPrimary),
      ),
      body: _error != null
          ? _ErrorState(th: th, onRetry: _load)
          : topics == null
              ? Center(child: CircularProgressIndicator(color: th.accent))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        widget.category.displayNameAr,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: th.textSub, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...topics.map(
                      (topic) => _TopicCard(
                        th: th,
                        topic: topic,
                        progress: _progress[topic.id],
                        hasWeakTags: topic.questions.any(
                          (q) =>
                              q.weakTag != null &&
                              _weakTags.contains(q.weakTag),
                        ),
                        onTap: () => _openTopic(topic),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final AppTheme th;
  final GrammarTopic topic;
  final TopicProgress? progress;
  final bool hasWeakTags;
  final VoidCallback onTap;

  const _TopicCard({
    required this.th,
    required this.topic,
    required this.progress,
    required this.hasWeakTags,
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
        leading: _ProgressDot(th: th, progress: progress),
        title: Row(
          children: [
            Expanded(
              child: Text(
                topic.titleEn,
                style: TextStyle(
                  color: th.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _LevelBadge(th: th, level: topic.level),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              topic.titleAr,
              textAlign: TextAlign.right,
              style: TextStyle(color: th.textSub, fontSize: 13),
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasWeakTags)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.warning_amber_rounded,
                    color: Colors.amber, size: 18),
              ),
            Icon(Icons.chevron_right_rounded, color: th.textSub),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ProgressDot extends StatelessWidget {
  final AppTheme th;
  final TopicProgress? progress;

  const _ProgressDot({
    required this.th,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final item = progress;
    final attempted = item != null && item.attemptCount > 0;
    final complete = attempted && item.lastPercent >= 0.8;
    final color = complete ? Colors.green.shade400 : Colors.amber.shade500;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: attempted ? color.withValues(alpha: 0.16) : Colors.transparent,
        border: Border.all(
          color: attempted ? color : th.textSub.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Icon(
        complete
            ? Icons.check_rounded
            : attempted
                ? Icons.adjust_rounded
                : Icons.radio_button_unchecked_rounded,
        color: attempted ? color : th.textSub.withValues(alpha: 0.65),
        size: 18,
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final AppTheme th;
  final String level;

  const _LevelBadge({
    required this.th,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: th.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: th.accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
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
        label: Text('Reload topics', style: TextStyle(color: th.accent)),
      ),
    );
  }
}
