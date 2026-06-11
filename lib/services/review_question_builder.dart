import 'dart:math';
import '../models/review_question.dart';
import '../providers/favourites_provider.dart';
import 'word_definition_service.dart';

/// A resolved quiz candidate: the lookup key, the form to show the learner, the
/// dictionary entry, and the answer string for the active [ReviewMode].
typedef _Candidate = ({
  String key,
  String? displayForm,
  Map<String, dynamic> entry,
  String answer,
  String? cefrLevel,
});

// CEFR level fallback order: from highest to lowest
const _cefrOrder = ['C2', 'C1', 'B2', 'B1', 'A2', 'A1'];
const _targetChoiceCount = 5;
const _minChoiceCount = 2;

class ReviewQuestionBuilder {
  static final _rng = Random();

  /// Builds a quiz from the learner's saved words (MCQ Review V1).
  static ReviewSession build({
    required List<SavedWordRef> savedWords,
    required ReviewMode mode,
    int maxQuestions = 10,
  }) {
    final candidates = <_Candidate>[];
    for (final w in savedWords) {
      final entry = WordDefinitionService.resolveEntry(w.key);
      final candidate = _candidateFromEntry(
        key: w.key,
        displayForm: w.clickedForm ?? w.key,
        entry: entry,
        mode: mode,
      );
      if (candidate != null) candidates.add(candidate);
    }
    return _assemble(
      candidates,
      mode,
      maxQuestions,
      distractorPool: candidates,
      fallbackDistractorPool: _dictionaryCandidates(mode),
    );
  }

  /// Dev-only Arabic shell practice: show existing Arabic translations as the
  /// prompt and ask for the associated English headword. This uses legacy
  /// vocabulary data only as temporary scaffolding, not final Arabic curriculum.
  static ReviewSession buildArabicDevRandom({int maxQuestions = 10}) {
    return buildRandom(mode: ReviewMode.arabic, maxQuestions: maxQuestions);
  }

  /// Builds a quiz from random eligible dictionary words (Random MCQ V2).
  ///
  /// Supports optional [cefrFilter] (e.g. 'B1'). If more words are requested
  /// than exist at that level, fills from the next lower levels in order and
  /// sets [ReviewSession.fillNote] describing the actual breakdown.
  static ReviewSession buildRandom({
    required ReviewMode mode,
    int maxQuestions = 10,
    String? cefrFilter, // null or 'All' = all levels
    Set<String>? usedWordKeys, // keys from saved batches; enforce ≤20% overlap
  }) {
    final allEligible = _dictionaryCandidates(mode, randomEligibleOnly: true);

    if (allEligible.length < _minChoiceCount) return ReviewSession([]);

    List<_Candidate> selected;
    Map<String, int> levelBreakdown = {};
    String? fillNote;

    final isFiltered =
        cefrFilter != null && cefrFilter != 'All' && cefrFilter.isNotEmpty;

    if (!isFiltered) {
      allEligible.shuffle(_rng);
      selected = _selectWithFreshness(allEligible, maxQuestions, usedWordKeys);
      for (final c in selected) {
        final lvl = c.cefrLevel ?? 'Unknown';
        levelBreakdown[lvl] = (levelBreakdown[lvl] ?? 0) + 1;
      }
    } else {
      // filtered branch
      // Targeted CEFR level with graceful fallback to lower levels
      final byLevel = <String, List<_Candidate>>{};
      for (final c in allEligible) {
        final lvl = c.cefrLevel ?? 'Unknown';
        (byLevel[lvl] ??= []).add(c);
      }
      for (final list in byLevel.values) {
        list.shuffle(_rng);
      }

      selected = [];
      final targetPool = _freshFirst(
        List<_Candidate>.from(byLevel[cefrFilter] ?? []),
        usedWordKeys,
      );
      final fromTarget = targetPool.take(maxQuestions).toList();
      selected.addAll(fromTarget);
      if (fromTarget.isNotEmpty) {
        levelBreakdown[cefrFilter] = fromTarget.length;
      }

      // Fill from lower levels if needed
      if (selected.length < maxQuestions) {
        final targetIdx = _cefrOrder.indexOf(cefrFilter);
        final fillLevels =
            targetIdx >= 0 ? _cefrOrder.sublist(targetIdx + 1) : <String>[];
        for (final lvl in fillLevels) {
          if (selected.length >= maxQuestions) break;
          final pool = _freshFirst(
            List<_Candidate>.from(byLevel[lvl] ?? []),
            usedWordKeys,
          );
          final needed = maxQuestions - selected.length;
          final fromLvl = pool.take(needed).toList();
          selected.addAll(fromLvl);
          if (fromLvl.isNotEmpty) {
            levelBreakdown[lvl] = fromLvl.length;
          }
        }
      }

      // Build fill note if we couldn't fully satisfy the target level
      final targetCount = levelBreakdown[cefrFilter] ?? 0;
      if (targetCount < maxQuestions && selected.isNotEmpty) {
        final available = byLevel[cefrFilter]?.length ?? 0;
        final parts =
            levelBreakdown.entries.map((e) => '${e.value} ${e.key}').join(', ');
        fillNote =
            'Only $available $cefrFilter words available. Filled with: $parts';
      }
    }

    if (selected.isEmpty) return ReviewSession([]);
    selected.shuffle(_rng);
    final randomDistractorPool = _randomDistractorPool(
      allEligible: allEligible,
      cefrFilter: isFiltered ? cefrFilter : null,
      selected: selected,
    );

    return _assemble(
      selected,
      mode,
      maxQuestions,
      distractorPool: randomDistractorPool,
      fallbackDistractorPool: randomDistractorPool,
      cefrFilter: isFiltered ? cefrFilter : null,
      levelBreakdown: levelBreakdown,
      fillNote: fillNote,
    );
  }

