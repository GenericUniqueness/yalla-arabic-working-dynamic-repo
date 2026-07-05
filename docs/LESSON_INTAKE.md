# Lesson Intake

Last updated: 2026-07-05

Use this tracker for source videos/audio before they become app lessons.

## Intake rule

A source is not ready for app integration until it has:

- Arabic audio or source video
- Arabic transcript/subtitles with timestamps
- English translation/subtitles aligned to the Arabic
- review status for Arabic and English
- app-ready `content.json`
- `audio.mp3`
- rights/provenance status recorded

Videos with usable Arabic subtitles are the first priority. Videos without
usable Arabic subtitles should be skipped until human Arabic captions exist.

## Status values

Use these values consistently:

- `candidate`
- `needs_arabic_captions`
- `needs_english_translation`
- `needs_review`
- `ready_for_build`
- `integrated`
- `blocked`
- `skipped`

## Source tracker

| Status | Course | Lesson | Source title | Source URL/id | Arabic captions | English captions/translation | Review | App files | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| candidate | 1 | 1 | Easy Arabic Podcast \| Buy a Car | `gObdQ1pXfII` | needs inspection | needs inspection | not started | planned `course_01/lesson_01/main_story` | Playlist index 1. |
| candidate | 1 | 2 | Easy Arabic Podcast: Learn 2x Faster | `Nn0BWPHW7rs` | needs inspection | needs inspection | not started | planned `course_01/lesson_02/main_story` | Playlist index 2. |
| candidate | 1 | 3 | كفاية بقى يا جماعة! الفصحى أفضل | `zCMC-vHq-j0` | needs inspection | needs inspection | not started | planned `course_01/lesson_03/main_story` | Playlist index 3. |
| candidate | 1 | 4 | Learn Arabic with Real Objects (Comprehensible Input) | `LJLV0BeRAqY` | needs inspection | needs inspection | not started | planned `course_01/lesson_04/main_story` | Playlist index 4. |
| candidate | 1 | 5 | Learn Arabic with Animals (Comprehensible Input) | `r-XT6CW44qw` | needs inspection | needs inspection | not started | planned `course_01/lesson_05/main_story` | Playlist index 5. |
| integrated | 1 | 6 | Easy Arabic Podcast \| How to describe things? [Subtitles] | `-U-cnbFBc9c` | present/manual VTT downloaded | present/manual VTT downloaded | draft pending human review | `course_01/lesson_06/main_story`; raw packet in `../content_pipeline/raw/06_-U-cnbFBc9c` | Playlist index 6; private-dev golden lesson slice. |
| integrated | 1 | 7 | Easy Arabic Podcast about Social Media | `Mq51rklpGog` | present/manual | present/aligned | dev only | `course_01/lesson_07/main_story` | Permission not claimed. |
| candidate | 1 | 8 | ARABIC LANGUAGE / DAILY RUTINE. Listening for Beginners. | `ENZE1Knq3nU` | needs inspection | needs inspection | not started | planned `course_01/lesson_08/main_story` | Playlist index 8; title typo kept from source. |
| candidate | 1 | 9 | Arabic Conversation for Beginners #1 [Turn On Subtitles] | `dinQIb4ZFXY` | present/manual available | present/manual available | not started | planned `course_01/lesson_09/main_story` | Playlist index 9; good fallback after lesson 6. |
| integrated | 1 | 10 | Arabic Conversation for Beginners #2 The Family | `lfPrnUZ4osQ` | present/manual | present/aligned | dev only | `course_01/lesson_10/main_story` | Permission not claimed. |
| needs_english_translation | 1 | 11 | Easy Arabic Podcast \| PANGKOR ISLAND [English Subtitles] | `q8nqcGCzmPQ` | present/manual available | no manual English track found; auto-translation possible but not release-ready | not started | planned `course_01/lesson_11/main_story` | Playlist index 11; needs English translation/review before app work. |
| needs_english_translation | 1 | 12 | Easy Arabic Podcast \| Why Malaysia? [subtitles] | `8LWVrX2BtUM` | present/manual available | no manual English track found; auto-translation possible but not release-ready | not started | planned `course_01/lesson_12/main_story` | Playlist index 12; needs English translation/review before app work. |

Playlist URL: `https://www.youtube.com/playlist?list=PLbhGMu9BBf-E`

## Per-lesson checklist

Before integration:

- [ ] Source URL/id recorded.
- [ ] Source ownership/permission status recorded.
- [ ] Arabic captions exist locally.
- [ ] English captions exist locally or translation task is complete.
- [ ] Arabic transcript reviewed.
- [ ] English translation reviewed.
- [ ] Audio extracted and converted to `audio.mp3`.
- [ ] `content.json` generated.
- [ ] Schema validation passed.
- [ ] Timing diagnostics reviewed.

During integration:

- [ ] Files copied to `assets/courses/course_<NN>/lesson_<NN>/<type>/`.
- [ ] `lib/data/courses_data.dart` updated.
- [ ] `pubspec.yaml` explicit asset lines added.
- [ ] App opens the lesson.
- [ ] Audio plays.
- [ ] Transcript highlights correctly.
- [ ] English toggle works.
- [ ] Word taps do not crash.

After integration:

- [ ] `flutter analyze` run or inability recorded.
- [ ] `flutter test` run or inability recorded.
- [ ] Debug APK build run or deferred with reason.
- [ ] Report added under `reports/` for significant content additions.

## Active raw packet

The current next lesson candidate is playlist index 6:

```text
../content_pipeline/raw/06_-U-cnbFBc9c/
  -U-cnbFBc9c.ar.vtt
  -U-cnbFBc9c.en.vtt
  -U-cnbFBc9c.opus
```

Draft app-ready output has also been generated:

```text
../content_pipeline/app_ready/06_-U-cnbFBc9c/
  content.json
  audio.mp3
```

The draft validates structurally, but still needs human review. Current warnings:
`redistribution_permission` is `not_claimed`, sentence 22 has a 14.580s gap, and
sentence 111 is a numeric-only Arabic cue.

Integrated app asset:

```text
assets/courses/course_01/lesson_06/main_story/
  content.json
  audio.mp3
```

Arabic root glossary slice:

```text
assets/arabic_glossary.json
```

## Current blockers

- Lesson 6 has not been reviewed by a human Arabic/English reviewer.
- Lesson 6 root glossary is a curated draft, not reviewed linguistic authority.
- Caption cleaning and app-ready JSON generation are implemented only as a first
  draft helper in `scripts/build_lesson_from_vtt.py`.
- Source ownership/redistribution permission is still not claimed.
- Yalla English reference repo is now available at `../yalla-english-app`.
