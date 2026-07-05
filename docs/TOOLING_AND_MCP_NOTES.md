# Tooling and MCP Notes

Last updated: 2026-07-05

This project does not currently require a special MCP connector for video
extraction. The practical path is local tooling plus explicit approval for
network/download commands when needed.

## Expected local tools

- `python` - validation, cleaning, pipeline scripts
- `yt-dlp` - video metadata, audio extraction, subtitle extraction
- `ffmpeg` - audio conversion to `audio.mp3`
- `flutter` / `dart` - app validation and builds
- `git` - status/diff/history

## Current tool status in this shell

- `python` is available (`Python 3.14.5` observed).
- `flutter` is not on PATH.
- `dart` is not on PATH.
- `yt-dlp` on PATH is available but old (`2025.09.05` observed).
- `python -m yt_dlp` is updated and usable (`2026.07.04` observed after
  `python -m pip install -U yt-dlp`).
- `ffmpeg` is available (`2025-11-27-git-61b034a47c` observed).

## Network policy

Video metadata/download work needs network access. If a command fails due to
sandbox or network restrictions, rerun it with the required approval flow rather
than working around the restriction.

## MCP expectation

Useful MCP-style capabilities would be:

- browser inspection of public source pages
- file/resource access inside known repos
- possibly search/research for tool documentation

But direct video extraction should stay in local scripts/CLI tools so outputs are
reproducible and easy to audit.

## Current source-link status

- Yalla English local reference exists at `../yalla-english-app`.
- `../repo links.txt` contains the Yalla Arabic GitHub URL and the Arabic source
  playlist URL: `https://www.youtube.com/playlist?list=PLbhGMu9BBf-E`.
- `../repo links.txt` does not currently contain the Yalla English GitHub URL.
- Once a playlist URL is present, first run metadata-only checks with `yt-dlp`
  before downloading audio/subtitles.

## Current YouTube tooling note

Metadata-only playlist inspection succeeded on 2026-07-05 with:

`yt-dlp --flat-playlist --dump-json "https://www.youtube.com/playlist?list=PLbhGMu9BBf-E"`

Subtitle inspection did not complete cleanly with installed PATH
`yt-dlp 2025.09.05`; it timed out and produced YouTube `nsig`/SABR warnings.
The pip module was updated on 2026-07-05, and `python -m yt_dlp` now reports
`2026.07.04`. Use `python -m yt_dlp` for project intake commands until PATH is
updated.

Individual subtitle inspection succeeded for playlist indices 6, 9, 11, and 12:

- 6 (`-U-cnbFBc9c`): manual Arabic and English subtitles available.
- 9 (`dinQIb4ZFXY`): manual Arabic and English subtitles available.
- 11 (`q8nqcGCzmPQ`): manual Arabic subtitles available; no manual English
  subtitle track found.
- 12 (`8LWVrX2BtUM`): manual Arabic subtitles available; no manual English
  subtitle track found.

The active local raw packet is:

`../content_pipeline/raw/06_-U-cnbFBc9c`

The first draft app-ready packet is:

`../content_pipeline/app_ready/06_-U-cnbFBc9c`

The generator script is `scripts/build_lesson_from_vtt.py`.
