# Context

Last updated: 2026-07-06

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

**Phase 0 is complete**: app runs on web, all 3 lessons have bundled audio + transcript, deploys to GitHub Pages.

**Phase 1 is complete**: sentence breaking fixed, root word system implemented, glossary expanded to 155 entries, definition window UI/UX redesigned.

### Current state

- `flutter analyze` passes (0 errors, 0 warnings)
- Last commit: `4175345` — Phase 1 improvements
- Deployed URL: `https://genericuniqueness.github.io/yalla-arabic-working-dynamic-repo/`
- 3 bundled lessons: lesson_06 (435 sentences), lesson_07 (241 sentences), lesson_10 (49 sentences)
- 155 glossary entries across all 3 lessons
- 19 roots in centralized root dictionary

### Key source of truth files

| File | Purpose |
|------|---------|
| `lib/screens/lessons/player_screen.dart` | Lesson player UI, transcript rendering, word taps |
| `lib/services/audio_handler.dart` | Audio loading chain (local → R2 → bundled asset) |
| `lib/services/word_definition_service.dart` | Arabic word matching/lookup, word family computation |
| `lib/services/root_service.dart` | Centralized root dictionary service |
| `lib/screens/lessons/word_definition_overlay.dart` | Word definition popup UI (redesigned) |
| `assets/arabic_glossary.json` | 155 entries across all 3 lessons |
| `assets/roots.json` | Centralized root dictionary (19 roots) |
| `assets/word_definitions.json` | Inherited English dictionary (fallback) |

### Content files

| Path | Content |
|------|---------|
| `assets/courses/course_01/lesson_06/main_story/content.json` | Lesson 6 transcript (435 sentences) |
| `assets/courses/course_01/lesson_06/main_story/audio.mp3` | Lesson 6 audio (14.77 MB, 64kbps mono) |
| `assets/courses/course_01/lesson_07/main_story/content.json` | Lesson 7 transcript (241 sentences) |
| `assets/courses/course_01/lesson_07/main_story/audio.mp3` | Lesson 7 audio (11.66 MB, 64kbps mono) |
| `assets/courses/course_01/lesson_10/main_story/content.json` | Lesson 10 transcript (49 sentences) |
| `assets/courses/course_01/lesson_10/main_story/audio.mp3` | Lesson 10 audio (1.75 MB, 64kbps mono) |

### Correct YouTube video IDs

| Lesson | YouTube ID | Title |
|--------|-----------|-------|
| 6 | `-U-cnbFBc9c` | Easy Arabic Podcast — How to describe things? |
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
      "id": 0,
      "arabic": "بسم الله الرحمن الرحيم",
      "english": "In the name of God, the Most Gracious, the Most Merciful.",
      "start_time": 1.14,
      "end_time": 4.603,
      "source_caption_type": "human_ar_manual",
      "english_alignment_confidence": "high"
    }
  ]
}
```

## Key constraints

- Audio MUST be MP3 format for web (not opus — GitHub Pages doesn't serve opus with correct MIME type)
- Total bundled audio ~28MB across 3 lessons
- No emulator/device testing possible — verification is via static analyze + web deploy
- Content redistribution_permission is `not_claimed` — not release-ready
- Dart package name `ez_english_app` must NOT be renamed (breaks all imports)

## Detailed docs folder

The `docs/` folder contains 27 detailed project files. These are the **canonical detailed reference** for architecture, specs, and pipeline work. Key ones:

| File | Purpose |
|------|---------|
| `docs/START_HERE.md` | Fastest orientation path for new agents |
| `docs/WORD_PANEL_SPEC.md` | Target Arabic word-panel design |
| `docs/GLOSSARY_SCHEMA.md` | Arabic glossary data contract |
| `docs/CODEBASE_MAP.md` | Source layout, audit findings |
| `docs/ARCHITECTURE.md` | App architecture |
