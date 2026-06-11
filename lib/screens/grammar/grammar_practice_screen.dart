import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'package:provider/provider.dart';

import '../../models/grammar_models.dart';
import '../../providers/theme_provider.dart';
import '../../services/grammar_storage_service.dart';
import 'grammar_result_screen.dart';

class GrammarPracticeScreen extends StatefulWidget {
  final GrammarTopic? topic;
  final List<GrammarQuestion>? questions;
  final String? titleEn;
  final String? titleAr;
  final bool isWeakReview;

  const GrammarPracticeScreen({
    super.key,
    this.topic,
    this.questions,
    this.titleEn,
    this.titleAr,
    this.isWeakReview = false,
  });

  @override
  State<GrammarPracticeScreen> createState() => _GrammarPracticeScreenState();
}

class _GrammarPracticeScreenState extends State<GrammarPracticeScreen> {
  late GrammarSession _session;
  bool _loading = true;
  bool _answered = false;
  bool _currentCorrect = false;
  int? _selectedIndex;
  String _selectedAnswer = '';
  String _correctAnswer = '';
  List<int> _placedOrder = [];
  int? _selectedLeftIndex;
  Map<int, int> _matchedPairs = const {};
  List<int> _rightOrder = const [];
  int? _wrongLeftIndex;
  int? _wrongRightIndex;
  int _matchWrongAttempts = 0;
  Timer? _matchErrorClearTimer;

  @override
  void initState() {
    super.initState();
    _buildSession();
  }

  Future<void> _buildSession() async {
    final topic = widget.topic;
    List<GrammarQuestion> questions =
        topic?.questions ?? widget.questions ?? const [];

    if (topic != null && questions.isNotEmpty) {
      final progress = await GrammarStorageService.loadTopicProgress(topic.id);
      if (progress != null && progress.attemptCount >= 1) {
        questions = List.of(questions)..shuffle();
      }
    }

    // Shuffle MCQ options once per session so the correct answer isn't always first.
    final rng = Random();
    questions = questions.map((q) => q.withShuffledOptions(rng)).toList();

    if (!mounted) return;
    setState(() {
      _session = GrammarSession(
        topic: topic,
        titleEn: widget.titleEn ?? topic?.titleEn ?? 'Weak Points Review',
        titleAr: widget.titleAr ?? topic?.titleAr ?? 'مراجعة نقاط الضعف',
        questions: questions,
        isWeakReview: widget.isWeakReview,
      );
      _loading = false;
    });
    _resetQuestionState();
  }

  void _resetQuestionState() {
    _answered = false;
    _currentCorrect = false;
    _selectedIndex = null;
    _selectedAnswer = '';
    _correctAnswer = '';
    _placedOrder = [];
    _selectedLeftIndex = null;
    _matchedPairs = {};
    _wrongLeftIndex = null;
    _wrongRightIndex = null;
    _matchWrongAttempts = 0;
    _matchErrorClearTimer?.cancel();
    _matchErrorClearTimer = null;

    if (!_session.isComplete &&
        _session.current.type == GrammarQuestionType.meaningMatch) {
      final pairCount = _session.current.pairs.length;
      _rightOrder = List.generate(pairCount, (index) => index)..shuffle();
    } else {
      _rightOrder = const [];
    }
  }

  Future<void> _markAnswered({
    required bool isCorrect,
    required String selectedAnswer,
    required String correctAnswer,
  }) async {
    if (_answered) return;
    final question = _session.current;
    setState(() {
      _answered = true;
      _currentCorrect = isCorrect;
      _selectedAnswer = selectedAnswer;
      _correctAnswer = correctAnswer;
    });
    if (isCorrect && question.weakTag != null) {
      await GrammarStorageService.clearWeakTag(question.weakTag!);
    }
  }

  void _answerChoice(int index) {
    if (_answered) return;
    final question = _session.current;
    final correctIndex = question.correctIndex ?? -1;
    _selectedIndex = index;
    _markAnswered(
      isCorrect: index == correctIndex,
      selectedAnswer: question.options[index],
      correctAnswer: question.correctAnswerText,
    );
  }

  void _placeWord(int wordIndex) {
    if (_answered || _placedOrder.contains(wordIndex)) return;
    setState(() => _placedOrder = [..._placedOrder, wordIndex]);
    final question = _session.current;
    if (_placedOrder.length == question.words.length) {
      final correct = _sameOrder(_placedOrder, question.correctOrder);
      _markAnswered(
        isCorrect: correct,
        selectedAnswer: _placedOrder.map((i) => question.words[i]).join(' '),
        correctAnswer: question.correctAnswerText,
      );
    }
  }

  void _removePlacedWord(int wordIndex) {
    if (_answered) return;
    setState(() {
      _placedOrder = _placedOrder.where((i) => i != wordIndex).toList();
    });
  }

