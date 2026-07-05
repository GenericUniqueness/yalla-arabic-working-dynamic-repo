# Status

Last updated: 2026-07-05 - **Yalla Arabic** (private dev shell).

## Identity

- App label: Yalla Arabic
- Android package / applicationId: `com.yallaarabic.dev`
- Distribution: private dev only (no Play, no signing, no R2, no public release)

## What works now

- Bilingual UI + English/Arabic language toggle (RTL when Arabic).
- "Main Courses" with three locally bundled Al-Fusha lessons:
  - `course_01/lesson_06` — "Easy Arabic Podcast | How to describe things?"
  - `course_01/lesson_07` — "Easy Arabic Podcast | about Social Media"
  - `course_01/lesson_10` — "Arabic Conversation for Beginners #2 | The Family"
- Audio playback with timestamp-driven transcript highlight + autoscroll.
- Arabic-primary transcript, English-secondary translation.
- Vocabulary review (dev quiz).
- Clickable Arabic vocabulary lookup over the transcript.
- First Arabic root-aware glossary slice for lesson 6 in
  `assets/arabic_glossary.json` with 19 draft entries.
- About page (bilingual, preserved verbatim).

## What is intentionally disabled

- Login / Firebase auth / Google Sign-In / email verification (`bypassAuth`).
- Onboarding tour gating.
- Production Firebase, Cloudflare R2 streaming, Google Play release, signing.

## What must not be touched

- The Yalla English repo (read-only reference; local path
  `../yalla-english-app`).
- About page content.
- Package id `com.yallaarabic.dev` / label "Yalla Arabic".
- The internal Dart package name `ez_english_app` (renaming breaks imports).
- `assets/word_definitions.json` without a reviewed preview + validation.
- Legal docs (`docs/privacy_policy.*`) and any secrets/signing/Firebase config.

## Known limitations

- Only 3 of 12 source playlist videos are integrated (videos 6, 7, and 10).
- Playlist item 6 is the active next lesson candidate; Arabic/English VTT files
  and `.opus` audio are staged locally under
  `../content_pipeline/raw/06_-U-cnbFBc9c`.
- A draft app-ready candidate 6 `content.json` and `audio.opus` were generated
  under `../content_pipeline/app_ready/06_-U-cnbFBc9c`.
- Candidate 6 is bundled into app assets under
  `assets/courses/course_01/lesson_06/main_story/`.
- Clickable Arabic vocabulary is still **dev scaffolding**, but lesson 6 now has
  a first Arabic-first root glossary. Matching is exact/normalized surface-form
  matching, not full morphology.
- Lesson 07 has some long transcript lines (readable but dense); not split, to
  preserve highlight timing (no safe intra-line timestamps).
- No emulator/device playback test recorded; verification is static analyze +
  tests + APK build.

## Next steps

- **Project handoff:** use `docs/START_HERE.md` and `docs/WORKING_TASKS.md` as
  the current resume path for agents/devs.
- **Broad direction:** use `docs/ROADMAP.md` for immediate, foundation, and
  long-term priorities.
- **Local specs:** use `docs/CODEBASE_MAP.md`, `docs/VALIDATION_CHECKLIST.md`,
  `docs/LESSON_SCHEMA.md`, `docs/LESSON_INTAKE.md`, and
  `docs/WORD_PANEL_SPEC.md` for repo-local implementation work that does not
  require Yalla English or the source playlist.
- **Pipeline planning:** use `docs/VIDEO_EXTRACTION_RUNBOOK.md`,
  `docs/GLOSSARY_SCHEMA.md`, and `docs/TOOLING_AND_MCP_NOTES.md` before building
  new extraction/translation/glossary tooling.
- **Release/legal gates:** use `docs/LEGAL_TODO.md` and
  `docs/RELEASE_READINESS.md`; these are later-stage checklists, not a request
  to release now.
- **Yalla English reference:** first read-only inspection is recorded in
  `docs/YALLA_ENGLISH_REFERENCE.md`; inspect review/practice and content scripts
  next when implementation tasks need them.
- **Full playlist:** source playlist is
  `https://www.youtube.com/playlist?list=PLbhGMu9BBf-E` with 12 entries.
  Playlist indices 6, 7, and 10 are integrated as private-dev lessons. Next,
  review lesson 6 captions/glossary, resolve validator warnings, and inspect the
  root-aware word popup in-app before building an APK. See
  `docs/VIDEO_EXTRACTION_RUNBOOK.md`.
- **Real Yasir-recorded content:** replace YouTube-sourced lessons with
  purpose-recorded Al-Fusha audio + timestamps captured at recording time.
- **Full Arabic word panel:** replace the inverted English dictionary with a
  purpose-built Arabic→English lesson glossary (with morphology) before any real
  release.
