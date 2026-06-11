# Yalla Arabic (private dev shell)

Yalla Arabic is a Flutter Android app for **English speakers learning Modern
Standard Arabic / Al-Fusha**. It is a **private development shell**, not a public
release.

> This repository was copied from the **Yalla English** app and re-flipped for
> Arabic. It is **not** Yalla English. Old Yalla English course content has been
> removed; see `docs/YALLA_ARABIC_REPO_SEPARATION_AUDIT.md`.

## Identity

- App label: **Yalla Arabic**
- Android package / applicationId: **com.yallaarabic.dev**
- Version: see the `version:` line in `pubspec.yaml`
- Distribution: **private dev only** — no Play release, no production signing,
  no public redistribution assumed.

> Note: the internal Dart package name in `pubspec.yaml` is still
> `ez_english_app`. That is an inherited code identifier (used by
> `package:ez_english_app/...` imports) and is intentionally left unchanged to
> avoid breaking imports. It is **not** the app's product identity.

## What the app does today

- Bilingual UI with an English/Arabic language toggle (drives text direction).
- "Main Courses" with two locally bundled Al-Fusha listening lessons.
- Audio player with timestamp-driven transcript highlighting and autoscroll.
- Arabic-primary transcript (RTL) + optional English-secondary translation.
- Vocabulary review (Arabic prompt / English choice dev quiz).
- Temporary clickable Arabic vocabulary lookup (dev scaffolding — see below).
- Auth / Firebase / onboarding intentionally bypassed for dev
  (`QaBuildConfig.bypassAuth => true`; `home:` goes straight to `HomeScreen`).

## Current content (the only bundled lessons)

- `assets/courses/course_01/lesson_07/main_story/` — content.json + audio.opus
- `assets/courses/course_01/lesson_10/main_story/` — content.json + audio.opus

These are the **only** course assets bundled into the APK (see
`docs/ASSET_POLICY.md`). They are registered in `lib/data/courses_data.dart`.

## Key docs

- `docs/ARCHITECTURE.md` — app shell + content/player architecture.
- `docs/ASSET_POLICY.md` — exactly what is bundled and why.
- `docs/CONTENT_PIPELINE.md` — how lessons are produced and how to add more.
- `docs/STATUS.md` — what works, what is disabled, next steps.
- `docs/YALLA_ARABIC_REPO_SEPARATION_AUDIT.md` — Yalla English separation audit.
- `docs/REPORT_INDEX.md` — where Yalla Arabic reports live.
- `AGENTS.md` — operating rules for Codex/Claude work in this repo.

## Repos & folders

- **This app repo (modify here):**
  `/Users/m/Desktop/YallaArabic_PROJECT_HOME/01_ACTIVE_APP_REPO/yalla_arabic_working`
- **Content pipeline:**
  `/Users/m/Desktop/YallaArabic_PROJECT_HOME/03_CONTENT_SOURCES/youtube_teacher_pilot`
- **Yalla English production repo — READ-ONLY reference, never modify:**
  `/Users/m/Desktop/YallaEnglish_PROJECT_HOME/01_ACTIVE_APP_REPO/yalla_english_working`

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug                 # universal / fat APK
flutter build apk --debug --split-per-abi  # per-ABI APKs
```

## Safety

- Never modify the Yalla English repo (read-only reference only).
- Do not copy Yalla English course JSON/audio back into this repo.
- Do not wire up production Firebase, signing, Cloudflare R2, or Google Play.
- Keep the Android package `com.yallaarabic.dev` and label "Yalla Arabic".
- Do not change the About page content.
