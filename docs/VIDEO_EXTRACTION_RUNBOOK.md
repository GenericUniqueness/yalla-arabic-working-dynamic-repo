# Video Extraction Runbook

Last updated: 2026-07-05

This runbook defines the future source-video-to-lesson flow. It can be used once
the Yalla Arabic playlist/video list is available.

## Tooling expectation

No dedicated MCP connector is required for video extraction in the current
workspace. The expected implementation path is local CLI tooling:

- `yt-dlp` for video metadata, audio download, and subtitle download
- `ffmpeg` for audio conversion/normalization to `audio.opus`
- Python for caption cleaning, alignment checks, and lesson validation
- optional LLM workflow for English translation when English captions are
  missing
- human review for Arabic transcript and English translation accuracy

Network access will be required only when downloading or inspecting remote video
metadata/captions. If the sandbox blocks that, request approval at the command
that needs it.

## Source priority

Preferred source order:

1. Teacher/original recordings with local transcript and rights cleared.
2. Videos with reliable Arabic captions already available.
3. Videos with audio but no Arabic captions, only if human Arabic captions will
   be supplied.

Missing English captions are not a blocker if translation/review capacity
exists. Missing Arabic captions are a blocker for the first pipeline phase.

## Pipeline stages

### 1. Inspect source

Record:

- source URL/id
- title
- playlist index
- duration
- available subtitle tracks
- available audio format
- rights/permission status

Expected command shape:

```bash
python -m yt_dlp --list-subs --skip-download VIDEO_URL
python -m yt_dlp --dump-json --skip-download VIDEO_URL
```

### 2. Download audio

Expected command shape:

```bash
python -m yt_dlp -x --audio-format opus --audio-quality 0 -o "audio/%(id)s.%(ext)s" VIDEO_URL
```

If `yt-dlp` outputs another format, convert with `ffmpeg`:

```bash
ffmpeg -i input_audio -vn -c:a libopus -b:a 48k audio.opus
```

### 3. Download captions

Arabic captions:

```bash
python -m yt_dlp --skip-download --write-subs --sub-langs ar --sub-format vtt VIDEO_URL
```

English captions when available:

```bash
python -m yt_dlp --skip-download --write-subs --sub-langs en --sub-format vtt VIDEO_URL
```

Do not rely on auto-generated captions as release-quality text without review.

### 4. Clean captions

Clean caption artifacts:

- repeated lines
- markup tags
- speaker/noise labels when not useful
- empty cues
- overlapping cues
- very short duplicate fragments

Preserve timing unless the reviewer intentionally changes segmentation.

### 5. Create English translation if missing

If English captions are unavailable:

- translate from Arabic transcript to natural English
- preserve line alignment
- mark translation as machine-generated/unreviewed
- require human review before release-quality status

### 6. Build app-ready lesson

Create:

```text
content.json
audio.opus
```

Follow `docs/LESSON_SCHEMA.md`.

Current helper:

```bash
python scripts/build_lesson_from_vtt.py \
  --arabic ../content_pipeline/raw/06_-U-cnbFBc9c/-U-cnbFBc9c.ar.vtt \
  --english ../content_pipeline/raw/06_-U-cnbFBc9c/-U-cnbFBc9c.en.vtt \
  --audio ../content_pipeline/raw/06_-U-cnbFBc9c/-U-cnbFBc9c.opus \
  --output ../content_pipeline/app_ready/06_-U-cnbFBc9c/content.json \
  --title "Easy Arabic Podcast | How to describe things? [Subtitles]" \
  --video-id=-U-cnbFBc9c \
  --playlist-index 6 \
  --copy-audio
```

### 7. Validate

Run:

```bash
python scripts/validate_lesson_content.py path/to/content.json
```

For integrated app assets:

```bash
python scripts/validate_lesson_content.py --report reports/lesson_validation_latest.md
```

Then run the app validation checklist in `docs/VALIDATION_CHECKLIST.md`.

### 8. Integrate into app

- copy files to `assets/courses/course_<NN>/lesson_<NN>/<type>/`
- add explicit asset lines in `pubspec.yaml`
- add lesson entry in `lib/data/courses_data.dart`
- run validator again against app assets
- run Flutter validation when tooling is available

## Directory suggestion

Use a pipeline workspace outside committed app assets until a lesson is ready:

```text
content_pipeline/
  metadata/
  captions_raw/
  captions_clean/
  translations/
  audio_raw/
  audio_opus/
  app_ready/
  reports/
```

The exact folder can change, but raw and generated pipeline state should not be
mixed with committed app assets until integration.

## Current active workspace

The current raw packet for playlist index 6 is:

```text
../content_pipeline/raw/06_-U-cnbFBc9c/
  -U-cnbFBc9c.ar.vtt
  -U-cnbFBc9c.en.vtt
  -U-cnbFBc9c.opus
../content_pipeline/app_ready/06_-U-cnbFBc9c/
  content.json
  audio.opus
```

Use this packet for the first pipeline implementation pass. The generated draft
currently validates structurally but needs human caption/translation review.

## Do not do

- Do not use cookies, proxies, or anti-blocking workarounds.
- Do not retry endlessly on bot/CAPTCHA blocks.
- Do not add source content to the app without provenance.
- Do not mark machine translation as reviewed.
- Do not bundle broad `assets/courses/`.
- Do not copy Yalla English content into Yalla Arabic.
