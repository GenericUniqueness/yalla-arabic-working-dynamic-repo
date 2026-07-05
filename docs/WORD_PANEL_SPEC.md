# Arabic Word Panel Spec

Last updated: 2026-07-05

This spec defines where the Yalla Arabic word panel should go. The current app
has a temporary lookup based on inherited English dictionary data; this document
describes the target Arabic-first replacement.

Update 2026-07-05: the first Arabic-first version is implemented for lesson 6.
The popup now supports word details, root-family content, and synonyms/antonyms
from `assets/arabic_glossary.json`.

## Product goal

When a learner taps an Arabic word or phrase in a lesson transcript, show a
focused learner panel that explains the surface form in context and connects it
to the wider Arabic word family.

The panel should help an English speaker answer:

- What does this word/phrase mean here?
- What is the base form or lemma?
- What root does it come from?
- What related words share the same root?
- How can I recognize or use this form in other sentences?

## Current implementation

Current files:

- `assets/arabic_glossary.json`
- `assets/word_definitions.json`
- `lib/services/word_definition_service.dart`
- `lib/screens/lessons/word_definition_overlay.dart`
- `lib/screens/lessons/player_screen.dart`
- `test/word_definition_service_test.dart`

Current behavior:

- loads a curated Arabic-first glossary when available
- loads inherited English-keyed dictionary
- extracts Arabic candidates from fields like `mcq_safe_arabic`, `arabic`, and
  `learner_panel.arabic`
- normalizes Arabic by stripping marks/tatweel and folding alef variants
- uses Arabic word-boundary checks
- skips tiny/common blocked terms
- prefers longest non-overlapping matches
- opens `WordDefinitionOverlay` with a temporary dev badge

Current limitations:

- no true morphology
- no automatic root extraction
- no lemma-aware matching
- no clitic handling
- no contextual disambiguation
- inherited dictionary can produce context-imperfect Arabic matches
- Arabic-first glossary is draft/pending review, not release-ready

## Target data model

Recommended glossary file shape:

```json
{
  "schema_version": "arabic_word_panel_v1",
  "entries": [
    {
      "id": "ktb-kitaab",
      "surface_forms": ["كتاب", "الكتاب"],
      "normalized_forms": ["كتاب", "الكتاب"],
      "lemma": "كتاب",
      "root": "ك ت ب",
      "pattern": "فعال",
      "part_of_speech": "noun",
      "english_meaning": "book",
      "context_meaning": "the book",
      "level": "A1",
      "dialect_register": "MSA",
      "examples": [
        {
          "arabic": "هذا كتاب جديد.",
          "english": "This is a new book.",
          "source": "curated"
        }
      ],
      "root_family": [
        {
          "arabic": "كتب",
          "english": "he wrote",
          "part_of_speech": "verb"
        },
        {
          "arabic": "كاتب",
          "english": "writer",
          "part_of_speech": "noun"
        }
      ],
      "synonyms": [],
      "antonyms": [],
      "review": {
        "status": "unreviewed",
        "reviewer": "",
        "notes": ""
      }
    }
  ]
}
```

Use real Arabic text in the actual data. The example above is illustrative.

## Panel layout

The panel should have three learner-facing sections:

1. Word in context
   - tapped surface form
   - pronunciation/transliteration if available
   - context-specific English meaning
   - short usage note
2. Root and family
   - root letters
   - lemma/base form
   - pattern/wazn when available
   - related words from the same root
3. Related meaning
   - synonyms
   - antonyms
   - lesson examples
   - save/review action if supported

Avoid overwhelming beginners. Root-family data should be collapsible or limited
to the most useful few forms in early versions.

## Matching requirements

The matcher should eventually support:

- diacritic-insensitive matching
- tatweel-insensitive matching
- alef/hamza normalization
- optional definite article handling
- common clitic handling for `و`, `ف`, `ب`, `ل`, `ك`, and attached pronouns
- longest match preference for phrases
- no noisy matching of high-frequency function words
- context override when a lesson supplies a specific meaning

Do not rely on English-style whitespace tokenization alone. Arabic clitics and
inflected forms need language-specific logic.

## Review states

Every glossary entry should carry a review state:

- `generated`
- `needs_review`
- `reviewed`
- `rejected`

Release-quality panels should only show `reviewed` entries by default. Dev
builds may show unreviewed entries with a visible badge.

## Testing plan

Add tests for:

- normalization of marks, tatweel, alef/hamza variants
- matching with definite article
- matching with common prefixes/clitics
- longest phrase match over shorter word match
- blocked function words
- root-family grouping
- unknown-word fallback
- reviewed vs unreviewed entry display policy

## Migration plan

1. Keep current temporary lookup working as a fallback.
2. Add a new Arabic glossary asset with a small reviewed sample.
3. Add a new service beside `WordDefinitionService` or refactor behind a stable
   interface.
4. Wire the player to prefer Arabic glossary matches.
5. Keep temporary inherited dictionary behind a dev flag only.
6. Remove or de-emphasize inherited dictionary once enough reviewed Arabic
   glossary coverage exists.

## Open decisions

- Where will reviewed Arabic glossary data live?
- Who reviews root, lemma, and translation accuracy?
- Should root-family words be generated first and reviewed later, or manually
  curated from the start?
- Do we need pronunciation audio for tapped words?
- Should the same glossary power review questions, or should review use a
  separate lesson-vocabulary model?

## Current Implementation Notes

- Matching is surface-form based with Arabic normalization for hamza/diacritics.
- It is not a morphology engine yet.
- The middle root section is shared through each entry's `root_family` block.
- Full-lesson vocabulary coverage is not claimed; lesson 6 currently has a
  curated 19-entry draft glossary.
