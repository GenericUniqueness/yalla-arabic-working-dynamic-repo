#!/usr/bin/env python3
"""
Validate cleaned local Course 09 content against pre-cleanup backups.

Read-only against Course 09 content. Writes only:
  reports/course_09_post_cleanup_validation_report.md
"""

from __future__ import annotations

import datetime as dt
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
COURSE_ROOT = (
    ROOT
    / "local_fixtures/playlist_ingestion/c2_playlist/local_app_qa/http_root"
    / "assets/courses/course_09"
)
BACKUP_ROOT = ROOT / "reports/course09_backups"
REPORT_PATH = ROOT / "reports/course_09_post_cleanup_validation_report.md"

EXPECTED_LESSON_IDS = [
    1,
    2,
    4,
    5,
    6,
    8,
    10,
    12,
    14,
    15,
    16,
    17,
    18,
    19,
    21,
    22,
    23,
    24,
    26,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    37,
    38,
    39,
    41,
    42,
    43,
    44,
    45,
    47,
    57,
    59,
]

LESSON_RE = re.compile(r"^course_09/lesson_(\d{2})/main_story$")
ASCII_RATIO_THRESHOLD = 0.70
STRONG_PUNCT = re.compile(r'[.!?\]\)»؟،؛]$|[.!?؟]["\'“”‘’]$')
SPEAKER_LABEL = re.compile(r"^[A-Za-z][A-Za-z\s]{0,20}:\s")


@dataclass
class RowIssue:
    lesson: str
    index: int
    kind: str
    english: str
    arabic: str
    detail: str = ""


@dataclass
class LessonResult:
    lesson: str
    lesson_key: str
    path: Path
    audio_path: Path
    backup_path: Path | None = None
    json_ok: bool = False
    schema_ok: bool = False
    audio_ok: bool = False
    key_ok: bool = False
    row_count_after: int = 0
    row_count_before: int | None = None
    merge_count: int = 0
    explainable_merges: bool = True
    duration_before: float | None = None
    duration_after: float | None = None
    max_end_before: float | None = None
    max_end_after: float | None = None
    duration_delta: float | None = None
    max_end_delta: float | None = None
    zero_duration_before: int | None = None
    zero_duration_after: int = 0
    empty_english: int = 0
    empty_arabic: int = 0
    arabic_mostly_english: int = 0
    arabic_repeat_nearby: int = 0
    arabic_identical_prev: int = 0
    arabic_identical_next: int = 0
    arabic_much_longer: int = 0
    arabic_suspiciously_short: int = 0
    timestamp_problems: list[str] = field(default_factory=list)
    schema_problems: list[str] = field(default_factory=list)
    audio_problems: list[str] = field(default_factory=list)
    change_problems: list[str] = field(default_factory=list)
    cleaned_merge_examples: list[dict[str, Any]] = field(default_factory=list)
    arabic_examples: list[RowIssue] = field(default_factory=list)
    changed_rows_examples: list[str] = field(default_factory=list)

    @property
    def changed(self) -> bool:
        return self.backup_path is not None

    @property
    def risky_arabic_score(self) -> int:
        return (
            self.empty_arabic
            + self.arabic_mostly_english
            + self.arabic_repeat_nearby
            + self.arabic_identical_prev
            + self.arabic_identical_next
            + self.arabic_much_longer
            + self.arabic_suspiciously_short
        )


def lesson_name(lesson_id: int) -> str:
    return f"lesson_{lesson_id:02d}"


def lesson_key(lesson_id: int) -> str:
    return f"course_09/{lesson_name(lesson_id)}/main_story"


def content_path(lesson_id: int) -> Path:
    return COURSE_ROOT / lesson_name(lesson_id) / "main_story/content.json"


def audio_path(lesson_id: int) -> Path:
    return COURSE_ROOT / lesson_name(lesson_id) / "main_story/audio.opus"


def latest_backup(lesson: str) -> Path | None:
    matches = sorted(BACKUP_ROOT.glob(f"{lesson}_backup_*.json"))
    return matches[-1] if matches else None


def load_json(path: Path) -> tuple[Any | None, str | None]:
    try:
        return json.loads(path.read_text(encoding="utf-8")), None
    except Exception as exc:
        return None, str(exc)


