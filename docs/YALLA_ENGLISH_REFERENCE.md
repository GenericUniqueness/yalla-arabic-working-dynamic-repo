# Yalla English Reference

Last updated: 2026-07-05

Yalla English is the inspiration/reference app for Yalla Arabic. Treat it as a
read-only source of product and implementation patterns.

## Status

The Yalla English repo is available in this workspace as read-only reference:

- local path: `../yalla-english-app`
- GitHub URL: not recorded in `../repo links.txt`
- branch/commit inspected: not recorded; use Git with a per-command
  `safe.directory` override if needed because this sandbox user differs from
  the filesystem owner

The root workspace `repo links.txt` still says `English: // not recieved yet`.
It also does not currently contain the source Arabic playlist URL.

## Hard rule

Never modify Yalla English from this project. Do not copy Yalla English course
JSON/audio into Yalla Arabic.

## What to study

Use the English repo to inspect and document:

- lesson player screen:
  - audio loading
  - transcript timing and highlighting
  - autoscroll behavior
  - sentence repeat/seek behavior
  - translation visibility settings
- word definition panel:
  - layout
  - data fields
  - synonyms/antonyms/examples
  - how taps are detected in transcript text
  - fallback behavior for unknown words
- review/practice:
  - how vocabulary questions are built
  - how progress is stored
  - weak-word review behavior
- course model:
  - course/lesson/type structure
  - local vs remote content loading
  - asset registration
- app shell:
  - navigation structure
  - settings
  - downloads/offline behavior
  - auth/onboarding flow, for later only
- build/release:
  - debug/release APK commands
  - signing/Firebase/Play flow, for later only

## What should transfer to Yalla Arabic

Likely reusable:

- Flutter app shell patterns
- player architecture
- transcript highlighting/autoscroll pattern
- basic review flow
- visual structure of the word panel
- explicit content asset policy

Must be redesigned for Arabic:

- word lookup and morphology
- root-word grouping
- Arabic normalization/tokenization
- Arabic-first glossary schema
- English translation QA process
- Arabic transcript line splitting/timing rules

## Inspection Notes

Snapshot from the imported repo:

- Flutter/Dart Android app.
- App name: Yalla English.
- Android package: `com.yallaenglish.app`.
- Play version documented by English repo: `1.4.1+25`.
- Production app state documented by English repo: closed testing.
- English docs say the active external audio/content master had 537 JSON/audio
  one-to-one mappings.
- Local English repo tree contains more `content.json` files than the active
  mapping count. Treat local content files as editing/history material unless
  the English docs identify them as active.

### Lesson player

Relevant files:

- `../yalla-english-app/lib/screens/lessons/player_screen.dart`
- `../yalla-english-app/lib/providers/audio_provider.dart`
- `../yalla-english-app/lib/services/audio_handler.dart`
- `../yalla-english-app/lib/providers/download_provider.dart`

Reusable concepts:

- lesson type tabs with stable order: main story, POV, mini story,
  conversation, commentary, vocabulary
- `AudioQueueItem` queue built from course lessons and available lesson types
- current sentence tracking from audio position
- timestamp-driven transcript highlight
- autoscroll that pauses when the user manually scrolls and resumes when the
  active sentence returns to view
- sleep timer, speed control, repeat/shadowing mode, favourites, download state
- offline guard before uncached streamed playback

Yalla Arabic implications:

- Keep the same high-level player shape.
- Preserve Arabic-primary transcript display and English as support text.
- Treat repeat/shadowing as a valuable Arabic pronunciation/listening feature.
- Do not copy English content paths or old Course 01 `rule_` special cases.

### Word panel

Relevant files:

- `../yalla-english-app/lib/screens/lessons/word_definition_overlay.dart`
- `../yalla-english-app/lib/services/word_definition_service.dart`
- `../yalla-english-app/assets/word_definitions.json`
- `../yalla-english-app/scripts/word_panel/`

English panel data includes fields such as:

- `definition`
- `arabic`
- `example`
- `pos`
- `phonetic`
- `ipa`
- `cefr`
- `lemma`
- `lookup_forms`
- `forms`
- `form_examples`
- `synonyms`
- `similar`
- `collocations`
- `phrasal_verbs`
- `verb_pattern`
- `idioms`
- `learner_panel`
- `panel_type`
- `redirect_target`
- `review_state`

Reusable concepts:

- cache JSON lookup data after first load
- allow richer canonical entries and thinner redirect entries
- prefer learner-panel content when available
- expose examples, usage notes, related words, and review status
- keep unresolved/sensitive/special panels explicit instead of guessing

Yalla Arabic redesign requirements:

- replace English inflection lookup with Arabic normalization and morphology
- support surface form, normalized form, lemma, root, pattern/wazn, POS, English
  meaning, examples, synonyms, antonyms, and root family
- handle clitics, definite article, diacritics, tatweel, alef variants,
  ya/alef-maqsura, and ta marbuta normalization
- use human review states before treating generated entries as release-ready

### Review system

Relevant files to inspect next:

- `../yalla-english-app/lib/services/review_question_builder.dart`
- `../yalla-english-app/lib/providers/review_provider.dart`
- `../yalla-english-app/lib/screens/review/`

Expected reusable concepts:

- build review prompts from lesson vocabulary
- track weak words and saved words
- store local/cloud progress separately from content definitions

Yalla Arabic implication: review should eventually target Arabic recognition,
Arabic-to-English meaning, root-family recognition, and listening comprehension.

### Content model

Relevant files:

- `../yalla-english-app/lib/models/course.dart`
- `../yalla-english-app/lib/models/sentence.dart`
- `../yalla-english-app/lib/data/courses_data.dart`
- `../yalla-english-app/pubspec.yaml`

The model shape matches Yalla Arabic closely:

- `Course`
- `Lesson`
- `LessonType`
- `SentenceData`
- `LessonContent`
- top-level `lesson_title`
- `sentences`
- per-sentence `english`, `arabic`, `start_time`, `end_time`

Reusable concept: course definitions are hardcoded in Dart, while content JSON
and audio paths follow `assets/courses/course_<NN>/lesson_<NN>/<type>/`.

Yalla Arabic implication: keep this schema for now. Add validation and pipeline
discipline around it rather than redesigning the whole app model prematurely.

### Content pipeline and operational discipline

Relevant English reference areas:

- `../yalla-english-app/scripts/content/`
- `../yalla-english-app/scripts/word_panel/`
- `../yalla-english-app/scripts/grammar/`
- `../yalla-english-app/reports/`
- `../yalla-english-app/docs/ASSET_RECOVERY.md`
- `../yalla-english-app/docs/REPORT_INDEX.md`

Transfer the discipline:

- keep generated artifacts out of Git unless explicitly whitelisted
- write reports for content repair, validation, and release-relevant changes
- preserve source/content masters outside the app repo when they become large
- never expose secrets/signing/Firebase values in reports

Do not transfer:

- English course content
- English audio
- English production package/signing/release identity
- old Mac absolute paths as current Windows truth

### Build/deployment

Yalla English is useful later for release discipline, but not yet as a shipping
template. Yalla Arabic is still a private dev shell and must not inherit the
English production package, signing, Firebase setup, or Play release workflow.

## Next Reference Tasks

- Inspect the English review system in more detail and map it to Arabic review
  tasks.
- Compare English `word_definition_overlay.dart` with Yalla Arabic's current
  overlay and decide whether to fork, simplify, or build a new Arabic panel.
- Inspect English content validation/report scripts for patterns worth adapting.
- Record exact English Git branch/commit once Git safe-directory handling is
  configured or user confirms the repo metadata.
