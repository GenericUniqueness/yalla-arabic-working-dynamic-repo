#!/usr/bin/env python3
"""
Course 09 Arabic Phase 2 repair skeleton.

Current status:
- --dry-run only writes Markdown reports.
- --apply is intentionally blocked until a future task defines approved write rules.
- No translations are generated.
- No APIs are called.
- No R2 upload code exists.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COURSE_ROOT = (
    ROOT
    / "local_fixtures/playlist_ingestion/c2_playlist/local_app_qa/http_root"
    / "assets/courses/course_09"
)
REPORTS_DIR = ROOT / "reports"

LESSON_IDS = [
    1, 2, 4, 5, 6, 8, 10, 12, 14, 15, 16, 17, 18, 19, 21, 22, 23, 24,
    26, 28, 29, 30, 31, 32, 33, 34, 35, 37, 38, 39, 41, 42, 43, 44, 45,
    47, 57, 59,
]

ACTION_ORDER = [
    "keep",
    "drop_duplicate",
    "arabic_is_english",
    "repeated_nearby",
    "suspicious_shift",
    "suspicious_length",
    "needs_retranslation",
    "needs_review",
]

ASCII_RATIO_THRESHOLD = 0.70


@dataclass
class ClassifiedRow:
    lesson: str
    index: int
    start: float
    end: float
    english: str
    arabic: str
    issue_type: str
    proposed_action: str
    confidence: str
    reason: str


def lesson_name(lesson_id: int) -> str:
    return f"lesson_{lesson_id:02d}"


def parse_lesson_id(value: str) -> int:
    match = re.fullmatch(r"lesson_(\d{2})", value)
    if not match:
        raise ValueError(f"Lesson must look like lesson_18, got {value!r}")
    lesson_id = int(match.group(1))
    if lesson_id not in LESSON_IDS:
        raise ValueError(f"Unknown Course 09 lesson: {value}")
    return lesson_id


def content_path(lesson_id: int) -> Path:
    return COURSE_ROOT / lesson_name(lesson_id) / "main_story/content.json"


def load_rows(lesson_id: int) -> list[dict]:
    path = content_path(lesson_id)
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError(f"{path} has {type(data).__name__} root, expected list")
    return data


def is_mostly_ascii(text: str) -> bool:
    if not text:
        return False
    ascii_chars = sum(1 for char in text if ord(char) < 128)
    return ascii_chars / max(len(text), 1) > ASCII_RATIO_THRESHOLD


def arabic_letter_count(text: str) -> int:
    return sum(1 for char in text if "\u0600" <= char <= "\u06ff")


def english_words(text: str) -> list[str]:
    return re.findall(r"[A-Za-z]+(?:'[A-Za-z]+)?", text.lower())


def is_punctuation_only(text: str) -> bool:
    return bool(text) and not any(char.isalnum() for char in text)


def normalized_words(text: str) -> set[str]:
    stop = {
        "a", "an", "and", "are", "be", "can", "do", "for", "i", "in", "is",
        "it", "of", "on", "or", "that", "the", "this", "to", "we", "you",
    }
    return {word for word in english_words(text) if word not in stop}


def english_similarity(a: str, b: str) -> float:
    aw = normalized_words(a)
    bw = normalized_words(b)
    if not aw and not bw:
        return 1.0 if a.strip() == b.strip() else 0.0
    if not aw or not bw:
        return 0.0
    return len(aw & bw) / len(aw | bw)


def row_text(row: dict, field: str) -> str:
    return str(row.get(field, "")).strip()


def classify_row(rows: list[dict], index: int) -> ClassifiedRow:
    row = rows[index]
    english = row_text(row, "text")
    arabic = row_text(row, "ara")
    start = float(row.get("start", 0))
    end = float(row.get("end", 0))

    prev_arabic = row_text(rows[index - 1], "ara") if index > 0 else ""
    next_arabic = row_text(rows[index + 1], "ara") if index + 1 < len(rows) else ""
    prev_english = row_text(rows[index - 1], "text") if index > 0 else ""
    next_english = row_text(rows[index + 1], "text") if index + 1 < len(rows) else ""
    max_neighbor_similarity = max(
        english_similarity(english, prev_english),
        english_similarity(english, next_english),
    )

    nearby_repeat = False
    if arabic and len(arabic) > 10:
        for neighbor in (index - 2, index - 1, index + 1, index + 2):
            if 0 <= neighbor < len(rows) and neighbor != index:
                if row_text(rows[neighbor], "ara") == arabic:
                    nearby_repeat = True
                    break

    identical_prev = arabic and arabic == prev_arabic
    identical_next = arabic and arabic == next_arabic
    punctuation_only = is_punctuation_only(arabic)
    mostly_english = is_mostly_ascii(arabic)
    too_short = (
        len(english_words(english)) >= 8
        and arabic
        and arabic_letter_count(arabic) < max(4, len(english) * 0.10)
    )
    too_long = bool(arabic and english and len(arabic) > max(160, len(english) * 3.5))

    if not arabic or punctuation_only:
        return ClassifiedRow(
            lesson="",
            index=index,
            start=start,
            end=end,
            english=english,
            arabic=arabic,
            issue_type="needs_retranslation",
            proposed_action="needs_retranslation",
            confidence="high",
            reason="Arabic is empty or punctuation-only.",
        )

    if mostly_english and arabic_letter_count(arabic) < 6:
        return ClassifiedRow(
            lesson="",
            index=index,
            start=start,
            end=end,
            english=english,
            arabic=arabic,
            issue_type="arabic_is_english",
            proposed_action="arabic_is_english",
            confidence="high",
            reason="Arabic field is effectively untranslated English.",
        )

    if too_short and arabic_letter_count(arabic) < 8:
        return ClassifiedRow(
            lesson="",
            index=index,
            start=start,
            end=end,
            english=english,
            arabic=arabic,
            issue_type="suspicious_length",
            proposed_action="needs_retranslation",
            confidence="high",
            reason="Arabic is far too short for the cleaned English row.",
        )

    if identical_prev or identical_next:
        if max_neighbor_similarity >= 0.55:
            return ClassifiedRow(
                lesson="",
                index=index,
                start=start,
                end=end,
                english=english,
                arabic=arabic,
                issue_type="drop_duplicate",
                proposed_action="keep",
                confidence="medium",
                reason="Duplicate Arabic may be valid because adjacent English is repeated or drill-like.",
            )
        return ClassifiedRow(
            lesson="",
            index=index,
            start=start,
            end=end,
            english=english,
            arabic=arabic,
            issue_type="drop_duplicate",
            proposed_action="drop_duplicate",
            confidence="medium",
            reason="Duplicate Arabic appears next to different English and likely needs repair.",
        )

    if too_long:
        return ClassifiedRow(
            lesson="",
            index=index,
            start=start,
            end=end,
            english=english,
            arabic=arabic,
            issue_type="suspicious_shift",
            proposed_action="suspicious_shift",
            confidence="medium",
            reason="Arabic is much longer than the cleaned English row.",
        )

    if nearby_repeat:
        if max_neighbor_similarity >= 0.55:
            return ClassifiedRow(
                lesson="",
                index=index,
                start=start,
                end=end,
                english=english,
                arabic=arabic,
                issue_type="repeated_nearby",
                proposed_action="keep",
                confidence="medium",
                reason="Nearby repeated Arabic may match repeated or drill-like English.",
            )
        return ClassifiedRow(
            lesson="",
            index=index,
            start=start,
            end=end,
            english=english,
            arabic=arabic,
            issue_type="repeated_nearby",
            proposed_action="repeated_nearby",
            confidence="medium",
            reason="Arabic repeats nearby and should be checked against neighboring rows.",
        )

    if mostly_english:
        return ClassifiedRow(
            lesson="",
            index=index,
            start=start,
            end=end,
            english=english,
            arabic=arabic,
            issue_type="arabic_is_english",
            proposed_action="needs_review",
            confidence="low",
            reason="Arabic contains substantial English; may be acceptable for names/terms or may need retranslation.",
        )

    if too_short:
        return ClassifiedRow(
            lesson="",
            index=index,
            start=start,
            end=end,
            english=english,
            arabic=arabic,
            issue_type="suspicious_length",
            proposed_action="suspicious_length",
            confidence="medium",
            reason="Arabic may be too compressed or shifted.",
        )

    return ClassifiedRow(
        lesson="",
        index=index,
        start=start,
        end=end,
        english=english,
        arabic=arabic,
        issue_type="keep",
        proposed_action="keep",
        confidence="high",
        reason="No Arabic repair signal found.",
    )


def classify_lesson(lesson_id: int) -> list[ClassifiedRow]:
    lesson = lesson_name(lesson_id)
    rows = load_rows(lesson_id)
    classified = []
    for index in range(len(rows)):
        item = classify_row(rows, index)
        item.lesson = lesson
        classified.append(item)
    return classified


def report_path_for(lesson_ids: list[int]) -> Path:
    if len(lesson_ids) == 1:
        return REPORTS_DIR / f"course_09_arabic_phase2_dry_run_{lesson_name(lesson_ids[0])}.md"
    return REPORTS_DIR / "course_09_arabic_phase2_dry_run_all.md"


def truncate(value: str, limit: int = 150) -> str:
    value = " ".join(value.split())
    if len(value) <= limit:
        return value
    return value[: limit - 1] + "…"


def md(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def action_counts(rows: list[ClassifiedRow]) -> dict[str, int]:
    counts = {action: 0 for action in ACTION_ORDER}
    for row in rows:
        counts[row.proposed_action] = counts.get(row.proposed_action, 0) + 1
    return counts


def lesson_risk_score(counts: dict[str, int]) -> int:
    return (
        counts.get("needs_retranslation", 0) * 5
        + counts.get("suspicious_shift", 0) * 5
        + counts.get("drop_duplicate", 0) * 3
        + counts.get("repeated_nearby", 0) * 3
        + counts.get("arabic_is_english", 0) * 2
        + counts.get("suspicious_length", 0) * 2
        + counts.get("needs_review", 0)
    )


def representative_examples(rows: list[ClassifiedRow], limit: int = 50) -> list[ClassifiedRow]:
    suspicious = [row for row in rows if row.proposed_action != "keep"]
    if len(suspicious) <= limit:
        return suspicious

    buckets: dict[str, list[ClassifiedRow]] = {action: [] for action in ACTION_ORDER}
    for row in suspicious:
        buckets.setdefault(row.proposed_action, []).append(row)

    selected: list[ClassifiedRow] = []

    # Take examples across classifications first, then fill by lesson diversity.
    for action in ACTION_ORDER:
        if action == "keep":
            continue
        selected.extend(buckets.get(action, [])[:5])

    seen = {(row.lesson, row.index) for row in selected}
    by_lesson = sorted(
        {row.lesson for row in suspicious},
        key=lambda lesson: sum(1 for row in suspicious if row.lesson == lesson),
        reverse=True,
    )
    for lesson in by_lesson:
        for row in suspicious:
            key = (row.lesson, row.index)
            if row.lesson == lesson and key not in seen:
                selected.append(row)
                seen.add(key)
                break
        if len(selected) >= limit:
            break

    for row in suspicious:
        if len(selected) >= limit:
            break
        key = (row.lesson, row.index)
        if key not in seen:
            selected.append(row)
            seen.add(key)

    return selected[:limit]


def generate_report(lesson_ids: list[int], rows: list[ClassifiedRow]) -> str:
    now = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    counts = action_counts(rows)

    lesson_rows: dict[str, list[ClassifiedRow]] = {}
    for row in rows:
        lesson_rows.setdefault(row.lesson, []).append(row)

    per_lesson: list[tuple[str, dict[str, int], int, int]] = []
    for lesson, lesson_items in sorted(lesson_rows.items()):
        lesson_counts = action_counts(lesson_items)
        suspicious_total = sum(
            count for action, count in lesson_counts.items() if action != "keep"
        )
        per_lesson.append(
            (lesson, lesson_counts, suspicious_total, lesson_risk_score(lesson_counts))
        )

    worst_lessons = sorted(per_lesson, key=lambda item: (item[3], item[2]), reverse=True)[:10]
    recommended_first = worst_lessons[0][0] if worst_lessons else "none"
    examples = representative_examples(rows, 50)

    lines = [
        "# Course 09 Arabic Phase 2 Dry-Run Repair Report",
        "",
        f"Generated: {now}",
        "",
        "## Scope",
        "",
        "- Source of truth: cleaned local Course 09 English transcript.",
        "- This is a dry-run report only.",
        "- No translations were generated.",
        "- No paid APIs were called.",
        "- No `content.json` files were modified.",
        "- No R2 upload was run.",
        "",
        "## Target",
        "",
        ", ".join(lesson_name(lesson_id) for lesson_id in lesson_ids),
        "",
        "## Classification Counts",
        "",
        "| Proposed action | Rows |",
        "|---|---:|",
    ]
    for action in ACTION_ORDER:
        lines.append(f"| {action} | {counts.get(action, 0)} |")

    lines += [
        "",
        "## Per-Lesson Classification Counts",
        "",
        "| Lesson | Rows | Suspicious | Risk score | keep | drop_duplicate | arabic_is_english | repeated_nearby | suspicious_shift | suspicious_length | needs_retranslation | needs_review |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for lesson, lesson_counts, suspicious_total, risk_score in per_lesson:
        total = sum(lesson_counts.values())
        lines.append(
            f"| {lesson} | {total} | {suspicious_total} | {risk_score} | "
            f"{lesson_counts.get('keep', 0)} | "
            f"{lesson_counts.get('drop_duplicate', 0)} | "
            f"{lesson_counts.get('arabic_is_english', 0)} | "
            f"{lesson_counts.get('repeated_nearby', 0)} | "
            f"{lesson_counts.get('suspicious_shift', 0)} | "
            f"{lesson_counts.get('suspicious_length', 0)} | "
            f"{lesson_counts.get('needs_retranslation', 0)} | "
            f"{lesson_counts.get('needs_review', 0)} |"
        )

    lines += [
        "",
        "## Top 10 Worst Lessons",
        "",
        "| Rank | Lesson | Suspicious rows | Risk score | Main repair signals |",
        "|---:|---|---:|---:|---|",
    ]
    for rank, (lesson, lesson_counts, suspicious_total, risk_score) in enumerate(worst_lessons, 1):
        non_keep = Counter(
            {
                action: count
                for action, count in lesson_counts.items()
                if action != "keep" and count
            }
        )
        main_signals = ", ".join(
            f"{action}: {count}" for action, count in non_keep.most_common(3)
        )
        lines.append(
            f"| {rank} | {lesson} | {suspicious_total} | {risk_score} | {main_signals} |"
        )

    lines += [
        "",
        "## Recommended First Lesson To Repair",
        "",
        f"- Recommended first lesson: `{recommended_first}`.",
        "- Reason: it has the highest weighted mix of retranslation, shift, duplicate, repeated-nearby, and untranslated-English signals.",
        "",
        "## Later Automation Safety",
        "",
        "- Safest to automate later after explicit approval: exact `arabic_is_english` rows with high confidence, empty or punctuation-only `needs_retranslation` rows, and very-short `needs_retranslation` rows where Arabic clearly cannot match the cleaned English.",
        "- Automatable only with neighboring-row rules and backups: `drop_duplicate` and `repeated_nearby`, because some pronunciation drills intentionally repeat English and Arabic.",
        "- Requires AI retranslation or human review: `needs_retranslation`, `suspicious_shift`, low-confidence `needs_review`, mixed Arabic/English rows, and `suspicious_length` rows where existing Arabic may be a partial but shifted translation.",
        "",
        "## Representative Examples",
        "",
        "| Lesson | Row | Timestamp | English line | Current Arabic | Issue type | Proposed action | Confidence |",
        "|---|---:|---|---|---|---|---|---|",
    ]
    for row in examples:
        lines.append(
            f"| {row.lesson} | {row.index} | {row.start:.3f}-{row.end:.3f} | "
            f"`{md(truncate(row.english, 130))}` | "
            f"`{md(truncate(row.arabic, 130))}` | "
            f"{row.issue_type} | {row.proposed_action} | {row.confidence} |"
        )

    lines += [
        "",
        "## Implementation Notes",
        "",
        "- `--apply` is intentionally disabled in this skeleton.",
        "- Future apply mode should back up each lesson, preserve `text/start/end`, and modify only `ara` after explicit approval.",
        "- Rows marked `needs_retranslation` should receive new Arabic only in a future API-approved task.",
        "- Rows marked `drop_duplicate`, `repeated_nearby`, or `suspicious_shift` need neighboring-row context before any write.",
    ]
    return "\n".join(lines) + "\n"


def run_dry_run(lesson_ids: list[int]) -> Path:
    rows: list[ClassifiedRow] = []
    for lesson_id in lesson_ids:
        rows.extend(classify_lesson(lesson_id))
    path = report_path_for(lesson_ids)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(generate_report(lesson_ids, rows), encoding="utf-8")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description="Course 09 Arabic Phase 2 repair skeleton")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true", help="Analyze and write a report only")
    mode.add_argument("--apply", action="store_true", help="Reserved for future use; disabled now")
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--lesson", help="Lesson key such as lesson_18")
    target.add_argument("--all", action="store_true", help="Analyze all Course 09 lessons")
    args = parser.parse_args()

    lesson_ids = LESSON_IDS if args.all else [parse_lesson_id(args.lesson)]

    if args.apply:
        print("ERROR: --apply is intentionally disabled in this skeleton.", file=sys.stderr)
        print("No content files were modified.", file=sys.stderr)
        return 2

    report_path = run_dry_run(lesson_ids)
    print(f"Report saved: {report_path}")
    print(f"Lessons analyzed: {len(lesson_ids)}")
    print("Content files modified: no")
    print("Paid API calls: no")
    print("R2 upload command run: no")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
