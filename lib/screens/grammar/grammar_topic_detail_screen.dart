import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../models/grammar_models.dart';
import '../../providers/theme_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/daily_usage_service.dart';
import 'grammar_practice_screen.dart';

class GrammarTopicDetailScreen extends StatefulWidget {
  final GrammarTopic topic;

  const GrammarTopicDetailScreen({
    super.key,
    required this.topic,
  });

  @override
  State<GrammarTopicDetailScreen> createState() =>
      _GrammarTopicDetailScreenState();
}

class _GrammarTopicDetailScreenState extends State<GrammarTopicDetailScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_trackOpen());
  }

  Future<void> _trackOpen() async {
    final topic = widget.topic;
    await DailyUsageService.recordGrammarOpened();
    await AnalyticsService.logGrammarTopicOpened(
      topicId: topic.id,
      categoryId: topic.category,
      level: topic.level,
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final topic = widget.topic;

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        backgroundColor: th.playerBar,
        elevation: 0,
        title: Text(topic.titleEn, style: TextStyle(color: th.textPrimary)),
        iconTheme: IconThemeData(color: th.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              topic.titleEn,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                topic.titleAr,
                textAlign: TextAlign.right,
                style: TextStyle(color: th.textSub, fontSize: 16, height: 1.7),
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              th: th,
              title: 'What is it?',
              body: topic.explanationEn,
            ),
            const SizedBox(height: 12),
            _SectionCard(
              th: th,
              title: 'بالعربي',
              body: topic.explanationAr,
              isArabic: true,
            ),
            const SizedBox(height: 12),
            _ComparisonCard(th: th, comparisons: topic.arabicComparison),
            const SizedBox(height: 12),
            _MistakesCard(th: th, mistakes: topic.commonMistakes),
            const SizedBox(height: 24),
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
                  'Start Practice (${topic.questions.length} questions)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GrammarPracticeScreen(topic: topic),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final AppTheme th;
  final String title;
  final String body;
  final bool isArabic;

  const _SectionCard({
    required this.th,
    required this.title,
    required this.body,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: th.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: th.textSub.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: th.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Text(
              body,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: isArabic ? 15 : 14,
                height: isArabic ? 1.7 : 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final AppTheme th;
  final List<GrammarComparison> comparisons;

  const _ComparisonCard({
    required this.th,
    required this.comparisons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: th.card,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AppColors.warning, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Arabic vs English',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...comparisons.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.arabicStructure,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: th.textPrimary,
                              fontSize: 14,
                              height: 1.7,
                            ),
                          ),
                          Text(
                            item.arabicLiteral,
                            textAlign: TextAlign.right,
                            style: TextStyle(color: th.textSub, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.englishCorrect,
                      style: TextStyle(
                        color: th.textPrimary,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MistakesCard extends StatelessWidget {
  final AppTheme th;
  final List<GrammarMistake> mistakes;

  const _MistakesCard({
    required this.th,
    required this.mistakes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: th.card,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: AppColors.error, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Common mistakes',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...mistakes.asMap().entries.map((entry) {
            final index = entry.key;
            final mistake = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.close_rounded,
                        color: AppColors.error, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mistake.wrong,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_rounded,
                        color: AppColors.success, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mistake.correct,
                        style: TextStyle(
                          color: th.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (index != mistakes.length - 1) ...[
                  const SizedBox(height: 10),
                  Divider(color: th.textSub.withValues(alpha: 0.1)),
                  const SizedBox(height: 10),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}
