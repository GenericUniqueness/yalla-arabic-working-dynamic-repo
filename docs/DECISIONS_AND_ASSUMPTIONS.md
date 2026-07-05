# Decisions and Assumptions

Last updated: 2026-07-04

Use this file for product/technical decisions that future agents should not have
to rediscover.

## Decisions

- Yalla Arabic is for English speakers learning Modern Standard Arabic /
  Al-Fusha.
- The app is currently private dev-only.
- Yalla English is inspiration and read-only reference, not a source of copied
  production content.
- Lessons are listening-first. Audio plus aligned Arabic/English transcript is
  the core unit.
- Videos with usable Arabic subtitles are the first content priority.
- Missing English subtitles can be generated, but translations need review.
- The Arabic word panel should include root-word relationships, not only a
  direct dictionary definition.
- Keep app identity as `Yalla Arabic` and Android package `com.yallaarabic.dev`.
- Keep the inherited Dart package name `ez_english_app` for now to avoid import
  churn.

## Assumptions

- Existing Yalla Arabic code is allowed to change, but Yalla English is not.
- The current two bundled lessons are useful dev fixtures and should not be
  broken while building the next layer.
- The long-term content source may shift from YouTube-derived lessons to
  purpose-recorded lessons.
- Human review is required for release-quality Arabic transcripts and English
  translations.
- APK/deployment work is later, after the content and app foundations are stable.

## Risks

- YouTube captions may be missing, low quality, unavailable, or legally
  unsuitable.
- Machine-generated English translations may be fluent but inaccurate.
- Arabic tokenization/morphology can produce bad word-panel matches if treated
  like English.
- Existing code still carries inherited English naming and assumptions.
- The current word panel uses temporary inverted English dictionary data.
- Old docs mention Mac-specific paths that may not exist in this Windows
  workspace.

## Decision log

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-07-04 | Add handoff-first docs instead of rewriting all older docs. | Existing docs are useful but need a top-level resume/task layer. |
| 2026-07-04 | Keep new docs mostly ASCII. | Existing terminal output showed mojibake for some non-ASCII text. |