  /// Builds a quiz from a saved batch's word keys.
  static ReviewSession buildFromKeys({
    required List<String> wordKeys,
    required ReviewMode mode,
    String? cefrFilter,
  }) {
    final candidates = <_Candidate>[];
    for (final key in wordKeys) {
      final entry = WordDefinitionService.resolveEntry(key);
      final candidate = _candidateFromEntry(
        key: key,
        entry: entry,
        mode: mode,
      );
      if (candidate != null) candidates.add(candidate);
    }
    final allEligible = _dictionaryCandidates(mode, randomEligibleOnly: true);
    final randomDistractorPool = _randomDistractorPool(
      allEligible: allEligible,
      cefrFilter: cefrFilter,
      selected: candidates,
    );
    return _assemble(
      candidates,
      mode,
      candidates.length,
      distractorPool: randomDistractorPool,
      fallbackDistractorPool: randomDistractorPool,
      cefrFilter: cefrFilter,
    );
  }

  // Prefer fresh words; cap seen words at ≤20% of n (relaxed if not enough fresh).
  static List<_Candidate> _selectWithFreshness(
    List<_Candidate> shuffled,
    int n,
    Set<String>? usedWordKeys,
  ) {
    if (usedWordKeys == null || usedWordKeys.isEmpty) {
      return shuffled.take(n).toList();
    }
    final fresh = shuffled.where((c) => !usedWordKeys.contains(c.key)).toList();
    final seen = shuffled.where((c) => usedWordKeys.contains(c.key)).toList();
    final maxSeen = (n * 0.2).floor();
    final allowedSeen = min(seen.length, max(maxSeen, n - fresh.length));
    final allowedFresh = min(fresh.length, n - allowedSeen);
    final result = [...fresh.take(allowedFresh), ...seen.take(allowedSeen)];
    result.shuffle(_rng);
    return result;
  }

  // Reorder a (pre-shuffled) pool so fresh words come first.
  static List<_Candidate> _freshFirst(
    List<_Candidate> pool,
    Set<String>? usedWordKeys,
  ) {
    if (usedWordKeys == null || usedWordKeys.isEmpty) return pool;
    final fresh = pool.where((c) => !usedWordKeys.contains(c.key)).toList();
    final seen = pool.where((c) => usedWordKeys.contains(c.key)).toList();
    return [...fresh, ...seen];
  }

