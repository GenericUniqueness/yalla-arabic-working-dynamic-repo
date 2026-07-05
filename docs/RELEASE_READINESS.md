# Release Readiness

Last updated: 2026-07-04

This is a staged map from current private dev shell to eventual APK/release.
It is not a request to start release work now.

## Stage 0: private dev shell

Current state.

- [x] App identity is Yalla Arabic.
- [x] Android package is `com.yallaarabic.dev`.
- [x] Auth is bypassed for local/dev work.
- [x] Two local lessons are integrated.
- [x] Documentation/spec baseline exists.
- [ ] Flutter toolchain works in the active environment.
- [ ] `flutter analyze` baseline is known.
- [ ] `flutter test` baseline is known.
- [ ] Debug APK build baseline is known.

## Stage 1: content foundation

- [ ] Source playlist/video list confirmed.
- [ ] Content pipeline workspace confirmed.
- [ ] Lesson validator runs on every generated `content.json`.
- [ ] Lesson intake tracker is populated.
- [ ] At least one new lesson is integrated through the documented pipeline.
- [ ] Arabic and English review process is defined.

## Stage 2: learning feature foundation

- [ ] Temporary word lookup replaced or gated behind dev-only mode.
- [ ] Arabic glossary schema implemented with reviewed sample entries.
- [ ] Word panel supports lemma/root/root-family display.
- [ ] Review questions use Arabic-safe vocabulary data.
- [ ] Player UX tested on a real Android device.

## Stage 3: internal test APK

- [ ] Dev package identity decision confirmed.
- [ ] Debug/internal APK build works.
- [ ] App installs on target devices.
- [ ] Audio playback, background playback, transcript, review, and settings work.
- [ ] Privacy/legal placeholders are not shown as final public text.
- [ ] Content rights are private-dev-safe.

## Stage 4: production decisions

Do not start casually.

- [ ] Final package id decision.
- [ ] Signing strategy.
- [ ] Firebase/auth/account model.
- [ ] Analytics decision.
- [ ] Content hosting decision.
- [ ] Privacy policy and account deletion flow.
- [ ] Store listing/assets.
- [ ] Production content rights.

## Current blockers

- Flutter/Dart were not available on PATH in the current shell.
- Yalla English reference repo is not available.
- Source Arabic playlist is available, but subtitle/audio extraction and
  per-video caption QA are still pending.
- Content rights are not release-ready.
- Legal/privacy docs are not Yalla Arabic release-ready.