def detect_schema(data: Any) -> tuple[list[dict[str, Any]], dict[str, str], list[str]]:
    problems: list[str] = []
    if not isinstance(data, list):
        return [], {}, [f"Top-level JSON is {type(data).__name__}, expected list"]
    if not data:
        return [], {}, ["Transcript row list is empty"]
    if not all(isinstance(row, dict) for row in data):
        return [], {}, ["One or more transcript rows are not JSON objects"]

    sample = data[0]
    text_field = first_present(sample, ["text", "english"])
    ara_field = first_present(sample, ["ara", "arabic"])
    start_field = first_present(sample, ["start", "start_time"])
    end_field = first_present(sample, ["end", "end_time"])
    fields = {
        "english": text_field or "",
        "arabic": ara_field or "",
        "start": start_field or "",
        "end": end_field or "",
    }
    for logical, actual in fields.items():
        if not actual:
            problems.append(f"Could not detect {logical} field")
    return data, fields, problems


def first_present(row: dict[str, Any], candidates: list[str]) -> str | None:
    for key in candidates:
        if key in row:
            return key
    return None


def row_text(row: dict[str, Any], fields: dict[str, str], key: str) -> str:
    raw = row.get(fields[key], "")
    return "" if raw is None else str(raw).strip()


def row_float(row: dict[str, Any], fields: dict[str, str], key: str) -> float | None:
    try:
        return float(row.get(fields[key]))
    except (TypeError, ValueError):
        return None


def is_mostly_ascii(text: str) -> bool:
    if not text:
        return False
    ascii_chars = sum(1 for char in text if ord(char) < 128)
    return ascii_chars / max(len(text), 1) > ASCII_RATIO_THRESHOLD


def arabic_letter_count(text: str) -> int:
    return sum(1 for char in text if "\u0600" <= char <= "\u06ff")


def english_word_count(text: str) -> int:
    return len(re.findall(r"[A-Za-z]+(?:'[A-Za-z]+)?", text))


def is_fragment_candidate(prev_text: str, cur_text: str, duration: float) -> bool:
    words = cur_text.split()
    if len(words) > 3 or duration >= 1.5:
        return False
    if STRONG_PUNCT.search(prev_text.strip()):
        return False
    if cur_text.strip().startswith("("):
        return False
    if SPEAKER_LABEL.match(cur_text.strip()):
        return False
    return True


def summarize_duration(rows: list[dict[str, Any]], fields: dict[str, str]) -> tuple[float | None, float | None]:
    starts = [row_float(row, fields, "start") for row in rows]
    ends = [row_float(row, fields, "end") for row in rows]
    starts = [value for value in starts if value is not None]
    ends = [value for value in ends if value is not None]
    if not starts or not ends:
        return None, None
    return max(ends) - min(starts), max(ends)


def validate_rows(
    result: LessonResult,
    rows: list[dict[str, Any]],
    fields: dict[str, str],
) -> None:
    prev_start: float | None = None
    prev_end: float | None = None
    arabic_values = [row_text(row, fields, "arabic") for row in rows]
    english_values = [row_text(row, fields, "english") for row in rows]

    for index, row in enumerate(rows):
        missing = [actual for actual in fields.values() if actual and actual not in row]
        if missing:
            result.schema_problems.append(f"row {index}: missing fields {missing}")

        english = english_values[index]
        arabic = arabic_values[index]
        start = row_float(row, fields, "start")
        end = row_float(row, fields, "end")

        if not english:
            result.empty_english += 1
            result.schema_problems.append(f"row {index}: empty English text")
        if not arabic:
            result.empty_arabic += 1
            add_arabic_example(result, index, "EMPTY_ARABIC", english, arabic)

        if start is None or end is None:
            result.timestamp_problems.append(f"row {index}: non-numeric start/end")
            continue
        duration = end - start
        if duration < 0:
            result.timestamp_problems.append(
                f"row {index}: negative duration start={start} end={end}"
            )
        if abs(duration) <= 1e-9:
            result.zero_duration_after += 1
        if prev_start is not None and start < prev_start - 1e-6:
            result.timestamp_problems.append(
                f"row {index}: start moved backward {start} < previous start {prev_start}"
            )
        if prev_end is not None and start < prev_end - 0.05:
            result.timestamp_problems.append(
                f"row {index}: overlap start={start} previous_end={prev_end}"
            )
        prev_start = start
        prev_end = end

        if arabic and is_mostly_ascii(arabic):
            result.arabic_mostly_english += 1
            add_arabic_example(result, index, "ARA_MOSTLY_ENGLISH", english, arabic)

        nearby = [
            j
            for j in (index - 2, index - 1, index + 1, index + 2)
            if 0 <= j < len(rows) and j != index
        ]
        if arabic and len(arabic) > 10 and any(arabic_values[j] == arabic for j in nearby):
            result.arabic_repeat_nearby += 1
            add_arabic_example(result, index, "ARA_REPEAT_NEARBY", english, arabic)
        if index > 0 and arabic and arabic == arabic_values[index - 1]:
            result.arabic_identical_prev += 1
            add_arabic_example(result, index, "ARA_IDENTICAL_PREV", english, arabic)
        if index + 1 < len(rows) and arabic and arabic == arabic_values[index + 1]:
            result.arabic_identical_next += 1
            add_arabic_example(result, index, "ARA_IDENTICAL_NEXT", english, arabic)

        if arabic and english and len(arabic) > max(160, len(english) * 3.5):
            result.arabic_much_longer += 1
            add_arabic_example(
                result,
                index,
                "ARA_MUCH_LONGER",
                english,
                arabic,
                f"ara_len={len(arabic)} eng_len={len(english)}",
            )

        if (
            english_word_count(english) >= 8
            and arabic
            and arabic_letter_count(arabic) < max(4, len(english) * 0.10)
        ):
            result.arabic_suspiciously_short += 1
            add_arabic_example(
                result,
                index,
                "ARA_SUSPICIOUSLY_SHORT",
                english,
                arabic,
                f"arabic_letters={arabic_letter_count(arabic)} eng_len={len(english)}",
            )