  /// Shared question assembly: selection, distractor choice, up-to-5-option shuffle.
  static ReviewSession _assemble(
    List<_Candidate> candidates,
    ReviewMode mode,
    int maxQuestions, {
    List<_Candidate>? distractorPool,
    List<_Candidate>? fallbackDistractorPool,
    String? cefrFilter,
    Map<String, int> levelBreakdown = const {},
    String? fillNote,
  }) {
    if (candidates.isEmpty) return ReviewSession([]);
    final primaryPool = distractorPool ?? candidates;
    final fallbackPool = fallbackDistractorPool ?? _dictionaryCandidates(mode);

    final selected = (List.of(candidates)..shuffle(_rng)).take(maxQuestions);
    final questions = <ReviewQuestion>[];

    for (final candidate in selected) {
      final correct = _cleanAnswer(candidate.answer);
      if (correct == null) continue;
      final correctNorm = _normaliseAnswer(correct);
      final synonymSet = _synonymsOf(candidate.entry);

      final distractors = <String>[];
      final usedAnswers = <String>{correctNorm};
      final targetDistractorCount = _targetChoiceCount - 1;

      final shuffledPrimary = List<_Candidate>.from(primaryPool)..shuffle(_rng);
      _addDistractorsFromCandidates(
        distractors: distractors,
        usedAnswers: usedAnswers,
        pool: shuffledPrimary,
        candidate: candidate,
        synonymSet: synonymSet,
        targetCount: targetDistractorCount,
      );

      if (distractors.length < targetDistractorCount) {
        _addFallbackDistractors(
          distractors: distractors,
          usedAnswers: usedAnswers,
          fallbackPool: fallbackPool,
          candidate: candidate,
          synonymSet: synonymSet,
          targetCount: targetDistractorCount,
        );
      }

      final choices = [
        correct,
        ...distractors.take(targetDistractorCount),
      ];
      if (choices.length < _minChoiceCount) continue;
      choices.shuffle(_rng);
      final correctIndex = choices.indexWhere(
        (choice) => _normaliseAnswer(choice) == correctNorm,
      );
      if (correctIndex < 0) continue;

      questions.add(ReviewQuestion(
        wordKey: candidate.key,
        displayWord: candidate.displayForm ?? candidate.key,
        phonetic: candidate.entry['phonetic'] as String?,
        correctAnswer: correct,
        choices: choices,
        correctIndex: correctIndex,
        mode: mode,
        entry: candidate.entry,
        cefrLevel: candidate.cefrLevel,
      ));
    }

    return ReviewSession(
      questions,
      cefrFilter: cefrFilter,
      levelBreakdown: levelBreakdown,
      fillNote: fillNote,
    );
  }

  static _Candidate? _candidateFromEntry({
    required String key,
    required Map<String, dynamic>? entry,
    required ReviewMode mode,
    String? displayForm,
  }) {
    if (entry == null) return null;
    if (mode == ReviewMode.arabic) {
      final prompt = _arabicPromptFor(entry, displayForm: displayForm);
      final answer = _englishHeadwordFor(key, entry);
      if (prompt == null || answer == null) return null;
      return (
        key: key,
        displayForm: prompt,
        entry: entry,
        answer: answer,
        cefrLevel: _optionalString(entry['cefr']),
      );
    }
    final answer = _answerFor(entry, mode);
    if (answer == null) return null;
    return (
      key: key,
      displayForm: displayForm ?? _optionalString(entry['display_word']) ?? key,
      entry: entry,
      answer: answer,
      cefrLevel: _optionalString(entry['cefr']),
    );
  }

  static List<_Candidate> _dictionaryCandidates(
    ReviewMode mode, {
    bool randomEligibleOnly = false,
  }) {
    final defs = WordDefinitionService.bundled ?? {};
    final candidates = <_Candidate>[];
    for (final e in defs.entries) {
      final rawEntry = e.value;
      if (rawEntry is! Map) continue;
      final entry = Map<String, dynamic>.from(rawEntry);
      if (randomEligibleOnly && !_isRandomEligible(entry)) continue;
      final candidate = _candidateFromEntry(
        key: e.key,
        entry: entry,
        mode: mode,
      );
      if (candidate != null) candidates.add(candidate);
    }
    return candidates;
  }

  static List<_Candidate> _randomDistractorPool({
    required List<_Candidate> allEligible,
    required String? cefrFilter,
    required Iterable<_Candidate> selected,
  }) {
    final isFiltered =
        cefrFilter != null && cefrFilter != 'All' && cefrFilter.isNotEmpty;
    if (!isFiltered) return allEligible;

    final allowedLevels = <String>{cefrFilter};
    for (final candidate in selected) {
      final level = candidate.cefrLevel;
      if (level != null && level.isNotEmpty) allowedLevels.add(level);
    }

    final filtered = allEligible.where((candidate) {
      final level = candidate.cefrLevel;
      return level != null && allowedLevels.contains(level);
    }).toList();
    return filtered.isEmpty ? allEligible : filtered;
  }

  static bool _isRandomEligible(Map<String, dynamic> entry) {
    final lp = entry['learner_panel'];
    return lp is Map && lp['schema_version'] == 'v20_gpt4o_mini';
  }

  static void _addDistractorsFromCandidates({
    required List<String> distractors,
    required Set<String> usedAnswers,
    required Iterable<_Candidate> pool,
    required _Candidate candidate,
    required Set<String> synonymSet,
    required int targetCount,
  }) {
    for (final other in pool) {
      if (distractors.length >= targetCount) break;
      if (other.key == candidate.key) continue;
      _addDistractorAnswer(
        distractors: distractors,
        usedAnswers: usedAnswers,
        answer: other.answer,
        synonymSet: synonymSet,
      );
    }
  }

