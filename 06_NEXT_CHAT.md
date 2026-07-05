# Next Chat — Where to Resume

Last updated: 2026-07-06

## Where work stopped

Session completed all Phase 1 improvements:

1. **Sentence breaking fixed**: Content.json entries split at natural sentence boundaries. Lesson 06: 232→435 entries, lesson 07: 108→241, lesson 10: 31→49. Script at `scripts/fix_sentence_breaking.py`.

2. **Root word system designed and implemented**:
   - `assets/roots.json` — centralized root dictionary with 19 roots
   - `lib/services/root_service.dart` — loads and queries root dictionary
   - `WordDefinitionService.getWordFamily()` — computes word families dynamically
   - `WordDefinitionService.getRootInfo()` — retrieves root info from centralized dictionary

3. **Glossary expanded**: 19→155 entries across all 3 lessons. Auto-generated entries for top 150 content words. Script at `scripts/generate_glossary.py`.

4. **Definition window UI/UX redesigned**: New overlay with accent strip, detail chips (POS/Pattern/Root), example cards, root family cards with word relationship labels, and better visual hierarchy.

**All code changes are uncommitted.** `flutter analyze` passes (0 errors, 0 warnings).

## Immediate next objective

**Commit the Phase 1 changes and verify the deployed app.** Then move to Phase 2 tasks:
- Verify audio syncing with transcript highlighting
- Verify seek, speed control, loop mode, play/pause
- Verify auto-scroll follows audio
- Update web/index.html title to "Yalla Arabic"

## Files changed this session

| File | Change |
|------|--------|
| `assets/courses/course_01/lesson_06/main_story/content.json` | Sentence splitting (232→435 entries) |
| `assets/courses/course_01/lesson_07/main_story/content.json` | Sentence splitting (108→241 entries) |
| `assets/courses/course_01/lesson_10/main_story/content.json` | Sentence splitting (31→49 entries) |
| `assets/roots.json` | New centralized root dictionary |
| `assets/arabic_glossary.json` | Expanded from 19→155 entries |
| `lib/services/root_service.dart` | New root service |
| `lib/services/word_definition_service.dart` | Added getWordFamily(), getRootInfo(), RootService.load() |
| `lib/screens/lessons/word_definition_overlay.dart` | Complete UI/UX redesign |
| `scripts/fix_sentence_breaking.py` | New sentence splitting script |
| `scripts/generate_glossary.py` | New glossary generation script |
| `scripts/extract_arabic_words.py` | New word extraction script |
| `reports/unique_words.json` | Word frequency analysis |
| `03_PROGRESS.md` | Updated with Phase 1 completion |
| `04_TASKS.md` | Updated task statuses |
| `06_NEXT_CHAT.md` | This file |

## Files to read first

1. `00_PROJECT.md` — project definition
2. `01_CONTEXT.md` — environment, architecture, MCP availability
3. `02_DECISIONS.md` — decisions already made (D1-D9)
4. `03_PROGRESS.md` — what's done (Phase 0 + Phase 1 complete)
5. `04_TASKS.md` — prioritized task list
6. `05_KNOWLEDGE.md` — bugs, architecture insights, MCP list
7. `06_NEXT_CHAT.md` — this file

## Key new files

| File | Purpose |
|------|---------|
| `assets/roots.json` | Centralized Arabic root dictionary |
| `lib/services/root_service.dart` | Root dictionary service |
| `scripts/fix_sentence_breaking.py` | Splits multi-sentence content entries |
| `scripts/generate_glossary.py` | Auto-generates glossary entries |
| `scripts/extract_arabic_words.py` | Extracts unique words for analysis |

## Available MCPs

Use proactively — do not ask the user:
- `context7` — library/framework docs (Flutter, just_audio, provider)
- `github` — repo operations, deploy status, remote file access
- `memory` — persistent knowledge graph across sessions
- `playwright` — browser testing, screenshots, UI verification
- `sequential-thinking` — multi-step reasoning for complex tasks

## Pitfalls

1. **Don't switch back to opus** — GitHub Pages MIME type is the root cause. MP3 only.
2. **Don't remove the course 1 bypass** — `remotePath: lesson.courseId == 1 ? '' : assetPath`. R2 is off-limits.
3. **Don't rename `ez_english_app`** — breaks all imports.
4. **Don't add broad `assets/courses/` bundling** — only explicit lesson paths.
5. **Flutter web asset loading** may struggle with >20MB files. Current total is ~28MB.
6. **Deploy takes ~2-3 minutes** after push.
7. **Root word system** uses centralized `assets/roots.json` — new roots should be added there.
8. **Glossary entries are auto-generated** — need human review for accuracy.
9. **Sentence splitting** depends on punctuation — unpunctuated captions may still have multiple sentences per entry.
10. **`flutter analyze` passes** with 0 errors and 0 warnings.

## Unresolved questions

1. Has the user verified the deployed app yet? (Audio + transcript + word panel)
2. Should the auto-generated glossary entries be reviewed for accuracy?
3. Are there more lessons to add from the playlist?
4. Should the app title be updated from "ez_english_app" to "Yalla Arabic"?
