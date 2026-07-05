# Glossary Schema

Last updated: 2026-07-05

This is the proposed data contract for the future Arabic-first glossary. The
glossary should power word taps, word panels, and eventually review questions.

Update 2026-07-05: a first draft implementation now exists in
`assets/arabic_glossary.json` for lesson 6, with app support in
`WordDefinitionService` and `WordDefinitionOverlay`. Treat this schema as the
target shape and the current asset as a golden-lesson draft pending review.

## Goals

- Explain Arabic words in lesson context.
- Connect surface forms to lemma/root/pattern.
- Support root-family exploration.
- Distinguish generated data from reviewed data.
- Avoid using inherited English dictionary data as the release source of truth.

## File shape

Current implemented path:

```text
assets/arabic_glossary.json
```

Recommended root:

```json
{
  "schema_version": "arabic_glossary_v1",
  "language": "ar",
  "learner_language": "en",
  "entries": []
}
```

## Entry shape

```json
{
  "id": "root-lemma-sense",
  "surface_forms": [],
  "normalized_forms": [],
  "lemma": "",
  "root": "",
  "pattern": "",
  "part_of_speech": "",
  "register": "MSA",
  "level": "",
  "english_meaning": "",
  "context_meaning": "",
  "usage_note": "",
  "examples": [],
  "root_family": [],
  "synonyms": [],
  "antonyms": [],
  "lesson_links": [],
  "review": {
    "status": "generated",
    "reviewer": "",
    "reviewed_at": "",
    "notes": ""
  }
}
```

## Required fields for display

Minimum viable reviewed entry:

- `id`
- `surface_forms`
- `normalized_forms`
- `lemma`
- `english_meaning`
- `review.status`

Required for root-family panel:

- `root`
- `root_family`

Required for review questions:

- `english_meaning`
- at least one safe Arabic prompt from `surface_forms` or examples
- enough distractor-safe entries in the same level/content pool

## Review statuses

Use:

- `generated`
- `needs_review`
- `reviewed`
- `rejected`

Release builds should show `reviewed` entries by default. Dev builds may show
non-reviewed entries with an explicit visible badge.

## Example object

```json
{
  "id": "ktb-kitaab-book",
  "surface_forms": ["كتاب", "الكتاب"],
  "normalized_forms": ["كتاب", "الكتاب"],
  "lemma": "كتاب",
  "root": "ك ت ب",
  "pattern": "فعال",
  "part_of_speech": "noun",
  "register": "MSA",
  "level": "A1",
  "english_meaning": "book",
  "context_meaning": "the book",
  "usage_note": "Common noun from the writing root family.",
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
  "lesson_links": [
    {
      "course_id": 1,
      "lesson_id": 7,
      "type": "main_story",
      "sentence_id": 3
    }
  ],
  "review": {
    "status": "reviewed",
    "reviewer": "human",
    "reviewed_at": "2026-07-04",
    "notes": ""
  }
}
```

## Generation policy

LLMs or morphology tools can draft:

- English meanings
- usage notes
- root-family candidates
- synonyms/antonyms
- example translations

They should not be treated as authoritative. Human review is required before
release-quality display.

## Open implementation choices

- Whether glossary data is global, per course, or per lesson.
- Whether review questions read directly from the glossary or from generated
  review-safe projections.
- Whether to store transliteration/pronunciation.
- Whether to use an Arabic morphology library in pipeline only or inside the app.

## Current validation

```bash
python scripts/validate_arabic_glossary.py
```

Current validator checks required display fields, Arabic surface forms, root
shape, examples, and root-family related words.