  void _selectLeftPair(int leftIndex) {
    if (_answered || _matchedPairs.containsKey(leftIndex)) return;
    setState(() {
      _selectedLeftIndex = _selectedLeftIndex == leftIndex ? null : leftIndex;
    });
  }

  void _selectRightPair(int rightIndex) {
    if (_answered || _selectedLeftIndex == null) return;
    if (_matchedPairs.containsValue(rightIndex)) return;

    final leftIndex = _selectedLeftIndex!;
    final question = _session.current;
    final isCorrect = leftIndex == rightIndex;
    if (!isCorrect) {
      // For 4+ pair questions allow one retry; second wrong attempt fails.
      final allowRetry = question.pairs.length >= 4 && _matchWrongAttempts < 1;
      _matchWrongAttempts++;
      setState(() {
        _wrongLeftIndex = leftIndex;
        _wrongRightIndex = rightIndex;
        _selectedLeftIndex = null;
      });
      if (allowRetry) {
        _matchErrorClearTimer?.cancel();
        _matchErrorClearTimer = Timer(const Duration(milliseconds: 700), () {
          if (mounted) {
            setState(() {
              _wrongLeftIndex = null;
              _wrongRightIndex = null;
            });
          }
        });
        return;
      }
      _markAnswered(
        isCorrect: false,
        selectedAnswer:
            '${question.pairs[leftIndex].left} = ${question.pairs[rightIndex].right}',
        correctAnswer: question.correctAnswerText,
      );
      return;
    }

    final nextMatches = Map<int, int>.from(_matchedPairs);
    nextMatches[leftIndex] = rightIndex;
    setState(() {
      _matchedPairs = nextMatches;
      _selectedLeftIndex = null;
    });
    if (nextMatches.length == question.pairs.length) {
      _markAnswered(
        isCorrect: true,
        selectedAnswer: question.correctAnswerText,
        correctAnswer: question.correctAnswerText,
      );
    }
  }

