import 'dart:convert';
import 'package:flutter/services.dart';

class ArabicVocabularyEntry {
  final String arabic;
  final String normalisedArabic;
  final String englishHeadword;
  final String? definition;
  final String sourceField;

  const ArabicVocabularyEntry({
    required this.arabic,
    required this.normalisedArabic,
    required this.englishHeadword,
    required this.sourceField,
    this.definition,
  });
}

class ArabicVocabularyMatch {
  final int start;
  final int end;
  final String surfaceText;
  final ArabicVocabularyEntry entry;

  const ArabicVocabularyMatch({
    required this.start,
    required this.end,
    required this.surfaceText,
    required this.entry,
  });
}

class _NormalisedArabicText {
  final String text;
  final List<int> sourceIndices;

  const _NormalisedArabicText(this.text, this.sourceIndices);
}

class WordDefinitionService {
  static Map<String, dynamic>? _cache;
  static List<ArabicVocabularyEntry>? _arabicVocabularyCache;
  static final Map<String, List<ArabicVocabularyMatch>> _arabicMatchCache = {};

  static final Set<String> _blockedArabicTerms = {
    'انا',
    'انت',
    'انتم',
    'هو',
    'هي',
    'هم',
    'هن',
    'هذا',
    'هذه',
    'ذلك',
    'تلك',
    'هنا',
    'هناك',
    'من',
    'في',
    'على',
    'عن',
    'الى',
    'او',
    'و',
    'ف',
    'ثم',
    'يا',
    'ما',
    'لا',
    'لم',
    'لن',
    'ان',
    'كان',
    'كانت',
    'لكن',
    'كل',
    'قد',
    'لقد',
    'مع',
    'بين',
    'كما',
    'اذا',
    'الذي',
    'التي',
    'الذين',
    'اي',
    'اين',
    'ايضا',
    'الان',
    'الناس',
    'اما',
    'ابي',
    'احمد',
    'بخير',
    'بعض',
    'بالي',
    'جدا',
    'جميلة',
    'حال',
    'خالد',
    'خديجة',
    'شيء',
    'صحيح',
    'صفيا',
    'فقط',
    'كيف',
    'لله',
    'لطيفة',
    'عائشة',
    'علي',
    'عمر',
    'ماذا',
    'محمد',
    'مقاطع',
    'مثلا',
    'نعم',
    'والله',
    'يعني',
    'يوم',
    'اليوم',
  };

  static Future<Map<String, dynamic>> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/word_definitions.json');
      _cache = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _arabicVocabularyCache = null;
      _arabicMatchCache.clear();
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  static Map<String, dynamic>? get bundled => _cache;

  static List<ArabicVocabularyEntry> get temporaryArabicVocabulary {
    final defs = _cache;
    if (defs == null || defs.isEmpty) return const [];
    return _arabicVocabularyCache ??= _buildArabicVocabulary(defs);
  }

