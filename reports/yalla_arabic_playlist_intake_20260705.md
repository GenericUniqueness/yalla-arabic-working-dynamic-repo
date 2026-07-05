# Yalla Arabic Playlist Intake

Date: 2026-07-05

## Source

Playlist URL:

`https://www.youtube.com/playlist?list=PLbhGMu9BBf-E`

Metadata command:

`yt-dlp --flat-playlist --dump-json "https://www.youtube.com/playlist?list=PLbhGMu9BBf-E"`

The command initially failed under sandbox networking with `WinError 10013`.
After approval, metadata-only inspection succeeded.

## Playlist Metadata

- Playlist title: `Arabic Khasu Yalla Arabic`
- Playlist id: `PLbhGMu9BBf-E`
- Playlist uploader/channel: `M.Muslim Muzammil`
- Channel id: `UCqeHbzVDL1jY-Cb5Em6dBdQ`
- Entry count: 12

## Entries

| Index | Video id | Title | Current app status |
| ---: | --- | --- | --- |
| 1 | `gObdQ1pXfII` | Easy Arabic Podcast \| Buy a Car | candidate |
| 2 | `Nn0BWPHW7rs` | Easy Arabic Podcast: Learn 2x Faster | candidate |
| 3 | `zCMC-vHq-j0` | كفاية بقى يا جماعة! الفصحى أفضل | candidate |
| 4 | `LJLV0BeRAqY` | Learn Arabic with Real Objects (Comprehensible Input) | candidate |
| 5 | `r-XT6CW44qw` | Learn Arabic with Animals (Comprehensible Input) | candidate |
| 6 | `-U-cnbFBc9c` | Easy Arabic Podcast \| How to describe things? [Subtitles] | candidate |
| 7 | `Mq51rklpGog` | Easy Arabic Podcast \| about Social Media | integrated |
| 8 | `ENZE1Knq3nU` | ARABIC LANGUAGE / DAILY RUTINE. Listening for Beginners. | candidate |
| 9 | `dinQIb4ZFXY` | Arabic Conversation for Beginners #1 [Turn On Subtitles] | candidate |
| 10 | `lfPrnUZ4osQ` | Arabic Conversation for Beginners #2 \| The Family [Turn On Subtitles] | integrated |
| 11 | `q8nqcGCzmPQ` | Easy Arabic Podcast \| PANGKOR ISLAND [English Subtitles] | candidate |
| 12 | `8LWVrX2BtUM` | Easy Arabic Podcast \| Why Malaysia? [subtitles] | candidate |

## Subtitle Inspection Status

Attempted command:

`yt-dlp --skip-download --list-subs --playlist-items 1:12 "https://www.youtube.com/playlist?list=PLbhGMu9BBf-E"`

Result: timed out after partial extraction with YouTube `nsig` and SABR warnings
from installed `yt-dlp 2025.09.05`.

Second attempt with structured `--print` also failed because YouTube reported no
requested downloadable format for each video under the current client behavior.

## Next Actions

- Update or repair local `yt-dlp` before relying on subtitle/audio extraction.
- Inspect subtitles one video at a time after the tool issue is resolved.
- Prioritize indices 6, 9, 11, and 12 first because their titles explicitly
  mention subtitles.
- Keep indices 7 and 10 as already-integrated dev lessons.
- Do not integrate any new lesson until Arabic and English text are reviewed and
  rights/provenance status is recorded.
