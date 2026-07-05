# Yalla Arabic — Working Dynamic Repo

Yalla Arabic is a Flutter Android app for **English speakers learning Modern
Standard Arabic / Al-Fusha**. This is a **private working fork** — builds,
progress, and development kept entirely separate from the original.

> **Origin:** Forked from [`2ms-muzammil/yalla-arabic-app`](https://github.com/2ms-muzammil/yalla-arabic-app).
> We copied Muzzamil's repo to work independently until the feature/branch is
> complete, then we can decide how to merge back. Separate repo = clean builds,
> isolated progress, no interference.

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

- `assets/courses/course_01/lesson_06/main_story/` — content.json + audio.opus
- `assets/courses/course_01/lesson_07/main_story/` — content.json + audio.opus
- `assets/courses/course_01/lesson_10/main_story/` — content.json + audio.opus

These are the **only** course lesson paths intended for bundled APK testing (see
`docs/ASSET_POLICY.md`). They are registered in `lib/data/courses_data.dart`.

## Key docs

- `docs/START_HERE.md` - first file for new agents/devs; product goal + read order.
- `docs/WORKING_TASKS.md` - living backlog, next actions, and open questions.
- `docs/ROADMAP.md` - immediate, foundation, and long-term project direction.
- `docs/ARCHITECTURE.md` — app shell + content/player architecture.
- `docs/ASSET_POLICY.md` — exactly what is bundled and why.
- `docs/VIDEO_EXTRACTION_RUNBOOK.md` — how lessons are produced and how to add more.
- `docs/STATUS.md` — what works, what is disabled, next steps.
- `docs/YALLA_ENGLISH_REFERENCE.md` - read-only Yalla English reference notes.
- `docs/DECISIONS_AND_ASSUMPTIONS.md` - durable product/technical assumptions.
- `docs/CODEBASE_MAP.md` - current source map and repo audit notes.
- `docs/VALIDATION_CHECKLIST.md` - checks to run by change type.
- `docs/LESSON_SCHEMA.md` - app-ready content JSON/audio contract.
- `docs/LESSON_INTAKE.md` - source video/audio intake tracker.
- `docs/WORD_PANEL_SPEC.md` - Arabic-first word panel target spec.
- `docs/VIDEO_EXTRACTION_RUNBOOK.md` - future video/audio/subtitle extraction flow.
- `docs/GLOSSARY_SCHEMA.md` - future Arabic glossary data contract.
- `docs/LEGAL_TODO.md` - legal/privacy/content-rights checklist.
- `docs/RELEASE_READINESS.md` - staged APK/release readiness map.
- `docs/TOOLING_AND_MCP_NOTES.md` - local tooling and MCP expectations.
- `docs/FIXES.md` - known issues, fixes, and follow-up corrections.
- `docs/YALLA_ARABIC_REPO_SEPARATION_AUDIT.md` — Yalla English separation audit.
- `docs/REPORT_INDEX.md` — where Yalla Arabic reports live.
- `AGENTS.md` — operating rules for Codex/Claude work in this repo.

## Repos & links

- **This working dynamic repo:** `https://github.com/GenericUniqueness/yalla-arabic-working-dynamic-repo`
- **Original Muzzamil repo (source):** `https://github.com/2ms-muzammil/yalla-arabic-app`
- **Muzzamil's GitHub profile:** `https://github.com/2ms-muzammil`

> See `repo_links.txt` for quick-copy URLs.

## Why a separate repo?

We cloned/copied Muzzamil's `yalla-arabic-app` into its own private GitHub repo
so that all builds, CI, commits, and feature work stay **completely isolated**
from the original. Once we're done (or ready to merge back), we can reconcile.
Until then: two separate repos, two separate build streams, zero cross-contamination.

## Local paths (dev machine reference)

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
