# Content Pipeline

Last updated: 2026-06-11 — **Yalla Arabic** (private dev shell).

The app repo contains only finished, bundled lessons. Lesson **production**
happens in a separate pipeline folder:

`/Users/m/Desktop/YallaArabic_PROJECT_HOME/03_CONTENT_SOURCES/youtube_teacher_pilot`

## Pipeline folder (not in this repo)

- `scripts/` — Python tooling: playlist inspection, caption download/cleaning,
  English alignment, app-ready JSON/audio generation, validation, report writers.
- `metadata/`, `captions_raw/`, `captions_clean/`, `audio_opus/`, `app_ready/` —
  working stages.
- `reports/` — the **authoritative Yalla Arabic pipeline reports**, e.g.
  `POST_INTEGRATION_QA_AND_CLICKABLE_VOCAB_REPORT.md`, `QA_FINDINGS.md`,
  `PIPELINE_STATE.json`, `NEXT_CODEX_CONTINUATION.md`, `LOCAL_FILE_INVENTORY.*`.

## Current state

- 2 of 12 playlist videos integrated (videos 7 & 10). The rest lacked usable
  public Arabic captions and were skipped.
- Lessons are Arabic-primary with per-line English alignment and timestamps.

## Lesson content schema (`content.json`)

Root is an object with a `sentences[]` array. Each sentence carries Arabic text,
English translation, and `start`/`end` timestamps (seconds). Timestamps must be
monotonic with no overlaps and no zero/negative durations. One `content.json`
plus one `audio.opus` per lesson/type folder (e.g. `main_story/`).

## Resuming the pipeline

1. Read the latest pipeline reports (above), especially
   `NEXT_CODEX_CONTINUATION.md` and `PIPELINE_STATE.json`.
2. Do not use cookies/proxies/anti-blocking or retry YouTube on bot/CAPTCHA.
3. Missing English captions are not a blocker; missing Arabic captions = skip
   that video.

## Adding more lessons later (manual local files)

1. Supply local human Arabic + English caption files for the video.
2. Run the existing clean → align → build → validate scripts in the pipeline.
3. Copy the generated `content.json` + `audio.opus` into
   `assets/courses/course_01/lesson_<NN>/main_story/` in this repo.
4. Register the lesson in `lib/data/courses_data.dart`.
5. Add the two explicit asset lines in `pubspec.yaml` (see `docs/ASSET_POLICY.md`).
6. Run `flutter analyze`, `flutter test`, and a debug APK build; verify the new
   lesson is bundled and no `course_02..09` entries appear.

## Future direction

- Replace YouTube-sourced lessons with purpose-recorded Al-Fusha audio.
- Replace the temporary inverted dictionary with a real Arabic→English lesson
  glossary before any real release.
