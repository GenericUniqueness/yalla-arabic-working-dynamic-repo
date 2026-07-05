# Context

Last updated: 2026-07-05

## Environment

- **Machine**: Windows desktop (user: freel)
- **No physical Android phone** — emulator blocked by CPU/Hyper-V. Web (Edge) is the primary dev target.
- **Flutter SDK**: 3.44.4 stable at `C:\tools\flutter\bin\flutter.bat`
- **yt-dlp**: available via `python -m yt_dlp` (v2026.07.04)
- **ffmpeg**: available for audio conversion

## Available MCPs

The following MCP servers are connected and should be used proactively:

| MCP | Use for |
|-----|---------|
| `context7` | Fetching up-to-date library/framework docs (Flutter, just_audio, etc.) |
| `github` | Repo operations: issues, PRs, file contents, search |
| `memory` | Persistent knowledge graph across sessions |
| `playwright` | Browser interaction, testing UI, screenshots |
| `sequential-thinking` | Multi-step reasoning and problem-solving |

**Do not ask the user** whether to use these — just use them when relevant. If an MCP call fails or isn't available, fall back to other tools.

## What was built

Phase 0 is complete: the app runs on web, all 3 lessons have bundled audio + transcript, and it deploys to GitHub Pages.

### Audio verification (2026-07-05)

- `AssetManifest.bin` on the deployed URL confirms all 3 `audio.mp3` files are bundled.
- `flutter analyze` passes (0 errors, 23 info-level lint warnings).
- The audio loading code path for Course 1 goes through `_player.setAsset()` which works on Flutter web.
- The transcript was previously hidden when audio failed; now that audio loads, the transcript should render.

### Key source of truth files

| File | Purpose |
|------|---------|
| `lib/screens/lessons/player_screen.dart` | Lesson player UI, transcript rendering, word taps |
| `lib/services/audio_handler.dart` | Audio loading chain (local → R2 → bundled asset) |
| `lib/providers/download_provider.dart` | Audio path construction |
| `lib/data/courses_data.dart` | Hardcoded course/lesson catalog |
| `lib/services/content_source_config.dart` | R2 base URL, content source config |
| `lib/services/word_definition_service.dart` | Arabic word matching/lookup |
| `lib/screens/lessons/word_definition_overlay.dart` | Word definition popup UI |
| `assets/arabic_glossary.json` | 19 draft entries for lesson 6 |
| `assets/word_definitions.json` | Inherited English dictionary (fallback) |

### Content files

| Path | Content |
|------|---------|
| `assets/courses/course_01/lesson_06/main_story/content.json` | Lesson 6 transcript (32 min) |
| `assets/courses/course_01/lesson_06/main_story/audio.mp3` | Lesson 6 audio (14.77 MB, 64kbps mono) |
| `assets/courses/course_01/lesson_07/main_story/content.json` | Lesson 7 transcript (25 min) |
| `assets/courses/course_01/lesson_07/main_story/audio.mp3` | Lesson 7 audio (11.66 MB, 64kbps mono) |
| `assets/courses/course_01/lesson_10/main_story/content.json` | Lesson 10 transcript (3 min) |
| `assets/courses/course_01/lesson_10/main_story/audio.mp3` | Lesson 10 audio (1.75 MB, 64kbps mono) |

### Correct YouTube video IDs

(MASTER_PLAN.md had wrong IDs)

| Lesson | YouTube ID | Title |
|--------|-----------|-------|
| 7 | `Mq51rklpGog` | Easy Arabic Podcast about Social Media |
| 10 | `lfPrnUZ4osQ` | Arabic Conversation for Beginners #2 The Family |

## Audio loading chain (critical)

In `audio_handler.dart:136-157`, audio loads in this priority:
1. `localFilePath` → `_player.setFilePath()` (production cache, dart:io)
2. `remotePath.isNotEmpty` → `_player.setUrl()` (Cloudflare R2 stream)
3. Fallback → `_player.setAsset()` (bundled asset)

In `player_screen.dart:268`: `remotePath: lesson.courseId == 1 ? '' : assetPath`
This forces Course 1 to ALWAYS use bundled assets (tier 3). This is intentional for local dev.

## Content.json schema

Each lesson has a `content.json` with:
```json
{
  "sentences": [
    {
      "arabic": "مرحبا بكم في حلقة جديدة",
      "english": "Welcome to a new episode",
      "start_ms": 0,
      "end_ms": 3500
    }
  ]
}
```

## Key constraints

- Audio MUST be MP3 format for web (not opus — GitHub Pages doesn't serve opus with correct MIME type)
- Total bundled audio ~28MB across 3 lessons
- No emulator/device testing possible — verification is via static analyze + web deploy
- Content redistribution_permission is `not_claimed` — not release-ready

## Detailed docs folder

The `docs/` folder contains 27 detailed project files written by prior sessions. These are the **canonical detailed reference** for architecture, specs, and pipeline work:

| File | Purpose |
|------|---------|
| `docs/START_HERE.md` | Fastest orientation path for new agents |
| `docs/WORKING_TASKS.md` | Living task board (supersedes stale backlogs) |
| `docs/STATUS.md` | Current working/disabled/limited areas |
| `docs/ARCHITECTURE.md` | App architecture (reuses Yalla English shell) |
| `docs/CODEBASE_MAP.md` | Source layout, audit findings, file inventory |
| `docs/VALIDATION_CHECKLIST.md` | Checks to run by change type |
| `docs/LESSON_SCHEMA.md` | App-ready lesson content contract |
| `docs/LESSON_INTAKE.md` | Source/video lesson tracker template |
| `docs/WORD_PANEL_SPEC.md` | Target Arabic word-panel design |
| `docs/VIDEO_EXTRACTION_RUNBOOK.md` | Video/audio/subtitle extraction flow |
| `docs/GLOSSARY_SCHEMA.md` | Arabic glossary data contract |
| `docs/CONTENT_PIPELINE.md` | Content pipeline overview |
| `docs/ASSET_POLICY.md` | What can be bundled in the APK |
| `docs/TOOLING_AND_MCP_NOTES.md` | CLI/MCP/tooling approach |
| `docs/FIXES.md` | Known issues and follow-up corrections |
| `docs/LEGAL_TODO.md` | Legal/content-rights gaps |
| `docs/RELEASE_READINESS.md` | Staged release readiness |
| `docs/ROADMAP.md` | Broad direction by time horizon |
| `docs/YALLA_ENGLISH_REFERENCE.md` | Read-only Yalla English notes |
| `docs/DECISIONS_AND_ASSUMPTIONS.md` | Earlier decision log |
| `docs/REPORT_INDEX.md` | Report index |
| `docs/FLIP_ARABIC_APP_REUSE_PLAN.md` | Original flip/reuse plan |
| `docs/MASTER_PLAN.md` | Original master plan |
| `docs/YALLA_ARABIC_DEV_CONTENT_PIPELINE.md` | Dev content pipeline |
| `docs/YALLA_ARABIC_REPO_SEPARATION_AUDIT.md` | Repo separation audit |

**Note**: Most `docs/` opus references were fixed in this session. Some remain in historical reports (`reports/`) and `docs/MASTER_PLAN.md` — those are archival.