  void _advance() {
    if (!_answered) return;
    _session.answer(
      isCorrect: _currentCorrect,
      selectedAnswer: _selectedAnswer,
      correctAnswer: _correctAnswer,
    );

    if (_session.isComplete) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GrammarResultScreen(result: _session.toResult()),
        ),
      );
      return;
    }

    setState(_resetQuestionState);
  }

  Future<void> _handleClose() async {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _matchErrorClearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;

    if (_loading) {
      return Scaffold(
        backgroundColor: th.bg,
        body: Center(child: CircularProgressIndicator(color: th.accent)),
      );
    }

    if (_session.questions.isEmpty) {
      return Scaffold(
        backgroundColor: th.bg,
        appBar: AppBar(
          backgroundColor: th.playerBar,
          elevation: 0,
          iconTheme: IconThemeData(color: th.textPrimary),
        ),
        body: Center(
          child: Text(
            'No grammar questions available.',
            style: TextStyle(color: th.textSub),
          ),
        ),
      );
    }

    final question = _session.current;
    final progress =
        _session.total > 0 ? _session.currentIndex / _session.total : 0.0;

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        backgroundColor: th.bg,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close practice',
          icon: Icon(Icons.close_rounded, color: th.textSub),
          onPressed: _handleClose,
        ),
        title: Text(
          _session.isWeakReview ? 'Weak Points' : _session.titleEn,
          style: TextStyle(
            color: th.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: th.textSub.withValues(alpha: 0.15),
            color: th.accent,
          ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Question ${_session.currentIndex + 1} / ${_session.total}',
                              style: TextStyle(color: th.textSub, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              question.prompt,
                              style: TextStyle(
                                color: th.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                            ),
                            if (question.promptAr != null) ...[
                              const SizedBox(height: 8),
                              Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text(
                                  question.promptAr!,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: th.textSub,
                                    fontSize: 14,
                                    height: 1.7,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            _AnswerArea(
                              th: th,
                              question: question,
                              answered: _answered,
                              selectedIndex: _selectedIndex,
                              placedOrder: _placedOrder,
                              selectedLeftIndex: _selectedLeftIndex,
                              matchedPairs: _matchedPairs,
                              rightOrder: _rightOrder,
                              wrongLeftIndex: _wrongLeftIndex,
                              wrongRightIndex: _wrongRightIndex,
                              onChoice: _answerChoice,
                              onPlaceWord: _placeWord,
                              onRemovePlacedWord: _removePlacedWord,
                              onSelectLeftPair: _selectLeftPair,
                              onSelectRightPair: _selectRightPair,
                            ),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: _answered
                                  ? _FeedbackPanel(
                                      key: ValueKey(question.id),
                                      th: th,
                                      isCorrect: _currentCorrect,
                                      question: question,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: th.accent,
                          disabledBackgroundColor:
                              th.textSub.withValues(alpha: 0.18),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _answered ? _advance : null,
                        child: Text(
                          _session.currentIndex == _session.total - 1
                              ? 'See Results'
                              : 'Next',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerArea extends StatelessWidget {
  final AppTheme th;
  final GrammarQuestion question;
  final bool answered;
  final int? selectedIndex;
  final List<int> placedOrder;
  final int? selectedLeftIndex;
  final Map<int, int> matchedPairs;
  final List<int> rightOrder;
  final int? wrongLeftIndex;
  final int? wrongRightIndex;
  final void Function(int index) onChoice;
  final void Function(int wordIndex) onPlaceWord;
  final void Function(int wordIndex) onRemovePlacedWord;
  final void Function(int leftIndex) onSelectLeftPair;
  final void Function(int rightIndex) onSelectRightPair;

  const _AnswerArea({
    required this.th,
    required this.question,
    required this.answered,
    required this.selectedIndex,
    required this.placedOrder,
    required this.selectedLeftIndex,
    required this.matchedPairs,
    required this.rightOrder,
    required this.wrongLeftIndex,
    required this.wrongRightIndex,
    required this.onChoice,
    required this.onPlaceWord,
    required this.onRemovePlacedWord,
    required this.onSelectLeftPair,
    required this.onSelectRightPair,
  });

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case GrammarQuestionType.multipleChoice:
      case GrammarQuestionType.chooseCorrectSentence:
        return _ChoiceList(
          th: th,
          question: question,
          answered: answered,
          selectedIndex: selectedIndex,
          onChoice: onChoice,
        );
      case GrammarQuestionType.fillBlankWithOptions:
        return _ChoiceList(
          th: th,
          question: question,
          answered: answered,
          selectedIndex: selectedIndex,
          onChoice: onChoice,
          compact: true,
        );
      case GrammarQuestionType.fixTheMistake:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (question.wrongSentence != null)
              _WrongSentenceCard(th: th, text: question.wrongSentence!),
            const SizedBox(height: 12),
            _ChoiceList(
              th: th,
              question: question,
              answered: answered,
              selectedIndex: selectedIndex,
              onChoice: onChoice,
            ),
          ],
        );
      case GrammarQuestionType.sentenceOrder:
        return _SentenceOrderArea(
          th: th,
          question: question,
          answered: answered,
          placedOrder: placedOrder,
          onPlaceWord: onPlaceWord,
          onRemovePlacedWord: onRemovePlacedWord,
        );
      case GrammarQuestionType.meaningMatch:
        return _MeaningMatchArea(
          th: th,
          question: question,
          answered: answered,
          selectedLeftIndex: selectedLeftIndex,
          matchedPairs: matchedPairs,
          rightOrder: rightOrder,
          wrongLeftIndex: wrongLeftIndex,
          wrongRightIndex: wrongRightIndex,
          onSelectLeftPair: onSelectLeftPair,
          onSelectRightPair: onSelectRightPair,
        );
    }
  }
}

class _ChoiceList extends StatelessWidget {
  final AppTheme th;
  final GrammarQuestion question;
  final bool answered;
  final int? selectedIndex;
  final void Function(int index) onChoice;
  final bool compact;

  const _ChoiceList({
    required this.th,
    required this.question,
    required this.answered,
    required this.selectedIndex,
    required this.onChoice,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(question.options.length, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 8 : 10),
          child: _ChoiceCard(
            th: th,
            text: question.options[index],
            index: index,
            selectedIndex: selectedIndex,
            correctIndex: question.correctIndex ?? -1,
            answered: answered,
            onTap: () => onChoice(index),
          ),
        );
      }),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final AppTheme th;
  final String text;
  final int index;
  final int? selectedIndex;
  final int correctIndex;
  final bool answered;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.th,
    required this.text,
    required this.index,
    required this.selectedIndex,
    required this.correctIndex,
    required this.answered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    final isCorrect = index == correctIndex;
    final isRtl = _containsArabic(text);

    Color bg = th.card;
    Color borderColor = th.textSub.withValues(alpha: 0.18);
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
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.4),
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
                  child: Directionality(
                    textDirection:
                        isRtl ? TextDirection.rtl : TextDirection.ltr,
                    child: Text(
                      text,
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                      style: TextStyle(
                        color: th.textPrimary,
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: answered && (isSelected || isCorrect)
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (answered && isCorrect)
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 20)
                else if (answered && isSelected)
                  Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WrongSentenceCard extends StatelessWidget {
  final AppTheme th;
  final String text;

  const _WrongSentenceCard({
    required this.th,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceOrderArea extends StatelessWidget {
  final AppTheme th;
  final GrammarQuestion question;
  final bool answered;
  final List<int> placedOrder;
  final void Function(int wordIndex) onPlaceWord;
  final void Function(int wordIndex) onRemovePlacedWord;

  const _SentenceOrderArea({
    required this.th,
    required this.question,
    required this.answered,
    required this.placedOrder,
    required this.onPlaceWord,
    required this.onRemovePlacedWord,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: th.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: th.accent.withValues(alpha: 0.25)),
          ),
          child: placedOrder.isEmpty
              ? Text(
                  'Tap words below to build the sentence',
                  style: TextStyle(color: th.textSub, fontSize: 13),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: placedOrder.map((wordIndex) {
                    return _WordChip(
                      th: th,
                      text: question.words[wordIndex],
                      selected: true,
                      disabled: answered,
                      onTap: () => onRemovePlacedWord(wordIndex),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(question.words.length, (wordIndex) {
            final used = placedOrder.contains(wordIndex);
            return _WordChip(
              th: th,
              text: question.words[wordIndex],
              selected: false,
              disabled: answered || used,
              onTap: () => onPlaceWord(wordIndex),
            );
          }),
        ),
      ],
    );
  }
}

class _WordChip extends StatelessWidget {
  final AppTheme th;
  final String text;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _WordChip({
    required this.th,
    required this.text,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? th.accent.withValues(alpha: 0.18)
        : disabled
            ? th.textSub.withValues(alpha: 0.08)
            : th.card;
    final fg = disabled && !selected
        ? th.textSub.withValues(alpha: 0.45)
        : th.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? th.accent.withValues(alpha: 0.55)
                  : th.textSub.withValues(alpha: 0.16),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MeaningMatchArea extends StatelessWidget {
  final AppTheme th;
  final GrammarQuestion question;
  final bool answered;
  final int? selectedLeftIndex;
  final Map<int, int> matchedPairs;
  final List<int> rightOrder;
  final int? wrongLeftIndex;
  final int? wrongRightIndex;
  final void Function(int leftIndex) onSelectLeftPair;
  final void Function(int rightIndex) onSelectRightPair;

  const _MeaningMatchArea({
    required this.th,
    required this.question,
    required this.answered,
    required this.selectedLeftIndex,
    required this.matchedPairs,
    required this.rightOrder,
    required this.wrongLeftIndex,
    required this.wrongRightIndex,
    required this.onSelectLeftPair,
    required this.onSelectRightPair,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: List.generate(question.pairs.length, (leftIndex) {
              final matched = matchedPairs.containsKey(leftIndex);
              final selected = selectedLeftIndex == leftIndex;
              final wrong = wrongLeftIndex == leftIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MatchTile(
                  th: th,
                  text: question.pairs[leftIndex].left,
                  selected: selected,
                  matched: matched,
                  wrong: wrong,
                  isArabic: false,
                  onTap: () => onSelectLeftPair(leftIndex),
                  disabled: answered || matched,
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: rightOrder.map((rightIndex) {
              final matched = matchedPairs.containsValue(rightIndex);
              final wrong = wrongRightIndex == rightIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MatchTile(
                  th: th,
                  text: question.pairs[rightIndex].right,
                  selected: false,
                  matched: matched,
                  wrong: wrong,
                  isArabic: true,
                  onTap: () => onSelectRightPair(rightIndex),
                  disabled: answered || matched,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MatchTile extends StatelessWidget {
  final AppTheme th;
  final String text;
  final bool selected;
  final bool matched;
  final bool wrong;
  final bool isArabic;
  final bool disabled;
  final VoidCallback onTap;

  const _MatchTile({
    required this.th,
    required this.text,
    required this.selected,
    required this.matched,
    required this.wrong,
    required this.isArabic,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = th.card;
    Color border = th.textSub.withValues(alpha: 0.16);
    if (matched) {
      bg = AppColors.success.withValues(alpha: 0.14);
      border = AppColors.success;
    } else if (wrong) {
      bg = AppColors.error.withValues(alpha: 0.14);
      border = AppColors.error;
    } else if (selected) {
      bg = th.accent.withValues(alpha: 0.16);
      border = th.accent;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Text(
              text,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: isArabic ? 14 : 15,
                height: isArabic ? 1.6 : 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  final AppTheme th;
  final bool isCorrect;
  final GrammarQuestion question;

  const _FeedbackPanel({
    super.key,
    required this.th,
    required this.isCorrect,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct!' : 'Not quite',
                style: TextStyle(
                  color: th.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.explanation,
            style: TextStyle(
              color: th.textPrimary,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          if (question.arabicNote != null) ...[
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                question.arabicNote!,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: th.textSub,
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

bool _sameOrder(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i += 1) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

bool _containsArabic(String value) {
  return RegExp(r'[\u0600-\u06FF]').hasMatch(value);
}
