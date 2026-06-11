import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'package:provider/provider.dart';

import '../../models/grammar_models.dart';
import '../../providers/theme_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/daily_usage_service.dart';
import '../../services/grammar_storage_service.dart';
import 'grammar_practice_screen.dart';
import 'grammar_weak_review_screen.dart';

class GrammarResultScreen extends StatefulWidget {
  final GrammarSessionResult result;

  const GrammarResultScreen({
    super.key,
    required this.result,
  });

  @override
  State<GrammarResultScreen> createState() => _GrammarResultScreenState();
}

class _GrammarResultScreenState extends State<GrammarResultScreen> {
  @override
  void initState() {
    super.initState();
    _persistResult();
  }

  Future<void> _persistResult() async {
    final result = widget.result;
    final topic = result.topic;
    if (topic != null && !result.isWeakReview) {
      await GrammarStorageService.saveTopicProgress(
        topic.id,
        result.correctCount,
        result.total,
      );
    }
    if (result.newWeakTags.isNotEmpty) {
      await GrammarStorageService.addWeakTags(
        result.newWeakTags,
        topicIds: topic == null ? const [] : [topic.id],
      );
    }
    await DailyUsageService.recordGrammarCompleted();
    await AnalyticsService.logGrammarTopicCompleted(
      topicId: topic?.id ?? 'weak_review',
      correctCount: result.correctCount,
      questionCount: result.total,
    );
  }

  void _tryAgain() {
    final result = widget.result;
    final topic = result.topic;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GrammarPracticeScreen(
          topic: topic,
          questions: topic == null
              ? result.results.map((item) => item.question).toList()
              : null,
          titleEn: result.titleEn,
          titleAr: result.titleAr,
          isWeakReview: result.isWeakReview,
        ),
      ),
    );
  }

  void _openWeakReview() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GrammarWeakReviewScreen()),
    );
  }

  void _backToTopics() {
    final navigator = Navigator.of(context);
    if (widget.result.topic == null) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    var routesSeen = 0;
    navigator.popUntil((route) => routesSeen++ >= 2 || route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final result = widget.result;
    final score = result.scoreRatio;
    final color = score >= 0.8
        ? AppColors.success
        : score >= 0.5
            ? AppColors.warning
            : AppColors.error;

    return Scaffold(
      backgroundColor: th.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _ScoreCircle(
                  th: th,
                  color: color,
                  score: result.correctCount,
                  total: result.total,
                  ratio: score,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                result.titleEn,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: th.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _scoreLabel(score),
                textAlign: TextAlign.center,
                style: TextStyle(color: th.textSub, fontSize: 14),
              ),
              if (result.newWeakTags.isNotEmpty) ...[
                const SizedBox(height: 22),
                _WeakTagsSection(th: th, tags: result.newWeakTags),
              ],
              const SizedBox(height: 22),
              Text(
                'Your answers',
                style: TextStyle(
                  color: th.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ...result.results.map((item) => _ResultRow(th: th, item: item)),
              const SizedBox(height: 22),
              _ActionButton(
                th: th,
                label: 'Try Again',
                icon: Icons.refresh_rounded,
                onTap: _tryAgain,
              ),
              const SizedBox(height: 10),
              if (result.newWeakTags.isNotEmpty) ...[
                _ActionButton(
                  th: th,
                  label: 'Review Weak Points',
                  icon: Icons.warning_amber_rounded,
                  onTap: _openWeakReview,
                  filled: true,
                ),
                const SizedBox(height: 10),
              ],
              _ActionButton(
                th: th,
                label: 'Back to Topics',
                icon: Icons.arrow_back_rounded,
                onTap: _backToTopics,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  final AppTheme th;
  final Color color;
  final int score;
  final int total;
  final double ratio;

  const _ScoreCircle({
    required this.th,
    required this.color,
    required this.score,
    required this.total,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 124,
            height: 124,
            child: CircularProgressIndicator(
              value: ratio,
              strokeWidth: 9,
              backgroundColor: th.textSub.withValues(alpha: 0.14),
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score/$total',
                style: TextStyle(
                  color: th.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${(ratio * 100).round()}%',
                style: TextStyle(color: th.textSub, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeakTagsSection extends StatelessWidget {
  final AppTheme th;
  final List<String> tags;

  const _WeakTagsSection({
    required this.th,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.amber, size: 19),
              const SizedBox(width: 8),
              Text(
                'Work on these',
                style: TextStyle(
                  color: th.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      tag.replaceAll('_', ' '),
                      style: TextStyle(
                        color: th.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final AppTheme th;
  final GrammarQuestionResult item;

  const _ResultRow({
    required this.th,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final color = item.isCorrect ? AppColors.success : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: th.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: th.textSub.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.question.prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: th.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!item.isCorrect) ...[
            const SizedBox(height: 8),
            Text(
              'Correct: ${item.correctAnswer}',
              style: TextStyle(color: th.textSub, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final AppTheme th;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _ActionButton({
    required this.th,
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? th.accent : Colors.transparent,
          foregroundColor: filled ? Colors.white : th.accent,
          side: BorderSide(
            color: filled ? th.accent : th.accent.withValues(alpha: 0.55),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        onPressed: onTap,
      ),
    );
  }
}

String _scoreLabel(double score) {
  if (score >= 0.9) return 'Excellent control';
  if (score >= 0.8) return 'Strong result';
  if (score >= 0.5) return 'Keep practising';
  return 'Review the basics again';
}