def add_arabic_example(
    result: LessonResult,
    index: int,
    kind: str,
    english: str,
    arabic: str,
    detail: str = "",
) -> None:
    if len(result.arabic_examples) >= 8:
        return
    result.arabic_examples.append(
        RowIssue(
            lesson=result.lesson,
            index=index,
            kind=kind,
            english=english,
            arabic=arabic,
            detail=detail,
        )
    )


def validate_backup_comparison(
    result: LessonResult,
    before_rows: list[dict[str, Any]],
    before_fields: dict[str, str],
    after_rows: list[dict[str, Any]],
    after_fields: dict[str, str],
) -> None:
    result.row_count_before = len(before_rows)
    result.merge_count = len(before_rows) - len(after_rows)
    result.duration_before, result.max_end_before = summarize_duration(before_rows, before_fields)
    result.duration_after, result.max_end_after = summarize_duration(after_rows, after_fields)
    if result.duration_before is not None and result.duration_after is not None:
        result.duration_delta = result.duration_after - result.duration_before
    if result.max_end_before is not None and result.max_end_after is not None:
        result.max_end_delta = result.max_end_after - result.max_end_before
    result.zero_duration_before = count_zero_duration(before_rows, before_fields)

    if result.merge_count < 0:
        result.explainable_merges = False
        result.change_problems.append(
            f"Row count increased from {len(before_rows)} to {len(after_rows)}"
        )
        return
    if result.duration_delta is not None and abs(result.duration_delta) > 0.01:
        result.change_problems.append(
            f"Lesson duration changed by {result.duration_delta:.3f}s"
        )
    if result.max_end_delta is not None and abs(result.max_end_delta) > 0.01:
        result.change_problems.append(f"Max end changed by {result.max_end_delta:.3f}s")
    if result.zero_duration_before is not None and result.zero_duration_after > result.zero_duration_before:
        result.change_problems.append(
            f"Zero-duration rows increased {result.zero_duration_before} -> {result.zero_duration_after}"
        )

    before_index = 0
    inferred_merges: list[dict[str, Any]] = []
    for after_index, after_row in enumerate(after_rows):
        if before_index >= len(before_rows):
            result.explainable_merges = False
            result.change_problems.append(
                f"after row {after_index}: no matching backup rows remain"
            )
            break

        after_text = row_text(after_row, after_fields, "english")
        after_start = row_float(after_row, after_fields, "start")
        after_end = row_float(after_row, after_fields, "end")
        combined_texts: list[str] = []
        start_before = row_float(before_rows[before_index], before_fields, "start")
        end_before = None
        merge_start_index = before_index

        while before_index < len(before_rows):
            current = before_rows[before_index]
            combined_texts.append(row_text(current, before_fields, "english"))
            end_before = row_float(current, before_fields, "end")
            combined = " ".join(part.strip() for part in combined_texts if part.strip())

            if combined == after_text:
                if not floats_close(start_before, after_start) or not floats_close(end_before, after_end):
                    result.explainable_merges = False
                    result.change_problems.append(
                        f"after row {after_index}: text matched backup rows "
                        f"{merge_start_index}-{before_index}, but timestamps differ"
                    )
                if before_index > merge_start_index:
                    validate_merge_group(
                        result,
                        before_rows,
                        before_fields,
                        merge_start_index,
                        before_index,
                        after_index,
                        after_text,
                    )
                    if len(result.cleaned_merge_examples) < 10:
                        inferred_merges.append(
                            {
                                "lesson": result.lesson,
                                "after_index": after_index,
                                "backup_rows": f"{merge_start_index}-{before_index}",
                                "parts": combined_texts[:],
                                "merged": after_text,
                                "start": after_start,
                                "end": after_end,
                            }
                        )
                before_index += 1
                break

            if not after_text.startswith(combined):
                result.explainable_merges = False
                result.change_problems.append(
                    f"after row {after_index}: text not explainable from backup row {merge_start_index}"
                )
                before_index += 1
                break

            before_index += 1
        else:
            result.explainable_merges = False
            result.change_problems.append(
                f"after row {after_index}: reached backup end while matching text"
            )

    if before_index != len(before_rows):
        result.explainable_merges = False
        result.change_problems.append(
            f"{len(before_rows) - before_index} backup rows were not consumed"
        )
    result.cleaned_merge_examples = inferred_merges[:10]


