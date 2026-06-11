# AGENTS.md

Operating rules for Codex/Claude working in the **Yalla Arabic** private dev
shell. Keep work small, safe, and clearly Arabic-focused.

## What this repo is

- **Yalla Arabic**, a Flutter Android app for English speakers learning Modern
  Standard Arabic / Al-Fusha. Private dev shell only.
- Android package `com.yallaarabic.dev`, label "Yalla Arabic".
- Copied from the Yalla English app and re-flipped. It is **not** Yalla English.
- Source of truth for state: `docs/STATUS.md`. Architecture: `docs/ARCHITECTURE.md`.

## Hard rules

1. **Never modify the Yalla English repo.** It is read-only reference only:
   `/Users/m/Desktop/YallaEnglish_PROJECT_HOME/01_ACTIVE_APP_REPO/yalla_english_working`
2. Do not copy Yalla English course JSON/audio/lessons into this repo.
3. Do not re-add broad `assets/courses/` bundling — bundle only explicit lessons.
4. Do not restore login / Firebase auth / onboarding (dev keeps `bypassAuth`).
5. Do not change the About page content.
6. Keep package `com.yallaarabic.dev` and label "Yalla Arabic".
7. Do not wire up or touch production Firebase, signing/keystores, Cloudflare R2,
   Google Play, legal/support sites, or any secrets.
8. Do not break the two current Arabic lessons (`course_01/lesson_07`, `lesson_10`).
9. Do not delete large folders blindly; prefer audit/report first.

## Operating workflow

- Inspect the repo and relevant docs/reports before changing code or content.
- Prefer small, stable changes over broad refactors.
- For content/code changes, run the smallest meaningful validation and record a
  Markdown report under `reports/` for important work.
- Do not print secrets, API keys, OAuth client IDs, keystore passwords, or
  Firebase private values in chat, logs, reports, or diffs.

## Protected / do-not-touch files

- `android/key.properties`, `android/app/upload-keystore.jks` (if present)
- `android/app/google-services.json`, `lib/firebase_options.dart` (if present)
- `.env` files, any Firebase config downloads
- `docs/privacy_policy.md` / `.html` (legal text)
- About page content in `lib/screens/settings/about_screen.dart`

## Validation expectations

- Standard checks: `flutter pub get`, `flutter analyze`, `flutter test`,
  `flutter build apk --debug` (and `--split-per-abi`).
- Confirm after changes: package is `com.yallaarabic.dev`, label is
  "Yalla Arabic", only the 2 Arabic lessons are bundled, old English courses are
  neither bundled nor registered.
