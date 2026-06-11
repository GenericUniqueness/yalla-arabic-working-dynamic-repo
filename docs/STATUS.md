# Status

Last updated: 2026-06-11 — **Yalla Arabic** (private dev shell).

## Identity

- App label: Yalla Arabic
- Android package / applicationId: `com.yallaarabic.dev`
- Distribution: private dev only (no Play, no signing, no R2, no public release)

## What works now

- Bilingual UI + English/Arabic language toggle (RTL when Arabic).
- "Main Courses" with two locally bundled Al-Fusha lessons:
  - `course_01/lesson_07` — "Easy Arabic Podcast | about Social Media"
  - `course_01/lesson_10` — "Arabic Conversation for Beginners #2 | The Family"
- Audio playback with timestamp-driven transcript highlight + autoscroll.
- Arabic-primary transcript, English-secondary translation.
- Vocabulary review (dev quiz).
- Temporary clickable Arabic vocabulary lookup over the transcript.
- About page (bilingual, preserved verbatim).

## What is intentionally disabled

- Login / Firebase auth / Google Sign-In / email verification (`bypassAuth`).
- Onboarding tour gating.
- Production Firebase, Cloudflare R2 streaming, Google Play release, signing.

## What must not be touched

- The Yalla English repo (read-only reference).
- About page content.
- Package id `com.yallaarabic.dev` / label "Yalla Arabic".
- The internal Dart package name `ez_english_app` (renaming breaks imports).
- `assets/word_definitions.json` without a reviewed preview + validation.
- Legal docs (`docs/privacy_policy.*`) and any secrets/signing/Firebase config.

## Known limitations

- Only 2 of 12 source playlist videos are integrated (videos 7 & 10); the others
  lacked usable public Arabic captions.
- Clickable Arabic vocabulary is **temporary dev scaffolding** (exact/normalized
  matching, no morphology); some matches can be context-imperfect.
- Lesson 07 has some long transcript lines (readable but dense); not split, to
  preserve highlight timing (no safe intra-line timestamps).
- No emulator/device playback test recorded; verification is static analyze +
  tests + APK build.

## Next steps

- **Full playlist:** for remaining videos, supply local human Arabic + English
  caption files, run the pipeline (clean/align/build/validate), add lessons
  under `course_01`, register them in `courses_data.dart`, and extend the
  `pubspec.yaml` asset lines explicitly. See `docs/CONTENT_PIPELINE.md`.
- **Real Yasir-recorded content:** replace YouTube-sourced lessons with
  purpose-recorded Al-Fusha audio + timestamps captured at recording time.
- **Full Arabic word panel:** replace the inverted English dictionary with a
  purpose-built Arabic→English lesson glossary (with morphology) before any real
  release.
