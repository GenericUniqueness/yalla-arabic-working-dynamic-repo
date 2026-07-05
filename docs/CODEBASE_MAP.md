# Codebase Map

Last updated: 2026-07-04

This map explains the current Yalla Arabic Flutter app as it exists now. Use it
with `docs/START_HERE.md`, `docs/STATUS.md`, and `docs/ARCHITECTURE.md`.

## App identity

- Product name: `Yalla Arabic`
- Android applicationId/namespace: `com.yallaarabic.dev`
- Internal Dart package name: `ez_english_app`
- Current mode: private dev shell
- Auth mode: bypassed with local guest identity

Do not rename the Dart package just to make it look cleaner. The imports use
`package:ez_english_app/...`, so a rename is a planned migration, not a drive-by
cleanup.

## Boot path

- `lib/main.dart`
  - initializes Flutter bindings
  - initializes notification service
  - initializes `YallaAudioHandler` through `audio_service`
  - wires Provider/ChangeNotifier app state
  - routes to debug launchers when debug flags are set
  - otherwise routes directly to `HomeScreen`
- `lib/services/qa_build_config.dart`
  - keeps `bypassAuth` true
  - supplies the local dev guest user id/email

## Main app state

- `lib/providers/auth_provider.dart`
  - still exists, but dev flow bypasses real auth
- `lib/providers/settings_provider.dart`
  - language, text direction, transcript visibility, font size, autoplay
- `lib/providers/audio_provider.dart`
  - UI-facing wrapper over `YallaAudioHandler`
  - current queue item, playback state, active transcript sentence
- `lib/providers/progress_provider.dart`
  - listening/progress tracking
  - local-only when auth is bypassed
- `lib/providers/favourites_provider.dart`
  - saved words/batches
  - local-only when auth is bypassed
- `lib/providers/download_provider.dart`
  - course asset/download state
  - still has inherited remote/R2 assumptions

## Course and lesson model

- `lib/models/course.dart`
  - `Course`, `Lesson`, `LessonType`
  - supported lesson type folders include `main_story`, `vocabulary`,
    `mini_story`, `conversation`, `pov`, and `commentary`
- `lib/data/courses_data.dart`
  - current hardcoded catalog
  - only course 1, lessons 7 and 10 are registered
- `pubspec.yaml`
  - only the two current lesson JSON/audio asset paths are explicitly bundled

Lesson path convention:

```text
assets/courses/course_<NN>/lesson_<NN>/<type_folder>/content.json
assets/courses/course_<NN>/lesson_<NN>/<type_folder>/audio.opus
```

## Lesson content parsing

- `lib/models/sentence.dart`
  - parses lesson content from either a root list or an object with `sentences`
  - preferred root field: `lesson_title`
  - sentence fields:
    - `id`
    - `english` or legacy `text`
    - `arabic` or legacy `ara`
    - `start_time` or legacy `start`
    - `end_time` or legacy `end`
- `lib/services/audio_handler.dart`
  - loads JSON from remote/cache when a remote path exists
  - falls back to bundled asset JSON
  - validates only that `LessonContent.fromJson` can parse the body
  - loads audio from local file, R2/remote URL, or bundled asset
- `lib/services/transcript_diagnostics.dart`
  - debug-only timing diagnostics
  - checks empty English text, invalid timestamps, overlaps, large gaps,
    compressed English words/sec, first-start offset, and final tail gap

Current gap: validation is parse-oriented, not schema-quality-oriented. See
`docs/LESSON_SCHEMA.md` and `docs/VALIDATION_CHECKLIST.md`.

## Player and transcript UI

- `lib/screens/lessons/player_screen.dart`
  - main audio lesson experience
  - renders Arabic primary, right-aligned and RTL-oriented
  - renders English translation when `settings.showArabicTranslation` is true
  - highlights active sentence by timestamp
  - supports repeat/segment practice
  - calls `WordDefinitionService.matchArabicTerms` for temporary clickable
    Arabic vocabulary
- `lib/screens/lessons/word_definition_overlay.dart`
  - current popup/panel for word details
  - supports temporary-dev vocabulary badge/state

## Word lookup and review

- `assets/word_definitions.json`
  - inherited English-keyed dictionary
  - currently reused as temporary Arabic lookup source
- `lib/services/word_definition_service.dart`
  - loads `assets/word_definitions.json`
  - builds temporary Arabic vocabulary from fields like `mcq_safe_arabic`,
    `arabic`, and `learner_panel.arabic`
  - normalizes Arabic by stripping marks/tatweel and folding alef variants
  - uses Arabic word boundaries and a blocklist for tiny/common terms
  - prefers longest phrase matches
- `lib/services/review_question_builder.dart`
  - builds English and temporary Arabic dev MCQ review sessions
  - Arabic dev mode shows Arabic prompt with English choices

The final Arabic word panel needs a new Arabic-first glossary/morphology model.
See `docs/WORD_PANEL_SPEC.md`.

## Grammar

- `assets/grammar/` and `assets/grammar/topics/`
  - bundled grammar content inherited/adapted for the app
- `lib/services/grammar_content_service.dart`
  - loads grammar index and topic files from assets
- `lib/screens/grammar/`
  - grammar list, practice, result, weak review, topic detail

Grammar appears secondary to the listening-first lesson flow for the current
milestone.

## Debug and local tooling

- `lib/services/content_source_config.dart`
  - production R2 base URL remains present
  - debug-only local override and DP-alignment flags remain present
  - contains inherited `course_05` normalized-audio fixture paths
- `lib/screens/debug/qa_lesson_launcher.dart`
  - debug transcript/lesson launcher
- `lib/screens/debug/qa_word_panel_screen.dart`
  - debug word-panel screen

These are useful for dev work but need review before any release path.

## Tests

- `test/word_definition_service_test.dart`
  - Arabic normalization
  - temporary Arabic phrase matching
  - common-word skipping
  - clickable vocab match coverage in the two integrated lessons
- `test/review_question_builder_test.dart`
  - English and Arabic MCQ session generation
  - distractor safety
  - Arabic prompts with English choices
- `test/analytics_service_test.dart`
  - analytics behavior
- `test/widget_test.dart`
  - provider/widget-level behavior

## Current audit findings

Track these as cleanup or validation items, not emergency fixes:

- `docs/privacy_policy.md` and `.html` still describe Yalla English. Existing
  rules say not to edit legal docs casually, so treat this as a later legal
  replacement task.
- `lib/services/content_source_config.dart` still has inherited `course_05`
  debug fixture paths.
- `lib/services/audio_cache_service.dart` comments still use old course examples.
- Firebase, Firestore, analytics, R2, signing, and account deletion code remain
  present but are intentionally bypassed or deferred for dev.
- Android Kotlin source path contains `com/yallaenglish/app`, documented as
  cosmetic because the Android applicationId/namespace is already Arabic dev.
- Current content assets include `redistribution_permission: not_claimed`;
  release-quality content needs a reviewed rights/permission path.
