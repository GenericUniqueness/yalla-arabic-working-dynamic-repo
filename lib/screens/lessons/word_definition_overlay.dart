import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/theme_provider.dart';
import '../../services/word_definition_service.dart';

class WordDefinitionOverlay extends StatelessWidget {
  final String word;
  final String? clickedForm;
  final String? lessonKey;
  final String? englishMeaning;
  final String? definition;
  final bool temporaryDevVocabulary;
  final ArabicVocabularyEntry? arabicEntry;

  const WordDefinitionOverlay({
    super.key,
    required this.word,
    this.clickedForm,
    this.lessonKey,
    this.englishMeaning,
    this.definition,
    this.temporaryDevVocabulary = false,
    this.arabicEntry,
  });

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final l10n = context.l10n;
    final display = clickedForm ?? word;
    final entry = arabicEntry;
    final meaning = (entry?.englishHeadword ?? englishMeaning)?.trim();
    final hasMeaning = meaning != null && meaning.isNotEmpty;
    final definitionText = (entry?.definition ?? definition)?.trim();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 680),
        child: Container(
          decoration: BoxDecoration(
            color: th.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header accent strip
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: th.accent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
              ),
              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Word header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  display,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    color: th.textPrimary,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                ),
                                if (entry?.lemma != null &&
                                    entry!.lemma != display) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.lemma!,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      color: th.textSub,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: l10n.close,
                            icon: Icon(
                              Icons.close_rounded,
                              color: th.textSub,
                              size: 22,
                            ),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                      // English meaning
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: th.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hasMeaning ? meaning : l10n.arabicLookupComingSoon,
                          style: TextStyle(
                            color: hasMeaning ? th.textPrimary : th.textSub,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                      // Definition
                      if (definitionText != null && definitionText.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          definitionText,
                          style: TextStyle(
                            color: th.textSub,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                      // Word details section
                      if (entry != null) ...[
                        const SizedBox(height: 16),
                        _SectionHeader(
                          icon: Icons.info_outline,
                          text: 'Word Details',
                          color: th.textSub,
                        ),
                        const SizedBox(height: 10),
                        _DetailChips(th: th, entry: entry),
                        // Example
                        if (entry.exampleArabic != null ||
                            entry.exampleEnglish != null) ...[
                          const SizedBox(height: 14),
                          _ExampleCard(
                            th: th,
                            arabic: entry.exampleArabic,
                            english: entry.exampleEnglish,
                          ),
                        ],
                        // Root family
                        if (entry.hasRootPanel) ...[
                          const SizedBox(height: 16),
                          _SectionHeader(
                            icon: Icons.account_tree_outlined,
                            text: 'Root Family',
                            color: th.textSub,
                          ),
                          const SizedBox(height: 10),
                          _RootFamilyCard(th: th, entry: entry),
                        ],
                        // Synonyms / Antonyms
                        if (entry.synonyms.isNotEmpty ||
                            entry.antonyms.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _SectionHeader(
                            icon: Icons.compare_arrows,
                            text: 'Related Words',
                            color: th.textSub,
                          ),
                          const SizedBox(height: 10),
                          if (entry.synonyms.isNotEmpty)
                            _WordChips(
                              th: th,
                              label: 'Similar',
                              values: entry.synonyms,
                              chipColor: th.accent.withValues(alpha: 0.10),
                            ),
                          if (entry.antonyms.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _WordChips(
                              th: th,
                              label: 'Opposite',
                              values: entry.antonyms,
                              chipColor: th.bg,
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _DetailChips extends StatelessWidget {
  final dynamic th;
  final ArabicVocabularyEntry entry;

  const _DetailChips({required this.th, required this.entry});

  @override
  Widget build(BuildContext context) {
    final items = <_ChipData>[];
    if (entry.partOfSpeech != null) {
      items.add(_ChipData('POS', entry.partOfSpeech!));
    }
    if (entry.pattern != null) {
      items.add(_ChipData('Pattern', entry.pattern!));
    }
    if (entry.root != null) {
      items.add(_ChipData('Root', entry.root!));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: th.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  color: th.textSub,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                style: TextStyle(
                  color: th.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ChipData {
  final String label;
  final String value;
  const _ChipData(this.label, this.value);
}

class _ExampleCard extends StatelessWidget {
  final dynamic th;
  final String? arabic;
  final String? english;

  const _ExampleCard({required this.th, this.arabic, this.english});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: th.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: th.textSub.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote,
                size: 14,
                color: th.accent.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                'Example',
                style: TextStyle(
                  color: th.textSub,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          if (arabic != null) ...[
            const SizedBox(height: 8),
            Text(
              arabic!,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (english != null) ...[
            if (arabic != null) const SizedBox(height: 6),
            Text(
              english!,
              style: TextStyle(
                color: th.textSub,
                fontSize: 13,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RootFamilyCard extends StatelessWidget {
  final dynamic th;
  final ArabicVocabularyEntry entry;

  const _RootFamilyCard({required this.th, required this.entry});

  @override
  Widget build(BuildContext context) {
    final rootInfo = WordDefinitionService.getRootInfo(entry.root);
    final coreMeaning = rootInfo?.coreMeaning ?? entry.rootCoreMeaning;
    final explanation = rootInfo?.explanation ?? entry.rootExplanation;

    final computedFamily = WordDefinitionService.getWordFamily(
      entry.root,
      excludeLemma: entry.lemma,
    );

    final familyWords = computedFamily.isNotEmpty
        ? computedFamily
            .map((e) => ArabicRelatedWord(
                  arabic: e.arabic,
                  english: e.englishHeadword,
                  relation: e.partOfSpeech,
                ))
            .toList()
        : entry.relatedWords;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: th.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: th.accent.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Root display
          if (entry.root != null)
            Text(
              entry.root!,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: th.accent,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          if (coreMeaning != null) ...[
            const SizedBox(height: 6),
            Text(
              coreMeaning,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (explanation != null) ...[
            const SizedBox(height: 6),
            Text(
              explanation,
              style: TextStyle(
                color: th.textSub,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          // Family words
          if (familyWords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'FAMILY MEMBERS',
              style: TextStyle(
                color: th.textSub,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: familyWords.take(6).map((word) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: th.card,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        word.arabic,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: th.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        word.english,
                        style: TextStyle(
                          color: th.textSub,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (word.relation != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          word.relation!,
                          style: TextStyle(
                            color: th.accent.withValues(alpha: 0.7),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _WordChips extends StatelessWidget {
  final dynamic th;
  final String label;
  final List<String> values;
  final Color chipColor;

  const _WordChips({
    required this.th,
    required this.label,
    required this.values,
    required this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: th.textSub,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: values.map((value) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: th.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
