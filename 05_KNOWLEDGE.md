# Knowledge

Last updated: 2026-07-06

## Bugs found and fixed

### `_checkOnline()` crashes on web
- **File**: `lib/screens/lessons/player_screen.dart:332-342`
- **Cause**: `InternetAddress.lookup('one.one.one.one')` uses dart:io, throws `UnsupportedError` on Flutter web. Catch block returns `false`, app thinks it's always offline.
- **Fix**: Added `if (kIsWeb) return true;` at top of `_checkOnline()`.
- **Commit**: `4e76fb0`

### `scrollCacheExtent` deprecated
- **File**: `lib/screens/lessons/player_screen.dart:784`
- **Cause**: Flutter 3.44 deprecated `cacheExtent` in favor of `ScrollCacheExtent.pixels()`.
- **Fix**: Changed `cacheExtent: 800.0` to `scrollCacheExtent: const ScrollCacheExtent.pixels(800.0)`.
- **Commit**: `c9b9280`

### Opus audio fails on GitHub Pages
- **File**: All `.opus` files bundled as assets
- **Cause**: GitHub Pages serves `.opus` files with MIME type `application/octet-stream` instead of `audio/ogg`. HTML5 Audio element rejects with `MEDIA_ERR_SRC_NOT_SUPPORTED` (error code 4).
- **Fix**: Converted all audio to MP3 format (64kbps mono 44100Hz). GitHub Pages serves `.mp3` as `audio/mpeg`.
- **Commit**: `6cdacaa`

### Transcript hidden when audio fails
- **File**: `lib/screens/lessons/player_screen.dart:772-773`
- **Symptom**: "No text ANYWHERE, just player buttons"
- **Cause**: When audio loading fails, `audio.loadError != null`, and `_buildSentenceList` shows error dialog INSTEAD of transcript. The transcript list never renders.
- **Status**: Resolves automatically now that audio loads successfully (MP3 fix). If audio ever fails again, the error dialog will still hide the transcript — consider showing both.

## Available MCPs

These MCP servers are connected and should be used proactively:

| MCP | Use for |
|-----|---------|
| `context7` | Fetch up-to-date library/framework docs (Flutter, just_audio, provider, etc.) — use instead of guessing API syntax |
| `github` | Repo operations: issues, PRs, file contents, search — use for checking deploy status, reading remote files |
| `memory` | Persistent knowledge graph across sessions — use to store/retrieve project knowledge |
| `playwright` | Browser interaction, testing UI, screenshots — use to verify deployed app |
| `sequential-thinking` | Multi-step reasoning — use for complex debugging or planning |

**Do not ask the user** whether to use these — just use them when the task calls for it.

## Key architecture insights

### Audio loading chain (`audio_handler.dart:136-157`)
1. `localFilePath` → `setFilePath()` (production cache, uses dart:io)
2. `remotePath.isNotEmpty` → `setUrl()` (Cloudflare R2 stream)
3. Fallback → `setAsset()` (bundled asset)

### Course 1 bypass (`player_screen.dart:268`)
`remotePath: lesson.courseId == 1 ? '' : assetPath`
This forces bundled asset loading for all 3 current lessons. R2 streaming is used for production Yalla English lessons only.

### Content loading (`audio_handler.dart:178-256`)
1. If `remotePath` is not empty: tries R2 cache → R2 HTTP fetch → asset fallback
2. If `remotePath` is empty: goes straight to `rootBundle.loadString(item.jsonPath)`
For Course 1, `remotePath` is empty, so JSON loads from bundled assets.

### Transcript display (`player_screen.dart:750-919`)
- `_buildSentenceList()` renders the transcript
- Shows error dialog if `audio.loadError != null` (hides transcript!)
- Shows spinner if `audio.content == null`
- Shows bilingual list (Arabic RTL + English LTR) when content loads
- Active sentence highlights with accent color + left border
- Auto-scrolls to current sentence

### Word definition panel
- `WordDefinitionService.matchArabicTerms(text)` finds tappable words
- `WordDefinitionOverlay` shows: lemma, root family, POS, synonyms/antonyms
- Backed by `assets/arabic_glossary.json` (155 entries across all 3 lessons)
- Fallback to `assets/word_definitions.json` (inherited English dictionary)
- Root families computed dynamically from centralized `assets/roots.json`

