import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../lessons/word_definition_overlay.dart';

// QA-only screen for V19 word-panel live testing.
// Reachable only when dart-define QA_WORD_PANEL=true is set at build time.
class QaWordPanelScreen extends StatelessWidget {
  const QaWordPanelScreen({super.key});

  static const _words = [
    'accepted',
    'accountants',
    'airports',
    'alan',
    'alabama',
    'amazon',
    'dr',
    'gonna',
    'nope',
    'braced',
    'mamas',
  ];

  static const _notes = {
    'accepted': 'inflected_redirect → accept',
    'accountants': 'plural_redirect → accountant',
    'airports': 'plural_redirect → airport',
    'alan': 'proper_name_panel (NAME)',
    'alabama': 'place_name_panel (PLACE)',
    'amazon': 'no panel_type → normal',
    'dr': 'no panel_type, has learner_panel',
    'gonna': 'no panel_type, has learner_panel',
    'nope': 'no panel_type, has learner_panel',
    'braced': 'no panel_type, no learner_panel',
    'mamas': 'no panel_type, no learner_panel',
  };

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        backgroundColor: th.card,
        title: Text(
          'V19 Word Panel QA',
          style: TextStyle(color: th.textPrimary, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: _words.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final word = _words[i];
          final note = _notes[word] ?? '';
          return Material(
            color: th.card,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showDialog(
                context: context,
                builder: (_) => WordDefinitionOverlay(word: word),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(word,
                              style: TextStyle(
                                  color: th.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(note,
                              style:
                                  TextStyle(color: th.textSub, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: th.textSub, size: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
