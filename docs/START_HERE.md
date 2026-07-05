# Start Here

Last updated: 2026-07-05

This is the fastest orientation path for a new agent, developer, or LLM picking
up Yalla Arabic.

## Product goal

Ship **Yalla Arabic**, a Flutter Android app for English speakers learning
Modern Standard Arabic / Al-Fusha.

The target experience is inspired by **Yalla English**:

- listening-first lessons built around real audio
- timestamped transcript highlighting
- primary target-language transcript plus English support
- tappable words that open a learner-focused definition panel
- review/practice flows that reuse lesson vocabulary

For Yalla Arabic, the lesson core is:

1. Arabic audio
2. Arabic subtitles/transcript with timestamps
3. English translation/subtitles aligned to the Arabic

If English subtitles do not exist, they must be generated and reviewed. Arabic
and English alignment should be reviewed by humans before content is treated as
release-quality.

## Current repo state

This repo is already a Flutter app copied from Yalla English and re-flipped as a
private Yalla Arabic dev shell.

Known links from the workspace:

- Yalla Arabic GitHub: `https://github.com/2ms-muzammil/yalla-arabic-app`
- Yalla English local reference: `../yalla-english-app`
- Yalla English GitHub: not recorded in `../repo links.txt`
- Source Arabic playlist:
  `https://www.youtube.com/playlist?list=PLbhGMu9BBf-E`

Current app facts:

- app label: `Yalla Arabic`
- Android package/applicationId: `com.yallaarabic.dev`
- internal Dart package name: `ez_english_app` (inherited; do not rename yet)
- auth/onboarding/Firebase login: bypassed for dev
- bundled lessons: `course_01/lesson_06`, `course_01/lesson_07`, and
  `course_01/lesson_10`
- word panel: lesson 6 has a first Arabic root-aware glossary slice; inherited
  English dictionary inversion remains as fallback/dev scaffolding
- distribution: private dev only, no Play release/signing/secrets work

## Read order

Read these files in order before making non-trivial changes:

1. `AGENTS.md` - hard operating rules
2. `docs/START_HERE.md` - this orientation file
3. `docs/WORKING_TASKS.md` - current backlog and next actions
4. `docs/ROADMAP.md` - broad direction by time horizon
5. `docs/STATUS.md` - current working/disabled/limited areas
6. `docs/ARCHITECTURE.md` - app architecture
7. `docs/CODEBASE_MAP.md` - current source layout and audit notes
8. `docs/VALIDATION_CHECKLIST.md` - checks to run by change type
9. `docs/LESSON_SCHEMA.md` - app-ready lesson content contract
10. `docs/LESSON_INTAKE.md` - source/video lesson tracker template
11. `docs/WORD_PANEL_SPEC.md` - target Arabic word-panel design
12. `docs/VIDEO_EXTRACTION_RUNBOOK.md` - future source-video extraction flow
13. `docs/GLOSSARY_SCHEMA.md` - future Arabic glossary data contract
14. `docs/TOOLING_AND_MCP_NOTES.md` - expected CLI/MCP/tooling approach
15. `docs/FIXES.md` - known issues and follow-up corrections
16. `docs/VIDEO_EXTRACTION_RUNBOOK.md` - lesson production flow
17. `docs/ASSET_POLICY.md` - what can be bundled in the APK
18. `docs/YALLA_ENGLISH_REFERENCE.md` - read-only Yalla English reference notes
19. `docs/LEGAL_TODO.md` and `docs/RELEASE_READINESS.md` - later release gates

## Important source files

- `lib/main.dart` - app boot, provider wiring, dev auth bypass route
- `lib/data/courses_data.dart` - current course/lesson catalog
- `lib/screens/lessons/player_screen.dart` - audio lesson UI, transcript, word taps
- `lib/services/audio_handler.dart` - bundled content/audio loading and playback
- `assets/arabic_glossary.json` - first root-aware glossary slice for lesson 6
- `lib/services/word_definition_service.dart` - Arabic glossary lookup plus fallback lookup
- `lib/screens/lessons/word_definition_overlay.dart` - definition panel UI
- `lib/services/review_question_builder.dart` - vocabulary review generation
- `pubspec.yaml` - explicit lesson asset bundle list

## Current spec docs

- `docs/CODEBASE_MAP.md` - repo-based source map and audit findings
- `docs/ROADMAP.md` - immediate, foundation, and long-term direction
- `docs/VALIDATION_CHECKLIST.md` - validation commands and manual checks
- `docs/LESSON_SCHEMA.md` - required content JSON/audio shape
- `docs/LESSON_INTAKE.md` - tracker for candidate videos/audio
- `docs/WORD_PANEL_SPEC.md` - Arabic-first word panel target
- `docs/VIDEO_EXTRACTION_RUNBOOK.md` - planned video/audio/subtitle extraction flow
- `docs/GLOSSARY_SCHEMA.md` - future glossary JSON contract
- `docs/TOOLING_AND_MCP_NOTES.md` - local tools and MCP expectations

## Immediate constraints

- Do not modify Yalla English. It is read-only inspiration/reference.
- Do not copy Yalla English course JSON/audio into this repo.
- Do not reintroduce broad `assets/courses/` bundling.
- Do not change About/legal text or production secrets/signing/Firebase config.
- Keep `com.yallaarabic.dev` and the app label `Yalla Arabic`.

## Content direction

The preferred lesson intake flow is:

1. Choose source video/audio.
2. Extract or obtain Arabic subtitles with timestamps.
3. Extract or obtain English subtitles, or generate English translation.
4. Review Arabic transcript and English translation.
5. Build app-ready `content.json` plus `audio.mp3`.
6. Add explicit app assets and catalog entry.
7. Validate transcript timing, playback, review questions, and word taps.

The first usable source set should prioritize videos that already have Arabic
subtitles. Videos without reliable Arabic subtitles should be skipped until local
human captions are supplied.

## What is still missing

- Yalla English GitHub URL, if we want it recorded separately from the local
  imported folder.
- The active content pipeline folder for this imported Windows workspace, if it
  differs from the older Mac paths in existing docs.
- A reviewed Arabic morphology/glossary strategy for the real word panel.
- APK/deployment plan, which is intentionally later.
