# Yalla Arabic — Repo Separation Audit

Audit date: 2026-06-11. Repo:
`/Users/m/Desktop/YallaArabic_PROJECT_HOME/01_ACTIVE_APP_REPO/yalla_arabic_working`

This repo was copied from the Yalla English app and re-flipped for Arabic. This
audit records the Yalla English leftovers that were found and what was done.

## Summary confirmations

- ✅ Original Yalla English repo **unchanged** (read-only inspection only): it is
  still a clean git tree with all 537 course JSON files and 486 reports.
- ✅ Old Yalla English courses are **not visible** in the app (only course 1,
  lessons 7 & 10 are registered in `lib/data/courses_data.dart`).
- ✅ Old Yalla English course assets are **not broadly bundled** — `pubspec.yaml`
  lists only the 2 Arabic lesson paths; there is no broad `assets/courses/`.
- ✅ The APK uses **only** the Yalla Arabic local lessons (`course_01/lesson_07`,
  `course_01/lesson_10`).
- ✅ Identity preserved: package `com.yallaarabic.dev`, label "Yalla Arabic".

## Leftovers found and disposition

| Leftover | Was it visible / bundled? | Action |
| --- | --- | --- |
| `assets/courses/course_02`…`course_09` (≈530 English `content.json`) | On disk + git-tracked; **not** bundled, **not** registered | **Deleted** from this repo (duplicated in read-only English repo + git history) |
| `assets/courses/course_01/rule_1..7` English JSON | Tracked, already removed from worktree | Deletion staged |
| `reports/` (≈2083 tracked English production reports) | Tracked; misleading provenance | **Deleted** (3 untracked `yalla_arabic_*` reports kept) |
| `README.md`, `PROJECT.md`, `AGENTS.md` | Described Yalla English production | **Rewritten** for Yalla Arabic |
| `docs/ARCHITECTURE.md`, `docs/STATUS.md`, `docs/REPORT_INDEX.md` | Yalla English content | **Rewritten** for Yalla Arabic |
| `docs/ASSET_RECOVERY.md` (English audio/content master recovery) | Misleading for dev shell | **Deleted** |
| `docs/RELEASE_RUNBOOK.md` (English Play/AAB/signing release) | Misleading for dev shell | **Deleted** |
| `docs/firebase_signing_owner_actions.md` (English signing stub) | Misleading | **Deleted** |
| `docs/current_architecture.md`, `docs/current_project_status.md` (superseded English stubs) | Misleading | **Deleted** |
| `pubspec.yaml` `name: ez_english_app` | Internal Dart package id (used by 4 `package:` imports) | **Kept** intentionally — renaming breaks imports; documented as non-identity |
| `lib/services/content_source_config.dart` R2 base URL + course_05 fixture map | Debug-only; not used by bundled lessons | **Kept** — inherited debug config, not bundled, harmless |
| `docs/privacy_policy.md` / `.html` | Legal text | **Kept untouched** (legal; out of scope) |
| Android Kotlin path `.../kotlin/com/yallaenglish/app/MainActivity.kt` | Cosmetic source path only | **Kept** — applicationId/namespace are already `com.yallaarabic.dev`; moving the file is risk without benefit |

## What was cleaned (file operations)

- `git rm -r assets/courses/course_02 … course_09` (English course JSON).
- Staged deletion of `assets/courses/course_01/rule_*`.
- `git rm` of all tracked files under `reports/` (English production reports),
  preserving the 3 untracked `yalla_arabic_*` reports.
- `git rm` of `docs/ASSET_RECOVERY.md`, `docs/RELEASE_RUNBOOK.md`,
  `docs/firebase_signing_owner_actions.md`; `rm` of the two superseded
  `docs/current_*.md` stubs.
- Rewrote `README.md`, `PROJECT.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`,
  `docs/STATUS.md`, `docs/REPORT_INDEX.md`.
- Added `docs/ASSET_POLICY.md`, `docs/CONTENT_PIPELINE.md`, this audit, and
  `.gitignore` whitelist updates for the new tracked docs.

## What was left intentionally (and why)

- `pubspec.yaml` `name: ez_english_app` — internal code identifier; renaming
  would break `package:ez_english_app/...` imports in the source. App identity
  (package id + label) is already correct.
- `content_source_config.dart` inherited R2/fixture config — debug-only, not used
  by the bundled dev lessons; removing it risks breaking debug tooling for no
  bundle-size or correctness gain.
- Firebase dependencies in `pubspec.yaml` — present but auth is bypassed; removing
  them is a larger refactor outside this cleanup's safe scope.
- Legal/privacy docs — out of scope per safety rules.

## Remaining risks / future cleanup TODOs

- Internal package name `ez_english_app` is cosmetically English; a future,
  carefully-tested rename could align it, but it is not required and is risky.
- Kotlin package folder `com/yallaenglish/app/` is cosmetic; could be migrated to
  `com/yallaarabic/dev/` with manifest/Gradle care if ever desired.
- Firebase dependencies remain unused-but-present; could be trimmed later.
- The clickable Arabic vocabulary reuses the English-keyed dictionary as a
  temporary inverted lookup; replace with a real Arabic glossary before release.

## Verification commands

```bash
# identity
grep -nE 'applicationId|namespace' android/app/build.gradle.kts   # com.yallaarabic.dev
grep -n 'android:label' android/app/src/main/AndroidManifest.xml  # Yalla Arabic
# no broad course bundling; only 2 lessons
grep -n 'assets/courses' pubspec.yaml
# only 2 lessons on disk
ls assets/courses/course_01                                       # lesson_07 lesson_10
# clean APK
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep -c 'course_0[2-9]'  # 0
```
