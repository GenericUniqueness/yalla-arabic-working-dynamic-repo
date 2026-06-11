import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../models/review_question.dart';
import '../../models/quiz_models.dart';
import '../../providers/favourites_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/quiz_storage_service.dart';
import '../lessons/word_definition_overlay.dart';
import 'vocab_review_screen.dart' show cefrColor;

class ReviewSummaryScreen extends StatefulWidget {
  final ReviewSession session;
  final String? batchId;
  final String? batchName;
  final bool isRandom;

  const ReviewSummaryScreen({
    super.key,
    required this.session,
    this.batchId,
    this.batchName,
    this.isRandom = false,
  });

  @override
  State<ReviewSummaryScreen> createState() => _ReviewSummaryScreenState();
}

class _ReviewSummaryScreenState extends State<ReviewSummaryScreen> {
  bool _missedSaved = false;
  bool _batchSaved = false;

  Future<void> _saveMissedWords() async {
    final favs = context.read<FavouritesProvider>();
    final missed = widget.session.missedQuestions;
    for (final q in missed) {
      if (!favs.isWordSaved(q.wordKey)) {
        await favs.toggleSavedWord(q.wordKey);
      }
    }
    if (mounted) setState(() => _missedSaved = true);
  }

  Future<void> _saveBatch() async {
    if (!widget.isRandom) return;
    final session = widget.session;
    if (!mounted) return;
    final th = context.read<ThemeProvider>().current;
    final l10n = AppStrings.of(context, listen: false);

    final defaultName = session.cefrFilter != null
        ? l10n.cefrBatch(session.cefrFilter!)
        : l10n.randomBatch;
    final ctrl = TextEditingController(text: defaultName);

    final input = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: th.card,
        title: Text(
          l10n.nameThisBatch,
          style: TextStyle(color: th.textPrimary),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: th.textPrimary),
          decoration: InputDecoration(
            hintText: l10n.batchNameHint,
            hintStyle: TextStyle(color: th.textSub),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: th.accent)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: th.accent, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(l10n.skip, style: TextStyle(color: th.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context,
                ctrl.text.trim().isEmpty ? defaultName : ctrl.text.trim()),
            child: Text(l10n.save, style: TextStyle(color: th.accent)),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (input == null || !mounted) return;
    final name = input.isEmpty ? defaultName : input;

    try {
      final mode = session.questions.isNotEmpty &&
              session.questions.first.mode == ReviewMode.arabic
          ? 'arabic'
          : 'english';
      await QuizStorageService.saveBatch(QuizBatch(
        id: QuizStorageService.newBatchId(),
        name: name,
        wordKeys: session.allWordKeys,
        cefrFilter: session.cefrFilter,
        requestedSize: session.total,
        levelBreakdown: session.levelBreakdown,
        createdAt: DateTime.now(),
        mode: mode,
      ));
      if (mounted) setState(() => _batchSaved = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final l10n = context.l10n;
    final correct = widget.session.correctCount;
    final total = widget.session.total;
    final missed = widget.session.missedQuestions;
    final score = total > 0 ? correct / total : 0.0;

    final String emoji;
    final String message;
    if (score >= 0.9) {
      emoji = '🏆';
      message = l10n.excellent;
    } else if (score >= 0.7) {
      emoji = '⭐';
      message = l10n.wellDone;
    } else if (score >= 0.5) {
      emoji = '💪';
      message = l10n.keepPracticing;
    } else {
      emoji = '📖';
      message = l10n.reviewTheseWords;
    }

    return Scaffold(
      backgroundColor: th.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(emoji,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: th.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                '${l10n.score}: ${l10n.scoreLine(correct, total)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: th.textSub, fontSize: 18),
              ),
              // CEFR filter label
              if (widget.session.cefrFilter != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: cefrColor(widget.session.cefrFilter)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: cefrColor(widget.session.cefrFilter)
                              .withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      widget.session.cefrFilter!,
                      style: TextStyle(
                          color: cefrColor(widget.session.cefrFilter),
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
              // Fill note (shown when CEFR filter had insufficient words)
              if (widget.session.fillNote != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: th.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.session.fillNote!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: th.textSub, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: score,
                  minHeight: 8,
                  backgroundColor: th.textSub.withValues(alpha: 0.15),
                  color: score >= 0.7 ? AppColors.success : th.accent,
                ),
              ),
              const SizedBox(height: 24),

              // Missed words section
              if (missed.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      l10n.wordsToReview(missed.length),
                      style: TextStyle(
                          color: th.textSub,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (!_missedSaved)
                      TextButton.icon(
                        onPressed: _saveMissedWords,
                        icon: Icon(Icons.bookmark_add_outlined,
                            color: th.accent, size: 16),
                        label: Text(l10n.saveMissed,
                            style: TextStyle(color: th.accent, fontSize: 12)),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              color: AppColors.success, size: 16),
                          const SizedBox(width: 4),
                          Text(l10n.saved,
                              style: TextStyle(
                                  color: AppColors.success, fontSize: 12)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: missed
                      .map((q) => ActionChip(
                            avatar: q.cefrLevel != null
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: cefrColor(q.cefrLevel),
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                            label: Text(q.displayWord,
                                textDirection: q.mode == ReviewMode.arabic
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                style: TextStyle(
                                    color: th.accent,
                                    fontWeight: FontWeight.w600)),
                            backgroundColor: th.accent.withValues(alpha: 0.1),
                            side: BorderSide(
                                color: th.accent.withValues(alpha: 0.3)),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => WordDefinitionOverlay(
                                word: q.wordKey,
                                clickedForm: q.wordKey,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],

              // Save batch button (random quizzes only)
              if (widget.isRandom && !_batchSaved)
                OutlinedButton.icon(
                  onPressed: _saveBatch,
                  icon: Icon(Icons.save_outlined, color: th.accent, size: 16),
                  label: Text(l10n.saveThisBatch,
                      style: TextStyle(color: th.accent)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: th.accent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              if (widget.isRandom && _batchSaved)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded,
                        color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    Text(l10n.saved,
                        style:
                            TextStyle(color: AppColors.success, fontSize: 13)),
                  ],
                ),
              if (widget.isRandom) const SizedBox(height: 12),

              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: th.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(l10n.done,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