  static String normaliseArabic(String raw) {
    final normalised = _normaliseArabicWithMap(raw).text;
    return normalised.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<ArabicVocabularyMatch> matchArabicTerms(String text) {
    final cached = _arabicMatchCache[text];
    if (cached != null) return cached;

    final terms = temporaryArabicVocabulary;
    if (terms.isEmpty || text.trim().isEmpty) {
      _arabicMatchCache[text] = const [];
      return const [];
    }

    final normalised = _normaliseArabicWithMap(text);
    if (normalised.text.trim().isEmpty) {
      _arabicMatchCache[text] = const [];
      return const [];
    }

    final occupied = List<bool>.filled(text.length, false);
    final matches = <ArabicVocabularyMatch>[];

    for (final entry in terms) {
      var searchFrom = 0;
      while (searchFrom < normalised.text.length) {
        final index = normalised.text.indexOf(
          entry.normalisedArabic,
          searchFrom,
        );
        if (index < 0) break;

        final end = index + entry.normalisedArabic.length;
        searchFrom = index + 1;
        if (!_hasArabicBoundaries(normalised.text, index, end)) continue;
        if (end > normalised.sourceIndices.length) continue;

        final originalStart = normalised.sourceIndices[index];
        final originalEnd = normalised.sourceIndices[end - 1] + 1;
        if (originalStart < 0 ||
            originalEnd > text.length ||
            originalStart >= originalEnd) {
          continue;
        }
        var overlaps = false;
        for (var i = originalStart; i < originalEnd; i++) {
          if (occupied[i]) {
            overlaps = true;
            break;
          }
        }
        if (overlaps) continue;

        for (var i = originalStart; i < originalEnd; i++) {
          occupied[i] = true;
        }
        matches.add(ArabicVocabularyMatch(
          start: originalStart,
          end: originalEnd,
          surfaceText: text.substring(originalStart, originalEnd),
          entry: entry,
        ));
      }
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    _arabicMatchCache[text] = List.unmodifiable(matches);
    return _arabicMatchCache[text]!;
  }

  static ArabicVocabularyEntry? resolveArabicTerm(String rawTerm) {
    final normalised = normaliseArabic(rawTerm);
    if (normalised.isEmpty) return null;
    for (final entry in temporaryArabicVocabulary) {
      if (entry.normalisedArabic == normalised) return entry;
    }
    return null;
  }

  static String normalise(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?;:]'), '')
        .replaceAll(RegExp(r"^'+|'+$"), '')
        .trim();
  }

  static Map<String, dynamic>? resolveEntry(String rawWord) {
    final defs = _cache;
    if (defs == null) return null;
    final key = normalise(rawWord);
    if (key.isEmpty) return null;

    // 1. Exact match
    final exactRaw = defs[key];
    if (exactRaw != null) {
      final entry = Map<String, dynamic>.from(exactRaw as Map);
      final lemma = entry['lemma'] as String?;
      // Follow explicit lemma redirect (e.g. decided → decide).
      if (lemma != null &&
          lemma.isNotEmpty &&
          lemma != key &&
          defs.containsKey(lemma)) {
        return Map<String, dynamic>.from(defs[lemma] as Map);
      }
      // Return immediately only if enriched or a confirmed base form.
      // Thin inflected entries (no learner_panel, no self-referential lemma)
      // fall through so lookup_forms / heuristic can find the richer base.
      if (entry['learner_panel'] != null ||
          entry['panel_type'] != null ||
          lemma == key) {
        return entry;
      }
    }

    // 2. lookup_forms linear scan
    for (final e in defs.entries) {
      final entry = e.value as Map<String, dynamic>;
      final forms = entry['lookup_forms'];
      if (forms is List && forms.contains(key)) {
        return Map<String, dynamic>.from(entry);
      }
    }

    // 3. Heuristic suffix stripping
    for (final suffix in ['ing', 'ed', 'er', 'ly', 's']) {
      if (key.length > suffix.length + 2 && key.endsWith(suffix)) {
        final stem = key.substring(0, key.length - suffix.length);
        if (defs.containsKey(stem)) {
          return Map<String, dynamic>.from(defs[stem] as Map);
        }
      }
    }

    // 4. Last resort: thin exact entry rather than null.
    if (exactRaw != null) {
      return Map<String, dynamic>.from(exactRaw as Map);
    }

    return null;
  }

  static List<ArabicVocabularyEntry> _buildArabicVocabulary(
    Map<String, dynamic> defs,
  ) {
    final byNormalised = <String, ArabicVocabularyEntry>{};
    final priorities = <String, int>{};
    for (final source in defs.entries) {
      final rawEntry = source.value;
      if (rawEntry is! Map) continue;
      final entry = Map<String, dynamic>.from(rawEntry);
      if (!_isTemporaryArabicSourceEligible(entry)) continue;
      final english = _englishHeadwordFor(source.key, entry);
      if (english == null) continue;
      final definition = _optionalString(entry['mcq_safe_definition']) ??
          _optionalString(entry['definition']);

      for (final candidate in _arabicCandidates(entry)) {
        final sourceField = candidate.sourceField;
        for (final term in _splitArabicTerms(candidate.value)) {
          final cleaned = _cleanArabicTerm(term);
          if (!_isUsefulArabicTerm(cleaned)) continue;
          final normalised = normaliseArabic(cleaned);
          if (!_isUsefulNormalisedArabicTerm(normalised)) continue;
          final priority = _arabicEntryPriority(entry);
          final existingPriority = priorities[normalised];
          if (existingPriority == null || priority > existingPriority) {
            byNormalised[normalised] = ArabicVocabularyEntry(
              arabic: cleaned,
              normalisedArabic: normalised,
              englishHeadword: english,
              definition: definition,
              sourceField: sourceField,
            );
            priorities[normalised] = priority;
          }
        }
      }
    }

    final entries = byNormalised.values.toList();
    entries.sort((a, b) {
      final tokenCompare = _wordCount(b.normalisedArabic)
          .compareTo(_wordCount(a.normalisedArabic));
      if (tokenCompare != 0) return tokenCompare;
      return b.normalisedArabic.length.compareTo(a.normalisedArabic.length);
    });
    return List.unmodifiable(entries);
  }

  static Iterable<({String sourceField, String value})> _arabicCandidates(
    Map<String, dynamic> entry,
  ) sync* {
    for (final field in ['mcq_safe_arabic', 'arabic']) {
      final value = _optionalString(entry[field]);
      if (value != null && _containsArabic(value)) {
        yield (sourceField: field, value: value);
      }
    }
    final panel = entry['learner_panel'];
    if (panel is Map) {
      final value = _optionalString(panel['arabic']);
      if (value != null && _containsArabic(value)) {
        yield (sourceField: 'learner_panel.arabic', value: value);
      }
    }
  }

  static Iterable<String> _splitArabicTerms(String raw) {
    return raw.split(RegExp(r'[,،;؛/|]'));
  }

  static String _cleanArabicTerm(String raw) {
    return raw
        .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]|"[^"]*"'), ' ')
        .replaceAll(RegExp(r'[.!?؟:ـ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isUsefulArabicTerm(String term) {
    if (term.isEmpty || !_containsArabic(term)) return false;
    final normalised = normaliseArabic(term);
    return _isUsefulNormalisedArabicTerm(normalised);
  }

  static bool _isUsefulNormalisedArabicTerm(String term) {
    if (term.length < 3) return false;
    final words = _wordCount(term);
    if (words > 4) return false;
    if (words == 1) {
      if (term.length < 5) return false;
      if (_blockedArabicTerms.contains(term)) return false;
    }
    return RegExp(r'[\u0600-\u06FF]').hasMatch(term);
  }

  static bool _isTemporaryArabicSourceEligible(Map<String, dynamic> entry) {
    final register = _optionalString(entry['register'])?.toLowerCase();
    if (register == 'informal' || register == 'slang') return false;
    final panelType = _optionalString(entry['panel_type'])?.toLowerCase();
    if (panelType != null &&
        (panelType.contains('transcript_noise') ||
            panelType.contains('slang') ||
            panelType.contains('informal') ||
            panelType.contains('proper_name'))) {
      return false;
    }
    if (_optionalString(entry['named_entity_kind']) != null) return false;
    if (_optionalString(entry['cefr']) != null) return true;
    if (_optionalString(entry['display_word']) != null) return true;
    if (_optionalString(entry['mcq_safe_definition']) != null) return true;
    final panel = entry['learner_panel'];
    return panel is Map && panel['schema_version'] == 'v20_gpt4o_mini';
  }

  static int _arabicEntryPriority(Map<String, dynamic> entry) {
    var priority = 0;
    if (_optionalString(entry['display_word']) != null) priority += 4;
    if (_optionalString(entry['mcq_safe_definition']) != null) priority += 2;
    final panel = entry['learner_panel'];
    if (panel is Map) {
      priority += 4;
      if (panel['schema_version'] == 'v20_gpt4o_mini') priority += 4;
    }
    return priority;
  }

  static int _wordCount(String text) =>
      text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;

  static String? _englishHeadwordFor(
    String key,
    Map<String, dynamic> entry,
  ) {
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

  static String? _cleanAnswer(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static String? _optionalString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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

  static bool _containsArabic(String value) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(value);
  }

  static _NormalisedArabicText _normaliseArabicWithMap(String raw) {
    final buffer = StringBuffer();
    final sourceIndices = <int>[];
    for (var i = 0; i < raw.length; i++) {
      final unit = raw.codeUnitAt(i);
      if (_isArabicMark(unit) || unit == 0x0640) continue;
      final replacement = _normalisedArabicCodeUnit(unit);
      buffer.writeCharCode(replacement);
      sourceIndices.add(i);
    }
    return _NormalisedArabicText(buffer.toString(), sourceIndices);
  }

  static int _normalisedArabicCodeUnit(int unit) {
    switch (unit) {
      case 0x0622: // آ
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0671: // ٱ
        return 0x0627; // ا
      default:
        return unit;
    }
  }

  static bool _isArabicMark(int unit) {
    return (unit >= 0x0610 && unit <= 0x061A) ||
        (unit >= 0x064B && unit <= 0x065F) ||
        unit == 0x0670 ||
        (unit >= 0x06D6 && unit <= 0x06ED);
  }

  static bool _hasArabicBoundaries(String text, int start, int end) {
    final before = start == 0 ? null : text.codeUnitAt(start - 1);
    final after = end >= text.length ? null : text.codeUnitAt(end);
    return (before == null || !_isArabicWordCodeUnit(before)) &&
        (after == null || !_isArabicWordCodeUnit(after));
  }

  static bool _isArabicWordCodeUnit(int unit) {
    return (unit >= 0x0600 && unit <= 0x06FF) ||
        (unit >= 0x0750 && unit <= 0x077F) ||
        (unit >= 0x08A0 && unit <= 0x08FF);
  }
}
