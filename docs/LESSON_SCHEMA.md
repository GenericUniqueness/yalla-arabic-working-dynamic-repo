# Lesson Schema

Last updated: 2026-07-04

This is the working schema for Yalla Arabic lesson content. It documents what
the app accepts today and what future lesson production should produce.

## File layout

Each lesson type has exactly one transcript JSON and one audio file:

```text
assets/courses/course_<NN>/lesson_<NN>/<type_folder>/content.json
assets/courses/course_<NN>/lesson_<NN>/<type_folder>/audio.mp3
```

Current supported `type_folder` values come from `LessonType.assetFolder`:

- `main_story`
- `vocabulary`
- `mini_story`
- `conversation`
- `pov`
- `commentary`

Current integrated lessons only use `main_story`.

## Preferred JSON root

```json
{
  "lesson_title": "Arabic lesson title",
  "private_dev_source": {
    "source": "youtube_teacher_pilot_private_dev_only",
    "video_id": "VIDEO_ID",
    "webpage_url": "https://www.youtube.com/watch?v=VIDEO_ID",
    "playlist_index": 7,
    "redistribution_permission": "not_claimed"
  },
  "sentences": []
}
```

The app can currently parse a raw root list of sentences, but new content should
use the object root above.

## Sentence object

Preferred fields:

```json
{
  "id": 0,
  "arabic": "Arabic transcript line",
  "english": "English translation line",
  "start_time": 0.96,
  "end_time": 20.6,
  "source_caption_type": "human_ar_manual",
  "english_alignment_confidence": "high"
}
```

Required for app-ready Yalla Arabic content:

- `id`: integer, unique within lesson, sequential from 0 preferred
- `arabic`: non-empty string
- `english`: non-empty string
- `start_time`: number in seconds
- `end_time`: number in seconds

Accepted legacy aliases in current parser:

- `text` as fallback for `english`
- `ara` as fallback for `arabic`
- `start` as fallback for `start_time`
- `end` as fallback for `end_time`

Do not use legacy aliases for new content.

## Timing rules

- `start_time >= 0`
- `end_time > start_time`
- sentence timings must be monotonic
- overlapping sentences are invalid unless a future feature explicitly supports
  overlap
- large gaps should be reviewed and documented
- first sentence should usually start close to the first spoken audio
- final sentence should end close to the final spoken audio

Current debug thresholds in `TranscriptDiagnostics`:

- first start above `1.5s` is suspicious
- gap above `12s` is large
- English words/sec above `8` for lines with at least 8 English words is
  compressed

These are diagnostics, not absolute product rules. Arabic speech rate and line
length still need human judgment.

## Text and encoding rules

- Files must be UTF-8.
- Arabic must display as Arabic characters, not mojibake.
- Arabic should be normalized only for lookup/search, not destructively changed
  in the human transcript unless the reviewer approves.
- Preserve natural punctuation if it helps learners.
- Avoid extremely long lines when safe timestamps exist for splitting.
- Do not split a line when there is no safe timestamp for the split.
- English should be a natural translation, not necessarily word-for-word.
- Mark machine-generated English as unreviewed until human review happens.

## Provenance fields

For non-original or externally sourced lessons, include source metadata. Current
lessons use `private_dev_source` with:

- `source`
- `video_id`
- `webpage_url`
- `playlist_index`
- `redistribution_permission`

Before any release-quality distribution, `redistribution_permission` must be
reviewed and changed from `not_claimed` to an explicit approved status.

## Registration requirements

Adding a lesson requires all of this:

- `content.json` on disk
- `audio.mp3` on disk for local build
- explicit `content.json` line in `pubspec.yaml`
- explicit `audio.mp3` line in `pubspec.yaml`
- matching lesson entry in `lib/data/courses_data.dart`
- validation pass from `docs/VALIDATION_CHECKLIST.md`

Validator:

```bash
python scripts/validate_lesson_content.py path/to/content.json
```

## Current parser behavior

`LessonContent.fromJson` is permissive:

- accepts root object or root list
- does not require non-empty strings
- defaults missing timestamps to `0.0`
- defaults missing ids to list index

That permissiveness helps old/dev content load, but it is not enough for content
quality. New pipeline validation should enforce the stricter rules above before
files are added to the app.
