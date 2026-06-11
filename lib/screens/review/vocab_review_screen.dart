import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../models/review_question.dart';
import '../../models/quiz_models.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/pronunciation_audio_service.dart';
import '../../services/quiz_storage_service.dart';
import '../../services/analytics_service.dart';
import '../../services/daily_usage_service.dart';
import 'review_summary_screen.dart';

// Delegates to AppColors — single source of truth for CEFR colours.
Color cefrColor(String? level) => AppColors.cefrColor(level);

class VocabReviewScreen extends StatefulWidget {
  final ReviewSession session;
  final String? batchId;
  final String? batchName;
  final bool isRandom;

  const VocabReviewScreen({
    super.key,
    required this.session,
    this.batchId,
    this.batchName,
    this.isRandom = false,
  });

  @override
  State<VocabReviewScreen> createState() => _VocabReviewScreenState();
}

class _VocabReviewScreenState extends State<VocabReviewScreen> {
  int? _selectedIndex;
  bool _answered = false;
  bool _waitingForContinue = false;
  bool _playingPronunciation = false;
  String? _playingPronunciationKey;
  final PronunciationAudioService _pronunciationAudio =
      PronunciationAudioService();
  // Incremented on each question advance so the choices Column gets a fresh key,
  // preventing AnimatedContainer from bleeding the previous question's color state
  // onto the next question's cards.
  int _questionIndex = 0;
  bool _completionTracked = false;

  @override
  void initState() {
    super.initState();
    _trackStart();
  }

  String get _quizSource {
    if (widget.batchId != null) return 'saved_batch';
    return widget.isRandom ? 'random' : 'saved_words';
  }

  String get _quizMode {
    final questions = widget.session.questions;
    if (questions.isEmpty) return 'unknown';
    return questions.first.mode == ReviewMode.arabic ? 'arabic' : 'english';
  }

  Future<void> _trackStart() async {
    await DailyUsageService.recordReviewQuizStarted();
    await AnalyticsService.logReviewQuizStarted(
      quizSource: _quizSource,
      quizMode: _quizMode,
      questionCount: widget.session.total,
    );
  }

  Future<void> _trackCompletion() async {
    if (_completionTracked) return;
    _completionTracked = true;
    await DailyUsageService.recordReviewQuizCompleted();
    await AnalyticsService.logReviewQuizCompleted(
      quizSource: _quizSource,
      quizMode: _quizMode,
      correctCount: widget.session.correctCount,
      questionCount: widget.session.total,
    );
  }

  @override
  void dispose() {
    _pronunciationAudio.dispose();
    super.dispose();
  }

  Future<void> _playPronunciation(ReviewQuestion question) async {
    if (_playingPronunciation) return;
    setState(() {
      _playingPronunciation = true;
      _playingPronunciationKey = question.wordKey;
    });
    final speed = context.read<SettingsProvider>().pronunciationSpeed;
    await _pronunciationAudio.play(question.wordKey, speed: speed);
    if (!mounted) return;
    setState(() {
      _playingPronunciation = false;
      _playingPronunciationKey = null;
    });
  }

  Future<void> _onChoiceTap(int index) async {
    if (_answered) return;
    final bool correct = index == widget.session.current.correctIndex;
    setState(() {
      _selectedIndex = index;
      _answered = true;
      _waitingForContinue = !correct;
    });
    if (correct) {
      await Future.delayed(const Duration(milliseconds: 750));
      if (!mounted) return;
      await _recordAndAdvance(index);
    }
    // Wrong answer: wait for the user to tap Continue.
  }

  void _onContinue() {
    if (!_waitingForContinue || _selectedIndex == null) return;
    _recordAndAdvance(_selectedIndex!);
  }

