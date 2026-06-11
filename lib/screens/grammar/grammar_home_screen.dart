import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/grammar_models.dart';
import '../../providers/theme_provider.dart';
import '../../services/grammar_content_service.dart';
import '../../services/grammar_storage_service.dart';
import 'grammar_topic_list_screen.dart';
import 'grammar_weak_review_screen.dart';

class GrammarHomeScreen extends StatefulWidget {
  const GrammarHomeScreen({super.key});

  @override
  State<GrammarHomeScreen> createState() => _GrammarHomeScreenState();
}

class _GrammarHomeScreenState extends State<GrammarHomeScreen> {
  List<GrammarCategory>? _categories;
  List<String> _weakTags = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final categories = await GrammarContentService.loadIndex();
      final weakTags = await GrammarStorageService.loadWeakTags();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _weakTags = weakTags;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _openWeakReview() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GrammarWeakReviewScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _openCategory(GrammarCategory category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GrammarTopicListScreen(category: category),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final categories = _categories;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, color: th.accent, size: 26),
                const SizedBox(width: 10),
                Text(
                  'Grammar',
                  style: TextStyle(
                    color: th.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Master English grammar for Arabic speakers',
              style: TextStyle(color: th.textSub, fontSize: 13),
            ),
            const SizedBox(height: 18),
            if (_weakTags.isNotEmpty) ...[
              _WeakPointsCard(
                th: th,
                count: _weakTags.length,
                onTap: _openWeakReview,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Topics',
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _error != null
                  ? _ErrorState(th: th, onRetry: _load)
                  : categories == null
                      ? Center(
                          child: CircularProgressIndicator(color: th.accent),
                        )
                      : ListView(
                          children: [
                            ...categories.map(
                              (category) => _CategoryCard(
                                th: th,
                                category: category,
                                onTap: () => _openCategory(category),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeakPointsCard extends StatelessWidget {
  final AppTheme th;
  final int count;
  final VoidCallback onTap;

  const _WeakPointsCard({
    required this.th,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.55)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Weak Points',
                      style: TextStyle(
                        color: th.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$count grammar point${count == 1 ? '' : 's'} to practise',
                      style: TextStyle(color: th.textSub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: th.textSub),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _grammarCategoryIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('tense') || lower.contains('time')) return Icons.schedule_rounded;
  if (lower.contains('verb')) return Icons.directions_run_rounded;
  if (lower.contains('noun') || lower.contains('pronoun')) return Icons.person_rounded;
  if (lower.contains('adjective') || lower.contains('adverb')) return Icons.color_lens_rounded;
  if (lower.contains('question') || lower.contains('interrogat')) return Icons.help_outline_rounded;
  if (lower.contains('preposition')) return Icons.place_rounded;
  if (lower.contains('modal') || lower.contains('auxiliary')) return Icons.tune_rounded;
  if (lower.contains('conditional') || lower.contains('if')) return Icons.fork_right_rounded;
  if (lower.contains('article')) return Icons.article_rounded;
  if (lower.contains('conjunction') || lower.contains('connect')) return Icons.link_rounded;
  if (lower.contains('passive')) return Icons.swap_horiz_rounded;
  if (lower.contains('reported') || lower.contains('indirect')) return Icons.record_voice_over_rounded;
  if (lower.contains('sentence') || lower.contains('clause')) return Icons.text_fields_rounded;
  if (lower.contains('punctuation')) return Icons.format_quote_rounded;
  return Icons.school_rounded;
}

class _CategoryCard extends StatelessWidget {
  final AppTheme th;
  final GrammarCategory category;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.th,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: th.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: th.textSub.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: th.accent.withValues(alpha: 0.16),
          child: Icon(_grammarCategoryIcon(category.displayName), color: th.accent, size: 20),
        ),
        title: Text(
          category.displayName,
          style: TextStyle(
            color: th.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${category.topicIds.length} topics',
          style: TextStyle(color: th.textSub, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: th.textSub),
        onTap: onTap,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: th.textSub.withValues(alpha: 0.55), size: 48),
          const SizedBox(height: 12),
          Text(
            'Grammar content could not load',
            style: TextStyle(color: th.textPrimary, fontSize: 15),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text('Try again', style: TextStyle(color: th.accent)),
          ),
        ],
      ),
    );
  }
}
