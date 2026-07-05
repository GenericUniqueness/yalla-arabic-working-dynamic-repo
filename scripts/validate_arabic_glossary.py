#!/usr/bin/env python3
"""Validate the draft Arabic root glossary asset."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PATH = ROOT / "assets" / "arabic_glossary.json"
ARABIC_RE = re.compile(r"[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]")
ROOT_RE = re.compile(r"^[\u0621-\u064a]( [\u0621-\u064a]){2,3}$")


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PATH
    if not path.is_absolute():
        path = ROOT / path

    errors: list[str] = []
    warnings: list[str] = []

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - validator reports all read/parse failures.
        print(f"FAIL: could not read {path}: {exc}")
        return 1

    entries = data.get("entries")
    if not isinstance(entries, list) or not entries:
        errors.append("entries must be a non-empty array")
        entries = []

    seen_forms: dict[str, int] = {}
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            errors.append(f"entry {index}: must be an object")
            continue
        validate_entry(index, entry, errors, warnings, seen_forms)

    print("# Arabic Glossary Validation")
    print()
    print(f"File: `{path}`")
    print(f"Entries: {len(entries)}")
    print(f"Errors: {len(errors)}")
    print(f"Warnings: {len(warnings)}")
    print()

    for error in errors:
        print(f"- [error] {error}")
    for warning in warnings:
        print(f"- [warning] {warning}")

    return 1 if errors else 0


def validate_entry(
    index: int,
    entry: dict[str, Any],
    errors: list[str],
    warnings: list[str],
    seen_forms: dict[str, int],
) -> None:
    forms = string_list(entry.get("surface_forms"))
    if not forms:
        errors.append(f"entry {index}: surface_forms must contain at least one form")
    for form in forms:
        if not ARABIC_RE.search(form):
            errors.append(f"entry {index}: surface form has no Arabic letters: {form!r}")
        normalised = normalise_arabic(form)
        if normalised in seen_forms and seen_forms[normalised] != index:
            warnings.append(
                f"entry {index}: surface form {form!r} duplicates entry {seen_forms[normalised]}"
            )
        else:
            seen_forms[normalised] = index

    required_strings = [
        "lemma",
        "root",
        "part_of_speech",
        "english_meaning",
        "short_definition",
        "lesson_example_arabic",
        "lesson_example_english",
    ]
    for field in required_strings:
        if not nonempty_string(entry.get(field)):
            errors.append(f"entry {index}: {field} is missing or empty")

    root = entry.get("root")
    if isinstance(root, str) and not ROOT_RE.match(root.strip()):
        warnings.append(f"entry {index}: root should be spaced Arabic letters: {root!r}")

    if not ARABIC_RE.search(str(entry.get("lesson_example_arabic", ""))):
        errors.append(f"entry {index}: lesson_example_arabic has no Arabic letters")

    family = entry.get("root_family")
    if not isinstance(family, dict):
        errors.append(f"entry {index}: root_family must be an object")
        return

    if not nonempty_string(family.get("core_meaning")):
        errors.append(f"entry {index}: root_family.core_meaning is missing")
    if not nonempty_string(family.get("explanation")):
        errors.append(f"entry {index}: root_family.explanation is missing")

    related = family.get("related_words")
    if not isinstance(related, list) or not related:
        warnings.append(f"entry {index}: root_family.related_words is empty")
        return

    for related_index, related_word in enumerate(related):
        if not isinstance(related_word, dict):
            errors.append(f"entry {index}: related word {related_index} must be an object")
            continue
        if not nonempty_string(related_word.get("arabic")):
            errors.append(f"entry {index}: related word {related_index} missing arabic")
        if not nonempty_string(related_word.get("english")):
            errors.append(f"entry {index}: related word {related_index} missing english")


def string_list(raw: Any) -> list[str]:
    if not isinstance(raw, list):
        return []
    return [item.strip() for item in raw if isinstance(item, str) and item.strip()]


def nonempty_string(raw: Any) -> bool:
    return isinstance(raw, str) and bool(raw.strip())


def normalise_arabic(raw: str) -> str:
    replacements = str.maketrans({
        "آ": "ا",
        "أ": "ا",
        "إ": "ا",
        "ٱ": "ا",
    })
    text = raw.translate(replacements)
    text = re.sub(r"[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06edـ]", "", text)
    return re.sub(r"\s+", " ", text).strip()


if __name__ == "__main__":
    raise SystemExit(main())
