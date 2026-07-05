#!/usr/bin/env python3
"""
Build a draft Yalla Arabic content.json from paired Arabic/English VTT files.

This is a pipeline helper, not a release-quality translation/review substitute.
It preserves caption timing, pairs cues conservatively, and marks the output as
private-dev/unreviewed through provenance metadata.

Usage:
  python scripts/build_lesson_from_vtt.py \
    --arabic ../content_pipeline/raw/06_-U-cnbFBc9c/-U-cnbFBc9c.ar.vtt \
    --english ../content_pipeline/raw/06_-U-cnbFBc9c/-U-cnbFBc9c.en.vtt \
    --audio ../content_pipeline/raw/06_-U-cnbFBc9c/-U-cnbFBc9c.opus \
    --output ../content_pipeline/app_ready/06_-U-cnbFBc9c/content.json \
    --title "Easy Arabic Podcast | How to describe things? [Subtitles]" \
    --video-id=-U-cnbFBc9c \
    --playlist-index 6 \
    --copy-audio
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path


TIMING_RE = re.compile(
    r"^(?P<start>\d{2}:\d{2}(?::\d{2})?[\.,]\d{3})\s+-->\s+"
    r"(?P<end>\d{2}:\d{2}(?::\d{2})?[\.,]\d{3})"
)
TAG_RE = re.compile(r"<[^>]+>")
SPACE_RE = re.compile(r"\s+")


@dataclass(frozen=True)
class Cue:
    start: float
    end: float
    text: str


def main() -> int:
    args = parse_args()

    arabic_cues = parse_vtt(args.arabic)
    english_cues = parse_vtt(args.english)
    if not arabic_cues:
        print(f"ERROR: no Arabic cues found in {args.arabic}", file=sys.stderr)
        return 1
    if not english_cues:
        print(f"ERROR: no English cues found in {args.english}", file=sys.stderr)
        return 1

    sentences, warnings = build_sentences(arabic_cues, english_cues)
    output = {
        "lesson_title": args.title,
        "private_dev_source": {
            "source": "youtube_teacher_pilot_private_dev_only",
            "video_id": args.video_id,
            "webpage_url": f"https://www.youtube.com/watch?v={args.video_id}",
            "playlist_index": args.playlist_index,
            "redistribution_permission": "not_claimed",
            "arabic_caption_source": args.arabic.name,
            "english_caption_source": args.english.name,
            "review_status": "unreviewed_draft",
        },
        "sentences": sentences,
        "vocabulary": [],
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    if args.copy_audio:
        if not args.audio:
            print("ERROR: --copy-audio requires --audio", file=sys.stderr)
            return 1
        if not args.audio.exists():
            print(f"ERROR: audio file does not exist: {args.audio}", file=sys.stderr)
            return 1
        shutil.copy2(args.audio, args.output.with_name("audio.opus"))

    print(f"Wrote {args.output}")
    print(f"Arabic cues: {len(arabic_cues)}")
    print(f"English cues: {len(english_cues)}")
    print(f"Sentences: {len(sentences)}")
    for warning in warnings:
        print(f"WARNING: {warning}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build draft Yalla Arabic lesson JSON from paired VTT captions.",
    )
    parser.add_argument("--arabic", required=True, type=Path, help="Arabic VTT file.")
    parser.add_argument("--english", required=True, type=Path, help="English VTT file.")
    parser.add_argument("--audio", type=Path, help="Optional source audio file.")
    parser.add_argument("--output", required=True, type=Path, help="Output content.json.")
    parser.add_argument("--title", required=True, help="Lesson title.")
    parser.add_argument("--video-id", required=True, help="YouTube video id.")
    parser.add_argument("--playlist-index", required=True, type=int, help="Playlist index.")
    parser.add_argument(
        "--copy-audio",
        action="store_true",
        help="Copy --audio next to content.json as audio.opus.",
    )
    return parser.parse_args()


def parse_vtt(path: Path) -> list[Cue]:
    text = path.read_text(encoding="utf-8-sig")
    lines = text.splitlines()
    cues: list[Cue] = []
    i = 0

    while i < len(lines):
        line = lines[i].strip()
        match = TIMING_RE.match(line)
        if not match:
            i += 1
            continue

        start = parse_time(match.group("start"))
        end = parse_time(match.group("end"))
        i += 1
        text_lines: list[str] = []
        while i < len(lines) and lines[i].strip():
            text_lines.append(lines[i].strip())
            i += 1

        cue_text = clean_text(" ".join(text_lines))
        if cue_text and end > start:
            cues.append(Cue(start=start, end=end, text=cue_text))
    return cues


def parse_time(raw: str) -> float:
    raw = raw.replace(",", ".")
    parts = raw.split(":")
    if len(parts) == 2:
        minutes, seconds = parts
        return int(minutes) * 60 + float(seconds)
    if len(parts) == 3:
        hours, minutes, seconds = parts
        return int(hours) * 3600 + int(minutes) * 60 + float(seconds)
    raise ValueError(f"unsupported timestamp: {raw}")


def clean_text(raw: str) -> str:
    text = TAG_RE.sub("", raw)
    text = text.replace("&nbsp;", " ")
    return SPACE_RE.sub(" ", text).strip()


def build_sentences(arabic_cues: list[Cue], english_cues: list[Cue]) -> tuple[list[dict], list[str]]:
    warnings: list[str] = []
    if len(arabic_cues) == len(english_cues):
        pairs = list(zip(arabic_cues, english_cues, strict=True))
    else:
        warnings.append(
            f"cue count mismatch; Arabic={len(arabic_cues)} English={len(english_cues)}; paired by timestamp overlap"
        )
        pairs = [(arabic, best_english_match(arabic, english_cues)) for arabic in arabic_cues]

    sentences: list[dict] = []
    for index, (arabic, english) in enumerate(pairs):
        confidence = "high" if timings_close(arabic, english) else "needs_review"
        sentences.append(
            {
                "id": index,
                "english": english.text,
                "arabic": arabic.text,
                "start_time": round(arabic.start, 3),
                "end_time": round(arabic.end, 3),
                "source_caption_type": "human_ar_manual",
                "english_alignment_confidence": confidence,
            }
        )
    return sentences, warnings


def best_english_match(arabic: Cue, english_cues: list[Cue]) -> Cue:
    def score(candidate: Cue) -> tuple[float, float]:
        overlap = max(0.0, min(arabic.end, candidate.end) - max(arabic.start, candidate.start))
        midpoint_delta = abs(((arabic.start + arabic.end) / 2) - ((candidate.start + candidate.end) / 2))
        return (-overlap, midpoint_delta)

    return min(english_cues, key=score)


def timings_close(arabic: Cue, english: Cue) -> bool:
    return abs(arabic.start - english.start) <= 0.05 and abs(arabic.end - english.end) <= 0.05


if __name__ == "__main__":
    raise SystemExit(main())
