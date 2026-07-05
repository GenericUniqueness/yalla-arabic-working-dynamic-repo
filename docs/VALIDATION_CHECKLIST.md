# Validation Checklist

Last updated: 2026-07-05

Use this checklist before and after meaningful code/content changes. Not every
task needs every check; pick the smallest set that covers the risk.

## Always check after docs-only changes

- [ ] Read changed docs for broken paths, stale statements, and unclear next
  steps.
- [ ] Run `git status --short --untracked-files=all`.
- [ ] Confirm new docs are not ignored by `.gitignore` if they are meant to be
  committed.

## Standard app validation

Run from the app repo root:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

If Flutter/Android tooling is unavailable, record that clearly in the final
handoff and in a report when the work is significant.

## Identity validation

- [ ] App label remains `Yalla Arabic`.
- [ ] Android package/applicationId remains `com.yallaarabic.dev`.
- [ ] Internal Dart package name remains `ez_english_app` unless doing a planned
  full rename.
- [ ] Auth remains bypassed for dev with `QaBuildConfig.bypassAuth == true`.
- [ ] No production Firebase, signing, R2, or Play release config was added.
- [ ] About/legal/protected files were not changed unless the task explicitly
  authorized it.

Useful commands:

```bash
rg "applicationId|namespace|Yalla Arabic|bypassAuth|ez_english_app" android lib pubspec.yaml
```

## Asset validation

- [ ] `pubspec.yaml` lists each lesson file explicitly.
- [ ] No broad `assets/courses/` include was added.
- [ ] `lib/data/courses_data.dart` only registers lessons that exist on disk.
- [ ] New `content.json` and `audio.mp3` paths match the course/lesson/type
  convention.
- [ ] `assets/arabic_glossary.json` passes
  `scripts/validate_arabic_glossary.py` after glossary edits.
- [ ] Old Yalla English courses are not reintroduced.

Useful commands:

```bash
rg "assets/courses/" pubspec.yaml lib/data/courses_data.dart
rg "course_0[2-9]" pubspec.yaml assets/courses lib/data/courses_data.dart
```

APK asset inspection after a build:

```bash
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep -E "assets/courses/"
```

## Lesson content validation

For every `content.json`:

- [ ] JSON root is an object.
- [ ] `lesson_title` is present and non-empty.
- [ ] `sentences` is a non-empty array.
- [ ] Every sentence has integer `id`.
- [ ] Every sentence has non-empty `arabic`.
- [ ] Every sentence has non-empty `english`.
- [ ] Every sentence has numeric `start_time` and `end_time`.
- [ ] `end_time > start_time`.
- [ ] Sentence timings are monotonic and non-overlapping.
- [ ] Large gaps are intentional and documented.
- [ ] Arabic text is valid UTF-8 and displays correctly in an editor/app.
- [ ] English translation is human-reviewed or marked as unreviewed.
- [ ] Source/provenance fields are present for non-original content.

See `docs/LESSON_SCHEMA.md` for the canonical schema.

Current validator:

```bash
python scripts/validate_lesson_content.py
python scripts/validate_arabic_glossary.py
python scripts/validate_lesson_content.py --report reports/lesson_validation_latest.md
python scripts/validate_lesson_content.py assets/courses/course_01/lesson_07/main_story/content.json
```

## Player validation

- [ ] Lesson opens from home/list screen.
- [ ] Audio loads from the expected source.
- [ ] Transcript loads from the expected source.
- [ ] Active sentence highlight follows playback.
- [ ] Autoscroll does not jump erratically.
- [ ] Arabic is primary, right-aligned, and readable.
- [ ] English translation visibility toggle works.
- [ ] Sentence repeat controls seek to the right segment.
- [ ] Missing word-panel matches do not crash the player.

## Word panel validation

Current temporary panel:

- [ ] `WordDefinitionService.load()` succeeds.
- [ ] Arabic normalization tests pass.
- [ ] Common words are not over-linked.
- [ ] Long phrase matches beat shorter overlapping matches.
- [ ] Tapping a matched word opens `WordDefinitionOverlay`.
- [ ] Tapping unmatched text degrades gracefully.

Future real panel:

- [ ] Glossary entry has surface, lemma, root, meaning, and reviewed examples.
- [ ] Root-family grouping is useful and not noisy.
- [ ] Synonyms/antonyms are reviewed for context.
- [ ] Generated data is marked until reviewed.

See `docs/WORD_PANEL_SPEC.md`.

## Review/quiz validation

- [ ] Arabic review mode shows Arabic prompt and English choices.
- [ ] Choices are unique after normalization.
- [ ] Correct answer appears exactly once.
- [ ] Distractors are not synonyms of the correct answer.
- [ ] Empty/unsafe dictionary entries are skipped.
- [ ] Saved-word and random review paths both work.

## Report expectations

Create a Markdown report under `reports/` for significant code/content changes.
Include:

- objective
- files changed
- validation commands and outcomes
- known residual risks
- next recommended task