  Future<void> _recordAndAdvance(int answeredIndex) async {
    widget.session.answer(answeredIndex);
    if (!mounted) return;
    if (widget.session.isComplete) {
      await _saveHistory();
      await _trackCompletion();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewSummaryScreen(
            session: widget.session,
            batchId: widget.batchId,
            batchName: widget.batchName,
            isRandom: widget.isRandom,
          ),
        ),
      );
    } else {
      setState(() {
        _selectedIndex = null;
        _answered = false;
        _waitingForContinue = false;
        _questionIndex++;
      });
    }
  }

  Future<void> _saveHistory() async {
    final session = widget.session;
    if (session.total == 0) return;
    try {
      await QuizStorageService.addHistoryEntry(
        QuizHistoryEntry(
          id: QuizStorageService.newHistoryId(),
          score: session.correctCount,
          total: session.total,
          completedAt: DateTime.now(),
          mode: session.questions.isNotEmpty &&
                  session.questions.first.mode == ReviewMode.arabic
              ? 'arabic'
              : 'english',
          batchId: widget.batchId,
          batchName: widget.batchName,
          cefrFilter: session.cefrFilter,
          isRandom: widget.isRandom,
        ),
      );
    } catch (_) {}
  }

  Future<void> _handleBack() async {
    if (widget.session.currentIndex == 0) {
      Navigator.of(context).pop();
      return;
    }
    final th = context.read<ThemeProvider>().current;
    final l10n = AppStrings.of(context, listen: false);
    final nav = Navigator.of(context);

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: th.card,
        title: Text(
          l10n.pauseQuizQuestion,
          style: TextStyle(color: th.textPrimary),
        ),
        content: Text(
          l10n.answeredCount(
            widget.session.currentIndex,
            widget.session.total,
          ),
          style: TextStyle(color: th.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: Text(l10n.keepGoing, style: TextStyle(color: th.accent)),
          ),
          if (widget.isRandom)
            TextButton(
              onPressed: () => Navigator.pop(context, 'save_exit'),
              child: Text(
                l10n.saveBatchExit,
                style: TextStyle(color: th.accent, fontWeight: FontWeight.w600),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'exit'),
            child: Text(
              l10n.exitWithoutSaving,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == null || result == 'continue') return;

    if (result == 'save_exit' && widget.isRandom) {
      await _saveBatchFromCurrentSession();
      if (mounted) nav.pop();
    } else if (result == 'exit') {
      nav.pop();
    }
  }

  Future<void> _saveBatchFromCurrentSession() async {
    final session = widget.session;
    if (session.total == 0) return;
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
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: th.accent),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: th.accent, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(l10n.skip, style: TextStyle(color: th.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              ctrl.text.trim().isEmpty ? defaultName : ctrl.text.trim(),
            ),
            child: Text(l10n.save, style: TextStyle(color: th.accent)),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (input == null) return;
    final name = input.isEmpty ? defaultName : input;

    try {
      final mode = session.questions.isNotEmpty &&
              session.questions.first.mode == ReviewMode.arabic
          ? 'arabic'
          : 'english';
      await QuizStorageService.saveBatch(
        QuizBatch(
          id: QuizStorageService.newBatchId(),
          name: name,
          wordKeys: session.allWordKeys,
          cefrFilter: session.cefrFilter,
          requestedSize: session.total,
          levelBreakdown: session.levelBreakdown,
          createdAt: DateTime.now(),
          mode: mode,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.batchSaved(name)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: th.accent,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final l10n = context.l10n;
    final session = widget.session;

    if (session.isComplete) return const SizedBox.shrink();

    final q = session.current;
    final progress =
        session.total > 0 ? session.currentIndex / session.total : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: th.bg,
        appBar: AppBar(
          backgroundColor: th.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: th.textSub),
            onPressed: _handleBack,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.reviewTitle,
                style: TextStyle(
                  color: th.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (session.cefrFilter != null) ...[
                const SizedBox(width: 8),
                _CefrBadge(level: session.cefrFilter),
              ],
            ],
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: th.textSub.withValues(alpha: 0.15),
              color: th.accent,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (q.cefrLevel != null)
                    _CefrBadge(level: q.cefrLevel)
                  else
                    const SizedBox.shrink(),
                  Text(
                    '${session.currentIndex + 1} / ${session.total}',
                    style: TextStyle(color: th.textSub, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Word display
            Expanded(
              flex: 3,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              q.displayWord,
                              textAlign: q.mode == ReviewMode.arabic
                                  ? TextAlign.right
                                  : TextAlign.center,
                              textDirection: q.mode == ReviewMode.arabic
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              style: TextStyle(
                                color: th.textPrimary,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (q.mode != ReviewMode.arabic) ...[
                            const SizedBox(width: 8),
                            Semantics(
                              label: 'Play pronunciation',
                              button: true,
                              child: IconButton(
                                tooltip: 'Play pronunciation',
                                onPressed: _playingPronunciation
                                    ? null
                                    : () => _playPronunciation(q),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: _playingPronunciation &&
                                          _playingPronunciationKey == q.wordKey
                                      ? SizedBox(
                                          key: const ValueKey('playing'),
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: th.accent,
                                          ),
                                        )
                                      : Icon(
                                          Icons.volume_up_rounded,
                                          key: const ValueKey('speaker'),
                                          color: th.accent,
                                        ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (q.mode != ReviewMode.arabic &&
                          q.phonetic != null &&
                          q.phonetic!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          q.phonetic!,
                          style: TextStyle(color: th.textSub, fontSize: 16),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        l10n.chooseEnglishMeaning,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: th.textSub.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      if (_answered) ...[
                        const SizedBox(height: 10),
                        Text(
                          _selectedIndex == q.correctIndex
                              ? l10n.correct
                              : l10n.tryAgain,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedIndex == q.correctIndex
                                ? AppColors.success
                                : AppColors.error,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Choice cards
            Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  _waitingForContinue ? 8 : 24,
                ),
                child: Column(
                  key: ValueKey(_questionIndex),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(q.choices.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ChoiceCard(
                        text: q.choices[i],
                        index: i,
                        selectedIndex: _selectedIndex,
                        correctIndex: q.correctIndex,
                        answered: _answered,
                        isRtl: false,
                        th: th,
                        onTap: () => _onChoiceTap(i),
                      ),
                    );
                  }),
                ),
              ),
            ),
            if (_waitingForContinue)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: th.accent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.next,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CefrBadge extends StatelessWidget {
  final String? level;
  const _CefrBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    if (level == null) return const SizedBox.shrink();
    final color = cefrColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        level!,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String text;
  final int index;
  final int? selectedIndex;
  final int correctIndex;
  final bool answered;
  final bool isRtl;
  final AppTheme th;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.text,
    required this.index,
    required this.selectedIndex,
    required this.correctIndex,
    required this.answered,
    required this.isRtl,
    required this.th,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    final isCorrect = index == correctIndex;

    Color bg = th.card;
    Color borderColor = th.textSub.withValues(alpha: 0.2);

    if (answered) {
      if (isCorrect) {
        bg = AppColors.success.withValues(alpha: 0.15);
        borderColor = AppColors.success;
      } else if (isSelected) {
        bg = AppColors.error.withValues(alpha: 0.15);
        borderColor = AppColors.error;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: answered ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection:
                        isRtl ? TextDirection.rtl : TextDirection.ltr,
                    style: TextStyle(
                      color: th.textPrimary,
                      fontSize: 15,
                      fontWeight: answered && (isSelected || isCorrect)
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (answered && isCorrect)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                  )
                else if (answered && isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.cancel_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
