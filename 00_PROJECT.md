# Yalla Arabic — Project Definition

Last updated: 2026-07-06

## What this is

**Yalla Arabic** — a Flutter/Dart app for English speakers learning Modern Standard Arabic (Al-Fusha). Private dev shell only. Copied from the Yalla English app and re-flipped.

## Goal

Ship a working, usable Yalla Arabic app deployed live via GitHub Pages with:
- One properly-produced lesson (audio + transcript + tappable word definitions)
- A repeatable content pipeline for adding future lessons
- Auto-deploy on every push to `main`

## Target experience

1. Open a lesson → Arabic audio plays
2. Timestamped Arabic transcript highlights the current sentence line-by-line
3. English translation shown below each Arabic line
4. Tap any Arabic word → panel slides up showing meaning, root, root family, synonyms/antonyms
5. Review/quiz mode reuses lesson vocabulary

## Deployment

- **Primary**: GitHub Pages at `https://genericuniqueness.github.io/yalla-arabic-working-dynamic-repo/`
- **Source repo**: `https://github.com/GenericUniqueness/yalla-arabic-working-dynamic-repo` (public)
- **Source app**: `https://github.com/2ms-muzammil/yalla-arabic-app` (private fork, made public)
- **CI/CD**: GitHub Actions → `deploy-web.yml` (Pages) + `build.yml` (APK)

## Identity

| Field | Value |
|-------|-------|
| App label | Yalla Arabic |
| Android package | `com.yallaarabic.dev` |
| Dart package name | `ez_english_app` (inherited, do NOT rename — breaks imports) |
| Auth | Bypassed (`QaBuildConfig.bypassAuth == true`) |
| Distribution | Private dev only |

## Content

- 3 bundled lessons: course_01/lesson_06, lesson_07, lesson_10
- Source: YouTube videos from `https://www.youtube.com/playlist?list=PLbhGMu9BBf-E`
- Audio: converted to MP3, bundled as assets
- Transcript: bilingual Arabic+English content.json per lesson

## What must NOT change

- Yalla English repo (read-only reference at `../yalla-english-app`)
- About page content
- Package `com.yallaarabic.dev` / label "Yalla Arabic"
- Dart package name `ez_english_app`
- Legal docs, secrets, signing, Firebase config
- Production Firebase, Cloudflare R2, Google Play, signing
