import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/theme_provider.dart';

class WordDefinitionOverlay extends StatelessWidget {
  final String word;
  final String? clickedForm;
  final String? lessonKey;
  final String? englishMeaning;
  final String? definition;
  final bool temporaryDevVocabulary;

  const WordDefinitionOverlay({
    super.key,
    required this.word,
    this.clickedForm,
    this.lessonKey,
    this.englishMeaning,
    this.definition,
    this.temporaryDevVocabulary = false,
  });

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final l10n = context.l10n;
    final display = clickedForm ?? word;
    final meaning = englishMeaning?.trim();
    final hasMeaning = meaning != null && meaning.isNotEmpty;
    final definitionText = definition?.trim();
    return Dialog(
      backgroundColor: th.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: th.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                temporaryDevVocabulary
                    ? 'Temporary dev vocabulary'
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
    );
  }
}
