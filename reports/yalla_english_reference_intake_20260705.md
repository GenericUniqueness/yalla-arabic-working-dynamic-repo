# Yalla English Reference Intake

Date: 2026-07-05

## Scope

First read-only intake of the imported `../yalla-english-app` reference repo for
Yalla Arabic planning. No Yalla English files were edited.

## Findings

- The English reference repo is present locally at `../yalla-english-app`.
- The root `../repo links.txt` still lists only the Yalla Arabic GitHub URL and
  says `English: // not recieved yet`.
- No Arabic source playlist URL was found in `../repo links.txt` or a workspace
  text search.
- Yalla English is a mature Flutter/Dart Android app with:
  - hardcoded course/lesson definitions in Dart
  - timestamped bilingual lesson JSON
  - audio queue playback
  - transcript highlight and autoscroll
  - download/offline support
  - word definition overlay
  - review/progress flows
- English docs record 537 active JSON/audio mappings in the external
  audio/content master.
- The local English repo contains more `content.json` files than the active
  mapping count, so local JSON count should not be treated as release-active
  without checking English repo docs/reports.

## Yalla Arabic Implications

- Keep the inherited course/lesson/sentence model for now.
- Reuse the high-level player pattern: queue, timestamp highlight, autoscroll,
  speed controls, repeat/shadowing, and download/offline state.
- Redesign the word panel around Arabic morphology instead of English inflection:
  surface form, normalization, lemma, root, pattern, examples, synonyms,
  antonyms, and root family.
- Transfer English repo operational discipline: reports, validation, explicit
  asset policy, generated artifact hygiene, and secret handling.
- Do not copy English lessons, audio, production package identity, signing,
  Firebase setup, or release workflow into Yalla Arabic.

## Docs Updated

- `docs/YALLA_ENGLISH_REFERENCE.md`
- `docs/START_HERE.md`
- `docs/WORKING_TASKS.md`
- `docs/LESSON_INTAKE.md`
- `docs/TOOLING_AND_MCP_NOTES.md`
- `docs/STATUS.md`
- `docs/REPORT_INDEX.md`

## Validation

No Flutter validation was run in this pass. Prior tool status still applies:
Flutter and Dart were not available on PATH in this shell.

Correction later on 2026-07-05: the user provided the Arabic playlist URL in
chat, and it has now been recorded in `../repo links.txt`:

`https://www.youtube.com/playlist?list=PLbhGMu9BBf-E`

See `reports/yalla_arabic_playlist_intake_20260705.md` for the playlist intake.
