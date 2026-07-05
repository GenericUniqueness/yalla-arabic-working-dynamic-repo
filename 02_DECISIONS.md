# Decisions

Last updated: 2026-07-05

## D1: Web (GitHub Pages) as primary deployment target
**Date**: 2026-07-05
**Decision**: Deploy to GitHub Pages. Android emulator blocked by CPU/Hyper-V. Windows desktop blocked by Firebase C++ SDK. Web confirmed working.
**Alternatives rejected**:
- Android emulator: CPU doesn't support x86_64 virtualization; Hyper-V prevents WHPX
- Windows desktop: Firebase C++ SDK linkage incompatible with VS 2019
- Physical Android device: User has no phone available

## D2: Keep course 1 bypass forcing bundled assets
**Date**: 2026-07-05
**Decision**: Keep `remotePath: lesson.courseId == 1 ? '' : assetPath` in `player_screen.dart:268`. This forces Course 1 to use `_player.setAsset()` instead of R2 streaming.
**Rationale**: The R2 bucket belongs to Yalla English production. We cannot upload our audio there. Bundled assets are the only option for local dev lessons.
**Alternatives rejected**:
- Upload to R2: prohibited by AGENTS.md rules (production R2 is off-limits)
- Use a different CDN: no free CDN set up yet; can be added later

## D3: MP3 format instead of Opus for web audio
**Date**: 2026-07-05
**Decision**: Convert all bundled audio from opus to MP3 (64kbps mono 44100Hz).
**Rationale**: GitHub Pages serves .opus files with wrong MIME type (`application/octet-stream`), causing HTML5 Audio to reject them with `MEDIA_ERR_SRC_NOT_SUPPORTED` (error code 4). MP3 is universally supported with correct MIME type `audio/mpeg`.
**Alternatives rejected**:
- Fix GitHub Pages MIME type: not configurable on free tier
- Use a different hosting provider: no free alternative set up
- Keep opus and stream from R2: R2 is off-limits per AGENTS.md

## D4: Bundle audio as assets instead of streaming
**Date**: 2026-07-05
**Decision**: Bundle MP3 files as Flutter web assets (~28MB total).
**Rationale**: No external hosting available. R2 is off-limits. GitHub Pages is the only deployment target.
**Alternatives rejected**:
- Stream from R2: off-limits per AGENTS.md
- Use a separate CDN: no free CDN configured
- Lazy-load audio: Flutter web asset bundling doesn't support this

## D5: Dart package name stays as `ez_english_app`
**Date**: 2026-07-05
**Decision**: Keep inherited Dart package name. Renaming would break all imports throughout the codebase.
**Rationale**: Package name is internal only; not user-visible. Renaming is high-risk for zero benefit.

## D6: 64kbps mono MP3 encoding
**Date**: 2026-07-05
**Decision**: Encode at 64kbps mono 44100Hz (slightly higher quality than initial 32kbps attempt).
**Rationale**: Speech-only content at 32kbps was clear but 64kbps provides better headroom. Total ~28MB is manageable for web asset loading.

## D7: Three audio loading tiers preserved
**Date**: 2026-07-05
**Decision**: Keep the 3-tier audio loading chain (local cache → R2 stream → bundled asset) in `audio_handler.dart`.
**Rationale**: Preserves production audio delivery path for when R2 is eventually used. Bundled lessons just skip to tier 3.

## D8: Use MCPs proactively, don't ask
**Date**: 2026-07-05
**Decision**: Available MCPs (context7, github, memory, playwright, sequential-thinking) should be used proactively without asking the user. Documented in `01_CONTEXT.md` and `05_KNOWLEDGE.md`.
**Rationale**: Repeatedly interrupting the model to say "use the MCP" wastes time. The docs now record MCP availability so future sessions know what tools are available.

## D9: ACOS docs are primary state, docs/ is detailed reference
**Date**: 2026-07-05
**Decision**: The 7 ACOS files (00-06) are the canonical project state for session handoffs. The `docs/` folder (27 files) is the detailed reference for architecture, specs, and pipeline work. Future sessions should read ACOS first, then `docs/START_HERE.md` for deep context.
**Rationale**: ACOS docs are compact and maintained per-session. The `docs/` folder has richer detail but can go stale (as happened with opus references). ACOS docs flag staleness.
