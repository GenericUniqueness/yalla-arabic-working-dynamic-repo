#!/usr/bin/env python3
"""
Validate Yalla Arabic lesson content.json files.

Default behavior:
  - validates every assets/courses/**/content.json file
  - exits non-zero only for structural errors
  - reports quality/legal/review concerns as warnings

Usage:
  python scripts/validate_lesson_content.py
  python scripts/validate_lesson_content.py assets/courses/course_01/lesson_07/main_story/content.json
  python scripts/validate_lesson_content.py --report reports/lesson_validation.md
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GLOB = "assets/courses/**/content.json"

LARGE_GAP_SECONDS = 12.0
SUSPICIOUS_FIRST_START_SECONDS = 1.5
COMPRESSED_ENGLISH_WORDS_PER_SECOND = 8.0
VERY_LONG_ARABIC_CHARS = 260
VERY_LONG_ENGLISH_CHARS = 260

ARABIC_RE = re.compile(r"[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]")
MOJIBAKE_MARKERS_RE = re.compile(r"[ØÙÐÑ]{2,}")
WORD_RE = re.compile(r"\S+")


@dataclass
class Issue:
    severity: str
    path: Path
    message: str
    index: int | None = None

    def render(self) -> str:
        loc = self.path.as_posix()
        if self.index is not None:
            loc = f"{loc}#{self.index}"
        return f"[{self.severity}] {loc}: {self.message}"


@dataclass
class LessonSummary:
    path: Path
    title: str = ""
    sentence_count: int = 0
    max_end_time: float = 0.0
    warnings: list[Issue] = field(default_factory=list)
    errors: list[Issue] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors


def main() -> int:
    args = parse_args()
    paths = resolve_paths(args.paths)
    summaries = [validate_file(path) for path in paths]

    output = render_report(summaries)
    print(output)

    if args.report:
        report_path = (ROOT / args.report).resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(output + "\n", encoding="utf-8")

    return 1 if any(not summary.ok for summary in summaries) else 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate Yalla Arabic lesson content.json files.",
    )
    parser.add_argument(
        "paths",
        nargs="*",
        help="Specific content.json files or directories. Defaults to all bundled course content.",
    )
    parser.add_argument(
        "--report",
        help="Optional Markdown report path, relative to repo root unless absolute.",
    )
    return parser.parse_args()


def resolve_paths(raw_paths: list[str]) -> list[Path]:
    if not raw_paths:
        return sorted(ROOT.glob(DEFAULT_GLOB))

    out: list[Path] = []
    for raw in raw_paths:
        path = Path(raw)
        if not path.is_absolute():
            path = ROOT / path
        if path.is_dir():
            out.extend(sorted(path.glob("**/content.json")))
        else:
            out.append(path)
    return sorted(dict.fromkeys(path.resolve() for path in out))


def validate_file(path: Path) -> LessonSummary:
    rel_path = path.relative_to(ROOT) if path.is_relative_to(ROOT) else path
    summary = LessonSummary(path=rel_path)

    if not path.exists():
        add_error(summary, "file does not exist")
        return summary

    try:
        raw = path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        add_error(summary, f"file is not valid UTF-8: {exc}")
        return summary
    except OSError as exc:
        add_error(summary, f"could not read file: {exc}")
        return summary

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        add_error(summary, f"invalid JSON: {exc}")
        return summary

    if isinstance(data, list):
        add_warning(summary, "root is a legacy sentence list; new content should use an object root")
        root = {"lesson_title": "", "sentences": data}
    elif isinstance(data, dict):
        root = data
    else:
        add_error(summary, f"root must be object or legacy list, got {type(data).__name__}")
        return summary

    title = root.get("lesson_title")
    if isinstance(title, str):
        summary.title = title.strip()
    if not summary.title:
        add_error(summary, "lesson_title is missing or empty")

    validate_source_metadata(summary, root)

    sentences = root.get("sentences")
    if not isinstance(sentences, list):
        add_error(summary, "sentences must be an array")
        return summary
    if not sentences:
        add_error(summary, "sentences array is empty")
        return summary

    summary.sentence_count = len(sentences)
    seen_ids: set[int] = set()
    previous_end: float | None = None

    for index, raw_sentence in enumerate(sentences):
        if not isinstance(raw_sentence, dict):
            add_error(summary, f"sentence is {type(raw_sentence).__name__}, expected object", index)
            continue

        sentence_id = raw_sentence.get("id", index)
        if not isinstance(sentence_id, int):
            add_error(summary, "id must be an integer", index)
        elif sentence_id in seen_ids:
            add_error(summary, f"duplicate id {sentence_id}", index)
        else:
            seen_ids.add(sentence_id)
            if sentence_id != index:
                add_warning(summary, f"id {sentence_id} does not match index {index}", index)

        arabic = text_field(raw_sentence, "arabic", "ara")
        english = text_field(raw_sentence, "english", "text")
        start = number_field(raw_sentence, "start_time", "start")
        end = number_field(raw_sentence, "end_time", "end")

        if "ara" in raw_sentence or "text" in raw_sentence or "start" in raw_sentence or "end" in raw_sentence:
            add_warning(summary, "uses legacy field aliases; prefer arabic/english/start_time/end_time", index)

        validate_text(summary, "arabic", arabic, index)
        validate_text(summary, "english", english, index)
        validate_arabic_quality(summary, arabic, index)
        validate_english_quality(summary, english, start, end, index)

        if start is None:
            add_error(summary, "start_time is missing or not numeric", index)
        if end is None:
            add_error(summary, "end_time is missing or not numeric", index)
        if start is None or end is None:
            continue

        if start < 0:
            add_error(summary, "start_time must be >= 0", index)
        if end <= start:
            add_error(summary, "end_time must be greater than start_time", index)
        if previous_end is not None:
            gap = start - previous_end
            if start < previous_end:
                add_error(summary, f"timestamp overlaps previous sentence by {previous_end - start:.3f}s", index)
            elif gap > LARGE_GAP_SECONDS:
                add_warning(summary, f"large gap before sentence: {gap:.3f}s", index)
        if index == 0 and start > SUSPICIOUS_FIRST_START_SECONDS:
            add_warning(summary, f"first sentence starts at {start:.3f}s", index)

        previous_end = end
        summary.max_end_time = max(summary.max_end_time, end)

    audio_path = path.with_name("audio.opus")
    if not audio_path.exists():
        add_warning(summary, "matching audio.opus is missing on disk")

    return summary


def validate_source_metadata(summary: LessonSummary, root: dict[str, Any]) -> None:
    source = root.get("private_dev_source")
    if source is None:
        add_warning(summary, "private_dev_source metadata is missing")
        return
    if not isinstance(source, dict):
        add_warning(summary, "private_dev_source must be an object")
        return

    for key in ["source", "video_id", "webpage_url", "playlist_index", "redistribution_permission"]:
        if key not in source or source[key] in ("", None):
            add_warning(summary, f"private_dev_source.{key} is missing")

    if source.get("redistribution_permission") == "not_claimed":
        add_warning(summary, "redistribution_permission is not_claimed; content is not release-ready")


def validate_text(summary: LessonSummary, field_name: str, value: str | None, index: int) -> None:
    if value is None:
        add_error(summary, f"{field_name} is missing or not a string", index)
        return
    if not value.strip():
        add_error(summary, f"{field_name} is empty", index)
        return

    limit = VERY_LONG_ARABIC_CHARS if field_name == "arabic" else VERY_LONG_ENGLISH_CHARS
    if len(value) > limit:
        add_warning(summary, f"{field_name} line is long ({len(value)} chars)", index)


def validate_arabic_quality(summary: LessonSummary, arabic: str | None, index: int) -> None:
    if not arabic:
        return
    has_arabic = bool(ARABIC_RE.search(arabic))
    has_mojibake = bool(MOJIBAKE_MARKERS_RE.search(arabic))
    if not has_arabic:
        add_warning(summary, "arabic line contains no Arabic Unicode letters", index)
    if has_mojibake:
        add_warning(summary, "arabic line contains possible mojibake markers", index)


def validate_english_quality(
    summary: LessonSummary,
    english: str | None,
    start: float | None,
    end: float | None,
    index: int,
) -> None:
    if not english or start is None or end is None or end <= start:
        return
    words = WORD_RE.findall(english)
    duration = end - start
    if len(words) >= 8 and duration > 0:
        words_per_second = len(words) / duration
        if words_per_second > COMPRESSED_ENGLISH_WORDS_PER_SECOND:
            add_warning(
                summary,
                f"compressed English timing: {len(words)} words in {duration:.3f}s ({words_per_second:.1f} words/sec)",
                index,
            )


def text_field(row: dict[str, Any], preferred: str, legacy: str) -> str | None:
    value = row.get(preferred, row.get(legacy))
    return value if isinstance(value, str) else None


def number_field(row: dict[str, Any], preferred: str, legacy: str) -> float | None:
    value = row.get(preferred, row.get(legacy))
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    return None


def add_error(summary: LessonSummary, message: str, index: int | None = None) -> None:
    summary.errors.append(Issue("error", summary.path, message, index))


def add_warning(summary: LessonSummary, message: str, index: int | None = None) -> None:
    summary.warnings.append(Issue("warning", summary.path, message, index))


def render_report(summaries: list[LessonSummary]) -> str:
    total_errors = sum(len(summary.errors) for summary in summaries)
    total_warnings = sum(len(summary.warnings) for summary in summaries)

    lines = [
        "# Lesson Content Validation",
        "",
        f"Files checked: {len(summaries)}",
        f"Errors: {total_errors}",
        f"Warnings: {total_warnings}",
        "",
    ]

    for summary in summaries:
        status = "PASS" if summary.ok else "FAIL"
        title = f" - {summary.title}" if summary.title else ""
        lines.extend(
            [
                f"## {status}: `{summary.path.as_posix()}`{title}",
                "",
                f"- sentences: {summary.sentence_count}",
                f"- max end time: {summary.max_end_time:.3f}s",
                f"- errors: {len(summary.errors)}",
                f"- warnings: {len(summary.warnings)}",
                "",
            ]
        )
        for issue in summary.errors + summary.warnings:
            lines.append(f"- {issue.render()}")
        if summary.errors or summary.warnings:
            lines.append("")

    return "\n".join(lines).rstrip()


if __name__ == "__main__":
    sys.exit(main())
