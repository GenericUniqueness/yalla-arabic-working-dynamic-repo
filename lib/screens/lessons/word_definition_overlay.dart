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
      backgroundColor: th.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    display,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: th.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.close,
                  icon: Icon(Icons.close_rounded, color: th.textSub),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasMeaning ? meaning : l10n.arabicLookupComingSoon,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (definitionText != null && definitionText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                definitionText,
                style: TextStyle(
                  color: th.textSub,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
            if (entry != null) ...[
              const SizedBox(height: 14),
              _SectionLabel(text: 'This word', color: th.textSub),
              const SizedBox(height: 8),
              _InfoGrid(
                th: th,
                items: [
                  if (entry.lemma != null) ('Lemma', entry.lemma!),
                  if (entry.partOfSpeech != null) ('Part of speech', entry.partOfSpeech!),
                  if (entry.pattern != null) ('Pattern', entry.pattern!),
                ],
              ),
              if (entry.exampleArabic != null || entry.exampleEnglish != null) ...[
                const SizedBox(height: 10),
                _ExampleBlock(
                  th: th,
                  arabic: entry.exampleArabic,
                  english: entry.exampleEnglish,
                ),
              ],
              if (entry.hasRootPanel) ...[
                const SizedBox(height: 14),
                _SectionLabel(text: 'Root family', color: th.textSub),
                const SizedBox(height: 8),
                _RootPanel(th: th, entry: entry),
              ],
              if (entry.synonyms.isNotEmpty || entry.antonyms.isNotEmpty) ...[
                const SizedBox(height: 14),
                _SectionLabel(text: 'More', color: th.textSub),
                const SizedBox(height: 8),
                if (entry.synonyms.isNotEmpty)
                  _ChipRow(th: th, label: 'Similar', values: entry.synonyms),
                if (entry.antonyms.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ChipRow(th: th, label: 'Opposite', values: entry.antonyms),
                ],
              ],
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: th.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                temporaryDevVocabulary
                    ? 'Golden lesson glossary draft'
                    : l10n.lookupBody,
                style: TextStyle(
                  color: temporaryDevVocabulary ? th.accent : th.textSub,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: temporaryDevVocabulary ? FontWeight.w700 : null,
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

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final dynamic th;
  final List<(String, String)> items;

  const _InfoGrid({required this.th, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: th.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${item.$1}: ${item.$2}',
            style: TextStyle(
              color: th.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ExampleBlock extends StatelessWidget {
  final dynamic th;
  final String? arabic;
  final String? english;

  const _ExampleBlock({required this.th, this.arabic, this.english});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: th.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (arabic != null)
            Text(
              arabic!,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (english != null) ...[
            if (arabic != null) const SizedBox(height: 6),
            Text(
              english!,
              style: TextStyle(
                color: th.textSub,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RootPanel extends StatelessWidget {
  final dynamic th;
  final ArabicVocabularyEntry entry;

  const _RootPanel({required this.th, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: th.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.root != null)
            Text(
              entry.root!,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          if (entry.rootCoreMeaning != null) ...[
            const SizedBox(height: 6),
            Text(
              entry.rootCoreMeaning!,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (entry.rootExplanation != null) ...[
            const SizedBox(height: 6),
            Text(
              entry.rootExplanation!,
              style: TextStyle(
                color: th.textSub,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (entry.relatedWords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.relatedWords.map((word) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: th.card,
                    borderRadius: BorderRadius.circular(8),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        word.english,
                        style: TextStyle(color: th.textSub, fontSize: 11),
                      ),
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

class _ChipRow extends StatelessWidget {
  final dynamic th;
  final String label;
  final List<String> values;

  const _ChipRow({
    required this.th,
    required this.label,
    required this.values,
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
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: th.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(color: th.textPrimary, fontSize: 12),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
