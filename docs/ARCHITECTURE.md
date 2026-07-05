# Architecture

Last updated: 2026-06-11 — **Yalla Arabic** (private dev shell).

## Overview

Yalla Arabic is a Flutter/Dart Android app for English speakers learning Modern
Standard Arabic / Al-Fusha. The app shell is reused from the Yalla English app
and re-flipped: Arabic is now the primary language, English the secondary
translation. It runs as a private dev build with login/onboarding bypassed.

## App shell (reused from Yalla English)

- `lib/main.dart` — entry point, Provider wiring, audio service init. Routes
  straight to `HomeScreen` because auth is bypassed (`QaBuildConfig.bypassAuth`).
- `lib/providers/` — app state (settings/language, downloads, etc.) via
  Provider/ChangeNotifier.
- `lib/screens/` — home, lesson list, player, review, settings/about.
- `lib/l10n/` — bilingual UI strings; the language toggle drives `MaterialApp`
  `Directionality` (RTL for Arabic).

## Course / lesson catalog

- `lib/data/courses_data.dart` defines the catalog. It currently contains a
  single course ("Main Courses") with two lessons (ids 7 and 10).
- Firestore is **not** the source of truth for the catalog; it is hardcoded.

## Local bundled content loading

- Content paths are derived from course/lesson ids:
  `assets/courses/course_<NN>/lesson_<NN>/<type>/content.json` and `audio.mp3`
  (see `player_screen.dart` and `download_provider.dart`).
- Content JSON is loaded from the app bundle via `rootBundle.loadString(...)`
  (`audio_handler.dart`). Because only the two Arabic lessons are declared in
  `pubspec.yaml`, only they are loadable; nothing else is in the bundle.
- `lib/services/content_source_config.dart` holds remote/override config
  (Cloudflare R2 base URL + debug-only local fixture overrides). For the bundled
  dev lessons this remote path is not used; it is inherited config kept for
  parity and debug tooling only.

## Audio player & transcript

- Playback via `just_audio` + `audio_service` (background/lock-screen).
- `content.json` root is an object with a `sentences[]` array; each sentence
  carries Arabic text, English translation, and start/end timestamps.
- The player highlights the active sentence by timestamp and autoscrolls.
  Arabic is rendered primary (RTL, right-aligned, larger); English is secondary
  (LTR), gated by `settings.showArabicTranslation`.

## Review system

- `lib/services/review_question_builder.dart` builds a dev quiz (Arabic prompt /
  English choice) with distractors; review screens are reused from the shell.

## Temporary clickable Arabic vocabulary (dev scaffolding)

- `lib/services/word_definition_service.dart` builds an **inverted** lookup
  (Arabic surface → English headword/meaning) from the inherited
  `assets/word_definitions.json` (an English-keyed dictionary reused only as a
  temporary dev lookup — no old English lessons/audio are used).
- Matching strips tashkeel/tatweel, folds alef/hamza, requires Arabic-letter
  word boundaries, prefers longest phrases, and applies a function-word
  blocklist. Tapped words open `WordDefinitionOverlay` with a "Temporary dev
  vocabulary" badge. Unmatched words fall back to plain text and never crash.
- This is **not** a real Arabic dictionary/morphology engine; see `docs/STATUS.md`.

## Settings / language toggle

- The English/Arabic toggle controls UI language and text direction across the
  app. About content is bilingual and is preserved verbatim — do not edit it.

## Disabled for dev

- Firebase auth, Google Sign-In, email verification, and onboarding are bypassed.
  Firebase deps remain in `pubspec.yaml` but no production Firebase is wired.

## Content pipeline (separate folder)

- Lesson source production (caption cleaning, English alignment, app-ready
  JSON/audio generation, validation) lives in the pipeline folder, not in this
  repo. See `docs/VIDEO_EXTRACTION_RUNBOOK.md`.

## Identity

- App label: **Yalla Arabic**; Android package/applicationId:
  `com.yallaarabic.dev` (`android/app/build.gradle.kts`,
  `android/app/src/main/AndroidManifest.xml`).
- Internal Dart package name remains `ez_english_app` (inherited; do not rename).