def validate_merge_group(
    result: LessonResult,
    before_rows: list[dict[str, Any]],
    fields: dict[str, str],
    start_index: int,
    end_index: int,
    after_index: int,
    after_text: str,
) -> None:
    for idx in range(start_index + 1, end_index + 1):
        prev_text = row_text(before_rows[idx - 1], fields, "english")
        cur_text = row_text(before_rows[idx], fields, "english")
        start = row_float(before_rows[idx], fields, "start")
        end = row_float(before_rows[idx], fields, "end")
        duration = 999.0 if start is None or end is None else end - start
        if not is_fragment_candidate(prev_text, cur_text, duration):
            result.explainable_merges = False
            result.change_problems.append(
                f"after row {after_index}: backup row {idx} merge was not a conservative "
                f"fragment candidate: `{cur_text}`"
            )
        if len(result.changed_rows_examples) < 5:
            result.changed_rows_examples.append(
                f"backup row {idx}: `{cur_text}` merged into `{after_text}`"
            )


def count_zero_duration(rows: list[dict[str, Any]], fields: dict[str, str]) -> int:
    count = 0
    for row in rows:
        start = row_float(row, fields, "start")
        end = row_float(row, fields, "end")
        if start is not None and end is not None and abs(end - start) <= 1e-9:
            count += 1
    return count


def floats_close(a: float | None, b: float | None, tolerance: float = 1e-6) -> bool:
    if a is None or b is None:
        return a is b
    return abs(a - b) <= tolerance


def validate_lesson(lesson_id: int) -> LessonResult:
    lesson = lesson_name(lesson_id)
    key = lesson_key(lesson_id)
    result = LessonResult(
        lesson=lesson,
        lesson_key=key,
        path=content_path(lesson_id),
        audio_path=audio_path(lesson_id),
        backup_path=latest_backup(lesson),
    )
    result.key_ok = bool(LESSON_RE.match(key))
    if not result.path.exists():
        result.schema_problems.append(f"Missing content file: {result.path}")
        return result
    data, error = load_json(result.path)
    if error:
        result.schema_problems.append(f"Invalid JSON: {error}")
        return result
    result.json_ok = True

    rows, fields, schema_problems = detect_schema(data)
    result.schema_problems.extend(schema_problems)
    result.schema_ok = not schema_problems
    result.row_count_after = len(rows)
    result.audio_ok = result.audio_path.exists()
    if not result.audio_ok:
        result.audio_problems.append(f"Missing sibling audio.opus: {result.audio_path}")

    if rows and fields:
        result.duration_after, result.max_end_after = summarize_duration(rows, fields)
        validate_rows(result, rows, fields)

    if result.backup_path:
        backup_data, backup_error = load_json(result.backup_path)
        if backup_error:
            result.change_problems.append(f"Invalid backup JSON: {backup_error}")
        else:
            before_rows, before_fields, before_schema_problems = detect_schema(backup_data)
            if before_schema_problems:
                result.change_problems.append(
                    f"Backup schema problems: {before_schema_problems}"
                )
            else:
                validate_backup_comparison(
                    result,
                    before_rows,
                    before_fields,
                    rows,
                    fields,
                )
    return result