### Root word system (NEW)
- `assets/roots.json` — centralized root dictionary with 19 roots
- `lib/services/root_service.dart` — loads and queries root dictionary
- `WordDefinitionService.getWordFamily(root, excludeLemma)` — finds all glossary entries sharing a root
- `WordDefinitionService.getRootInfo(root)` — retrieves root info from centralized dictionary
- Root families are computed at runtime, not embedded in glossary entries

### Sentence breaking (NEW)
- `scripts/fix_sentence_breaking.py` — splits multi-sentence content.json entries
- Uses English punctuation as primary split signal
- Distributes Arabic text proportionally when it lacks punctuation
- Results: lesson_06: 232→435, lesson_07: 108→241, lesson_10: 31→49

## File format requirements

### Content JSON
```json
{
  "sentences": [
    {
      "arabic": "Arabic text",
      "english": "English translation",
      "start_time": 0.0,
      "end_time": 3.5,
      "source_caption_type": "human_ar_manual",
      "english_alignment_confidence": "high"
    }
  ]
}
```

### Audio
- Format: MP3 (NOT opus — GitHub Pages MIME type issue)
- Encoding: 64kbps, mono, 44100Hz
- Location: `assets/courses/course_01/lesson_<NN>/main_story/audio.mp3`
- Must be declared in `pubspec.yaml` under `flutter: assets:`
- Must be allowed in `.gitignore` (remove from `*.mp3` ignore block)

### Glossary JSON
```json
{
  "schema_version": "arabic_root_glossary_v0",
  "entries": [
    {
      "surface_forms": ["kitab", "al-kitab"],
      "lemma": "kitab",
      "root": "k t b",
      "pattern": "fi'al",
      "part_of_speech": "noun",
      "english_meaning": "book",
      "short_definition": "A written or printed work with pages.",
      "root_family": {
        "core_meaning": "writing",
        "explanation": "This root connects books, writing, writers, and offices.",
        "related_words": [
          {"arabic": "kataba", "english": "he wrote", "relation": "verb"},
          {"arabic": "katib", "english": "writer", "relation": "active participle"}
        ]
      }
    }
  ]
}
```

### Root dictionary (NEW)
```json
{
  "schema_version": "arabic_roots_v1",
  "roots": {
    "k t b": {
      "core_meaning": "writing",
      "explanation": "This root connects books, writing, writers, and offices.",
      "part_of_speech": "verb"
    }
  }
}
```

## Useful commands

```bash
# Run on Edge browser
cd "C:\Users\freel\Desktop\GWS\Working on YallaArabic (Official)\yalla-arabic-app"
flutter run -d edge

# Get dependencies
flutter pub get

# Static analysis
flutter analyze

# Build web release
flutter build web

# Build APK
flutter build apk --debug

# Convert audio
ffmpeg -i input.opus -codec:a libmp3lame -b:a 64k -ar 44100 -ac 1 output.mp3

# Download YouTube audio
python -m yt_dlp -f "bestaudio" --extract-audio --audio-format mp3 -o "%(id)s.%(ext)s" <URL>

# Fix sentence breaking
python scripts/fix_sentence_breaking.py

# Generate glossary entries
python scripts/generate_glossary.py

# Extract unique words
python scripts/extract_arabic_words.py

# Check git status
git status
git log --oneline -10
```

## Detailed docs folder

The `docs/` folder has 27 detailed project files. Key ones for code work:
- `docs/CODEBASE_MAP.md` — full source layout and audit findings
- `docs/ARCHITECTURE.md` — app architecture
- `docs/START_HERE.md` — orientation path, lists all docs in read order
- `docs/WORKING_TASKS.md` — living task board
- `docs/FIXES.md` — known issues
- `docs/VALIDATION_CHECKLIST.md` — checks to run by change type
- `docs/LESSON_SCHEMA.md` — content JSON contract
- `docs/WORD_PANEL_SPEC.md` — Arabic word panel target spec
- `docs/GLOSSARY_SCHEMA.md` — glossary data contract

**Stale references**: Most `docs/` opus references were fixed in this session. Some remain in historical reports (`reports/`) and `docs/MASTER_PLAN.md` — those are archival and not worth updating.

## Yalla English reference (read-only)

- Local path: `../yalla-english-app`
- GitHub: not recorded
- Key difference: Yalla English streams audio from Cloudflare R2 (`setUrl()`), not bundled assets
- Production R2 base: `https://pub-9071b083f7474a3083519acf9f8e8dbe.r2.dev/`
- The Yalla English app has all lessons with `remotePath: assetPath` (non-empty), so it always tries R2 first
