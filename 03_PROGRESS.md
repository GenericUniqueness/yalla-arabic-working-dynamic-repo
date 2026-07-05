# Progress

Last updated: 2026-07-06

## Completed

### Phase 0 — Get app usable on web (DONE)

| Task | Status | Commit |
|------|--------|--------|
| Fix `scrollCacheExtent` (deprecated API) | ✅ done | `c9b9280` |
| Fix `_checkOnline()` for web (dart:io crash) | ✅ done | `4e76fb0` |
| Add web platform support (`flutter create --platforms=web`) | ✅ done | `187d3d8` |
| Add GitHub Actions workflows (APK build + web deploy) | ✅ done | `8a71d8d` |
| Fix pubspec.yaml missing audio references | ✅ done | `d6601a2` |
| Download lesson 7 audio from YouTube (`Mq51rklpGog`) | ✅ done | `5c6b3f8` |
| Download lesson 10 audio from YouTube (`lfPrnUZ4osQ`) | ✅ done | `5c6b3f8` |
| Bundle all 3 lessons audio + content.json | ✅ done | `5c6b3f8` |
| Re-encode audio to 32kbps opus (attempt) | ✅ done, reverted | `a65f4f1` |
| Switch audio from opus to MP3 (fixes web MIME issue) | ✅ done | `6cdacaa` |
| Mark all Phase 0 tasks done in MASTER_PLAN.md | ✅ done | `b9a218c` |
| Verify MP3 audio assets in deployed build | ✅ done | `AssetManifest.bin` confirmed |
| Fix stale `audio.opus` refs in docs/ (33 matches, 15 files) | ✅ done | this session |
| Fix stale `audio.opus` refs in lib/ code files | ✅ done | this session |
| `flutter analyze` passes after opus→mp3 code cleanup | ✅ done | 0 errors, 23 info |

### Infrastructure (DONE)

| Item | Status |
|------|--------|
| GitHub repo created and public | ✅ |
| GitHub Pages enabled | ✅ |
| GitHub Actions CI/CD (APK + web deploy) | ✅ |
| Flutter SDK 3.44.4 installed | ✅ |
| `flutter pub get` passes | ✅ |
| `flutter analyze` passes (0 errors) | ✅ |

## Current state

- **Deployed URL**: `https://genericuniqueness.github.io/yalla-arabic-working-dynamic-repo/`
- **Latest commit**: `4175345` — Phase 1 improvements
- **Deploy status**: Pending (need to push after commit)
- **3 bundled lessons**: lesson_06 (435 sentences), lesson_07 (241 sentences), lesson_10 (49 sentences)
- **155 glossary entries** across all 3 lessons
- **19 roots** in centralized root dictionary
- **`flutter analyze`**: 0 errors, 0 warnings

## Phase 1 — COMPLETE

| Task | Status |
|------|--------|
| Audio plays on deployed URL | ✅ assets confirmed in manifest |
| Transcript text shows in UI | ✅ should work now that audio loads (error-state hiding was the blocker) |
| Word panel opens on tap | needs user verification on deployed URL |
| Sentence breaking at natural moments | ✅ done — content.json entries split at sentence boundaries (lesson_06: 232→435, lesson_07: 108→241, lesson_10: 31→49) |
| Root word system design + implementation | ✅ done — `assets/roots.json` + `lib/services/root_service.dart` + `WordDefinitionService.getWordFamily()` |
| Definition window population (per-word data) | ✅ done — glossary expanded from 19→155 entries (136 new auto-generated) |
| Definition window UI/UX improvement | ✅ done — redesigned overlay with accent strip, detail chips, example cards, root family cards |
| Lesson 6 glossary expansion (19 → 60-100+ entries) | ✅ done — 155 total entries across all 3 lessons |

## Blocked

| Item | Blocker |
|------|---------|
| Real device/emulator testing | No emulator (CPU), no phone |
| Content redistribution_permission | `not_claimed` — legal review needed |
