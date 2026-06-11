#!/usr/bin/env python3
"""
Word Panel Entry Census (V19B) — read-only classification of every dictionary key.

Walks every key in assets/word_definitions.json, classifies it into exactly one
of the 15 V19 panel types (see reports/word_panel_v19_taxonomy_design.md §2),
attaches secondary tags, a deterministic confidence, an evidence trail, and the
generation/patch/review policies for that panel type. Writes a machine-readable
JSON census and a human-readable Markdown summary under reports/.

The census is STRICTLY READ-ONLY:
  - never writes to assets/
  - never patches word_definitions.json
  - never calls GPT
  - never modifies the selector, the factory, or any Flutter UI
  - never commits

It imports scripts/word_panel/word_panel_core_learner_pack_selector.py as a
library only (no main() call, no I/O side effects) for its predicate set.

Spec: reports/word_panel_v19_census_script_spec.md
Taxonomy: reports/word_panel_v19_taxonomy_design.md
Roadmap: reports/word_panel_v19_implementation_roadmap.md (stage 2)

Usage:
  python3 scripts/word_panel/word_panel_entry_census.py --census-version 1
  python3 scripts/word_panel/word_panel_entry_census.py --scope sample --census-version 1_sample
  python3 scripts/word_panel/word_panel_entry_census.py --scope slips,gonna,apple --census-version probe
  python3 scripts/word_panel/word_panel_entry_census.py --explain slips
  python3 -m py_compile scripts/word_panel/word_panel_entry_census.py
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
DICT_PATH = REPO_ROOT / "assets" / "word_definitions.json"
SELECTOR_PATH = REPO_ROOT / "scripts" / "word_panel" / "word_panel_core_learner_pack_selector.py"
REPORTS = REPO_ROOT / "reports"

# ─── The 15 V19 panel types, in taxonomy §2 order (drives sort + summary) ─────
PANEL_TYPES = [
    "normal_word_panel",
    "inflected_redirect_panel",
    "plural_redirect_panel",
    "abbreviation_panel",
    "acronym_panel",
    "informal_contraction_panel",
    "slang_panel",
    "proper_name_panel",
    "place_name_panel",
    "brand_panel",
    "filler_noise_panel",
    "transcript_noise_block",
    "sensitive_review_panel",
    "phrase_future_panel",
    "unknown_review_panel",
]
PANEL_ORDER = {p: i for i, p in enumerate(PANEL_TYPES)}

# Default generation_lane / patch_policy / ui_hint per panel type (taxonomy §3).
# review_policy is refined by confidence in _policies().
PANEL_POLICY: dict[str, dict[str, str]] = {
    "normal_word_panel": {
        "generation_lane": "gpt_allowed", "patch_policy": "gpt_pass_patchable_only",
        "ui_hint": "full_panel"},
    "inflected_redirect_panel": {
        "generation_lane": "deterministic", "patch_policy": "redirect_only",
        "ui_hint": "redirect_to_base"},
    "plural_redirect_panel": {
        "generation_lane": "deterministic", "patch_policy": "redirect_only",
        "ui_hint": "redirect_to_base"},
    "abbreviation_panel": {
        "generation_lane": "gpt_blocked", "patch_policy": "census_only",
        "ui_hint": "show_expansion"},
    "acronym_panel": {
        "generation_lane": "gpt_blocked", "patch_policy": "census_only",
        "ui_hint": "show_expansion"},
    "informal_contraction_panel": {
        "generation_lane": "gpt_allowed", "patch_policy": "gpt_pass_patchable_only",
        "ui_hint": "full_panel_informal_chip"},
    "slang_panel": {
        "generation_lane": "gpt_allowed", "patch_policy": "gpt_pass_patchable_only",
        "ui_hint": "full_panel_informal_chip"},
    "proper_name_panel": {
        "generation_lane": "gpt_blocked", "patch_policy": "census_only",
        "ui_hint": "minimal_name_card"},
    "place_name_panel": {
        "generation_lane": "gpt_blocked", "patch_policy": "census_only",
        "ui_hint": "minimal_place_card"},
    "brand_panel": {
        "generation_lane": "gpt_blocked", "patch_policy": "census_only",
        "ui_hint": "minimal_brand_card"},
    "filler_noise_panel": {
        "generation_lane": "gpt_blocked", "patch_policy": "census_only",
        "ui_hint": "minimal_noise_card"},
    "transcript_noise_block": {
        "generation_lane": "gpt_blocked", "patch_policy": "census_only",
        "ui_hint": "suppress"},
    "sensitive_review_panel": {
        "generation_lane": "human_curated_only", "patch_policy": "human_curated_only",
        "ui_hint": "hold_until_reviewed"},
    "phrase_future_panel": {
        "generation_lane": "gpt_blocked", "patch_policy": "census_only",
        "ui_hint": "queue_for_v20"},
    "unknown_review_panel": {
        "generation_lane": "human_curated_only", "patch_policy": "human_curated_only",
        "ui_hint": "hold_until_reviewed"},
}

# Selector lane → set of panel types that "agree" with that lane (taxonomy §1).
LANE_EXPECTED: dict[str, set[str]] = {
    "auto_enrich_now": {"normal_word_panel"},
    "keep_existing": {"normal_word_panel"},
    "redirect_required": {"inflected_redirect_panel", "plural_redirect_panel"},
    "review_safe": {"informal_contraction_panel", "slang_panel", "abbreviation_panel",
                    "acronym_panel", "unknown_review_panel", "phrase_future_panel"},
    "review_sensitive": {"sensitive_review_panel"},
    "blocked": {"proper_name_panel", "place_name_panel", "brand_panel",
                "filler_noise_panel", "transcript_noise_block"},
}

# Taxonomy §2.12 definitive non-words. NON_WORD_NOISE (selector) plus the three
# coinages the taxonomy names explicitly. tink/cajol/caroac are not in
# NON_WORD_NOISE today, so the census names them here for rule R-NON-WORD-NOISE.
EXTRA_NON_WORDS = {"tink", "cajol", "caroac"}

MONTH_NAMES = {
    "january", "february", "march", "april", "may", "june", "july",
    "august", "september", "october", "november", "december",
}

# Definition phrases that signal a geographical place (place_name_panel).
PLACE_PATTERN = re.compile(
    r"\b(capital city|the capital of|a country|country in|country located|continent|"
    r"a river|a major river|an ocean|a sea|a mountain|a mountain range|an island|"
    r"a city in|a city located|a state in|a region in|a region of|a town in)\b"
)

# Inflection definition prefixes (rule R-INFLECTED-DEF-PREFIX).
INFLECTION_PREFIXES = (
    "past tense of", "past form of", "third person singular of",
    "present form of", "past participle of", "the past tense of",
    "the past form of", "the present form of",
)

# 22 worked-example anchors (taxonomy §5) — regenerated against the live census.
ANCHOR_EXPECTATIONS: list[tuple[str, str]] = [
    ("fix", "normal_word_panel"),
    ("jump", "normal_word_panel"),
    ("slips", "inflected_redirect_panel"),
    ("decided", "inflected_redirect_panel"),
    ("strode", "inflected_redirect_panel"),
    ("dr", "abbreviation_panel"),
    ("bc", "abbreviation_panel"),
    ("gonna", "informal_contraction_panel"),
    ("ain't", "informal_contraction_panel"),
    ("yo", "slang_panel"),
    ("uh", "filler_noise_panel"),
    ("tink", "transcript_noise_block"),
    ("alan's", "proper_name_panel"),
    ("london", "place_name_panel"),
    ("american", "sensitive_review_panel"),
    ("worship", "sensitive_review_panel"),
    ("shit", "sensitive_review_panel"),
    ("triest", "unknown_review_panel"),
    ("ck", "transcript_noise_block"),
    ("et", "unknown_review_panel"),
    ("apple", "normal_word_panel"),
    ("may", "normal_word_panel"),
]

# Module-level handle to the loaded dictionary (read-only) for expansion lookups.
CURRENT_DICT: dict[str, Any] = {}


# ─── Selector import (library only) ──────────────────────────────────────────

def load_selector() -> Any:
    """Import the selector module as a library. Fails loudly on any error."""
    if not SELECTOR_PATH.exists():
        raise FileNotFoundError(f"selector module not found at {SELECTOR_PATH}")
    sel_dir = str(SELECTOR_PATH.parent)
    if sel_dir not in sys.path:
        sys.path.insert(0, sel_dir)
    import importlib
    selector = importlib.import_module("word_panel_core_learner_pack_selector")
    # Sanity: every predicate the census relies on must be present. If the
    # selector's public surface drifts, fail loudly rather than mis-classify.
    required = [
        "is_bad_entry", "content_concern", "is_proper_noun", "is_brand_or_commercial",
        "is_acronym_or_all_caps", "looks_like_third_person_s_inflection",
        "is_archaic_or_obsolete", "has_rich_learner_panel", "assign_lane",
        "NON_WORD_NOISE", "INFORMAL_USEFUL_SLANG", "TRANSCRIPT_NOISE",
        "IRREGULAR_PAST_FORMS", "DICTIONARY_WORDS",
    ]
    missing = [name for name in required if not hasattr(selector, name)]
    if missing:
        raise AttributeError(
            f"selector module is missing expected predicates/sets: {missing}. "
            "The census imports the selector read-only and cannot continue."
        )
    return selector


# ─── Small extraction helpers ────────────────────────────────────────────────

def _def(entry: dict[str, Any]) -> str:
    return (entry.get("definition") or "").strip()


def _pos(entry: dict[str, Any]) -> str:
    return (entry.get("pos") or "").lower()


def _slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", text.strip().lower()).strip("_")


def _third_s_base(word: str, selector: Any) -> str | None:
    """Recover the base verb of a 3rd-person -s form that exists in the dict."""
    w = word.lower()
    cands: list[str] = []
    if w.endswith("ies") and len(w) >= 5:
        cands.append(w[:-3] + "y")
    if w.endswith("es") and len(w) >= 4:
        cands.append(w[:-2])
        cands.append(w[:-1])
    if w.endswith("s") and not w.endswith("ss") and len(w) >= 4:
        cands.append(w[:-1])
    for base in cands:
        if base != w and base in selector.DICTIONARY_WORDS:
            return base
    return None


def _base_from_def(definition: str) -> str | None:
    """Extract the base lemma from 'past tense of X', 'past participle of X', …"""
    m = re.search(
        r"\b(?:past tense|past participle|past form|present form|"
        r"third person singular)\s+of\s+([a-zA-Z]+)", definition, re.IGNORECASE)
    if m:
        return m.group(1).lower()
    return None


def _plural_base(definition: str) -> str | None:
    m = re.match(r"more than one\s+([a-zA-Z]+)", definition.strip(), re.IGNORECASE)
    if m:
        return m.group(1).lower()
    return None


def _abbrev_expansion(definition: str) -> str | None:
    d = definition
    m = re.search(r"short(?:\s+writing)?\s+for\s+['\"]?([a-zA-Z][a-zA-Z \-]*?)['\"]?[.;,]",
                  d, re.IGNORECASE)
    if m:
        return m.group(1).strip().lower()
    m = re.search(r"abbreviation\s+(?:meaning|for|of)\s+['\"]?([a-zA-Z][a-zA-Z \-]*?)['\"]?[.,;]",
                  d, re.IGNORECASE)
    if m:
        return m.group(1).strip().lower()
    m = re.search(r"stands\s+for\s+['\"]?([a-zA-Z][a-zA-Z \-]*?)['\"]?[.,;]",
                  d, re.IGNORECASE)
    if m:
        return m.group(1).strip().lower()
    return None


def _contraction_expansion(definition: str) -> str | None:
    m = re.search(r"way (?:of saying|to say)\s+['\"]([^'\"]+)['\"]", definition, re.IGNORECASE)
    if m:
        return m.group(1).strip().lower()
    m = re.search(r"saying\s+['\"]([^'\"]+)['\"]", definition, re.IGNORECASE)
    if m:
        return m.group(1).strip().lower()
    return None


def _has_abbrev_marker(defl: str) -> bool:
    return any(m in defl for m in ("short for", "short writing for", "abbreviation", "short form"))


def _has_contraction_marker(defl: str) -> bool:
    return any(m in defl for m in (
        "informal way of saying", "informal way to say", "a short way to say",
        "short way to say", "informal contraction", "non-standard way of saying",
        "informal, non-standard way of saying",
    ))


def _place_kind(defl: str) -> str:
    if "capital" in defl or "city" in defl or "town" in defl:
        return "city"
    if "country" in defl:
        return "country"
    if "continent" in defl:
        return "continent"
    if "river" in defl or "ocean" in defl or "sea" in defl:
        return "water"
    if "mountain" in defl or "island" in defl:
        return "landform"
    return "region"


def _inflection_tag(defl: str, key: str) -> str:
    if "past participle" in defl:
        return "verb_past_participle"
    if "past" in defl:
        return "verb_past"
    if "third person" in defl or (key.endswith("s") and "present" in defl):
        return "verb_third_s"
    if key.endswith("ing"):
        return "verb_gerund"
    if key.endswith("s"):
        return "verb_present_s"
    return "verb_inflected"


def _closest_candidates(key: str, pos: str) -> list[str]:
    """Best-effort 'what was considered' list for the fallback unknown bucket."""
    cands: list[str] = []
    if len(key) <= 4 and key.isalpha():
        cands.append("abbreviation_panel")
    if pos == "other":
        cands.append("filler_noise_panel")
        cands.append("slang_panel")
    if pos in {"verb", "noun", "adjective", "adverb"}:
        cands.append("normal_word_panel")
    if "'" in key:
        cands.append("proper_name_panel")
    if not cands:
        cands = ["normal_word_panel", "filler_noise_panel"]
    out: list[str] = []
    for c in cands:
        if c not in out:
            out.append(c)
    return out[:3]


def _clamp(x: float) -> float:
    return max(0.0, min(1.0, round(x, 4)))


# ─── Core classification ─────────────────────────────────────────────────────

def _curated_subdecision(key: str, entry: dict[str, Any], selector: Any) -> tuple[str, float, str]:
    """Sub-decision for R-CURATED-RICH-PANEL (spec §3.1, extended).

    Returns (panel_type, base_confidence, reason). The curated semantic content
    is never touched; only the panel type is chosen.
    """
    pos = _pos(entry)
    dl = _def(entry).lower()
    lemma = entry.get("lemma")
    # Curated inflected form: lemma redirect wins (taxonomy invariant 8 / C8).
    if lemma and lemma != key:
        return "inflected_redirect_panel", 0.9, "curated panel but lemma redirect"
    # Hesitation / drill sound.
    if pos == "other" and (dl.startswith("a sound") or dl.startswith("sound")):
        return "filler_noise_panel", 0.9, "curated panel; hesitation/sound definition"
    # Curated informal contraction (gonna, wanna, ...).
    if key in selector.INFORMAL_USEFUL_SLANG:
        return "informal_contraction_panel", 0.85, "curated panel; informal contraction set"
    # Curated promoted slang (nope, yep, yo, ...): real interjection meaning.
    if key in selector.TRANSCRIPT_NOISE:
        return "slang_panel", 0.7, "curated panel; promoted from v17 noise set"
    # Curated abbreviation (dr, ...).
    if _has_abbrev_marker(dl):
        return "abbreviation_panel", 0.85, "curated panel; abbreviation definition"
    # Curated contraction by definition wording.
    if _has_contraction_marker(dl):
        return "informal_contraction_panel", 0.85, "curated panel; contraction definition"
    # Curated but ambiguous short 'other' token (et, ...).
    if pos == "other" and len(key) <= 2:
        return "unknown_review_panel", 0.55, "curated panel; ambiguous short 'other' token"
    # Default: a real content word.
    return "normal_word_panel", 0.85, "curated rich learner panel — content word"


def classify(key: str, entry: dict[str, Any], selector: Any) -> dict[str, Any]:
    """Run the ordered V19 rule chain (spec §3). First rule wins for the
    primary type; later rules add tags / matched-rule records."""
    is_entry = isinstance(entry, dict)
    pos = _pos(entry) if is_entry else ""
    d = _def(entry) if is_entry else ""
    dl = d.lower()
    lemma = entry.get("lemma") if is_entry else None
    cefr_dict = entry.get("cefr") if is_entry else None
    rich = selector.has_rich_learner_panel(entry) if is_entry else False

    tags: list[str] = []
    matched: list[str] = []
    candidates: list[str] = []
    base: str | None = None
    reason = ""
    panel: str | None = None
    conf = 0.5
    multi_disagree = False

    sensitivity = selector.content_concern(key, entry) if is_entry else None

    # ── 1. R-BAD-ENTRY ───────────────────────────────────────────────────────
    if panel is None and is_entry and selector.is_bad_entry(key, entry):
        matched.append("R-BAD-ENTRY")
        panel, conf, reason = "transcript_noise_block", 0.95, "selector.is_bad_entry: malformed/non-word"
        tags.append("non_word")

    # ── 2. R-NON-WORD-NOISE ──────────────────────────────────────────────────
    if panel is None and (key in selector.NON_WORD_NOISE or key in EXTRA_NON_WORDS):
        matched.append("R-NON-WORD-NOISE")
        panel, conf, reason = "transcript_noise_block", 0.99, "curated non-word / nonce coinage"
        tags.append("non_word")

    # ── 3. R-DIGIT-KEY ───────────────────────────────────────────────────────
    if panel is None and any(c.isdigit() for c in key):
        matched.append("R-DIGIT-KEY")
        panel, conf, reason = "transcript_noise_block", 0.99, "key contains a digit"
        tags.append("digit_key")

    # ── 4. R-LEN-LE-2-NONSTANDARD ────────────────────────────────────────────
    if panel is None and len(key) <= 2 and (
        "not a common english word" in dl or "not a standard english word" in dl
    ):
        matched.append("R-LEN-LE-2-NONSTANDARD")
        panel, conf, reason = "transcript_noise_block", 0.95, "len<=2 + 'not a … english word'"
        tags.append("non_word_explicit")

    # ── 5. R-CURATED-RICH-PANEL (no sensitivity) ─────────────────────────────
    if panel is None and rich and sensitivity is None:
        matched.append("R-CURATED-RICH-PANEL")
        sub_panel, sub_conf, sub_reason = _curated_subdecision(key, entry, selector)
        panel, conf, reason = sub_panel, sub_conf, sub_reason
        tags.append("curated_rich_panel")
        if sub_panel == "inflected_redirect_panel":
            base = str(lemma).lower()
            tags.append(f"lemma:{base}")
            tags.append(_inflection_tag(dl, key))
        elif sub_panel == "abbreviation_panel":
            exp = _abbrev_expansion(d)
            if exp:
                tags.append(f"expansion:{_slug(exp)}")
        elif sub_panel == "informal_contraction_panel":
            tags.append("register:informal_spoken")
            exp = _contraction_expansion(d)
            if exp:
                tags.append(f"expansion:{_slug(exp)}")
        elif sub_panel == "slang_panel":
            tags.append("register:informal_spoken")
            tags.append("was_noise_v17")
        elif sub_panel == "filler_noise_panel":
            tags.append("noise_kind:hesitation")
        elif sub_panel == "unknown_review_panel":
            candidates = ["abbreviation_panel", "filler_noise_panel"]

    # ── 6. R-SENSITIVE ───────────────────────────────────────────────────────
    if panel is None and sensitivity is not None:
        matched.append("R-SENSITIVE")
        panel, conf, reason = "sensitive_review_panel", 0.95, f"content concern: {sensitivity}"
        tags.append(f"sensitivity:{sensitivity}")
        if rich:
            tags.append("curated_rich_panel")
    elif sensitivity is not None:
        # Sensitivity recorded as a tag even when an earlier rule won.
        tags.append(f"sensitivity:{sensitivity}")

    # ── 7. R-PROPER-NAME ─────────────────────────────────────────────────────
    is_possessive = key.endswith("'s")
    name_markers = any(m in dl for m in (
        "given name", "first name", "common name", "male name", "female name",
        "personal name", "the name", "possessive form of the name",
    ))
    proper = selector.is_proper_noun(key, entry) if is_entry else False
    if panel is None and (proper or (is_possessive and (name_markers or "name" in dl)) or name_markers):
        matched.append("R-PROPER-NAME")
        panel, conf, reason = "proper_name_panel", 0.9, "proper noun / personal name"
        if is_possessive:
            base = key[:-2]
            mname = re.search(r"name\s+([A-Za-z]+)", d)
            if mname:
                base = mname.group(1).lower()
            tags.append("possessive_form")
            tags.append(f"base_name:{base}")
            if base and base not in selector.DICTIONARY_WORDS:
                tags.append("possessive_orphan")
                conf = 0.7
        else:
            tags.append("name_kind:personal")

    # ── 8. R-PLACE-NAME ──────────────────────────────────────────────────────
    if panel is None and PLACE_PATTERN.search(dl) and pos in {"noun", "other", "proper noun", ""}:
        matched.append("R-PLACE-NAME")
        panel, conf, reason = "place_name_panel", 0.9, "geographical definition"
        tags.append(f"place_kind:{_place_kind(dl)}")

    # ── 9. R-BRAND ───────────────────────────────────────────────────────────
    brand = selector.is_brand_or_commercial(key) if is_entry else False
    if brand:
        matched.append("R-BRAND")
        if panel is None:
            panel, conf, reason = "brand_panel", 0.9, "curated brand / commercial token"
            tags.append("brand")
        else:
            tags.append("homonym_brand")
            multi_disagree = True

    # ── 10. R-ACRONYM ────────────────────────────────────────────────────────
    if panel is None and (selector.is_acronym_or_all_caps(key) if is_entry else False) \
            and ("stands for" in dl or "abbreviation meaning" in dl):
        matched.append("R-ACRONYM")
        panel, conf, reason = "acronym_panel", 0.9, "all-caps initialism"
        exp = _abbrev_expansion(d)
        if exp:
            tags.append(f"acronym_expansion:{_slug(exp)}")

    # ── 11. R-ABBREVIATION ───────────────────────────────────────────────────
    if panel is None and key.isalpha() and len(key) <= 4 and _has_abbrev_marker(dl) \
            and not key.isupper():
        matched.append("R-ABBREVIATION")
        panel, conf, reason = "abbreviation_panel", 0.85, "short token; abbreviation definition"
        exp = _abbrev_expansion(d)
        if exp:
            tags.append(f"expansion:{_slug(exp)}")

    # ── 12. R-INFORMAL-CONTRACTION ───────────────────────────────────────────
    if panel is None and (
        key in selector.INFORMAL_USEFUL_SLANG
        or ("'" in key and _has_contraction_marker(dl))
    ):
        matched.append("R-INFORMAL-CONTRACTION")
        panel, conf, reason = "informal_contraction_panel", 0.85, "informal contraction"
        tags.append("register:informal_spoken")
        exp = _contraction_expansion(d)
        if exp:
            tags.append(f"expansion:{_slug(exp)}")

    # ── 13. R-SLANG-PROMOTED ─────────────────────────────────────────────────
    if panel is None and key in selector.TRANSCRIPT_NOISE and (
        pos != "other" or (len(dl) > 25 and not dl.startswith(("a sound", "sound")))
    ):
        matched.append("R-SLANG-PROMOTED")
        panel, conf, reason = "slang_panel", 0.7, "promoted from v17 transcript-noise set"
        tags.append("register:informal_spoken")
        tags.append("was_noise_v17")

    # ── 14. R-FILLER-NOISE ───────────────────────────────────────────────────
    if panel is None and key in selector.TRANSCRIPT_NOISE and (
        dl.startswith("a sound") or dl.startswith("sound")
    ):
        matched.append("R-FILLER-NOISE")
        panel, conf, reason = "filler_noise_panel", 0.9, "hesitation/drill sound"
        tags.append("noise_kind:hesitation")

    # ── 15. R-INFLECTED-LEMMA ────────────────────────────────────────────────
    if panel is None and lemma and lemma != key:
        matched.append("R-INFLECTED-LEMMA")
        panel, conf, reason = "inflected_redirect_panel", 0.95, f"lemma redirect → {lemma}"
        base = str(lemma).lower()
        tags.append(f"lemma:{base}")
        tags.append(_inflection_tag(dl, key))

    # ── 16. R-INFLECTED-IRREGULAR ────────────────────────────────────────────
    if panel is None and key.lower() in selector.IRREGULAR_PAST_FORMS:
        matched.append("R-INFLECTED-IRREGULAR")
        base = _base_from_def(d)
        if base:
            panel, conf, reason = "inflected_redirect_panel", 0.95, "irregular past form"
            tags.append("irregular_past")
            tags.append(f"lemma_inferred:{base}")
        else:
            panel, conf, reason = "unknown_review_panel", 0.55, "irregular form, base not recoverable"
            candidates = ["inflected_redirect_panel", "normal_word_panel"]

    # ── 17. R-INFLECTED-3RD-S ────────────────────────────────────────────────
    if panel is None and is_entry \
            and selector.looks_like_third_person_s_inflection(key, entry):
        matched.append("R-INFLECTED-3RD-S")
        base = _third_s_base(key, selector)
        panel, conf, reason = "inflected_redirect_panel", 0.9, "dictionary-aware 3rd-person -s form"
        tags.append("verb_third_s")
        if base:
            tags.append(f"lemma_inferred:{base}")

    # ── 18. R-INFLECTED-DEF-PREFIX ───────────────────────────────────────────
    if panel is None and any(dl.startswith(p) for p in INFLECTION_PREFIXES):
        matched.append("R-INFLECTED-DEF-PREFIX")
        base = _base_from_def(d)
        if base:
            panel, conf, reason = "inflected_redirect_panel", 0.9, "definition prefix names a base verb"
            tags.append(f"lemma_inferred:{base}")
            tags.append(_inflection_tag(dl, key))
        else:
            panel, conf, reason = "unknown_review_panel", 0.55, "inflection prefix, base not recoverable"
            candidates = ["inflected_redirect_panel", "normal_word_panel"]

    # ── 19. R-PLURAL ─────────────────────────────────────────────────────────
    if panel is None and dl.startswith("more than one "):
        matched.append("R-PLURAL")
        base = _plural_base(d)
        if base:
            panel, conf, reason = "plural_redirect_panel", 0.95, "noun plural (definition: 'more than one …')"
            tags.append("plural")
            tags.append(f"lemma_inferred:{base}")
        else:
            panel, conf, reason = "unknown_review_panel", 0.55, "plural definition, base not recoverable"
            candidates = ["plural_redirect_panel", "normal_word_panel"]

    # ── 20. R-ARCHAIC ────────────────────────────────────────────────────────
    if panel is None and is_entry and selector.is_archaic_or_obsolete(key, entry):
        matched.append("R-ARCHAIC")
        panel, conf, reason = "unknown_review_panel", 0.65, "definition marked archaic/obsolete"
        tags.append("register:archaic")
        candidates = ["inflected_redirect_panel", "normal_word_panel"]

    # ── 21. R-NORMAL-WORD ────────────────────────────────────────────────────
    if panel is None and pos in {"verb", "noun", "adjective", "adverb"} \
            and (cefr_dict or "").upper() in {"A1", "A2", "B1", "B2"}:
        matched.append("R-NORMAL-WORD")
        conf = 0.85
        if rich:
            conf += 0.05
        if lemma == key:
            conf += 0.05
        panel, reason = "normal_word_panel", "base content word with A1–B2 CEFR"
        tags.append(f"pos:{pos}")
        tags.append(f"cefr:{(cefr_dict or '').upper()}")

    # ── 22. R-PHRASE-FUTURE ──────────────────────────────────────────────────
    if panel is None and (" " in key or "-" in key):
        matched.append("R-PHRASE-FUTURE")
        panel, conf, reason = "phrase_future_panel", 0.9, "multi-word / hyphenated key"
        tags.append("out_of_scope_v19")

    # ── 23. R-FALLBACK-UNKNOWN ───────────────────────────────────────────────
    if panel is None:
        matched.append("R-FALLBACK-UNKNOWN")
        panel, conf, reason = "unknown_review_panel", 0.5, "no rule matched"
        candidates = _closest_candidates(key, pos)

    # ── homonym side-tags (curated content words) ────────────────────────────
    if panel == "normal_word_panel" and key in MONTH_NAMES:
        tags.append("homonym_month")

    # ── confidence modifiers (spec §4) ───────────────────────────────────────
    if panel == "normal_word_panel" and pos == "other":
        conf -= 0.10
    if 0 < len(d) < 10:
        conf -= 0.10
    if ("not a standard english word" in dl) and not any(
        r in matched for r in ("R-BAD-ENTRY", "R-NON-WORD-NOISE", "R-LEN-LE-2-NONSTANDARD")
    ):
        conf -= 0.15
    if multi_disagree:
        conf -= 0.10
    conf = _clamp(conf)

    # ── low-confidence reroute (spec §4: <0.6 → unknown_review_panel) ─────────
    if conf < 0.6 and panel not in {"unknown_review_panel", "transcript_noise_block",
                                    "sensitive_review_panel"}:
        if panel not in candidates:
            candidates = [panel] + candidates
        panel = "unknown_review_panel"
        reason = f"confidence {conf} < 0.60 — routed to review ({reason})"

    # ── C3/C4 guard: every redirect needs a base ─────────────────────────────
    if panel in {"inflected_redirect_panel", "plural_redirect_panel"}:
        if not base:
            candidates = [panel] + candidates
            panel = "unknown_review_panel"
            reason = f"redirect base not recoverable ({reason})"
            conf = min(conf, 0.55)
        elif base not in selector.DICTIONARY_WORDS:
            tags.append("lemma_not_in_dict")

    # candidate_panel_types only for unknown or confidence < 0.85 (spec §2.1)
    if panel != "unknown_review_panel" and conf >= 0.85:
        candidates = []

    # cefr_of_expansion enrichment for abbreviation panels (audit only)
    if panel == "abbreviation_panel":
        exp_tag = next((t for t in tags if t.startswith("expansion:")), None)
        if exp_tag:
            head = exp_tag.split(":", 1)[1].split("_")[0]
            exp_entry = CURRENT_DICT.get(head)
            exp_cefr = exp_entry.get("cefr") if isinstance(exp_entry, dict) else None
            if exp_cefr:
                tags.append(f"cefr_of_expansion:{exp_cefr}")

    # ── selector lane alignment ──────────────────────────────────────────────
    try:
        lane_today, _lane_reason = selector.assign_lane(key, entry) if is_entry else ("unknown", "")
    except Exception as exc:  # never crash the census on one weird entry
        lane_today, _lane_reason = "selector_error", str(exc)
    agrees = panel in LANE_EXPECTED.get(lane_today, set())

    policies = _policies(panel, conf, base, selector)

    # de-duplicate tags while preserving order
    seen: set[str] = set()
    tags = [t for t in tags if not (t in seen or seen.add(t))]

    return {
        "key": key,
        "primary_panel_type": panel,
        "tags": tags,
        "confidence": _clamp(conf),
        "reason": reason,
        "generation_lane": policies["generation_lane"],
        "patch_policy": policies["patch_policy"],
        "review_policy": policies["review_policy"],
        "base_or_redirect_target": base if panel in {
            "inflected_redirect_panel", "plural_redirect_panel"} else None,
        "ui_hint": PANEL_POLICY[panel]["ui_hint"],
        "evidence": {
            "pos": entry.get("pos") if is_entry else None,
            "cefr_dict": cefr_dict,
            "lemma_field": lemma,
            "has_learner_panel": rich,
            "matched_rules": matched,
            "selector_lane_today": lane_today,
            "selector_agrees": agrees,
            "candidate_panel_types": candidates,
        },
    }


def _policies(panel: str, conf: float, base: str | None, selector: Any) -> dict[str, str]:
    pol = dict(PANEL_POLICY[panel])
    # review_policy refined by confidence + panel risk (taxonomy §3.3).
    if panel in {"sensitive_review_panel", "unknown_review_panel", "phrase_future_panel"}:
        review = "human_required"
    elif panel in {"informal_contraction_panel", "slang_panel"}:
        review = "human_spot_check"
    elif panel == "abbreviation_panel":
        in_dict = bool(base and base in selector.DICTIONARY_WORDS)
        review = "auto_safe" if (conf >= 0.9 and in_dict) else "human_spot_check"
    else:
        # redirects, noise, named entities, normal words
        review = "auto_safe" if conf >= 0.9 else "human_spot_check"
    pol["review_policy"] = review
    return pol


# ─── Census driver ───────────────────────────────────────────────────────────

def run_census(data: dict[str, Any], scope_keys: list[str], selector: Any) -> list[dict[str, Any]]:
    records = []
    for key in scope_keys:
        entry = data.get(key)
        if not isinstance(entry, dict):
            entry = {}
        records.append(classify(key, entry, selector))
    records.sort(key=lambda r: (PANEL_ORDER[r["primary_panel_type"]], r["key"]))
    return records


def resolve_scope(data: dict[str, Any], scope: str) -> tuple[str, list[str]]:
    keys = list(data.keys())
    if scope == "all":
        return "all", keys
    if scope == "sample":
        ordered = sorted(keys)
        step = max(1, len(ordered) // 200)
        sample = ordered[::step][:200]
        return "sample", sample
    requested = [w.strip() for w in scope.split(",") if w.strip()]
    return f"words:{','.join(requested)}", requested


# ─── Self-validation (spec §6) ───────────────────────────────────────────────

def self_validate(records: list[dict[str, Any]], scope_keys: list[str],
                  selector: Any) -> list[tuple[str, bool, str]]:
    checks: list[tuple[str, bool, str]] = []

    def add(cid: str, ok: bool, detail: str = "") -> None:
        checks.append((cid, ok, detail))

    add("C1", len(records) == len(scope_keys),
        f"{len(records)} classified vs {len(scope_keys)} in scope")

    bad_types = [r["key"] for r in records if r["primary_panel_type"] not in PANEL_ORDER]
    add("C2", not bad_types, f"{len(bad_types)} entries with unknown panel type")

    missing_base = [r["key"] for r in records
                    if r["primary_panel_type"] in {"inflected_redirect_panel", "plural_redirect_panel"}
                    and not r["base_or_redirect_target"]]
    add("C3", not missing_base, f"{len(missing_base)} redirects without a base")

    bad_base = []
    for r in records:
        if r["primary_panel_type"] in {"inflected_redirect_panel", "plural_redirect_panel"}:
            tgt = r["base_or_redirect_target"]
            if tgt and tgt not in selector.DICTIONARY_WORDS and "lemma_not_in_dict" not in r["tags"]:
                bad_base.append(r["key"])
    add("C4", not bad_base, f"{len(bad_base)} redirect bases neither in dict nor tagged lemma_not_in_dict")

    bad_normal = [r["key"] for r in records
                  if r["primary_panel_type"] == "normal_word_panel"
                  and (r["evidence"]["pos"] or "").lower() not in {"verb", "noun", "adjective", "adverb"}
                  and "curated_rich_panel" not in r["tags"]]
    add("C5", not bad_normal, f"{len(bad_normal)} normal_word_panel without valid POS / curated tag")

    bad_sens = [r["key"] for r in records
                if r["primary_panel_type"] == "sensitive_review_panel"
                and not any(t.startswith("sensitivity:") for t in r["tags"])]
    add("C6", not bad_sens, f"{len(bad_sens)} sensitive panels without a sensitivity: tag")

    bad_conf = [r["key"] for r in records if not (0.0 <= r["confidence"] <= 1.0)]
    add("C7", not bad_conf, f"{len(bad_conf)} entries with out-of-range confidence")

    bad_c8 = [r["key"] for r in records
              if r["primary_panel_type"] == "normal_word_panel"
              and r["evidence"]["lemma_field"]
              and r["evidence"]["lemma_field"] != r["key"]]
    add("C8", not bad_c8, f"{len(bad_c8)} normal_word_panel entries with a lemma redirect")

    by_type = Counter(r["primary_panel_type"] for r in records)
    add("C9", sum(by_type.values()) == len(records),
        f"by_type total {sum(by_type.values())} vs {len(records)}")

    agree = sum(1 for r in records if r["evidence"]["selector_agrees"])
    disagree = len(records) - agree
    add("C10", agree + disagree == len(records),
        f"agree {agree} + disagree {disagree} == {len(records)}")

    return checks


# ─── Output builders ─────────────────────────────────────────────────────────

def build_summary(records: list[dict[str, Any]]) -> dict[str, Any]:
    by_type = Counter(r["primary_panel_type"] for r in records)
    by_conf = {"high_>=_0.9": 0, "mid_0.6_0.9": 0, "low_<_0.6": 0}
    for r in records:
        c = r["confidence"]
        if c >= 0.9:
            by_conf["high_>=_0.9"] += 1
        elif c >= 0.6:
            by_conf["mid_0.6_0.9"] += 1
        else:
            by_conf["low_<_0.6"] += 1
    multi = sum(1 for r in records if len(r["tags"]) >= 3)
    agree = sum(1 for r in records if r["evidence"]["selector_agrees"])
    return {
        "total_classified": len(records),
        "by_panel_type": {p: by_type.get(p, 0) for p in PANEL_TYPES},
        "by_confidence_bucket": by_conf,
        "multi_tag_count": multi,
        "selector_lane_alignment": {
            "agree": agree,
            "disagree_with_reason": len(records) - agree,
        },
    }


def build_json(records: list[dict[str, Any]], summary: dict[str, Any],
               scope_label: str, dict_count: int) -> dict[str, Any]:
    return {
        "name": "Word Panel Entry Census v1",
        "generated_by": "word_panel_entry_census.py",
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "dictionary_path": "assets/word_definitions.json",
        "dictionary_key_count": dict_count,
        "scope": scope_label,
        "summary": summary,
        "entries": records,
    }


def build_md(records: list[dict[str, Any]], summary: dict[str, Any], scope_label: str,
             dict_count: int, checks: list[tuple[str, bool, str]],
             version: str, data: dict[str, Any]) -> str:
    L: list[str] = []
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    L.append(f"# Word Panel Entry Census v{version}")
    L.append("")
    L.append(f"Generated at: {ts}")
    L.append("Generated by: `word_panel_entry_census.py`")
    L.append(f"Scope: `{scope_label}`")
    L.append(f"Dictionary keys (full): {dict_count}")
    L.append(f"Entries classified (this scope): {summary['total_classified']}")
    L.append("")

    L.append("## 1. Counts by panel type")
    L.append("")
    L.append("| Panel type | Count |")
    L.append("|---|---|")
    for p in PANEL_TYPES:
        L.append(f"| `{p}` | {summary['by_panel_type'][p]} |")
    L.append("")

    L.append("## 2. Confidence histogram")
    L.append("")
    L.append("| Bucket | Count |")
    L.append("|---|---|")
    for k, v in summary["by_confidence_bucket"].items():
        L.append(f"| {k} | {v} |")
    L.append("")

    L.append("## 3. Selector-lane alignment")
    L.append("")
    sla = summary["selector_lane_alignment"]
    L.append(f"- agree: **{sla['agree']}**")
    L.append(f"- disagree_with_reason: **{sla['disagree_with_reason']}**")
    L.append("")
    disagreements = Counter(
        (r["evidence"]["selector_lane_today"], r["primary_panel_type"])
        for r in records if not r["evidence"]["selector_agrees"]
    )
    L.append("| selector lane today | v19 panel type | Count |")
    L.append("|---|---|---|")
    for (lane, panel), n in sorted(disagreements.items(), key=lambda x: -x[1]):
        L.append(f"| `{lane}` | `{panel}` | {n} |")
    L.append("")

    L.append("## 4. Per-panel-type examples (top 20 by confidence)")
    L.append("")
    by_panel: dict[str, list[dict[str, Any]]] = {p: [] for p in PANEL_TYPES}
    for r in records:
        by_panel[r["primary_panel_type"]].append(r)
    for p in PANEL_TYPES:
        rows = sorted(by_panel[p], key=lambda r: -r["confidence"])[:20]
        L.append(f"### `{p}` ({len(by_panel[p])})")
        L.append("")
        if not rows:
            L.append("_none in this scope_")
            L.append("")
            continue
        L.append("| key | conf | reason | tags |")
        L.append("|---|---|---|---|")
        for r in rows:
            tagstr = ", ".join(r["tags"][:6])
            L.append(f"| `{r['key']}` | {r['confidence']} | {r['reason']} | {tagstr} |")
        L.append("")

    L.append("## 5. Multi-tag entries (tags ≥ 3, first 30)")
    L.append("")
    multi = [r for r in records if len(r["tags"]) >= 3][:30]
    L.append("| key | panel type | tags |")
    L.append("|---|---|---|")
    for r in multi:
        L.append(f"| `{r['key']}` | `{r['primary_panel_type']}` | {', '.join(r['tags'])} |")
    L.append("")

    unknown = [r for r in records if r["primary_panel_type"] == "unknown_review_panel"]
    L.append(f"## 6. Unknown review queue ({len(unknown)})")
    L.append("")
    L.append("| key | conf | candidates | reason |")
    L.append("|---|---|---|---|")
    for r in unknown[:200]:
        L.append(f"| `{r['key']}` | {r['confidence']} | {', '.join(r['evidence']['candidate_panel_types'])} | {r['reason']} |")
    if len(unknown) > 200:
        L.append(f"| … | | | {len(unknown) - 200} more in JSON |")
    L.append("")

    sensitive = [r for r in records if r["primary_panel_type"] == "sensitive_review_panel"]
    L.append(f"## 7. Sensitive review queue ({len(sensitive)})")
    L.append("")
    by_kind: dict[str, list[str]] = {}
    for r in sensitive:
        kind = next((t.split(":", 1)[1] for t in r["tags"] if t.startswith("sensitivity:")), "unknown")
        by_kind.setdefault(kind, []).append(r["key"])
    L.append("| sensitivity_kind | count | keys (sample) |")
    L.append("|---|---|---|")
    for kind, keys in sorted(by_kind.items()):
        L.append(f"| `{kind}` | {len(keys)} | {', '.join(sorted(keys)[:12])} |")
    L.append("")

    L.append("## 8. Worked-example anchors (taxonomy §5)")
    L.append("")
    L.append("| key | expected panel | actual panel | match | tags |")
    L.append("|---|---|---|---|---|")
    rec_by_key = {r["key"]: r for r in records}
    for key, expected in ANCHOR_EXPECTATIONS:
        r = rec_by_key.get(key)
        if r is None:
            if key not in data:
                L.append(f"| `{key}` | `{expected}` | _absent from dict_ | n/a | |")
            else:
                L.append(f"| `{key}` | `{expected}` | _not in scope_ | n/a | |")
            continue
        actual = r["primary_panel_type"]
        mark = "✅" if actual == expected else "❌"
        L.append(f"| `{key}` | `{expected}` | `{actual}` | {mark} | {', '.join(r['tags'][:5])} |")
    L.append("")

    L.append("## 9. Validation checks (spec §6)")
    L.append("")
    L.append("| Check | Result | Detail |")
    L.append("|---|---|---|")
    for cid, ok, detail in checks:
        L.append(f"| {cid} | {'PASS' if ok else 'FAIL'} | {detail} |")
    L.append("")
    L.append("### Acceptance lower-bounds (spec §7 — meaningful only for `--scope all`)")
    L.append("")
    bt = summary["by_panel_type"]
    L.append("| Metric | Value | Threshold | OK |")
    L.append("|---|---|---|---|")
    L.append(f"| inflected_redirect_panel | {bt['inflected_redirect_panel']} | ≥ 560 | "
             f"{'✅' if bt['inflected_redirect_panel'] >= 560 else '⚠️ (scope-dependent)'} |")
    L.append(f"| proper_name_panel | {bt['proper_name_panel']} | ≥ 200 | "
             f"{'✅' if bt['proper_name_panel'] >= 200 else '⚠️ (scope-dependent)'} |")
    L.append(f"| sensitive_review_panel | {bt['sensitive_review_panel']} | ≥ 80 | "
             f"{'✅' if bt['sensitive_review_panel'] >= 80 else '⚠️ (scope-dependent)'} |")
    L.append("")

    L.append("## 10. Constraints")
    L.append("")
    L.append("- `assets/word_definitions.json` was **not modified** (read-only census).")
    L.append("- Flutter UI was **not modified**.")
    L.append("- The selector / factory code was **not modified** (imported read-only).")
    L.append("- **No GPT call** was made.")
    L.append("- **No patch** was applied to any asset.")
    L.append("- **No commit** was made by this script.")
    L.append("")
    return "\n".join(L) + "\n"


# ─── --explain ───────────────────────────────────────────────────────────────

def explain(word: str, data: dict[str, Any], selector: Any) -> int:
    if word not in data:
        print(f"'{word}' is ABSENT from the dictionary — cannot classify.")
        return 0
    rec = classify(word, data[word], selector)
    print(f"=== EXPLAIN: {word!r} ===")
    print(f"primary_panel_type : {rec['primary_panel_type']}")
    print(f"confidence         : {rec['confidence']}")
    print(f"reason             : {rec['reason']}")
    print(f"tags               : {rec['tags']}")
    print(f"generation_lane    : {rec['generation_lane']}")
    print(f"patch_policy       : {rec['patch_policy']}")
    print(f"review_policy      : {rec['review_policy']}")
    print(f"base_or_redirect   : {rec['base_or_redirect_target']}")
    print(f"ui_hint            : {rec['ui_hint']}")
    print("evidence:")
    for k, v in rec["evidence"].items():
        print(f"    {k:24}: {v}")
    print("(no files written — --explain is stdout only)")
    return 0


# ─── CLI ─────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="V19B read-only word-panel entry census (no GPT, no dict patch, no commit).")
    parser.add_argument("--scope", default="all",
                        help="all | sample | word1,word2,... (default: all)")
    parser.add_argument("--census-version", default="1",
                        help="version string used in output filenames (default: 1)")
    parser.add_argument("--explain", default=None,
                        help="classify ONE word and print the evidence trail to stdout; writes no files")
    args = parser.parse_args()

    # Fail loudly on dictionary load or selector import failure.
    try:
        if not DICT_PATH.exists():
            raise FileNotFoundError(f"dictionary not found at {DICT_PATH}")
        data = json.loads(DICT_PATH.read_text())
        if not isinstance(data, dict) or not data:
            raise ValueError("dictionary did not parse into a non-empty object")
    except Exception as exc:
        print(f"FATAL: could not load dictionary: {exc}", file=sys.stderr)
        return 2

    try:
        selector = load_selector()
    except Exception as exc:
        print(f"FATAL: could not import selector module: {exc}", file=sys.stderr)
        return 2

    # Populate the selector's dictionary-aware lookup (needed by
    # looks_like_third_person_s_inflection and assign_lane). Read-only.
    selector.DICTIONARY_WORDS.clear()
    selector.DICTIONARY_WORDS.update(k.lower() for k in data.keys() if isinstance(k, str))

    global CURRENT_DICT
    CURRENT_DICT = data

    if args.explain:
        return explain(args.explain, data, selector)

    scope_label, scope_keys = resolve_scope(data, args.scope)
    print(f"Scope: {scope_label} ({len(scope_keys)} keys)")

    records = run_census(data, scope_keys, selector)
    summary = build_summary(records)
    checks = self_validate(records, scope_keys, selector)
    failures = [(cid, detail) for cid, ok, detail in checks if not ok]

    version = args.census_version
    json_path = REPORTS / f"word_panel_entry_census_v{version}.json"
    md_path = REPORTS / f"word_panel_entry_census_v{version}.md"

    payload = build_json(records, summary, scope_label, len(data))
    md_text = build_md(records, summary, scope_label, len(data), checks, version, data)

    REPORTS.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    md_path.write_text(md_text)

    print(f"Wrote JSON: {json_path}")
    print(f"Wrote MD:   {md_path}")
    print()
    print("Counts by panel type:")
    for p in PANEL_TYPES:
        print(f"  {p:28s} {summary['by_panel_type'][p]}")
    print()
    print("Self-validation:")
    for cid, ok, detail in checks:
        print(f"  {cid}: {'PASS' if ok else 'FAIL'} — {detail}")
    if failures:
        print()
        print(f"WARNING: {len(failures)} self-validation check(s) FAILED — see report.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
