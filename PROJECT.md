# Yalla Arabic — Project Technical Reference

Last updated: 2026-06-11

> Private dev shell. This is **Yalla Arabic**, not Yalla English.

## Current Status

| Area | State |
| --- | --- |
| App label | Yalla Arabic |
| Android package / applicationId | `com.yallaarabic.dev` |
| Internal Dart package name (`pubspec.yaml` `name:`) | `ez_english_app` (inherited code id; do not rename — breaks imports) |
| Purpose | English speakers learning Modern Standard Arabic / Al-Fusha |
| Distribution | Private dev only — no Play, no signing, no R2, no public release |
| Auth | Bypassed for dev (`QaBuildConfig.bypassAuth => true`) |
| Bundled content | 2 local lessons: `course_01/lesson_07` + `course_01/lesson_10` |
| Origin | Copied from the Yalla English app and re-flipped for Arabic |

## Tech Stack

| Layer | Technology |
| --- | --- |
| UI framework | Flutter / Dart |
| State management | Provider / ChangeNotifier |
| Audio playback | just_audio + audio_service (background) |
| Local prefs/cache | shared_preferences, path_provider, custom cache services |
| Firebase deps | present in `pubspec.yaml` but auth/login bypassed for dev |

## Source Layout

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | Entry point, provider/audio wiring; routes to `HomeScreen` (auth bypassed) |
| `lib/data/courses_data.dart` | Course/lesson catalog — only the 2 Arabic lessons |
| `lib/models/` | Course, lesson, sentence, review models |
| `lib/providers/` | App state providers |
| `lib/services/` | Audio, cache, content config, word-definition, review, etc. |
| `lib/screens/` | App screens (home, player, review, settings/about, ...) |
| `lib/l10n/` | Bilingual UI strings |
| `assets/courses/course_01/lesson_07,10/` | The two bundled Arabic lessons |
| `assets/word_definitions.json` | Inherited bilingual dictionary, reused as temporary Arabic-vocab lookup |
| `assets/grammar/` | Bundled grammar content |
| `assets/images/`, `assets/branding/` | Bundled images/icons |
| `reports/` | Yalla Arabic validation reports (English-era reports were removed) |

## Content & Assets

- Content paths are derived from course/lesson IDs:
  `assets/courses/course_<NN>/lesson_<NN>/<type>/content.json` (+ `audio.mp3`).
- Only the two Arabic lessons are declared in `pubspec.yaml` and bundled in the
  APK. See `docs/ASSET_POLICY.md`.
- Old Yalla English courses (`course_02`…`course_09`) were deleted from this
  copy; the originals remain in the read-only Yalla English repo. See
  `docs/YALLA_ARABIC_REPO_SEPARATION_AUDIT.md`.

## Reference Docs

- Architecture: `docs/ARCHITECTURE.md`
- Asset policy: `docs/ASSET_POLICY.md`
- Content pipeline: `docs/CONTENT_PIPELINE.md`
- Status: `docs/STATUS.md`
- Separation audit: `docs/YALLA_ARABIC_REPO_SEPARATION_AUDIT.md`
- Agent rules: `AGENTS.md`

## Change Discipline

- Keep edits focused and small.
- Do not restore login/Firebase/onboarding.
- Do not change About page content.
- Do not re-introduce broad `assets/courses/` bundling.
- Do not modify the Yalla English repo.
