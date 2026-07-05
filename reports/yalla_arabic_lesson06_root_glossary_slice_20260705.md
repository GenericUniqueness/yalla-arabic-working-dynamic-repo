# Lesson 06 Root Glossary Vertical Slice

Date: 2026-07-05

## Scope

Implemented the first private-dev golden lesson slice before APK build:

- bundled lesson 6 content/audio into app assets
- registered lesson 6 in `lib/data/courses_data.dart`
- added `assets/arabic_glossary.json` with 19 draft Arabic root-aware entries
- wired `WordDefinitionService` to prefer curated Arabic glossary entries and
  keep inherited dictionary matching as fallback
- updated `WordDefinitionOverlay` to show:
  - word details
  - root-family panel
  - synonyms/antonyms
- added `scripts/validate_arabic_glossary.py`

## Files Added

- `assets/arabic_glossary.json`
- `assets/courses/course_01/lesson_06/main_story/content.json`
- `assets/courses/course_01/lesson_06/main_story/audio.opus`
- `scripts/validate_arabic_glossary.py`
- `docs/FIXES.md`

## Validation

Available validations run:

```bash
python scripts/validate_lesson_content.py
python scripts/validate_arabic_glossary.py
```

Results:

- Lesson content: 3 files checked, 0 errors, 7 warnings.
- Arabic glossary: 19 entries, 0 errors, 0 warnings.

Known lesson warnings:

- lesson 6: rights not claimed, one 14.580s gap before sentence 22, sentence 111
  is numeric-only Arabic text (`500`)
- lessons 7 and 10: rights not claimed and local `audio.opus` missing

## Not Run

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- APK build

Reason: `flutter` and `dart` are not on PATH in this environment. User also
asked to stop before APK build and discuss before building.

## Next Decision

Before APK build, inspect or review:

- whether lesson 6 caption warnings are acceptable for a private-dev APK
- whether the 19-entry glossary is enough for the first visual test
- whether root-family wording should be shorter, collapsible, or more explicit
  for beginners