  static void _addFallbackDistractors({
    required List<String> distractors,
    required Set<String> usedAnswers,
    required List<_Candidate> fallbackPool,
    required _Candidate candidate,
    required Set<String> synonymSet,
    required int targetCount,
  }) {
    if (distractors.length >= targetCount) return;
    final cefr = candidate.cefrLevel;
    final pos = _posOf(candidate.entry);
    final posMatchPool = <_Candidate>[];
    final cefrOnlyPool = <_Candidate>[];
    final otherPool = <_Candidate>[];

    for (final other in fallbackPool) {
      if (other.key == candidate.key) continue;
      if (cefr != null && other.cefrLevel == cefr) {
        if (pos != null && _posOf(other.entry) == pos) {
          posMatchPool.add(other);
        } else {
          cefrOnlyPool.add(other);
        }
      } else {
        otherPool.add(other);
      }
    }

    for (final pool in [posMatchPool, cefrOnlyPool, otherPool]) {
      if (distractors.length >= targetCount) break;
      pool.shuffle(_rng);
      _addDistractorsFromCandidates(
        distractors: distractors,
        usedAnswers: usedAnswers,
        pool: pool,
        candidate: candidate,
        synonymSet: synonymSet,
        targetCount: targetCount,
      );
    }
  }

  static bool _addDistractorAnswer({
    required List<String> distractors,
    required Set<String> usedAnswers,
    required String answer,
    required Set<String> synonymSet,
  }) {
    final cleaned = _cleanAnswer(answer);
    if (cleaned == null) return false;
    final normalised = _normaliseAnswer(cleaned);
    if (usedAnswers.contains(normalised) || synonymSet.contains(normalised)) {
      return false;
    }
    distractors.add(cleaned);
    usedAnswers.add(normalised);
    return true;
  }

  static String? _answerFor(Map<String, dynamic> entry, ReviewMode mode) {
    if (mode == ReviewMode.arabic) {
      return _englishHeadwordFor('', entry);
    }
    final safe = _optionalString(entry['mcq_safe_definition']);
    final safeAnswer = _cleanAnswer(safe);
    if (safeAnswer != null) return safeAnswer;
    return _cleanAnswer(_optionalString(entry['definition']));
  }

  static Set<String> _synonymsOf(Map<String, dynamic> entry) {
    final result = <String>{};
    for (final field in ['synonyms', 'similar']) {
      final raw = entry[field];
      if (raw is List) {
        for (final s in raw) {
          final synonym = _cleanAnswer(_optionalString(s));
          if (synonym != null) result.add(_normaliseAnswer(synonym));
        }
      }
    }
    return result;
  }

  static String? _cleanAnswer(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static String _normaliseAnswer(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }

  static String? _optionalString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _arabicPromptFor(
    Map<String, dynamic> entry, {
    String? displayForm,
  }) {
    final explicitDisplay = _cleanAnswer(displayForm);
    if (explicitDisplay != null && _containsArabic(explicitDisplay)) {
      return explicitDisplay;
    }
    for (final field in ['mcq_safe_arabic', 'arabic']) {
      final value = _cleanAnswer(_optionalString(entry[field]));
      if (value != null && _containsArabic(value)) return value;
    }
    final panel = entry['learner_panel'];
    if (panel is Map) {
      final value = _cleanAnswer(_optionalString(panel['arabic']));
      if (value != null && _containsArabic(value)) return value;
    }
    return null;
  }

  static String? _englishHeadwordFor(String key, Map<String, dynamic> entry) {
    final displayWord = _cleanAnswer(_optionalString(entry['display_word']));
    if (displayWord != null && _isReadableEnglishAnswer(displayWord)) {
      return displayWord;
    }
    final cleanedKey = _cleanAnswer(key);
    if (cleanedKey != null && _isReadableEnglishAnswer(cleanedKey)) {
      return cleanedKey;
    }
    return null;
  }

  static bool _containsArabic(String value) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(value);
  }

  static bool _isReadableEnglishAnswer(String value) {
    final cleaned = _cleanAnswer(value);
    if (cleaned == null) return false;
    if (cleaned.length > 40) return false;
    if (!RegExp(r'[A-Za-z]').hasMatch(cleaned)) return false;
    if (RegExp(r'https?://|www\.|[_{}\[\]<>]').hasMatch(cleaned)) {
      return false;
    }
    return true;
  }

  static String? _posOf(Map<String, dynamic> entry) {
    return _optionalString(entry['pos'] ?? entry['part_of_speech']);
  }
}
