# Yalla Arabic Docs/Spec Baseline

Date: 2026-07-04

## Objective

Establish repo-local documentation and implementation specs that allow useful
Yalla Arabic work to continue without the Yalla English reference repo or the
source Arabic playlist.

## Files added

- `docs/START_HERE.md`
- `docs/WORKING_TASKS.md`
- `docs/YALLA_ENGLISH_REFERENCE.md`
- `docs/DECISIONS_AND_ASSUMPTIONS.md`
- `docs/CODEBASE_MAP.md`
- `docs/VALIDATION_CHECKLIST.md`
- `docs/LESSON_SCHEMA.md`
- `docs/LESSON_INTAKE.md`
- `docs/WORD_PANEL_SPEC.md`
- `docs/VIDEO_EXTRACTION_RUNBOOK.md`
- `docs/GLOSSARY_SCHEMA.md`
- `docs/LEGAL_TODO.md`
- `docs/RELEASE_READINESS.md`
- `docs/TOOLING_AND_MCP_NOTES.md`
- `scripts/validate_lesson_content.py`

## Files updated

- `.gitignore`
- `AGENTS.md`
- `README.md`
- `docs/STATUS.md`
- `docs/REPORT_INDEX.md`
- `docs/START_HERE.md`
- `docs/WORKING_TASKS.md`
- `docs/VALIDATION_CHECKLIST.md`
- `docs/LESSON_SCHEMA.md`

## Repo findings captured

- The app is a Flutter private dev shell with app identity `Yalla Arabic` and
  Android package/applicationId `com.yallaarabic.dev`.
- The internal Dart package name remains `ez_english_app` and should not be
  renamed casually.
- The current catalog registers only `course_01/lesson_07` and
  `course_01/lesson_10`.
- Current lesson parsing is permissive; formal lesson-quality validation is now
  documented in `docs/LESSON_SCHEMA.md` and `docs/VALIDATION_CHECKLIST.md`.
- Current Arabic word lookup is temporary and based on inherited English-keyed
  dictionary data; target replacement is documented in `docs/WORD_PANEL_SPEC.md`.
- The Yalla English repo and source Arabic playlist are still missing inputs.
- A reproducible lesson validator now exists at
  `scripts/validate_lesson_content.py`.

## Validation

Completed:

- Read current app docs and relevant source files.
- Checked `repo links.txt`; Yalla Arabic GitHub URL is present and Yalla English
  is not received yet.
- Confirmed new docs are explicitly unignored in `.gitignore`.
- Confirmed the new docs are linked from `README.md`, `AGENTS.md`,
  `docs/START_HERE.md`, `docs/STATUS.md`, `docs/REPORT_INDEX.md`, and
  `docs/WORKING_TASKS.md`.
- Ran `python scripts/validate_lesson_content.py --report reports/lesson_validation_20260704.md`.
  It passed structurally with 0 errors and 4 warnings:
  - both lessons have `redistribution_permission: not_claimed`
  - both matching `audio.opus` files are missing on disk in this workspace
- Checked extraction tooling:
  - `python` available: `Python 3.14.5`
  - `yt-dlp` available: `2025.09.05`
  - `ffmpeg` available: `2025-11-27-git-61b034a47c`

Not completed:

- `flutter --version` failed because `flutter` is not on PATH in this shell.
- `dart --version` failed because `dart` is not on PATH in this shell.
- Therefore `flutter analyze`, `flutter test`, and APK build were not run.

## Next recommended task

When toolchain access is available, run:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Without toolchain access, the next useful repo-only task is to create a small
sample reviewed glossary asset and tests for the future Arabic word-panel data
model.