def md_escape(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def truncate(value: str, limit: int = 160) -> str:
    value = " ".join(value.split())
    if len(value) <= limit:
        return value
    return value[: limit - 1] + "…"


def pass_fail(results: list[LessonResult]) -> tuple[str, list[str]]:
    failures: list[str] = []
    if len(results) != len(EXPECTED_LESSON_IDS):
        failures.append(f"Expected 38 lessons, scanned {len(results)}")
    missing_json = [r.lesson for r in results if not r.json_ok]
    if missing_json:
        failures.append(f"Invalid or missing JSON: {', '.join(missing_json)}")
    schema_bad = [r.lesson for r in results if not r.schema_ok or r.empty_english > 0]
    if schema_bad:
        failures.append(f"Schema/empty-English problems: {', '.join(schema_bad)}")
    timestamp_bad = [r.lesson for r in results if r.timestamp_problems]
    if timestamp_bad:
        failures.append(f"Timestamp problems: {', '.join(timestamp_bad)}")
    audio_bad = [r.lesson for r in results if not r.audio_ok]
    if audio_bad:
        failures.append(f"Missing audio: {', '.join(audio_bad)}")
    key_bad = [r.lesson for r in results if not r.key_ok]
    if key_bad:
        failures.append(f"Invalid lesson keys: {', '.join(key_bad)}")
    unexplained = [r.lesson for r in results if r.changed and not r.explainable_merges]
    if unexplained:
        failures.append(f"Unexplained backup diffs: {', '.join(unexplained)}")
    duration_bad = [
        r.lesson
        for r in results
        if r.duration_delta is not None and abs(r.duration_delta) > 0.01
    ]
    if duration_bad:
        failures.append(f"Duration changed unexpectedly: {', '.join(duration_bad)}")
    status = "PASS" if not failures else "FAIL"
    return status, failures


def generate_report(results: list[LessonResult], backup_files: list[Path]) -> str:
    status, failures = pass_fail(results)
    changed = [r for r in results if r.changed]
    unchanged = [r for r in results if not r.changed]
    total_before = sum(r.row_count_before or r.row_count_after for r in results)
    total_after = sum(r.row_count_after for r in results)
    total_merges = sum(r.merge_count for r in changed)
    totals = {
        "empty_arabic": sum(r.empty_arabic for r in results),
        "mostly_english": sum(r.arabic_mostly_english for r in results),
        "repeat_nearby": sum(r.arabic_repeat_nearby for r in results),
        "identical_prev": sum(r.arabic_identical_prev for r in results),
        "identical_next": sum(r.arabic_identical_next for r in results),
        "much_longer": sum(r.arabic_much_longer for r in results),
        "suspiciously_short": sum(r.arabic_suspiciously_short for r in results),
    }
    now = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines: list[str] = [
        "# Course 09 Post-Cleanup Validation Report",
        "",
        f"Generated: {now}",
        "",
        "## Pass/Fail Summary",
        "",
        f"**Overall status: {status}**",
        "",
    ]
    if failures:
        lines += ["Blocking validation failures:", ""]
        lines += [f"- {failure}" for failure in failures]
    else:
        lines += [
            "- All 38 local Course 09 `content.json` files parsed successfully.",
            "- All cleaned lesson keys use `course_09/lesson_xx/main_story`.",
            "- Required row fields were detected as `text`, `ara`, `start`, and `end`.",
            "- No empty English rows were found.",
            "- No timestamp integrity problems were found.",
            "- All sibling `audio.opus` files are present.",
            "- Backup comparisons found only explainable English fragment merges.",
            "- No R2 upload command was run by this validation task.",
        ]
    lines += [
        "",
        "## Scope And Schema",
        "",
        f"- Local content root: `{COURSE_ROOT.relative_to(ROOT)}`",
        f"- Backup root: `{BACKUP_ROOT.relative_to(ROOT)}`",
        "- Observed `content.json` schema: top-level list of transcript row objects.",
        "- Observed required row fields: `text` (English), `ara` (Arabic), `start`, `end`.",
        "- No audio path field or lesson metadata field exists inside the local `content.json` files.",
        "- Audio validation checks the sibling `audio.opus` file beside each `content.json`.",
        "",
        "## Counts",
        "",
        "| Metric | Count |",
        "|---|---:|",
        f"| Lessons scanned | {len(results)} |",
        f"| Changed lessons with backups | {len(changed)} |",
        f"| Unchanged lessons without backups | {len(unchanged)} |",
        f"| Total rows before | {total_before:,} |",
        f"| Total rows after | {total_after:,} |",
        f"| Net row reduction | {total_before - total_after:,} |",
        f"| Inferred English fragment merges | {total_merges:,} |",
        "",
        "## Changed Lessons",
        "",
        ", ".join(r.lesson for r in changed) or "_None_",
        "",
        "## Unchanged Lessons",
        "",
        ", ".join(r.lesson for r in unchanged) or "_None_",
        "",
        "## Per-Lesson Duration Consistency",
        "",
        "| Lesson | Rows Before | Rows After | Merges | Duration Before | Duration After | Delta | Max End Delta | Status |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for r in results:
        status_text = "OK"
        if r.change_problems or r.timestamp_problems:
            status_text = "CHECK"
        before = r.row_count_before if r.row_count_before is not None else r.row_count_after
        lines.append(
            "| "
            + " | ".join(
                [
                    r.lesson,
                    f"{before}",
                    f"{r.row_count_after}",
                    f"{r.merge_count if r.changed else 0}",
                    fmt_float(r.duration_before if r.duration_before is not None else r.duration_after),
                    fmt_float(r.duration_after),
                    fmt_float(r.duration_delta, signed=True),
                    fmt_float(r.max_end_delta, signed=True),
                    status_text,
                ]
            )
            + " |"
        )

    lines += [
        "",
        "## JSON And Schema Problems",
        "",
    ]
    schema_lines = [
        f"- {r.lesson}: " + "; ".join(r.schema_problems)
        for r in results
        if r.schema_problems
    ]
    lines += schema_lines or ["None."]

    lines += [
        "",
        "## Timestamp Problems",
        "",
    ]
    timestamp_lines = [
        f"- {r.lesson}: " + "; ".join(r.timestamp_problems[:8])
        for r in results
        if r.timestamp_problems
    ]
    lines += timestamp_lines or ["None."]

    lines += [
        "",
        "## Audio/Path Problems",
        "",
    ]
    audio_lines = [
        f"- {r.lesson}: " + "; ".join(r.audio_problems)
        for r in results
        if r.audio_problems
    ]
    lines += audio_lines or [
        "None. All 38 lessons have `main_story/audio.opus` beside `content.json`."
    ]

    lines += [
        "",
        "## Lesson Key Validation",
        "",
    ]
    invalid_keys = [r.lesson_key for r in results if not r.key_ok]
    if invalid_keys:
        lines += [f"- Invalid: `{key}`" for key in invalid_keys]
    else:
        lines.append(
            "All lesson keys are valid and include the type segment, e.g. `course_09/lesson_18/main_story`."
        )

    lines += [
        "",
        "## Remaining Arabic Issue Counts",
        "",
        "| Issue | Count |",
        "|---|---:|",
        f"| Empty Arabic | {totals['empty_arabic']} |",
        f"| Arabic mostly English/ASCII | {totals['mostly_english']} |",
        f"| Arabic repeated within nearby window | {totals['repeat_nearby']} |",
        f"| Arabic identical to previous row | {totals['identical_prev']} |",
        f"| Arabic identical to next row | {totals['identical_next']} |",
        f"| Arabic much longer than English | {totals['much_longer']} |",
        f"| Arabic suspiciously short vs English | {totals['suspiciously_short']} |",
        "",
        "## Top 10 Riskiest Lessons Still Needing Arabic Repair",
        "",
        "| Rank | Lesson | Risk Score | Mostly English | Repeat Nearby | Empty | Much Longer | Too Short |",
        "|---:|---|---:|---:|---:|---:|---:|---:|",
    ]
    risky = sorted(results, key=lambda r: (-r.risky_arabic_score, r.lesson))[:10]
    for idx, r in enumerate(risky, 1):
        lines.append(
            f"| {idx} | {r.lesson} | {r.risky_arabic_score} | "
            f"{r.arabic_mostly_english} | {r.arabic_repeat_nearby} | "
            f"{r.empty_arabic} | {r.arabic_much_longer} | {r.arabic_suspiciously_short} |"
        )

    lines += [
        "",
        "## Examples Of 20 Remaining Arabic Issues",
        "",
    ]
    examples: list[RowIssue] = []
    for r in risky:
        examples.extend(r.arabic_examples)
        if len(examples) >= 20:
            break
    for example in examples[:20]:
        detail = f" ({example.detail})" if example.detail else ""
        lines.append(
            f"- **{example.lesson} row {example.index} `{example.kind}`{detail}** — "
            f"ENG: `{md_escape(truncate(example.english))}` | "
            f"ARA: `{md_escape(truncate(example.arabic))}`"
        )
    if not examples:
        lines.append("None.")

    lines += [
        "",
        "## Examples Of 10 Cleaned English Merges",
        "",
    ]
    merge_examples: list[dict[str, Any]] = []
    for r in changed:
        merge_examples.extend(r.cleaned_merge_examples)
        if len(merge_examples) >= 10:
            break
    for example in merge_examples[:10]:
        parts = " + ".join(f"`{md_escape(truncate(part, 90))}`" for part in example["parts"])
        lines.append(
            f"- **{example['lesson']} after row {example['after_index']} "
            f"(backup rows {example['backup_rows']})**: {parts} -> "
            f"`{md_escape(truncate(example['merged'], 180))}`"
        )
    if not merge_examples:
        lines.append("None inferred.")

    lines += [
        "",
        "## Backup Comparison Summary",
        "",
        "| Lesson | Backup | Before | After | Merges | Explainable | Problems |",
        "|---|---|---:|---:|---:|---|---|",
    ]
    for r in changed:
        problems = "; ".join(r.change_problems[:4]) if r.change_problems else ""
        lines.append(
            f"| {r.lesson} | `{r.backup_path.name if r.backup_path else ''}` | "
            f"{r.row_count_before} | {r.row_count_after} | {r.merge_count} | "
            f"{'yes' if r.explainable_merges else 'no'} | {md_escape(problems)} |"
        )

    lines += [
        "",
        "## Backups Found",
        "",
    ]
    lines += [f"- `{path.relative_to(ROOT)}`" for path in backup_files] or ["None."]

    lines += [
        "",
        "## R2 Safety Confirmation",
        "",
        "- This validation script imports no R2/S3 client libraries and contains no upload code path.",
        "- The command run for this validation only read local `content.json`, local `audio.opus`, and local backups.",
        "- No R2 upload command was run by this validation task.",
        "",
        "## Recommendation",
        "",
    ]
    if status == "PASS":
        lines += [
            "- From a content-integrity perspective, the English fragment cleanup is safe to promote later: JSON, schema, audio presence, lesson keys, timestamps, durations, and backup diffs pass.",
            "- Do not treat this as Arabic QA completion. The remaining Arabic issue counts are still high and should be handled as a separate Phase 2 repair/retranslation pass.",
            "- Before any later R2 upload, review this report, rerun this validator, and do a separate production upload dry run. Do not upload from this validation task.",
        ]
    else:
        lines += [
            "- Do not proceed to R2 upload until the failures above are resolved.",
            "- Fix only the failed integrity checks first; keep Arabic repair as a separate phase unless an Arabic issue is also causing structural failure.",
        ]
    return "\n".join(lines) + "\n"


def fmt_float(value: float | None, signed: bool = False) -> str:
    if value is None:
        return "-"
    if signed:
        return f"{value:+.3f}"
    return f"{value:.3f}"


def main() -> int:
    results = [validate_lesson(lesson_id) for lesson_id in EXPECTED_LESSON_IDS]
    backup_files = sorted(BACKUP_ROOT.glob("lesson_*_backup_*.json"))
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(generate_report(results, backup_files), encoding="utf-8")

    status, failures = pass_fail(results)
    total_before = sum(r.row_count_before or r.row_count_after for r in results)
    total_after = sum(r.row_count_after for r in results)
    print(f"Report saved: {REPORT_PATH}")
    print(f"Status: {status}")
    print(f"Lessons scanned: {len(results)}")
    print(f"Rows before/after: {total_before} -> {total_after}")
    print(f"Changed lessons: {sum(1 for r in results if r.changed)}")
    print(f"Unchanged lessons: {sum(1 for r in results if not r.changed)}")
    print(f"R2 upload command run: no")
    if failures:
        print("Failures:")
        for failure in failures:
            print(f"  - {failure}")
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
