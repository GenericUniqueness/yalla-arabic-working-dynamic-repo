# Working Tasks

Last updated: 2026-07-05

This file is the living task board. Keep it current when work starts, pauses, or
finishes so the next agent can resume without guessing.

## Current milestone

Build a dependable Yalla Arabic dev foundation:

- durable docs and handoff context
- clear Yalla English reference plan
- content pipeline checklist
- app architecture map
- first backlog for lessons, word panel, QA, and APK path

See `docs/ROADMAP.md` for the broader immediate, foundation, and long-term
direction. Keep this file as the live task checklist.

## Now

- [x] Capture user brain dump into durable repo docs.
- [x] Inspect current Yalla Arabic app structure.
- [x] Record current architecture, constraints, and next actions.
- [x] Record current Yalla Arabic GitHub URL from `repo links.txt`.
- [x] Add codebase map, validation checklist, lesson schema, lesson intake
  tracker, and word-panel spec.
- [x] Add lesson content validator script.
- [x] Add video extraction runbook, glossary schema, legal TODO, release
  readiness, and tooling/MCP notes.
- [x] Get Yalla English repo path or GitHub URL from the user.
- [x] Get Yalla Arabic source playlist/video list from the user.
- [x] Add broad next-step roadmap in `docs/ROADMAP.md`.
- [x] Locate or create the active content pipeline workspace for this machine.

## Immediate: next 1-3 work sessions

- [x] Fix/update `yt-dlp` so subtitle inspection works reliably.
- [x] Inspect subtitles one video at a time for playlist indices 6, 9, 11, and
  12 first.
- [x] Choose the next viable lesson candidate based on Arabic caption quality,
  English subtitle/translation availability, and review capacity.
- [x] Confirm or create a local pipeline workspace outside committed app assets.
- [x] Record every new source decision in `docs/LESSON_INTAKE.md`.
- [ ] Clean and normalize candidate 6 Arabic/English VTT files.
- [x] Generate candidate 6 draft app-ready `content.json`.
- [x] Run lesson validator on candidate 6 draft app-ready JSON before app
  integration.
- [x] Integrate candidate 6 as a bundled private-dev lesson.
- [x] Add first Arabic root-aware glossary asset for lesson 6.
- [x] Wire the definition window to show word data, root family data, and
  synonyms/antonyms from the Arabic glossary.
- [x] Add Arabic glossary validator.
- [ ] Review candidate 6 validator warnings and caption quality.
- [ ] Manually inspect candidate 6 in the app before building an APK.

## Foundation: after the next viable lesson is identified

- [ ] Build content pipeline v1: metadata, caption download, caption cleaning,
  translation, review status, app-ready JSON, and validation.
- [ ] Integrate exactly one new lesson after it has reviewed Arabic, reviewed
  English, provenance, `content.json`, and `audio.opus`.
- [ ] Start a small reviewed Arabic glossary sample for one integrated lesson.
- [ ] Inspect Yalla English review/practice code and map reusable behavior to
  Arabic review tasks.

## Down the line

- [ ] Install/enable Flutter and Android tooling in this environment.
- [ ] Run `flutter pub get`, `flutter analyze`, `flutter test`, and a debug APK
  build when tooling is available.
- [ ] Decide content rights path: YouTube-derived, teacher-recorded, or mixed.
- [ ] Replace inherited legal/privacy docs before any public release.
- [ ] Decide release identity, Firebase/auth/account model, content hosting, and
  APK/AAB workflow.

## Next: Yalla English reference intake

- [x] Open Yalla English as read-only reference.
- [x] Identify reusable concepts:
  - lesson/player flow
  - transcript highlighting and autoscroll behavior
  - word-definition panel layout/content
  - course/lesson data model
  - build and release workflow, only as later reference
- [ ] Inspect review/practice flows in detail.
- [x] Record first findings in `docs/YALLA_ENGLISH_REFERENCE.md`.
- [ ] Convert review and word-panel findings into Yalla Arabic implementation
  tasks.

## Next: content pipeline

- [x] Document future video/audio/subtitle extraction flow in
  `docs/VIDEO_EXTRACTION_RUNBOOK.md`.
- [x] Confirm source playlist URL.
- [ ] Confirm source ownership/licensing assumptions.
- [x] List playlist videos.
- [x] List videos with usable Arabic subtitles for priority candidates 6, 9, 11,
  and 12.
- [ ] For each candidate video, collect:
  - source URL/id
  - Arabic subtitle file
  - English subtitle file or translation task
  - audio file
  - reviewer status
- [x] For active candidate 6, collect source URL/id, Arabic VTT, English VTT,
  and `.opus` audio in `../content_pipeline/raw/06_-U-cnbFBc9c`.
- [x] Add first VTT-to-lesson draft generator:
  `scripts/build_lesson_from_vtt.py`.
- [ ] Define the app-ready `content.json` validation checklist.
- [x] Add a per-lesson intake tracker under `docs/LESSON_INTAKE.md`.

## Next: Arabic word panel

The inherited word panel is useful inspiration, but Yalla Arabic needs a
language-specific design.

- [ ] Define the Arabic word panel data model:
  - surface word
  - normalized form
  - lemma
  - root
  - pattern/wazn if available
  - part of speech
  - English meaning
  - lesson examples
  - synonyms
  - antonyms
  - related words from the same root
- [ ] Decide what data is manually curated vs generated vs reviewed.
- [x] Document first target spec in `docs/WORD_PANEL_SPEC.md`.
- [x] Document first glossary data contract in `docs/GLOSSARY_SCHEMA.md`.
- [ ] Replace temporary inverted dictionary with a real Arabic lesson glossary.
- [x] Add first Arabic-first glossary slice in `assets/arabic_glossary.json`.
- [x] Update word popup to show the three-part Arabic panel:
  word details, root family, and extra related data.
- [ ] Add tests for Arabic normalization, root grouping, and panel rendering.

## Next: app cleanup and quality

- [ ] Audit inherited English naming that is user-visible or confusing.
- [x] Record current repo-based audit findings in `docs/CODEBASE_MAP.md`.
- [ ] Keep internal package name `ez_english_app` for now unless a planned rename
  is done with full import/build validation.
- [ ] Verify current tests pass on this machine.
- [ ] Run `flutter analyze`.
- [ ] Build a debug APK when Flutter/Android tooling is available.
- [ ] Record validation notes under `reports/` for significant work.

## Later: shipping path

- [x] Track known legal/privacy/content-rights gaps in `docs/LEGAL_TODO.md`.
- [x] Map staged release readiness in `docs/RELEASE_READINESS.md`.
- [ ] Decide release identity and signing strategy.
- [ ] Decide Firebase/auth/account model.
- [ ] Decide content hosting and offline/download strategy.
- [ ] Create APK/release checklist.
- [ ] Test on real Android devices.

## Open questions for the user

1. What is the Yalla English GitHub URL, if we want it recorded in addition to
   the local imported folder?
2. Are the initial lessons meant to be YouTube-derived only, teacher-recorded, or
   a mix?
3. Who will review Arabic transcripts and English translations?
4. Should the first phase stay private/dev-only until the content model is stable?
