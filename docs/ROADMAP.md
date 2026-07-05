# Roadmap

Last updated: 2026-07-05

This is the broad direction for Yalla Arabic. Use it to decide what to do next
without losing sight of the later shipping work. Use `docs/WORKING_TASKS.md` for
the live checklist and `docs/LESSON_INTAKE.md` for per-video status.

## Immediate: next 1-3 work sessions

Goal: turn the playlist into a reliable next lesson candidate without adding
fragile content to the app.

- **Fix source tooling.** The playlist URL is
  `https://www.youtube.com/playlist?list=PLbhGMu9BBf-E`. Metadata inspection
  works. PATH `yt-dlp` is still old, but `python -m yt_dlp` was updated to
  `2026.07.04` and works for individual subtitle/audio intake.
- **Inspect likely captioned videos first.** Playlist indices 6, 9, 11, and 12
  were inspected individually on 2026-07-05. Index 6 and 9 have manual Arabic
  and English subtitles. Index 11 and 12 have manual Arabic but need English
  translation/review.
- **Choose one next lesson candidate.** Playlist index 6 (`-U-cnbFBc9c`) is the
  active candidate because it has Arabic subtitles, English subtitles, and audio
  downloaded locally. It still needs caption cleaning, review, provenance, and
  app-ready JSON before integration.
- **Confirm the local pipeline workspace.** Raw files are staged outside the app
  repo at `../content_pipeline/raw/06_-U-cnbFBc9c`.
- **Keep docs current.** Any playlist, caption, tool, or source-rights finding
  belongs in `docs/LESSON_INTAKE.md` and, if significant, a `reports/` note.

## A Bit Further: foundation phase

Goal: make lesson production repeatable and start replacing temporary English
learning leftovers with Arabic-specific systems.

- **Build content pipeline v1.** Create a repeatable flow for metadata capture,
  subtitle download, caption cleaning, English translation when missing, human
  review state, app-ready `content.json`, `audio.opus`, and validation.
- **Integrate one new lesson safely.** Add only one lesson after reviewed Arabic,
  reviewed English, provenance, app-ready JSON, and audio exist. Register it in
  the Dart catalog and `pubspec.yaml` with explicit asset lines.
- **Start the real Arabic glossary.** Keep the current inverted dictionary as
  dev scaffolding. Build a small reviewed glossary sample for one integrated
  lesson with surface form, normalized form, lemma, root, pattern/wazn, part of
  speech, English meaning, examples, synonyms, antonyms, and root family.
- **Map review/practice from Yalla English.** Inspect the English review builder,
  provider, and screens. Reuse product behavior where it fits, but do not copy
  English content or English-specific assumptions.
- **Validate routinely.** Run the lesson validator after content changes. Run
  Flutter analysis/tests/builds once Flutter and Android tooling are available.

## Down The Line: product and shipping phase

Goal: move from private dev shell to a releasable Arabic-learning app only after
content, legal, and technical foundations are stable.

- **Decide the durable content strategy.** Choose whether the app will use
  YouTube-derived lessons, teacher-recorded lessons, or a mix. Any public
  release needs rights/provenance cleared; `redistribution_permission:
  not_claimed` is not releasable.
- **Replace inherited legal/product text.** The copied Yalla English privacy and
  legal docs must become Yalla Arabic-specific before any public distribution.
- **Prepare app quality.** Enable Flutter/Android tooling, run `flutter pub get`,
  `flutter analyze`, `flutter test`, build a debug APK, and test on real Android
  devices.
- **Decide production services.** Choose release identity, Firebase/auth/account
  model, progress storage, content hosting, offline/download behavior, and
  telemetry/error reporting.
- **Create the release path.** Only after the above decisions, define signing,
  APK/AAB, internal testing, Play Console, privacy, and support workflows.

## Current Defaults

- Private/dev-only until content model and rights are stable.
- Yalla English remains read-only reference.
- Do not copy Yalla English course JSON/audio/content into Yalla Arabic.
- Playlist indices 7 and 10 are the only integrated lessons for now.
- No new lesson is integrated without reviewed Arabic, reviewed English,
  provenance, `content.json`, and `audio.opus`.
