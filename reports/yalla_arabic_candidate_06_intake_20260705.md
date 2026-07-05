# Yalla Arabic Candidate 06 Intake

Date: 2026-07-05

## Source

- Playlist: `https://www.youtube.com/playlist?list=PLbhGMu9BBf-E`
- Playlist index: 6
- Video id: `-U-cnbFBc9c`
- Title: `Easy Arabic Podcast | How to describe things? [Subtitles]`
- Current role: active next lesson candidate for `course_01/lesson_06/main_story`

## Tooling

- PATH `yt-dlp` remains `2025.09.05`.
- `python -m yt_dlp` was updated to `2026.07.04` and used for successful intake.
- `ffmpeg` is available and was used by yt-dlp for `.opus` extraction.

## Subtitle Findings

Priority candidates were checked individually:

- Index 6 (`-U-cnbFBc9c`): manual Arabic and English subtitle tracks available.
- Index 9 (`dinQIb4ZFXY`): manual Arabic and English subtitle tracks available.
- Index 11 (`q8nqcGCzmPQ`): manual Arabic subtitle track available; no manual English track found.
- Index 12 (`8LWVrX2BtUM`): manual Arabic subtitle track available; no manual English track found.

## Local Raw Packet

```text
../content_pipeline/raw/06_-U-cnbFBc9c/
  -U-cnbFBc9c.ar.vtt   25,790 bytes
  -U-cnbFBc9c.en.vtt   21,292 bytes
  -U-cnbFBc9c.opus     25,063,538 bytes
```

## Draft App-Ready Packet

```text
../content_pipeline/app_ready/06_-U-cnbFBc9c/
  content.json
  audio.opus
```

Generated with `scripts/build_lesson_from_vtt.py`.

Validation result:

- Files checked: 1
- Errors: 0
- Warnings: 3
- Sentences: 232
- Max end time: 1934.580s

Warnings:

- `redistribution_permission` is `not_claimed`; content is not release-ready.
- Sentence 22 has a 14.580s gap before it.
- Sentence 111 has an Arabic field of `500`, so it contains no Arabic Unicode letters.

## Next Action

Clean and normalize the Arabic/English VTT files, inspect alignment quality,
record human review status, and resolve the validation warnings. Do not copy
this packet into app assets until review/provenance and schema validation are
complete.
