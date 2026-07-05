# Asset Policy

Last updated: 2026-07-05 — **Yalla Arabic** (private dev shell).

## Principle

Only the assets the app actually needs are bundled into the APK. Course content
is bundled **per explicit lesson path**, never via a broad `assets/courses/`
include. This keeps old Yalla English course content out of the build.

## Bundled course content (the only lessons)

From `pubspec.yaml` `flutter: assets:`:

```yaml
- assets/courses/course_01/lesson_06/main_story/content.json
- assets/courses/course_01/lesson_06/main_story/audio.opus
- assets/courses/course_01/lesson_07/main_story/content.json
- assets/courses/course_01/lesson_07/main_story/audio.opus
- assets/courses/course_01/lesson_10/main_story/content.json
- assets/courses/course_01/lesson_10/main_story/audio.opus
- assets/arabic_glossary.json
```

These three lessons are the **only** course assets intended for bundled APK
testing. They are registered in `lib/data/courses_data.dart` (course 1, lessons
6, 7, and 10).

## Other bundled assets

- `assets/branding/`, `assets/images/` — icons/branding.
- `assets/word_definitions.json` — inherited bilingual dictionary, reused as a
  temporary Arabic-vocabulary lookup (not a real Arabic dictionary).
- `assets/arabic_glossary.json` — first Arabic-first root glossary slice for
  lesson 6, draft pending human review.
- `assets/grammar/`, `assets/grammar/topics/` — bundled grammar content.

## Rules

1. **No broad `assets/courses/` include.** Add each new lesson's `content.json`
   and `audio.opus` as explicit lines.
2. Old Yalla English courses (`course_02`…`course_09`) were deleted from this
   repo. Do not re-add them. Originals live in the read-only Yalla English repo.
3. `*.opus` audio is git-ignored by default (see `.gitignore`). Lesson 6 audio
   is explicitly unignored because it is the current reproducible golden slice.
   Other lesson audio should remain local unless deliberately approved.
4. Adding a lesson = create the files on disk under
   `assets/courses/course_<NN>/lesson_<NN>/<type>/`, register it in
   `courses_data.dart`, and add the two explicit `pubspec.yaml` asset lines.

## Verifying the build is clean

```bash
flutter build apk --debug
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep -E 'course_0[2-9]'
# expected: no matches (0 old English course entries)
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep -E 'course_01/lesson_(06|07|10)'
# expected: the 3 Arabic lessons' content.json + audio.opus
```
