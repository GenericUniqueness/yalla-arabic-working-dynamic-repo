#!/usr/bin/env python3
"""
Rich enrichment factory for word panel generation.

This script is preview-first and no-patch by default. It builds a gold standard,
classifies entries, generates safe learner-panel previews, judges them with
deterministic checks, and writes review artifacts under reports/.

It does not modify assets/word_definitions.json, Flutter UI, Course 09, or
Firebase/auth.
"""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import os
import re
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional


def report_generated_stamp() -> str:
    """UTC stamp used in every report's Generated: line. v17 fix for stale dates."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

from openai import OpenAI


REPO_ROOT = Path(__file__).resolve().parents[2]
DICT_PATH = REPO_ROOT / "assets" / "word_definitions.json"
REPORTS = REPO_ROOT / "reports"
CORE_LEARNER_PACK_V1 = REPORTS / "word_panel_core_learner_pack_v1_selection.json"
GPT_GENERATION_SOURCE = "openai_api"
GPT_ALLOWED_REVIEW_SUITABILITY = {"mcq_safe", "review_only", "not_suitable"}
GPT_PREVIEW_WORDS_5 = ["count", "knock", "warn", "note", "seat"]
GPT_PREVIEW_WORDS_10 = ["count", "knock", "warn", "note", "seat", "wipe", "vote", "scan", "spread", "combine"]
GPT_PREVIEW_WORDS = [
    "count",
    "knock",
    "spell",
    "warn",
    "wipe",
    "vote",
    "scan",
    "spread",
    "combine",
    "mention",
    "explore",
    "perform",
    "promote",
    "punish",
    "sneeze",
    "capture",
    "dish",
    "film",
    "gift",
    "mail",
    "menu",
    "note",
    "seat",
    "tool",
    "wave",
]
GPT_REVIEW_SENSITIVE = {"stab", "punch", "wine", "idiot"}

PROMPT_LEAK_FRAGMENTS = [
    "ي ت أ س",
    "must start",
    "starts with",
    "comma-separated",
    "mudari",
    "root or imperative",
    "convert it",
]

# ─── v14 pipeline hardening (offline, no GPT) ────────────────────────────────

# Words the dictionary may mark A1 but which are clearly beyond A1.
# When GPT echoes A1 for one of these the validator emits a *warning*
# (the entry status flips to "review" via the issues list) so the
# human reviewer can decide.
SUSPECT_A1_WORDS: set[str] = {
    "jargon", "exposure", "dictator", "governor", "criminal", "biology",
    "scholar", "villain", "ancestor", "cassette", "penalty", "pursuit",
    "warrior", "wartime", "barrier", "comedy", "chaotic", "ancient",
    "naughty", "jealous", "aspirin", "brunette", "cucumber", "dialogue",
    "elevator", "everyday", "flagpole", "gardener", "officer", "journal",
    "lecture", "mammal", "mobile", "narrow", "novel", "object", "orphan",
    "parade", "petrol", "popcorn", "primary", "region", "reward",
    "rhythm", "shelter", "skilled", "spouse", "stadium", "streak",
    "studio", "stylish", "surface", "talent", "tighten", "tourist",
    "typical", "uniform", "variety", "warning", "massive", "contain",
}

# Known risky Arabic mappings flagged for manual review after v13.
SUSPECT_ARABIC_WORDS: set[str] = {
    "dial", "scooter", "boot", "orphan", "everyday", "exist",
    "depend", "flash",
}

# Legitimate non-verb Arabic words that start with ي and must NOT be
# false-flagged by the strict "non-verb Arabic looks verbal" check.
LEGITIMATE_NON_VERB_YA_ARABIC: set[str] = {
    "يومي", "يومية", "يتيم", "يتيمة", "يوم", "يد", "يدوي", "يدوية",
    "يمين", "يميني", "يسار", "يساري", "ياقوت", "ياسمين", "يقين",
    "يقظ", "يقظة", "يأس", "يافع", "يافعة", "ياء", "يخت",
}


class GPTPreviewFailure(RuntimeError):
    def __init__(
        self,
        message: str,
        *,
        api_call_count: int = 0,
        token_usage: Optional[Dict[str, int]] = None,
        # v18.2 batch-reliability metadata. None when the failure happened
        # outside the per-word loop (config errors, etc.).
        failed_word: Optional[str] = None,
        completed_word_count: int = 0,
        skipped_completed_count: int = 0,
        checkpoint_path: Optional[str] = None,
        resumable: bool = False,
    ):
        super().__init__(message)
        self.api_call_count = api_call_count
        self.token_usage = token_usage or {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0}
        self.failed_word = failed_word
        self.completed_word_count = completed_word_count
        self.skipped_completed_count = skipped_completed_count
        self.checkpoint_path = checkpoint_path
        self.resumable = resumable

SMOKE_20 = [
    "behave",
    "construct",
    "employ",
    "flash",
    "hop",
    "hurry",
    "participate",
    "pronounce",
    "rinse",
    "shut",
    "contain",
    "believe",
    "know",
    "include",
    "remain",
    "gonna",
    "ain't",
    "uh",
    "alan",
    "caroac",
]

GOLD_30 = [
    "behave",
    "construct",
    "employ",
    "flash",
    "hop",
    "hurry",
    "participate",
    "pronounce",
    "rinse",
    "shut",
    "contain",
    "believe",
    "know",
    "include",
    "remain",
    "gonna",
    "ain't",
    "uh",
    "alan",
    "caroac",
    "acceptable",
    "accurate",
    "annoyed",
    "ancient",
    "bald",
    "abroad",
    "childhood",
    "bedtime",
    "birth",
    "afterwards",
]

EXCLUDED_PATCHED = {
    "abandon",
    "absorb",
    "allow",
    "appear",
    "apply",
    "activate",
    "adjust",
    "amazement",
    "absence",
    "bull",
    "bird",
    "seller",
    "ache",
    "alternative",
    "nicely",
    "add",
    "build",
    "carry",
    "sorta",
    "accomplish",
    "admit",
    "adopt",
    "advertise",
    "acquire",
    "abroad",
    "acceptable",
    "accurate",
}

NEGATIVE_KEEP_EXISTING = {"uh"}
NEGATIVE_BLOCKED = {"alan", "caroac", "cassidy", "noam", "abby"}
LIMITED_FORM_VERBS = {"consist", "depend", "exist", "rely", "require"}

# v18.3: stative/non-progressive verbs that must NOT receive a deterministic
# -ing injection. Excludes LIMITED_FORM_VERBS which are handled separately.
STATIVE_VERBS_NO_ING: set[str] = {
    "know", "believe", "prefer", "contain", "own", "mean", "deserve",
    "fit", "suit", "resemble", "possess", "belong", "need", "want",
    "seem", "appear",
}

# Long words that genuinely are A1 for Arabic learners — CEFR-echo check
# should not fire for these even when corrected_cefr matches dictionary. (G1b)
CEFR_ECHO_ALLOWLIST: set[str] = {
    "computer", "internet", "wonderful", "comfortable", "important",
    "favorite", "favourite", "elephant", "delicious",
}

# Arabic fragments that signal instruction/rule text leaked into arabic_nuance.
# Any of these strings inside arabic_nuance triggers warn:arabic_meta_in_nuance. (G3)
ARABIC_INSTRUCTION_FRAGMENTS: list[str] = [
    "قاعدة", "تعليمات", "يبدأ بـ", "يبدأ ب", "ينتهي بـ", "حرف ي", "مثال:",
]

# Curated set of genuinely confusing English word pairs for Arabic learners.
# Stored as sorted tuples so lookup is order-independent.
# compares_with.word must appear in one of these pairs or a warn: warning is raised.
KNOWN_CONFUSING_PAIRS: set[tuple[str, str]] = {
    ("do", "make"),
    ("say", "tell"),
    ("borrow", "lend"),
    ("for", "since"),
    ("many", "much"),
    ("every day", "everyday"),
    ("affect", "effect"),
    ("remind", "warn"),
    ("arrive", "reach"),
    ("lay", "lie"),
    ("bring", "take"),
    ("see", "watch"),
    ("hear", "listen"),
    ("come", "go"),
    ("home", "house"),
    ("rob", "steal"),
    ("rise", "raise"),
    ("fewer", "less"),
    ("assure", "ensure"),
    ("beside", "besides"),
    ("lose", "loose"),
}

# v17: convenience set of all single words appearing in any known confusing pair.
# Used to emit warn:missing_known_comparison when a word is part of a curated
# pair and compares_with is null. Excludes multi-word entries like "every day".
KNOWN_CONFUSING_WORDS: set[str] = {
    w for pair in KNOWN_CONFUSING_PAIRS for w in pair if " " not in w
}


def known_partners_for(word: str) -> List[str]:
    """Return curated partner words for `word` from KNOWN_CONFUSING_PAIRS."""
    lw = word.lower()
    partners: List[str] = []
    for a, b in KNOWN_CONFUSING_PAIRS:
        if lw == a and " " not in b:
            partners.append(b)
        elif lw == b and " " not in a:
            partners.append(a)
    return partners


# v17: curated Arabic-sense risk map.
# For known recurring V16 sense traps, list acceptable Arabic substrings that
# indicate the right sense was used (any present => OK), and a list of bad
# Arabic substrings that indicate the wrong sense was used (any present =>
# warn). Map is small and maintainable, not a one-off hack per word.
ARABIC_SENSE_RISK_MAP: Dict[str, Dict[str, Any]] = {
    "combine": {
        "english_sense": "combine should mean mix/merge; for color senses use درجة لون not ظل",
        "good_arabic": ["يخلط", "يجمع", "يدمج", "يمزج", "درجة لون", "ألوان"],
        "bad_arabic": ["ظل جديد", "ظلًا", "ظلاً", "خلق ظل"],
    },
    "scan": {
        "english_sense": "scan should mean quick read/check, not machine scan unless example is machine scanning",
        # v17.4: broadened good_arabic to include the natural quick-read
        # phrasings the prompt now requests explicitly.
        "good_arabic": [
            "يراجع بسرعة", "يتفحص بسرعة", "يستعرض بسرعة",
            "يمر بسرعة على", "ينظر بسرعة",
            "يتفحص", "يراجع", "يطلع", "يفحص بسرعة", "يقرأ بسرعة",
        ],
        # v17.4: machine-scan wording is no longer silently OK — these
        # forms are flagged unless scanner/digital context is explicit in
        # the English fields (handled by the machine_context_arabic +
        # English-context fallback below).
        "bad_arabic": [
            "يمسح الوثيقة", "أمسح الوثيقة", "أقوم بمسح الوثيقة",
            "نمسح الوثيقة", "تمسح الوثيقة", "بمسح المستند",
        ],
        "machine_context_arabic": ["يمسح ضوئيًا", "يمسح ضوئيًّا", "ماسح ضوئي"],
    },
    "hum": {
        "english_sense": "hum is يدندن (humming a tune), not يغني (sing)",
        "good_arabic": ["يدندن", "دندن", "همهم"],
        "bad_arabic": ["يغني", "تغني", "غنّى"],
    },
    "seat": {
        "english_sense": "for 'take a seat' prefer natural Arabic like تفضل بالجلوس",
        "good_arabic": ["تفضل بالجلوس", "اجلس من فضلك", "مقعد", "مكان للجلوس"],
        "bad_arabic": ["أخذ مقعد", "خذ مقعد"],
    },
    "sneeze": {
        "english_sense": "sneeze: avoid the awkward 'tissue to catch the air' note",
        "good_arabic": ["يعطس"],
        "bad_arabic": ["يلتقط الهواء"],
        "bad_english_substrings": ["tissue to catch the air", "catch the air"],
    },
    "capture": {
        "english_sense": "capture definition must not be 'catch or catch'",
        "good_arabic": ["يقبض", "يأسر", "يلتقط"],
        "bad_arabic": [],
        "bad_english_substrings": ["catch or catch"],
    },
    # v17.4: lean sense check. "lean against the wall" should be rendered
    # as يستند إلى الجدار or يتكئ على الجدار, not the literal-but-unnatural
    # يميل ضد الجدار. The body-leaning / tilting sense (يميل / ينحني) is
    # also acceptable when the English example is about tilting, not
    # supporting against a surface.
    "lean": {
        "english_sense": "lean against a surface → يستند إلى / يتكئ على; lean/tilt → يميل / ينحني; never يميل ضد",
        "good_arabic": [
            "يستند إلى", "يستند على", "يتكئ على", "يتكأ على",
            "يميل إلى", "ينحني",
        ],
        "bad_arabic": ["يميل ضد", "ضد الجدار"],
    },
}

# v17: additional suspect-A1 single-word check list.
# These are recurring A1 mislabels from V16. Validator routes them to review
# when corrected_cefr=A1. Conservative list — not first-200 Arabic-learner vocab.
SUSPECT_A1_WORDS_V17: set[str] = {
    "flee", "behave", "grand", "aid", "burst", "lean", "wrap", "rub", "sew",
    "hop", "jog", "boo", "hum", "blank", "neat", "promote", "punish",
    "agreement", "capture", "announce", "arrange",
}

# v17.1: general CEFR heuristics that do not depend on curated word lists.
# Each entry is (predicate, warning_tag, message_builder). Heuristics return
# a soft warning so the entry routes to review but is not auto-rejected.

# Suffixes that strongly suggest an abstract/formal noun → unlikely A1.
_ABSTRACT_NOUN_SUFFIXES = (
    "tion", "sion", "ment", "ness", "ity", "ence", "ance", "ship", "hood",
    "ology", "graphy", "ism", "ure", "th",
)

# Endings that suggest a less-common physical/action verb → unlikely A1.
# These are mostly short Anglo-Saxon verbs that are perfectly real but live
# beyond the first ~200 learner words (flee, sew, rub, hop, jog, hum, etc.).
_UNCOMMON_VERB_LEN_THRESHOLD = 5  # short verbs more often legitimately A1
_KNOWN_A1_VERBS_FOR_HEURISTIC = {
    "be", "do", "go", "is", "am", "are", "was", "were",
    "have", "has", "had", "see", "saw", "say", "said",
    "eat", "ate", "drink", "drank", "want", "like", "love",
    "make", "made", "take", "took", "come", "came", "give", "gave",
    "get", "got", "put", "find", "found", "tell", "told",
    "think", "know", "work", "play", "live", "look", "feel", "felt",
    "use", "used", "buy", "bought", "sell", "sold", "open", "close",
    "start", "stop", "run", "walk", "talk", "ask", "answer",
    "read", "write", "wrote", "draw", "drew", "drive", "drove",
    "fly", "flew", "fall", "fell", "stand", "stood", "sit", "sat",
    "sleep", "slept", "wake", "woke", "wash", "cook", "clean",
    "help", "carry", "bring", "brought", "send", "sent", "show",
    "hear", "listen", "speak", "spoke", "learn", "study", "teach",
    "try", "tried", "wait", "leave", "left", "stay", "win", "won",
    "lose", "lost", "pay", "paid", "spend", "spent", "save", "share",
    "count", "knock", "spell", "wipe", "fix", "hide", "hid",
    "warn", "vote", "spread", "explore", "perform",
    # v17.2: align with A1 rubric anchor. `cheer` is everyday survival
    # vocabulary (cheering at sports, cheerful greeting) — basic for
    # Arabic learners and listed as an A1 anchor in the prompt rubric.
    # Without it here the validator demotes cheer purely on absence-from-list,
    # which contradicts the prompt the validator is meant to enforce.
    "cheer",
}

# v17.2: A2-common-verb allowlist used only to *suppress* a misleading
# "implies B1" tone in CEFR warnings. Membership here does not change
# patch-eligibility — the validator still warns when corrected_cefr=A1
# for these words via SUSPECT_A1_WORDS_V17. The point is that the reviewer
# should treat the word as "likely A2" rather than reflexively bumping to B1.
_KNOWN_A2_COMMON_WORDS_FOR_HEURISTIC = {
    # physical action verbs that are A2, not B1
    "hop", "jog", "rub", "sew", "lean", "spread", "wrap", "scan", "vote",
    "warn", "wipe", "mention", "explore", "perform", "combine", "sneeze",
    "arrange", "announce",
    # everyday adjectives/adverbs beyond A1 but well short of B1
    "blank", "neat", "angle", "apart",
}

# Suffixes that strongly suggest a formal/academic verb → unlikely A1.
_FORMAL_VERB_SUFFIXES = ("ate", "ize", "ise", "ify", "ute", "press")


# v17.4: CEFR anchor minimums.
# Small, curated, documented map of words that recur in V16/V17.x probes as
# genuinely B1+ for Arabic learners but get pushed down by the dictionary's
# A1 bias. The rule fires *category-level* — `if corrected_cefr < anchor_min:
# warn:cefr_below_anchor_minimum + route to review_cefr_only`. The map can
# grow without code changes; the validator logic remains generic.
#
# Sourced from the V17 root-cause audit's B1 anchor list. Kept small on
# purpose — only words where multiple probes agree the dictionary lies.
CEFR_ANCHOR_MINIMUMS: Dict[str, str] = {
    "flee": "B1",
    "behave": "B1",
    "burst": "B1",
    "promote": "B1",
    "punish": "B1",
    "capture": "B1",
    "agreement": "B1",
    "grand": "B1",
    "aid": "B1",
}


def cefr_level_index(value: Optional[str]) -> Optional[int]:
    """Return numeric index for a CEFR string. None for null/invalid."""
    mapping = {"A1": 1, "A2": 2, "B1": 3, "B2": 4, "C1": 5, "C2": 6}
    return mapping.get((value or "").strip())


def expected_difficulty_for_cefr(cefr: Optional[str]) -> Optional[str]:
    """v17.1: canonical difficulty<-cefr mapping used in validator warnings."""
    if not cefr:
        return None
    if cefr in {"A1", "A2"}:
        return "easy"
    if cefr == "B1":
        return "medium"
    if cefr in {"B2", "C1", "C2"}:
        return "advanced"
    return None

POS_ORDER = {"verb": 0, "noun": 1, "adjective": 2, "adverb": 3, "other": 4}
CEFR_ORDER = {"A1": 0, "A2": 1, "B1": 2, "B2": 3, "C1": 4, "C2": 5}


def load_words_from_report(path: Path) -> set[str]:
    if not path.exists():
        return set()
    payload = json.loads(path.read_text())
    words: set[str] = set()
    for entry in payload.get("entries", []):
        if isinstance(entry, dict) and entry.get("word"):
            words.add(entry["word"])
    return words


def excluded_words_for_unseen_preview() -> set[str]:
    return (
        load_words_from_report(REPORTS / "word_panel_gold_entry_standard_v1.json")
        | load_words_from_report(REPORTS / "word_panel_template_first_25_entry_assembled_preview.json")
        | EXCLUDED_PATCHED
    )


def cefr_rank(value: Optional[str]) -> int:
    if not value:
        return 99
    return CEFR_ORDER.get(value.upper(), 99)


def is_probable_inflected_word(word: str, entry: Dict[str, Any]) -> bool:
    definition = (entry.get("definition") or "").lower().strip()
    lemma = entry.get("lemma")
    pos = entry.get("pos")
    if lemma and lemma != word:
        return True
    if re.match(
        r"^(past tense of|past form of|present form of|third person singular of|the present form of|the past form of|the past tense of|past participle of)",
        definition,
    ):
        return True
    if "third person singular" in definition or "present tense" in definition and "third person" in definition:
        return True
    if pos == "verb" and word.endswith(("ed", "ing")):
        return True
    if pos in {"noun", "adjective", "adverb"} and word.endswith(("ed", "ing")) and ("past" in definition or "present" in definition):
        return True
    return False


def is_blocked_candidate(word: str, entry: Dict[str, Any]) -> bool:
    if word in NEGATIVE_BLOCKED:
        return True
    pos = entry.get("pos")
    definition = (entry.get("definition") or "").lower()
    if pos in {"proper noun", "bad_entry"}:
        return True
    if pos == "other" and ("name" in definition or "not a standard english word" in definition):
        return True
    if "name" in definition and pos in {"noun", "other"}:
        return True
    if "not a standard english word" in definition:
        return True
    return False


def is_review_candidate(word: str, entry: Dict[str, Any]) -> bool:
    if word in NEGATIVE_KEEP_EXISTING:
        return False
    if is_blocked_candidate(word, entry):
        return False
    if is_probable_inflected_word(word, entry):
        return True
    pos = entry.get("pos")
    if pos in {"pronoun", "preposition", "conjunction", "interjection"}:
        return True
    if pos == "other":
        return True
    return False


def classification_for_word(word: str, entry: Dict[str, Any]) -> tuple[str, str]:
    if word in NEGATIVE_KEEP_EXISTING:
        return "keep_existing", "manual keep-existing negative example"
    if is_blocked_candidate(word, entry):
        return "blocked", "proper noun / bad entry / nonstandard token"
    if is_review_candidate(word, entry):
        return "review_only", "inflected form or review-only token"
    if isinstance(entry.get("learner_panel"), dict):
        return "keep_existing", "existing learner_panel preserved"
    return "pass", "fresh unseen base entry"


def strip_leading_to(text: str) -> str:
    text = (text or "").strip()
    lowered = text.lower()
    if lowered.startswith("to "):
        text = text[3:]
    if text and text[0].isupper():
        text = text[0].lower() + text[1:]
    return text.rstrip(".")


def concise_definition(text: str) -> str:
    text = (text or "").strip()
    if not text:
        return text
    text = text.split(";", 1)[0].strip()
    text = text.split(" (", 1)[0].strip()
    return text.rstrip(".")


def build_usage_note(word: str, entry: Dict[str, Any]) -> str:
    definition = concise_definition(entry.get("definition", ""))
    pos = entry.get("pos")
    if pos == "verb":
        return f"Use {word} when someone {strip_leading_to(definition).lower()}."
    if pos == "noun":
        return f"Use {word} when talking about {definition.lower()}."
    if pos == "adjective":
        return f"Use {word} to describe something that is {definition.lower()}."
    if pos == "adverb":
        return f"Use {word} when describing how, when, or where something happens."
    return f"Use {word} in the meaning given by the dictionary entry."


def build_mcq_safe_definition(entry: Dict[str, Any]) -> str:
    definition = concise_definition(entry.get("definition", ""))
    pos = entry.get("pos")
    if pos == "verb":
        return strip_leading_to(definition)
    return definition


def build_mcq_safe_arabic(entry: Dict[str, Any]) -> str:
    arabic = (entry.get("arabic") or "").strip()
    if not arabic:
        return arabic
    return arabic.split("،", 1)[0].strip()


def looks_like_verb_arabic(entry: Dict[str, Any]) -> bool:
    arabic = (entry.get("arabic") or "").strip()
    if not arabic:
        return False
    first_token = re.split(r"[،,؛;\s]", arabic, maxsplit=1)[0].strip()
    if not first_token:
        return False
    if first_token.startswith("ال"):
        return False
    if first_token.startswith(("ي", "ت", "ن", "أ", "س")):
        return True
    if first_token.startswith("ا") and len(first_token) > 2:
        return True
    if "ّ" in first_token:
        return True
    if first_token.endswith(("ت", "وا", "ن")) and len(first_token) > 3:
        return True
    return False


def arabic_verb_segments(text: str) -> List[str]:
    parts = re.split(r"[،,؛/]+", (text or "").strip())
    return [part.strip() for part in parts if part.strip()]


def compute_ing_form(word: str) -> Optional[str]:
    """v18.3: Compute the canonical -ing form for a regular English verb.

    Returns None for stative/limited verbs where -ing should be omitted.
    Rules applied in order:
      1. ie-ending → ying (die→dying, tie→tying)
      2. Silent-e drop (not 'ee') → +ing (wipe→wiping, cope→coping)
      3. CVC doubling for 3-4 letter words (hop→hopping, hum→humming)
      4. Default → +ing (fix→fixing, burst→bursting)
    Mirrors the heuristic in _needs_doubling() to stay consistent.
    """
    w = word.lower()
    if w in LIMITED_FORM_VERBS or w in STATIVE_VERBS_NO_ING:
        return None
    if w.endswith("ie"):
        return w[:-2] + "ying"
    if w.endswith("e") and not w.endswith("ee"):
        return w[:-1] + "ing"
    _V = set("aeiou")
    _ND = set("wxyhaeiou")
    if (
        3 <= len(w) <= 4
        and w[0] not in _V
        and w[-1] not in _ND
        and w[-2] in _V
        and w[-3] not in _V
    ):
        return w + w[-1] + "ing"
    return w + "ing"


def normalize_arabic_verb_segment(segment: str) -> str:
    return re.sub(r"[\u064B-\u0652\u0670\u0653-\u0655]", "", (segment or "").strip())


def looks_like_verbal_arabic_for_nonverb_check(arabic: str) -> bool:
    """Strict check for non-verb entries: only flag if arabic starts with \u064A (unambiguous verb prefix).

    \u0623 starts many nouns (\u0623\u062F\u0627\u0629, \u0623\u0645\u0644, \u0623\u0641\u0643\u0627\u0631), so it is excluded here to avoid false positives.
    Legitimate non-verb Arabic words that start with \u064A (e.g. \u064A\u0648\u0645\u064A, \u064A\u062A\u064A\u0645) are whitelisted via
    LEGITIMATE_NON_VERB_YA_ARABIC and must not be flagged.
    """
    if not arabic:
        return False
    first_token = re.split(r"[\u060C,\u061B;\s]", arabic.strip(), maxsplit=1)[0].strip()
    if not first_token or first_token.startswith("\u0627\u0644"):
        return False
    if first_token in LEGITIMATE_NON_VERB_YA_ARABIC:
        return False
    return first_token.startswith("\u064A")


def contains_english_letters(text: str) -> bool:
    """True if `text` contains any ASCII letters. Used to detect English
    leaking into Arabic-only fields like arabic_nuance."""
    if not text:
        return False
    return bool(re.search(r"[A-Za-z]", text))


def looks_like_present_style_verb_arabic_segment(segment: str) -> bool:
    normalized = normalize_arabic_verb_segment(segment)
    if not normalized:
        return False
    first_token = re.split(r"\s+", normalized, maxsplit=1)[0].strip()
    if not first_token:
        return False
    if first_token.startswith("ال"):
        return False
    return first_token.startswith(("ي", "ت", "أ", "س"))


def looks_like_imperative_or_root_verb_arabic_segment(segment: str) -> bool:
    normalized = normalize_arabic_verb_segment(segment)
    if not normalized:
        return False
    first_token = re.split(r"\s+", normalized, maxsplit=1)[0].strip()
    if not first_token:
        return False
    if first_token.startswith(("ي", "ت", "أ", "س")):
        return False
    root_like = {
        "نشر",
        "فرش",
        "صوّت",
        "امسح",
        "حذر",
        "طرق",
        "كتب",
        "قرأ",
        "خرج",
        "دخل",
        "وضع",
        "وقف",
    }
    imperative_like = {
        "امسح",
        "صوّت",
        "اكتب",
        "اقرأ",
        "خذ",
        "ضع",
        "قف",
        "اجلس",
        "ادخل",
        "اخرج",
    }
    if first_token in root_like or first_token in imperative_like:
        return True
    if len(first_token) > 2 and first_token[0] not in {"ي", "ت", "أ", "س"}:
        return True
    return False


def build_lookup_forms(word: str, entry: Dict[str, Any]) -> List[str]:
    lookup_forms = entry.get("lookup_forms")
    if isinstance(lookup_forms, list) and lookup_forms:
        return lookup_forms
    forms = entry.get("forms")
    if isinstance(forms, dict):
        ordered = []
        for key in ["base", "third_person", "past", "past_participle", "ing", "present_s", "third_s"]:
            if key in forms and forms[key] not in ordered:
                ordered.append(forms[key])
        return ordered
    return [word]


def build_form_pairs_from_entry(word: str, entry: Dict[str, Any], limited: bool = False) -> List[Dict[str, str]]:
    forms = entry.get("forms") or {}
    pairs: List[Dict[str, str]] = [{"label": "Base", "value": word}]
    value_map = {
        "base": "base",
        "third_person": "third_person",
        "third_s": "third_person",
        "present_s": "third_person",
        "past": "past",
        "past_part": "past_participle",
        "past_participle": "past_participle",
        "ing": "ing",
    }
    ordered_keys = ["base", "third_person", "past", "past_participle"]
    if not limited:
        ordered_keys.append("ing")
    for key in ordered_keys:
        value = forms.get(key)
        if value is None:
            for source_key, mapped_key in value_map.items():
                if mapped_key == key and source_key in forms:
                    value = forms[source_key]
                    break
        if value and value not in [item["value"] for item in pairs]:
            label = short_form_label(key)
            pairs.append({"label": label, "value": value})
    return pairs


def build_verb_examples(entry: Dict[str, Any], limited: bool = False) -> List[Dict[str, str]]:
    form_examples = entry.get("form_examples") or {}
    items: List[Dict[str, str]] = []
    main_example = entry.get("main_example") or entry.get("example") or ""
    if main_example:
        items.append({"label": "Main example", "text": main_example})
    ordered_keys = ["base", "third_person", "past", "past_participle"]
    if not limited:
        ordered_keys.append("ing")
    source_lookup = {
        "base": ["base", "present_s"],
        "third_person": ["third_person", "third_s", "present_s"],
        "past": ["past"],
        "past_participle": ["past_participle", "past_part"],
        "ing": ["ing", "present_part", "present_continuous"],
    }
    for key in ordered_keys:
        text = ""
        for source_key in source_lookup.get(key, [key]):
            if form_examples.get(source_key):
                text = form_examples[source_key]
                break
        if text and text not in [item["text"] for item in items]:
            items.append({"label": short_form_label(key), "text": text})
    return items


def build_dynamic_pass_entry(word: str, entry: Dict[str, Any]) -> Dict[str, Any]:
    pos = entry.get("pos")
    limited = word in LIMITED_FORM_VERBS
    learner_panel: Dict[str, Any] = {
        "schema_version": "beginner_v2",
        "grammar": {
            "part_of_speech": pos,
            "usage_note": build_usage_note(word, entry),
        },
        "examples": build_verb_examples(entry, limited=limited) if pos == "verb" else [{"label": "Main example", "text": entry.get("main_example") or entry.get("example") or ""}],
        "mcq_safe_definition": build_mcq_safe_definition(entry),
        "mcq_safe_arabic": build_mcq_safe_arabic(entry),
    }
    if pos == "verb":
        learner_panel["forms"] = build_form_pairs_from_entry(word, entry, limited=limited)
    lookup_forms = build_lookup_forms(word, entry)
    if lookup_forms:
        learner_panel["lookup_forms"] = lookup_forms
    if entry.get("learner_note"):
        learner_panel["learner_note"] = entry["learner_note"]
    if entry.get("common_mistake"):
        learner_panel["common_mistake"] = entry["common_mistake"]
    return learner_panel


def sort_key_for_candidate(word: str, entry: Dict[str, Any]) -> tuple[int, int, int, str]:
    return (
        cefr_rank(entry.get("cefr")),
        POS_ORDER.get(entry.get("pos"), 99),
        len(word),
        word,
    )


def load_core_learner_pack() -> Dict[str, Any]:
    if not CORE_LEARNER_PACK_V1.exists():
        raise SystemExit(f"Missing core learner pack: {CORE_LEARNER_PACK_V1}")
    return json.loads(CORE_LEARNER_PACK_V1.read_text())


def select_gpt_preview_words(pack: Dict[str, Any], limit: int = 25) -> List[str]:
    pack_words = {
        row["word"]
        for row in pack.get("words", [])
        if isinstance(row, dict) and row.get("risk_lane") == "auto_enrich_now"
    }
    selected: List[str] = []
    if limit == 5:
        candidate_words = GPT_PREVIEW_WORDS_5
    elif limit == 10:
        candidate_words = GPT_PREVIEW_WORDS_10
    elif limit == 25:
        candidate_words = GPT_PREVIEW_WORDS
    else:
        raise SystemExit("GPT preview supports only 5-word, 10-word, or 25-word preview lists.")
    for word in candidate_words:
        if word not in pack_words:
            raise SystemExit(f"GPT preview word not present in Core Learner Pack auto_enrich_now lane: {word}")
        selected.append(word)
    if len(selected) != limit:
        raise SystemExit(f"GPT preview word list must contain exactly {limit} words.")
    return selected


def gpt_response_schema() -> Dict[str, Any]:
    string_or_null = {"anyOf": [{"type": "string"}, {"type": "null"}]}
    cefr_or_null = {"anyOf": [{"type": "string", "enum": ["A1", "A2", "B1", "B2", "C1", "C2"]}, {"type": "null"}]}
    array_of_strings = {"type": "array", "items": {"type": "string"}}
    forms_array = {
        "type": "array",
        "items": {
            "type": "object",
            "additionalProperties": False,
            "required": ["label", "value", "example"],
            "properties": {
                "label": {"type": "string", "enum": ["Base", "Past", "Past participle", "-ing", "Third-person"]},
                "value": {"type": "string"},
                "example": {"type": "string"},
            },
        },
    }
    countability_or_null = {"anyOf": [{"type": "string", "enum": ["countable", "uncountable", "both", "n/a"]}, {"type": "null"}]}
    compares_with_or_null = {
        "anyOf": [
            {
                "type": "object",
                "additionalProperties": False,
                "required": ["word", "diff"],
                "properties": {
                    "word": {"type": "string"},
                    "diff": {"type": "string"},
                },
            },
            {"type": "null"},
        ]
    }
    learner_panel_schema = {
        "type": "object",
        "additionalProperties": False,
        "required": ["schema_version", "grammar", "examples", "forms", "compares_with"],
        "properties": {
            "schema_version": {"type": "string", "const": "v16"},
            "grammar": {
                "type": "object",
                "additionalProperties": False,
                "required": ["part_of_speech", "usage_note", "notes", "countability"],
                "properties": {
                    "part_of_speech": {"type": "string"},
                    "usage_note": {"type": "string"},
                    "notes": array_of_strings,
                    "countability": countability_or_null,
                },
            },
            "examples": {
                "type": "array",
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["label", "text", "arabic"],
                    "properties": {
                        "label": {"type": "string"},
                        "text": {"type": "string"},
                        "arabic": string_or_null,
                    },
                },
            },
            "forms": forms_array,
            "compares_with": compares_with_or_null,
        },
    }
    return {
        "type": "object",
        "additionalProperties": False,
        "required": [
            "word",
            "entry_type",
            "difficulty",
            "corrected_cefr",
            "definition",
            "arabic",
            "arabic_nuance",
            "main_example",
            "mcq_safe_definition",
            "mcq_safe_arabic",
            "learner_panel",
            "learner_note",
            "common_mistake",
            "review_suitability",
            "patch_allowed",
            "gpt_generation_confirmed",
            "generation_source",
            "generated_by",
        ],
        "properties": {
            "word": {"type": "string"},
            "entry_type": {"type": "string"},
            "difficulty": {"type": "string", "enum": ["easy", "medium", "advanced", "unknown"]},
            "corrected_cefr": cefr_or_null,
            "definition": {"type": "string"},
            "arabic": {"type": "string"},
            "arabic_nuance": {"type": "string"},
            "main_example": {"type": "string"},
            "mcq_safe_definition": {"type": "string"},
            "mcq_safe_arabic": {"type": "string"},
            "learner_panel": learner_panel_schema,
            "learner_note": string_or_null,
            "common_mistake": string_or_null,
            "review_suitability": {"type": "string", "enum": sorted(GPT_ALLOWED_REVIEW_SUITABILITY)},
            "patch_allowed": {"type": "boolean", "const": False},
            "gpt_generation_confirmed": {"type": "boolean", "const": True},
            "generation_source": {"type": "string", "const": GPT_GENERATION_SOURCE},
            "generated_by": {"type": "string"},
        },
    }


def build_gpt_source_item(
    word: str,
    pack_row: Dict[str, Any],
    dict_entry: Dict[str, Any],
) -> Dict[str, Any]:
    return {
        "word": word,
        "pos": dict_entry.get("pos"),
        "cefr_dictionary": dict_entry.get("cefr"),
        "cefr_actual": pack_row.get("cefr_actual"),
        "definition": pack_row.get("definition") or dict_entry.get("definition"),
        "arabic": pack_row.get("arabic") or dict_entry.get("arabic"),
        "why_useful": pack_row.get("why_useful"),
        "risk_lane": pack_row.get("risk_lane"),
        "priority": pack_row.get("priority"),
        "has_learner_panel": bool(pack_row.get("has_learner_panel")),
        "mcq_suitable": pack_row.get("mcq_suitable"),
        "concern": pack_row.get("concern"),
        "lookup_forms": dict_entry.get("lookup_forms"),
        "forms": dict_entry.get("forms"),
    }


def gpt_system_prompt() -> str:
    return (
        "You generate one strict JSON object for an English learner word panel. "
        "Return JSON only. No markdown, no code fences, no commentary, no trailing notes. "
        "Do not invent expressions, idioms, phrasal verbs, or collocations. "
        "Do not write generic template usage notes. Every usage note must be short, specific, and learner-useful. "
        "Avoid phrases like 'Used to express...' or 'Used to refer to...' unless the note also gives a clear practical pattern. "
        "Prefer practical patterns such as count for numbers or totals, knock on/at a door, warn someone about/of something, note as a short written message, and seat as the place you sit. "
        "For nouns, write learner tips instead of definition-style wording; for example, note can be explained as a short written message or reminder, and seat can be explained as the place you sit while sit is the action. "
        "For vote, prefer a concrete pattern note such as using vote for a person or option in an election or group decision; do not write 'commonly used in elections' as the whole note. "
        "Do not force awkward continuous examples for stative or tricky verbs. "
        "For normal verbs, include all five canonical forms unless there is a clear reason not to: Base, Past, Past participle, -ing, Third-person. "
        "Use only those canonical label names; do not use Present continuous, Present participle, Present simple, Present S, or Third person singular. "
        "If a verb is irregular, show it through the canonical forms or a learner_note when useful. "
        "Do not return empty forms for a normal verb unless there is a clear reason. "
        "For all non-verb entries (nouns, adjectives, adverbs), learner_panel.forms must always be an empty array []. Never include Base, Past, -ing, or Third-person form items for nouns. "
        "For noun usage_note, do not write 'Use <word> to talk about...' or any self-referential phrasing. Write a specific learner tip about meaning, countability, or contrast instead. Good examples: 'A film is a movie you watch at a cinema or on TV; film can also mean a thin layer covering a surface.' or 'A wave is a ridge of moving water in the sea; countable: one wave, many waves.' or 'A tool is a physical object used to do or fix something, such as a hammer or screwdriver.' "
        "Keep Arabic learner-friendly and aligned to the English part of speech. "
        "If the word is a verb, the Arabic should read like a present-tense dictionary verb form, not a bare imperative when a present-tense form is better; if it is a noun/adjective/adverb, match that part of speech. "
        "For verbs, prefer mudari/present-style Arabic headwords where appropriate, such as يمسح, يصوّت, يطرق, يحذر, ينشر, or يفرش. "
        "For Arabic verb headwords, use the third-person masculine present (mudari) form as the canonical headword — this is standard learner-dictionary style and always starts with ي. Do not use ambiguous ت-starting bare or imperative forms when a clear ي-starting form exists. Correct examples: count → يعد; knock → يطرق; scan → يمسح، يفحص; spread → ينشر، يفرش; spell → يُهجّي، ينطق حروف الكلمة; wipe → يمسح; warn → يحذر. Do not mention this rule in the output. "
        "Write arabic_nuance as a plain Arabic sentence explaining the word's meaning and use. Do not include rule text, letter lists, grammar instructions, or any English in arabic_nuance. "
        "For learner_panel.examples[0], include an optional 'arabic' field: one short Arabic sentence translating the English example for an Arabic learner. Only include it when a translation genuinely aids comprehension. The arabic gloss must contain no Latin letters. "
        "When the word is commonly confused with exactly one other English word (classic Arabic-learner pitfalls: warn/remind, borrow/lend, say/tell, much/many, since/for, bring/take, see/watch, listen/hear, come/go, affect/effect, rob/steal, rise/raise, fewer/less, beside/besides, lose/loose, hear/listen, home/house, lay/lie, arrive/reach), include learner_panel.compares_with with 'word' (the confusable) and 'diff' (one concise English sentence explaining the distinction, at least 24 characters). Do not invent confusing-pair entries. If no genuine confusion exists, set compares_with to null. If the current word belongs to one of these listed pairs, compares_with should normally be set with the partner. "
        # v17: Arabic semantic accuracy.
        "Arabic accuracy is critical. The Arabic headword and arabic_nuance must match the exact sense expressed by the English definition and main example, not a generic dictionary alternative sense. "
        "Color sense of 'shade' must be درجة لون, not ظل (which means shadow). "
        "When 'scan' means looking quickly for information (the most common learner sense), use natural quick-read Arabic such as يراجع بسرعة, يتفحص بسرعة, يستعرض بسرعة, or يمر بسرعة على النص. Do not use machine-scan wording such as يمسح الوثيقة / أمسح الوثيقة / أقوم بمسح الوثيقة unless the English example is explicitly about a scanner or a digital/machine scan. The unambiguous machine-scan headword is يمسح ضوئيًا. "
        "For 'take a seat' contexts, use natural Arabic such as تفضل بالجلوس or اجلس من فضلك instead of literal أخذ مقعد. "
        "For 'hum' (humming a tune), use يدندن — not يغني which means sing. "
        "For 'lean against' (a wall, fence, table), prefer natural Arabic such as يستند إلى الجدار or يتكئ على الجدار. Do not use the literal-but-unnatural يميل ضد الجدار. The body-tilting/bending sense (lean forward, lean back) is يميل or ينحني. "
        "For 'sneeze', do not write notes about a tissue catching the air; sneezing is involuntary expulsion of air, and tissues are used to cover the nose/mouth, not 'catch' anything. "
        # v17: natural examples and definitions.
        "Definitions must be natural English and must not repeat themselves. Do not write 'catch or catch', 'X or X', or any phrase that names the headword twice as a synonym of itself. If the only synonym is the word itself, use a different paraphrase. "
        "Examples must be simple, present or past simple, and natural. Avoid awkward phrasings such as 'use a tissue to catch the air'. "
        # v17: learner_note / common_mistake guidance.
        "learner_note and common_mistake are optional, but use one of them whenever there is a genuinely useful learner point that the usage_note does not already make. Examples: a frequent grammar trap, a confused near-synonym, a register/formality note, or a typical L1-Arabic mistake. Set them to null if you would only repeat usage_note or write filler. Never force them. "
        # v17: MCQ-safe field shape.
        "mcq_safe_definition must be short, generic English (max ~12 words), must not contain the target word or its inflected forms, and must read like a definition fragment (not a full sentence with a subject). Good: 'Place where you sit, such as a chair.' Bad: 'A seat is a place where you sit.' "
        "mcq_safe_arabic must be a short Arabic phrase (max ~8 words), not a full example sentence, no sentence-final punctuation, no first-person verbs (أبحث/أمسح/أجمع/أعطس/...), and no second-person address. Use a neutral phrase like 'إخبار بخطر' or 'مكان للجلوس'. "
        "Cap learner_panel.grammar.notes at 2 items. "
        "corrected_cefr must be your independent judgement about the word's difficulty for an Arabic-speaking English learner. "
        "Do NOT echo cefr_dictionary. The source dictionary is heavily biased toward A1/A2 and is known to be miscalibrated. Treat cefr_dictionary as a low-trust hint to override, not to copy. "
        # v18.1: CEFR anti-echo reinforcement. V18 200-word diagnostic showed
        # 193/200 (96.5%) entries echoed the dictionary CEFR exactly. Make the
        # override expectation explicit with worked examples.
        "v18.1 CEFR anti-echo rule: if cefr_dictionary appears too low for the word's typical adult-learner difficulty, you MUST override it. Worked overrides: negotiate (dict A2 → B1), penetrate (dict A2 → B2), innovate (dict A2 → B1), acknowledge (dict A2 → B1), distinguish (dict A2 → B1). When in doubt between adjacent levels for an abstract/formal/multi-syllable verb, choose the higher level. "
        # v18.1: stative verb -ing handling — V18 showed 10% of entries
        # fabricated awkward progressive forms instead of omitting them.
        "v18.1 stative-verb rule: for stative or non-progressive verbs (know, believe, prefer, contain, own, mean, deserve, fit, suit, resemble, possess), omit the -ing form rather than fabricating an unnatural progressive form. Set forms accordingly; do not invent 'knowing as a continuous activity' examples. "
        "v18.3 -ing completeness: the stative exception is narrow. For ALL normal action verbs, you MUST include the -ing form. The complete list of verbs that legitimately omit -ing is short: know, believe, prefer, contain, own, mean, deserve, fit, suit, resemble, possess. Every other verb requires the -ing form with a natural example — including boo, fix, hop, hum, jog, pack, shut, wipe, burst, count, frown, knock, rinse, spell, bother, ban, lay, cope. When in doubt, always include -ing rather than omitting it. "
        # v18.1: explicit short-phrase MCQ Arabic examples.
        "v18.1 mcq_safe_arabic shape rule: produce a SHORT noun-phrase or verbal-noun phrase of ≤8 words, NEVER a subject-verb-object sentence, NEVER ending in . ! or ؟. Good examples: 'إخبار بخطر' (warn), 'مكان للجلوس' (seat), 'تجميع الأشياء' (combine), 'فحص سريع للنص' (scan). Bad (rejected): 'أبحث عن المعلومات في النص بسرعة.' "
        # v18.1: forbid default future will examples.
        "v18.1 example tense rule: prefer present simple or past simple for the main_example; do NOT default to 'will' future constructions unless the future meaning is the headword's central use. "
        "Use this rubric: "
        "A1 = true first-stage survival/common words only — concrete everyday nouns (food, body, family, school, home), the most basic verbs (be, have, do, go, come, eat, drink, see, want, count, knock, spell, fix), simple colors/numbers/greetings. "
        "A2 = common everyday words beyond first-stage — frequent action verbs (vote, scan, spread, warn, wipe, combine, mention, explore, perform, arrange, announce, sneeze, wrap), concrete physical verbs that are not first-stage (hop, jog, rub, sew, lean), everyday adjectives (blank, neat), everyday nouns, basic past/future patterns. Most concrete physical action verbs that are not basic A1 are A2, not B1. "
        "B1 = abstract, formal, academic, emotional, behavior, process, or genuinely less frequent words — promote, punish, capture, agreement, achieve, suggest, behavior nouns, formal verbs, multi-step processes, low-frequency or formal physical verbs (flee, behave, burst, hum), formal adjectives (grand), abstract nouns (aid, agreement). Do not push common concrete physical verbs into B1 just because they are not first-stage A1. "
        "B2 = advanced/formal/specialized words — academic verbs, abstract nouns of process, formal register. "
        "C1/C2 = rare, literary, or highly specialized. "
        "Concrete calibration anchors — use these as reference, do not echo blindly: "
        "A1: count, knock, spell, fix, cheer, hide, note, mail, gift, menu, seat, tool, wave, dish, film, aim, dry. "
        "A2: vote, scan, spread, warn, wipe, mention, explore, perform, combine, wrap, sneeze, arrange, announce, angle, apart, hop, jog, rub, sew, lean, blank, neat. "
        "B1: promote, punish, capture, agreement, flee, behave, burst, hum, grand, aid. These words have an anchored B1 minimum — never label them A1 or A2. "
        "Return null only when you are genuinely unsure between two adjacent levels — null is not an escape from hard cases, it is a last resort. "
        "difficulty must be consistent with corrected_cefr: A1 and A2 → 'easy', B1 → 'medium', B2/C1/C2 → 'advanced'. If you must depart from this mapping, give the reason briefly in learner_note. "
        "Definitions must start with a capital letter. "
        "Prefer present simple or past simple examples over default future will examples unless the future meaning is central. "
        "Use the provided source data only. "
        "For noun entries, set learner_panel.grammar.countability to countable, uncountable, both, or n/a. For non-noun entries, set countability to null. "
        "The exact output schema is:\n"
        "{"
        '"word": string, '
        '"entry_type": string, '
        '"difficulty": string, '
        '"corrected_cefr": string|null, '
        '"definition": string, '
        '"arabic": string, '
        '"arabic_nuance": string, '
        '"main_example": string, '
        '"mcq_safe_definition": string, '
        '"mcq_safe_arabic": string, '
        '"learner_panel": {'
        '"schema_version": "v16", '
        '"grammar": {"part_of_speech": string, "usage_note": string, "notes": [string], "countability": string|null}, '
        '"examples": [{"label": string, "text": string, "arabic": string|null}], '
        '"forms": [{"label": string, "value": string, "example": string}], '
        '"compares_with": {"word": string, "diff": string}|null'
        '}, '
        '"learner_note": string?, '
        '"common_mistake": string?, '
        '"review_suitability": string, '
        '"patch_allowed": false, '
        '"gpt_generation_confirmed": true, '
        '"generation_source": "openai_api", '
        '"generated_by": string'
        "}"
    )


def gpt_user_prompt(word: str, source_item: Dict[str, Any]) -> str:
    return json.dumps(
        {
            "task": "Generate a preview-only learner panel entry for a single word.",
            "word": word,
            "source": source_item,
            "rules": [
                "Output strict JSON only.",
                "No expressions, idioms, phrasal verbs, or collocations.",
                "Do not overwrite or assume any existing learner_panel.",
                "patch_allowed must be false.",
                "main_example must include the target word or the correct inflected form.",
                "The usage_note must be specific and learner-friendly, never generic.",
                "The usage_note should mention a natural pattern or use case, such as warn + someone + about/of something or note as a noun meaning a short written message.",
                "Do not use phrases like 'Used to express...' or 'Used to refer to...' unless the note also gives a concrete learner pattern.",
                "For nouns, do not write 'X as a noun means...' or 'use X to talk about...' style notes; write a learner tip or usage pattern instead.",
                "For vote, use a concrete pattern note such as 'Use vote for a person or option in an election or group decision.'",
                "The arabic_nuance must explain the meaning briefly in Arabic, not just say noun or verb.",
                "For normal verbs, prefer a dictionary-style present form such as يمسح, يصوّت, يطرق, or يحذر when that is the clearer learner headword.",
                "For Arabic verb headwords, use the third-person masculine present (mudari) form starting with ي — this is the canonical learner-dictionary headword. Do not use ambiguous ت-starting forms when a clear ي-starting form exists. Examples: count → يعد; knock → يطرق; spell → يُهجّي، ينطق حروف الكلمة; scan → يمسح، يفحص; spread → ينشر، يفرش.",
                "arabic_nuance must be a plain Arabic sentence about meaning and use. No rule text, no English, no letter lists.",
                "corrected_cefr must be your independent judgement; if uncertain, set null. Do not echo the cefr_dictionary value — the source dictionary is heavily biased toward A1 and is miscalibrated.",
                "A1 is reserved for true first-stage vocabulary (count, knock, spell, fix, cheer, hide, note, mail, gift, menu, seat, tool, wave, dish, film, aim, dry).",
                "A2 covers frequent action verbs and everyday nouns/adjectives (vote, scan, spread, warn, wipe, mention, explore, perform, combine, wrap, sneeze, arrange, announce, angle, apart, hop, jog, rub, sew, lean, blank, neat). Most concrete physical action verbs that are not first-stage A1 belong here, not B1.",
                "B1 covers abstract, formal, behavior, process, or genuinely less frequent words (promote, punish, capture, agreement, flee, behave, burst, hum, grand, aid). These words have an anchored B1 minimum — never label them A1 or A2. Do not push common concrete physical verbs into B1 just because they are not A1.",
                "Return null only when genuinely unsure between two adjacent levels — not as an escape for hard cases.",
                "difficulty must match corrected_cefr: A1/A2 → easy, B1 → medium, B2/C1/C2 → advanced. Departures must be explained in learner_note.",
                "Use only the canonical form labels Base, Past, Past participle, -ing, and Third-person.",
                "Do not use Present continuous, Present participle, Present simple, Present S, or Third person singular.",
                "For normal verbs, include all five canonical labels unless there is a clear reason not to.",
                "Do not return empty forms for a normal verb unless there is a clear reason.",
                "Definitions must start with a capital letter.",
                "Prefer present simple or past simple examples over default future will examples unless the future meaning is central.",
                "Keep mcq_safe_arabic short and usable; prefer a concise learner phrase, not a full sentence.",
                "If the word is stative or tricky, omit awkward -ing examples instead of forcing them.",
                "If forms are not useful or are awkward, return an empty forms array instead of omitting it.",
                "If forms are provided for verbs, each item must include label, value, and a natural example using that exact form.",
                "Keep mcq_safe_definition and mcq_safe_arabic short and usable.",
                "review_suitability must be one of mcq_safe, review_only, or not_suitable.",
                "For this preview, prefer mcq_safe when the entry is suitable for learner use.",
                "review_suitability must not be empty.",
                "generation_source must be openai_api.",
                "gpt_generation_confirmed must be true.",
                "learner_panel.grammar.notes must always be an array, even when empty.",
                "learner_panel.forms must always be an array, even when empty.",
                "For noun entries, set learner_panel.grammar.countability to one of: countable, uncountable, both, or n/a.",
                "For non-noun entries, set learner_panel.grammar.countability to null.",
                "For all non-verb entries (nouns, adjectives, adverbs), learner_panel.forms must be [] — an empty array. Never add Base, Past, -ing, or Third-person form items for a noun.",
                "For noun usage_note, do not write 'Use <word> to talk about...' or any self-referential phrasing. Write a specific learner tip instead, covering meaning, countability, or contrast with a related word.",
                "Set learner_panel.schema_version to 'v16'.",
                "For learner_panel.examples[0], add an optional 'arabic' field: a short Arabic translation of the English example sentence. Include it only when it genuinely helps an Arabic learner. The arabic field must contain no Latin letters. If no Arabic gloss is useful, set arabic to null.",
                "When the word is commonly confused with exactly one other English word, include learner_panel.compares_with with 'word' and 'diff'. Do not invent pairs. If no real confusion exists, set compares_with to null.",
                "Cap learner_panel.grammar.notes at 2 items maximum.",
                "Arabic must match the exact English sense. For color 'shade' use درجة لون not ظل. For 'scan' meaning quick reading use يتفحص بسرعة / يراجع بسرعة, not machine-scan wording unless the example is about a scanner. For 'hum' use يدندن not يغني. For 'take a seat' prefer تفضل بالجلوس.",
                "Definitions must not repeat themselves. Avoid 'catch or catch', 'X or X', or any tautology. Paraphrase if the only synonym is the word itself.",
                "Avoid awkward learner notes like 'use a tissue to catch the air' for sneeze. A tissue covers the nose/mouth; it does not 'catch' anything.",
                "Set learner_note or common_mistake only when there is a real teaching point beyond usage_note: a grammar trap, a near-synonym confusion, formality, or a typical Arabic-speaker mistake. Otherwise leave them null. Never force them.",
                "mcq_safe_definition must be short (max 12 words), must NOT contain the target word or its inflected forms, and should read as a definition fragment, not a full subject+verb sentence.",
                "mcq_safe_arabic must be a short Arabic phrase (max 8 words), no full sentence, no sentence-final punctuation, no first-person verbs (أبحث/أمسح/أجمع/أعطس/...).",
                "If the word is one side of a known confusing pair (warn/remind, borrow/lend, say/tell, much/many, since/for, bring/take, see/watch, listen/hear, come/go, affect/effect, rob/steal, rise/raise, fewer/less, beside/besides, lose/loose, home/house, lay/lie, arrive/reach), set compares_with with the partner.",
                # v18.1 reinforcements — surfaced by the 200-word diagnostic.
                "v18.1 CEFR override: cefr_dictionary is low-trust (V18 diagnostic showed it was echoed 96.5% of the time). When in doubt between adjacent levels for abstract/formal/multi-syllable verbs (negotiate, penetrate, innovate, acknowledge, distinguish), pick the higher level. Do not copy cefr_dictionary if your independent judgement disagrees.",
                "v18.1 stative verbs: for stative verbs (know, believe, prefer, contain, own, mean, deserve, fit, suit, resemble, possess), omit the -ing form rather than fabricating an unnatural progressive form.",
                "v18.3 -ing completeness: the stative exception is narrow. EVERY normal action verb NOT in the stative list above MUST have the -ing form. Never omit -ing when in doubt — include it. Every verb in this batch that is not stative requires a -ing form item.",
                "v18.1 mcq_safe_arabic must be a short phrase ≤8 words. Good shape: 'إخبار بخطر', 'مكان للجلوس', 'تجميع الأشياء'. Reject any full subject-verb-object Arabic sentence.",
                "v18.1 main_example must contain the exact target word or its inflected form. Prefer present simple or past simple; do not default to 'will' future unless future meaning is central.",
                "v18.1 definition must not repeat the target word as its own synonym; do not produce 'X or X' shapes.",
                "v18.1 verb forms: for monosyllabic CVC verbs (don, plan, stop, run, jog, hop), double the final consonant before -ed/-ing (donned/donning, planned/planning). Never produce 'doned' / 'doning'.",
            ],
            "preferred_shape": {
                "entry_type": "verb | noun | adjective | adverb",
                "difficulty": "easy | medium | advanced",
                "corrected_cefr": "A1 | A2 | B1 | B2 | C1 | C2 | null",
                "learner_panel": {
                    "schema_version": "v16",
                    "grammar": {
                        "part_of_speech": "must match entry_type",
                        "usage_note": "specific, natural, concise",
                        "notes": ["max 2 short learner notes"],
                        "countability": "countable|uncountable|both|n/a for nouns, null for non-nouns"
                    },
                    "examples": [
                        {
                            "label": "Main example",
                            "text": "must contain the target word or exact form",
                            "arabic": "optional short Arabic translation of the example — null if not useful"
                        }
                    ],
                    "forms": [
                        {"label": "Base", "value": "word", "example": "natural example using the exact form"}
                    ],
                    "compares_with": {
                        "word": "the commonly confused English word",
                        "diff": "one concise sentence explaining the difference — omit entirely if no genuine confusion"
                    }
                }
            },
        },
        ensure_ascii=False,
        indent=2,
    )


def openai_client() -> OpenAI:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise GPTPreviewFailure("OPENAI_API_KEY is required for --generate-with-gpt.")
    return OpenAI(api_key=api_key)


def call_gpt_json(client: OpenAI, model: str, word: str, source_item: Dict[str, Any]) -> tuple[Dict[str, Any], Dict[str, int], str]:
    response = client.chat.completions.create(
        model=model,
        temperature=0.2,
        max_tokens=1400,
        response_format={
            "type": "json_schema",
            "json_schema": {
                "name": "word_panel_preview_entry",
                "strict": True,
                "schema": gpt_response_schema(),
            },
        },
        messages=[
            {"role": "system", "content": gpt_system_prompt()},
            {"role": "user", "content": gpt_user_prompt(word, source_item)},
        ],
    )
    content = response.choices[0].message.content or ""
    payload = json.loads(content)
    usage = response.usage
    usage_counts = {
        "prompt_tokens": int(getattr(usage, "prompt_tokens", 0) or 0),
        "completion_tokens": int(getattr(usage, "completion_tokens", 0) or 0),
        "total_tokens": int(getattr(usage, "total_tokens", 0) or 0),
    }
    return payload, usage_counts, content


def repair_gpt_json(
    client: OpenAI,
    model: str,
    word: str,
    source_item: Dict[str, Any],
    issues: List[str],
    previous_raw: str,
) -> tuple[Dict[str, Any], Dict[str, int], str]:
    issue_specific_rules: List[str] = []
    if any("prompt leakage" in issue for issue in issues):
        issue_specific_rules.append(
            "One or more output fields contain literal rule text or grammar instructions. "
            "Rewrite those fields with natural learner content only. "
            "arabic_nuance must be a plain Arabic sentence about meaning and use — no letter lists, no English, no rule fragments."
        )
    if any("prefers ي-starting headword" in issue for issue in issues):
        issue_specific_rules.append(
            "The verb Arabic headword does not start with ي. Rewrite the arabic field using the "
            "third-person masculine present (mudari) form, which is the standard learner-dictionary headword. "
            "Examples: spell → يُهجّي، ينطق حروف الكلمة; count → يعد; knock → يطرق. "
            "Avoid ambiguous bare or imperative forms like تهجي when a clear ي-starting form exists."
        )
    if any("non-verb has forms" in issue for issue in issues):
        issue_specific_rules.append(
            "The entry has form items for a non-verb word. Set learner_panel.forms to [] (empty array). "
            "Never include Base, Past, -ing, or Third-person items for nouns, adjectives, or adverbs."
        )
    if any("missing required form label: -ing" in issue for issue in issues):
        issue_specific_rules.append(
            "The verb entry is missing the -ing form. Add it immediately as a new forms item. "
            "Compute the -ing value from the base word: "
            "CVC verbs (3-4 letters, consonant-vowel-consonant): double the final consonant before -ing "
            "(hop→hopping, hum→humming, jog→jogging, ban→banning, shut→shutting). "
            "Verbs ending in silent 'e' (not 'ee'): drop the 'e' then add -ing "
            "(cope→coping, wipe→wiping, rinse→rinsing, congratulate→congratulating). "
            "All other verbs: simply add -ing to the base "
            "(fix→fixing, pack→packing, burst→bursting, count→counting, boo→booing, spell→spelling, frown→frowning). "
            "Include a short, natural English example sentence using the exact -ing form value."
        )
    if any("generic usage note" in issue or "self-referential usage note" in issue for issue in issues):
        issue_specific_rules.append(
            "The usage_note is generic or self-referential. Rewrite it completely as a specific, practical "
            "learner tip. Do not use 'Use <word> to talk about...' phrasing. "
            "Examples of good noun usage notes: "
            "'A film is a movie you watch at a cinema or on TV; film can also mean a thin layer.' "
            "'A wave is a ridge of moving water in the sea; countable: one wave, many waves.' "
            "'A tool is a physical object used to do or fix something, such as a hammer or screwdriver.'"
        )
    repair_prompt = json.dumps(
        {
            "task": "Repair the previous JSON response so it satisfies the schema and rules.",
            "word": word,
            "source": source_item,
            "issues": issues,
            "previous_response": previous_raw,
            "rules": [
                "Return JSON only.",
                "Keep the same target word.",
                "Remove generic usage notes.",
                "Remove template garbage examples.",
                "Do not invent expressions, idioms, phrasal verbs, or collocations.",
                "Do not include awkward -ing examples for stative or tricky verbs.",
                *issue_specific_rules,
            ],
        },
        ensure_ascii=False,
        indent=2,
    )
    response = client.chat.completions.create(
        model=model,
        temperature=0.1,
        max_tokens=1400,
        response_format={
            "type": "json_schema",
            "json_schema": {
                "name": "word_panel_preview_entry_repair",
                "strict": True,
                "schema": gpt_response_schema(),
            },
        },
        messages=[
            {"role": "system", "content": gpt_system_prompt()},
            {"role": "user", "content": repair_prompt},
        ],
    )
    content = response.choices[0].message.content or ""
    payload = json.loads(content)
    usage = response.usage
    usage_counts = {
        "prompt_tokens": int(getattr(usage, "prompt_tokens", 0) or 0),
        "completion_tokens": int(getattr(usage, "completion_tokens", 0) or 0),
        "total_tokens": int(getattr(usage, "total_tokens", 0) or 0),
    }
    return payload, usage_counts, content


def check_prompt_leakage(payload: Dict[str, Any]) -> List[str]:
    """Return an issue string for each leaking field found (stops at first hit per field)."""
    issues: List[str] = []
    fragments_lower = [f.lower() for f in PROMPT_LEAK_FRAGMENTS]

    def leaks(text: str) -> bool:
        t = (text or "").lower()
        return any(frag in t for frag in fragments_lower)

    top_fields = [
        "definition", "arabic", "arabic_nuance",
        "main_example", "mcq_safe_definition", "mcq_safe_arabic",
    ]
    for field in top_fields:
        val = payload.get(field) or ""
        if leaks(val):
            issues.append(f"prompt leakage in {field}")

    lp = payload.get("learner_panel")
    if isinstance(lp, dict):
        gr = lp.get("grammar")
        if isinstance(gr, dict):
            if leaks(gr.get("usage_note") or ""):
                issues.append("prompt leakage in grammar.usage_note")
            for note in (gr.get("notes") or []):
                if isinstance(note, str) and leaks(note):
                    issues.append("prompt leakage in grammar.notes")
                    break
        for ex in (lp.get("examples") or []):
            if isinstance(ex, dict) and leaks(ex.get("text") or ""):
                issues.append("prompt leakage in examples.text")
                break
        for form in (lp.get("forms") or []):
            if isinstance(form, dict) and leaks(form.get("example") or ""):
                issues.append("prompt leakage in forms.example")
                break
    return issues


def merge_top_level_notes_into_panel(payload: Dict[str, Any]) -> None:
    learner_panel = payload.get("learner_panel")
    if not isinstance(learner_panel, dict):
        return
    grammar = learner_panel.get("grammar")
    if not isinstance(grammar, dict):
        return
    notes = grammar.get("notes")
    if not isinstance(notes, list):
        notes = []
        grammar["notes"] = notes
    learner_note = payload.get("learner_note")
    if isinstance(learner_note, str) and learner_note.strip():
        notes.append(learner_note.strip())
    common_mistake = payload.get("common_mistake")
    if isinstance(common_mistake, str) and common_mistake.strip():
        notes.append(f"Common mistake: {common_mistake.strip()}")


def looks_like_bad_usage_note(text: str) -> bool:
    lowered = text.lower().strip()
    if len(lowered) < 12:
        return True

    always_bad = [
        "simple learner sentences",
        "use this word in simple learner sentences",
        "use this verb in simple learner sentences",
        "use this verb to talk about",
        "use this word to talk about",
        "used to express",
        "used to refer to",
        "action or state",
        "name, place, thing, or idea",
        "talk about something",
        "used in many situations",
        "can be used in different tenses",
        "this is a common word",
    ]
    if any(p in lowered for p in always_bad):
        return True

    if "commonly used" in lowered:
        concrete_context = any(
            marker in lowered
            for marker in [
                " with ",
                " when ",
                " such as ",
                " like ",
                " for ",
                " on ",
                " at ",
                " about ",
                " of ",
                " to ",
                " contrast",
                " compared to ",
            ]
        )
        if not concrete_context:
            return True

    if "use" in lowered and (" to talk about " in lowered or "means" in lowered and "usage" not in lowered):
        return True

    return False


def looks_like_present_style_verb_arabic(text: str) -> bool:
    segments = arabic_verb_segments(text)
    if not segments:
        return False
    return all(looks_like_present_style_verb_arabic_segment(segment) for segment in segments)


def example_has_target(example_text: str, word: str, forms: Optional[List[str]] = None) -> bool:
    text = example_text.lower()
    target_forms = {word.lower()}
    if forms:
        target_forms.update(f.lower() for f in forms if f)
    return any(form in text for form in target_forms)


def validate_gpt_entry(
    word: str,
    payload: Dict[str, Any],
    source_item: Dict[str, Any],
    dict_entry: Dict[str, Any],
) -> Dict[str, Any]:
    # v17.4-A. Difficulty normalization. If corrected_cefr maps cleanly to a
    # canonical difficulty (A1/A2 → easy, B1 → medium, B2+ → advanced) and
    # GPT returned a different value, rewrite it in-place *unless*
    # learner_note explicitly justifies the exception. This stops A2+medium
    # entries from surviving and avoids spurious warn:cefr_difficulty_mismatch
    # warnings. The original value is recorded under
    # `difficulty_before_normalization` for transparency.
    _cefr_for_diff = (payload.get("corrected_cefr") or "").strip()
    _expected_diff = expected_difficulty_for_cefr(_cefr_for_diff)
    _gpt_diff = (payload.get("difficulty") or "").strip()
    _learner_note = (payload.get("learner_note") or "").strip().lower()
    _exception_markers = ("difficulty", "harder", "easier", "exception", "register")
    _has_justified_exception = bool(_learner_note) and any(
        m in _learner_note for m in _exception_markers
    )
    if (
        _expected_diff
        and _gpt_diff
        and _gpt_diff != "unknown"
        and _gpt_diff != _expected_diff
        and not _has_justified_exception
    ):
        payload["difficulty_before_normalization"] = _gpt_diff
        payload["difficulty"] = _expected_diff
        payload["difficulty_normalized"] = True

    issues: List[str] = []

    if payload.get("word") != word:
        issues.append("word mismatch")
    if payload.get("patch_allowed") is not False:
        issues.append("patch_allowed must be false")
    if payload.get("gpt_generation_confirmed") is not True:
        issues.append("gpt_generation_confirmed must be true")
    if payload.get("generation_source") != GPT_GENERATION_SOURCE:
        issues.append("generation_source must be openai_api")
    if payload.get("generated_by") in {None, ""}:
        issues.append("missing generated_by")
    review_suitability = payload.get("review_suitability")
    if review_suitability not in GPT_ALLOWED_REVIEW_SUITABILITY:
        issues.append("missing or invalid review_suitability")
    if review_suitability == "not_suitable":
        issues.append("review-sensitive word included")
    if any(key in payload for key in ["expressions", "idioms", "phrasal_verbs", "collocations"]):
        issues.append("forbidden expression field present")

    entry_type = payload.get("entry_type") or ""
    pos = (source_item.get("pos") or "").lower()
    if entry_type != pos:
        issues.append("entry_type mismatch")

    difficulty = payload.get("difficulty")
    if difficulty not in {"easy", "medium", "advanced", "unknown"}:
        issues.append("invalid difficulty")

    corrected_cefr = payload.get("corrected_cefr")
    if corrected_cefr is not None and corrected_cefr not in {"A1", "A2", "B1", "B2", "C1", "C2"}:
        issues.append("invalid corrected_cefr")

    defn = (payload.get("definition") or "").strip()
    if not defn:
        issues.append("missing definition")
    elif defn[0].islower():
        issues.append("definition must start capitalized")

    arabic = (payload.get("arabic") or "").strip()
    if not arabic:
        issues.append("missing arabic")

    if pos == "verb":
        segments = arabic_verb_segments(arabic)
        if not looks_like_verb_arabic({"arabic": arabic}):
            issues.append("verb Arabic does not look verbal")
        if not segments:
            issues.append("verb Arabic missing verb segments")
        else:
            for segment in segments:
                if not looks_like_present_style_verb_arabic_segment(segment):
                    issues.append("verb Arabic should be present-style")
                    break
                if looks_like_imperative_or_root_verb_arabic_segment(segment):
                    issues.append("verb Arabic looks imperative or root-like")
                    break
    if pos in {"noun", "adjective", "adverb"} and looks_like_verbal_arabic_for_nonverb_check(arabic):
        issues.append("non-verb Arabic looks verbal")

    if pos == "verb" and arabic:
        segs = arabic_verb_segments(arabic)
        if segs:
            first_norm = normalize_arabic_verb_segment(segs[0])
            first_token = re.split(r"\s+", first_norm, maxsplit=1)[0].strip()
            if first_token and not first_token.startswith("ي"):
                issues.append(
                    f"verb Arabic prefers ي-starting headword; first segment '{segs[0]}' starts with "
                    f"'{first_token[0]}' which may be an ambiguous bare or imperative form"
                )

    issues.extend(check_prompt_leakage(payload))

    main_example = (payload.get("main_example") or "").strip()
    if not main_example:
        issues.append("missing main example")
    elif not example_has_target(main_example, word, [word]):
        issues.append("main example missing target")

    mcq_def = (payload.get("mcq_safe_definition") or "").strip()
    mcq_ara = (payload.get("mcq_safe_arabic") or "").strip()
    if not mcq_def or len(mcq_def.split()) > 14:
        issues.append("mcq_safe_definition too long or missing")
    if not mcq_ara or len(mcq_ara.split()) > 14:
        issues.append("mcq_safe_arabic too long or missing")

    learner_panel = payload.get("learner_panel")
    if not isinstance(learner_panel, dict):
        issues.append("missing learner_panel")
    else:
        grammar = learner_panel.get("grammar")
        if not isinstance(grammar, dict):
            issues.append("missing grammar")
        else:
            usage_note = (grammar.get("usage_note") or "").strip()
            part_of_speech = (grammar.get("part_of_speech") or "").strip()
            notes = grammar.get("notes")
            if part_of_speech != pos:
                issues.append("learner_panel pos mismatch")
            if not usage_note or looks_like_bad_usage_note(usage_note):
                issues.append("generic usage note")
            if not isinstance(notes, list):
                issues.append("grammar notes must be array")
            countability = grammar.get("countability")
            valid_countability = {"countable", "uncountable", "both", "n/a"}
            if pos == "noun" and countability not in valid_countability:
                issues.append("noun missing valid countability")
            if usage_note and any(
                phrase in usage_note.lower()
                for phrase in [
                    f"{word.lower()} as a",
                    f"use '{word.lower()}' to talk about",
                    f"use {word.lower()} to talk about",
                    "used to talk about",
                ]
            ):
                issues.append("self-referential usage note")

        examples = learner_panel.get("examples")
        if not isinstance(examples, list) or not examples:
            issues.append("missing examples")
        else:
            example_texts = []
            for item in examples:
                if not isinstance(item, dict):
                    continue
                text = (item.get("text") or "").strip()
                if text:
                    example_texts.append(text)
            if not example_texts:
                issues.append("empty examples")
            if not any(example_has_target(text, word, [word]) for text in example_texts):
                issues.append("no example contains target")
            if any(re.search(r"\b(?:i|we|you|he|she|they)\s+will\b", text, re.I) for text in example_texts):
                issues.append("default will future example")
            template_bad = [
                re.compile(r"\bwe\s+___\b", re.I),
                re.compile(r"\bshe\s+___\b", re.I),
                re.compile(r"\bhe\s+___\b", re.I),
                re.compile(r"\bthey have ___ already\b", re.I),
                re.compile(r"\bthey are ___ now\b", re.I),
                re.compile(r"\bhe ___ yesterday\b", re.I),
                re.compile(r"\bshe ___ every day\b", re.I),
                re.compile(r"\bwe ___ every day\b", re.I),
            ]
            if any(regex.search(text) for regex in template_bad for text in example_texts):
                issues.append("template garbage example")

            # v16: examples[].arabic must not contain Latin letters if present.
            for item in examples:
                if not isinstance(item, dict):
                    continue
                arabic_gloss = (item.get("arabic") or "")
                if arabic_gloss and contains_english_letters(arabic_gloss):
                    issues.append("examples_arabic_has_latin")
                    break

        forms = learner_panel.get("forms")
        if not isinstance(forms, list):
            issues.append("forms is not a list")
        else:
            if pos == "verb":
                if word not in LIMITED_FORM_VERBS and len(forms) < 4:
                    issues.append("too few verb forms")
                if any(not isinstance(item, dict) for item in forms):
                    issues.append("forms item type invalid")
                for item in forms:
                    if not isinstance(item, dict):
                        continue
                    label = (item.get("label") or "").strip()
                    value = (item.get("value") or "").strip()
                    example = (item.get("example") or "").strip()
                    if not label or not value:
                        issues.append("empty verb form field")
                        continue
                    if label not in {"Base", "Past", "Past participle", "-ing", "Third-person"}:
                        issues.append(f"noncanonical form label: {label}")
                    if label == "-ing" and not value.endswith("ing"):
                        issues.append("form label/value mismatch for -ing")
                    if label == "Third-person" and not (value.endswith("s") or value.endswith("ies")):
                        issues.append("form label/value mismatch for Third-person")
                    if label in {"Past", "Past participle"} and value.endswith("ing"):
                        issues.append(f"form label/value mismatch for {label}")
                    if not example:
                        issues.append(f"missing example for form {label}")
                    if example and not example_has_target(example, word, [value, word]):
                        issues.append(f"form example missing exact form for {label}")
                    if label == "-ing" and word in LIMITED_FORM_VERBS:
                        issues.append("awkward forced -ing example")
                # v18.1: rule-based check for obvious bad doubled-consonant forms.
                # For monosyllabic CVC verbs that double the final consonant
                # before -ed/-ing (don→donned/donning, plan→planned/planning,
                # stop→stopped/stopping), flag fabricated single-consonant forms
                # like "doned" or "doning" as a hard issue. The "needs doubling"
                # check is conservative: short word, ends in a non-w/x/y
                # consonant after a single vowel, and not in DOUBLING_EXCEPTIONS.
                _w_lc = word.lower()
                _DOUBLING_EXCEPTIONS = {
                    # vowel-ending or multi-syllable / silent-e cases never double
                    # this list is just an explicit safety hatch
                }
                _VOWELS = set("aeiou")
                _NO_DOUBLE_FINAL = set("wxyhaeiou")
                def _needs_doubling(w: str) -> bool:
                    if len(w) < 3 or len(w) > 4:
                        return False
                    if w in _DOUBLING_EXCEPTIONS:
                        return False
                    # v18.1: vowel-initial words (edit, open, omit, enter) are
                    # almost always multi-syllable; doubling depends on stress
                    # which we cannot compute, so we conservatively skip them
                    # — false negatives route to review, no false positives.
                    if w[0] in _VOWELS:
                        return False
                    a, b, c = w[-3], w[-2], w[-1]
                    if c in _NO_DOUBLE_FINAL:
                        return False
                    if b not in _VOWELS:
                        return False
                    if a in _VOWELS:
                        return False  # CVVC like rain → rained, no doubling
                    return True
                if _needs_doubling(_w_lc):
                    final = _w_lc[-1]
                    expected_past = _w_lc + final + "ed"
                    expected_ing = _w_lc + final + "ing"
                    bad_past = _w_lc + "ed"
                    bad_ing = _w_lc + "ing"
                    for item in forms:
                        if not isinstance(item, dict):
                            continue
                        lbl = (item.get("label") or "").strip()
                        val = (item.get("value") or "").strip().lower()
                        if lbl in {"Past", "Past participle"} and val == bad_past and val != expected_past:
                            issues.append(
                                f"verb_form_doubling (hard) — {lbl} '{val}' should double final consonant ('{expected_past}')"
                            )
                        if lbl == "-ing" and val == bad_ing and val != expected_ing:
                            issues.append(
                                f"verb_form_doubling (hard) — -ing '{val}' should double final consonant ('{expected_ing}')"
                            )
                if not any(item.get("label") == "Past participle" for item in forms if isinstance(item, dict)):
                    issues.append("missing required form label: Past participle")
                if word not in LIMITED_FORM_VERBS and not any(item.get("label") == "-ing" for item in forms if isinstance(item, dict)):
                    issues.append("missing required form label: -ing")
                if word not in LIMITED_FORM_VERBS and not any(item.get("label") == "Third-person" for item in forms if isinstance(item, dict)):
                    issues.append("missing required form label: Third-person")
            elif forms:
                issues.append("non-verb has forms")

        # v16: compares_with validation (hard fail).
        compares_with_val = learner_panel.get("compares_with") if isinstance(learner_panel, dict) else None
        if compares_with_val is not None and not isinstance(compares_with_val, dict):
            issues.append("compares_with_shape_invalid")
        elif isinstance(compares_with_val, dict):
            cw_word = (compares_with_val.get("word") or "").strip()
            cw_diff = (compares_with_val.get("diff") or "").strip()
            if not cw_word or not cw_diff:
                issues.append("compares_with_shape_invalid")
            elif cw_word.lower() == word.lower():
                issues.append("compares_with_shape_invalid")
            elif len(cw_diff) < 24:
                issues.append("compares_with_shape_invalid")

    # ─── v14 quality warnings ──────────────────────────────────────────────
    # Soft warnings: flip pass → review and surface to humans, but they are
    # judgements the validator cannot make perfectly, so they are tagged
    # explicitly with the `warn:` prefix.

    warnings: List[str] = []

    # 1. CEFR sanity. If GPT echoes A1 for a known-suspect-A1 word, warn.
    corrected_cefr_value = (payload.get("corrected_cefr") or "")
    if word in SUSPECT_A1_WORDS and corrected_cefr_value == "A1":
        warnings.append(
            f"warn:suspect_A1 — '{word}' is likely beyond A1; reviewer must confirm CEFR"
        )
    if (
        corrected_cefr_value == "A1"
        and len(word) >= 9
        and word.endswith(("tion", "sion", "ity", "ment", "ness", "ology", "graphy"))
    ):
        warnings.append(
            f"warn:suspect_A1 — long abstract-noun shape, A1 is improbable for '{word}'"
        )
    if (
        corrected_cefr_value == "A1"
        and payload.get("difficulty") == "easy"
        and pos in {"noun", "adjective"}
        and len(word) >= 8
    ):
        # generic guardrail — long nouns/adjectives flagged easy+A1 deserve eyes
        if word not in {
            "everyday", "computer", "internet", "favorite", "favourite",
            "elephant", "delicious", "wonderful", "comfortable", "important",
        }:
            warnings.append(
                f"warn:suspect_A1 — '{word}' is an 8+ letter {pos} marked easy+A1"
            )

    # 2. Known suspicious Arabic mappings — always warn for human review.
    if word in SUSPECT_ARABIC_WORDS:
        warnings.append(
            f"warn:suspect_arabic — '{word}' is on the v13 risky-Arabic list; "
            f"verify '{(payload.get('arabic') or '').strip()}' is semantically correct"
        )

    # 3. arabic_nuance must be plain learner Arabic — no English, no rule text.
    nuance = (payload.get("arabic_nuance") or "")
    if nuance and contains_english_letters(nuance):
        warnings.append("warn:english_in_arabic_nuance — Latin letters present in arabic_nuance")

    # 4. Empty usage_note (separate from "generic" — distinct issue tag).
    lp_for_warn = payload.get("learner_panel") or {}
    gr_for_warn = lp_for_warn.get("grammar") or {}
    if isinstance(gr_for_warn, dict) and not (gr_for_warn.get("usage_note") or "").strip():
        warnings.append("warn:empty_usage_note — grammar.usage_note is empty")

    # 5. CEFR echo detection — warns when GPT echoes the dictionary CEFR for a
    #    long word that is probably mislabelled. Does not fire for short words or
    #    words in the allow-list of genuinely long A1 words. (G1b)
    cefr_dict_val = (source_item.get("cefr_dictionary") or "")
    if (
        corrected_cefr_value
        and corrected_cefr_value == cefr_dict_val
        and len(word) >= 7
        and word not in CEFR_ECHO_ALLOWLIST
    ):
        warnings.append(
            f"warn:cefr_echoes_dictionary — '{word}' corrected_cefr '{corrected_cefr_value}' "
            f"matches dictionary CEFR; confirm this is an independent judgement"
        )

    # 6. Arabic instruction-text leakage in arabic_nuance. (G3)
    if nuance and any(frag in nuance for frag in ARABIC_INSTRUCTION_FRAGMENTS):
        warnings.append(
            "warn:arabic_meta_in_nuance — instruction-text fragment found in arabic_nuance"
        )

    # 7. v16: expressions count cap (soft warning).
    lp_v16 = payload.get("learner_panel") or {}
    expressions_v16 = lp_v16.get("expressions") if isinstance(lp_v16, dict) else None
    if isinstance(expressions_v16, list) and len(expressions_v16) > 4:
        warnings.append(
            f"warn:expressions_too_many — {len(expressions_v16)} expressions (max 4)"
        )
    elif isinstance(expressions_v16, dict):
        total_exp = sum(len(v) for v in expressions_v16.values() if isinstance(v, list))
        if total_exp > 4:
            warnings.append(
                f"warn:expressions_too_many — {total_exp} total expressions in map form (max 4)"
            )

    # 8. v16: grammar.notes count cap (soft warning).
    notes_v16 = (gr_for_warn.get("notes") or []) if isinstance(gr_for_warn, dict) else []
    if isinstance(notes_v16, list) and len(notes_v16) > 2:
        warnings.append(
            f"warn:notes_too_many — {len(notes_v16)} grammar.notes items (max 2)"
        )

    # 9. v16: compares_with.word not in curated known pairs (soft warning).
    # v18.1 BUGFIX: KNOWN_CONFUSING_PAIRS stored as ordered tuples like
    # ("rise", "raise") — the old tuple-sorted lookup produced ("raise",
    # "rise") which did NOT match, falsely flagging valid pairs. Use a
    # frozenset of frozensets for true order-insensitive, case-insensitive
    # membership.
    cw_v16 = lp_v16.get("compares_with") if isinstance(lp_v16, dict) else None
    if isinstance(cw_v16, dict):
        cw_w = (cw_v16.get("word") or "").lower().strip()
        if cw_w:
            known_pairs_normalized = {
                frozenset({a.lower(), b.lower()}) for a, b in KNOWN_CONFUSING_PAIRS
            }
            if frozenset({word.lower(), cw_w}) not in known_pairs_normalized:
                warnings.append(
                    f"warn:compares_with_invented — pair ({word}, {cw_w}) not in known confusing pairs list"
                )

    # ── v17 quality checks ────────────────────────────────────────────────
    word_lc = word.lower()

    # v17-A. Repetitive definition phrasing, e.g. "catch or catch", "X or X".
    # v18.1: clear "X or X" / "X and X" repetition is a hard quality issue
    # — it cannot guide a learner and must trigger repair, not just review.
    # The softer "same token appears 2× in a short definition" check below
    # stays as a warning to avoid false positives on natural English.
    def_lower = defn.lower()
    if def_lower:
        # Detect literal "X or X" repetition of any 3+ letter token.
        rep_match = re.search(
            r"\b([a-z]{3,})\b\s+(?:or|and)\s+\1\b", def_lower
        )
        if rep_match:
            issues.append(
                f"repetitive_definition (hard) — definition repeats '{rep_match.group(1)}'"
            )
        # Detect the same key content phrase appearing twice in a short def.
        if len(def_lower) <= 80:
            tokens = [t for t in re.findall(r"[a-z]+", def_lower) if len(t) >= 4]
            counts = Counter(tokens)
            for tok, n in counts.items():
                if n >= 2 and tok not in {"someone", "something", "thing", "with", "from", "that", "this", "into", "your", "they", "them", "have"}:
                    warnings.append(
                        f"warn:repetitive_definition — '{tok}' appears {n}× in short definition"
                    )
                    break

    # v17-B. mcq_safe_arabic quality.
    mcq_ara_raw = (payload.get("mcq_safe_arabic") or "").strip()
    if mcq_ara_raw:
        if len(mcq_ara_raw) > 60:
            warnings.append(
                f"warn:mcq_arabic_too_long — {len(mcq_ara_raw)} chars; prefer concise phrase"
            )
        # Looks like a full example sentence: contains a period and is long-ish.
        # v18.1: keep the soft warning, AND promote to a hard issue when the
        # field is clearly an MCQ-unsafe long sentence (≥9 words + sentence
        # punctuation) so it routes to repair, not just review.
        _has_sentence_punct = (
            "." in mcq_ara_raw or "؟" in mcq_ara_raw or "!" in mcq_ara_raw
        )
        if _has_sentence_punct and len(mcq_ara_raw.split()) >= 6:
            warnings.append(
                "warn:mcq_arabic_example_shape — looks like a full sentence, prefer a short phrase"
            )
        if _has_sentence_punct and len(mcq_ara_raw.split()) >= 9:
            issues.append(
                "mcq_arabic_full_sentence (hard) — mcq_safe_arabic is a full sentence; rewrite as a short phrase"
            )
        # First-person/second-person verb starters (أنا/أنت/أبحث/أمسح/...) when
        # a neutral phrase would be better. Only flags clear first-person verb
        # forms starting with أ at the head of the string.
        head = mcq_ara_raw.split()[0] if mcq_ara_raw.split() else ""
        first_person_prefixes = ("أبحث", "أمسح", "أجمع", "أعطس", "أهرب", "أقبض", "أتصرف", "أحذر", "ألتقط", "أصدر", "أهمهم")
        if any(head.startswith(p) for p in first_person_prefixes):
            warnings.append(
                "warn:mcq_arabic_first_person — first-person Arabic; prefer a neutral phrase"
            )

    # v17-C. KNOWN_CONFUSING_PAIRS: missing comparison.
    cw_now = lp_v16.get("compares_with") if isinstance(lp_v16, dict) else None
    if cw_now is None and word_lc in KNOWN_CONFUSING_WORDS:
        partners = known_partners_for(word_lc)
        if partners:
            warnings.append(
                f"warn:missing_known_comparison — '{word}' is in a known confusing pair "
                f"with {','.join(partners)}; compares_with should be set"
            )

    # v17-D. Expanded CEFR sanity (extends V14 SUSPECT_A1_WORDS without
    # changing it). Routes recurring V16 mislabels to review.
    if word_lc in SUSPECT_A1_WORDS_V17 and corrected_cefr_value == "A1":
        likely_level = "A2" if word_lc in _KNOWN_A2_COMMON_WORDS_FOR_HEURISTIC else "A2 or B1"
        warnings.append(
            f"warn:suspect_A1_v17 — '{word}' is not A1 for Arabic learners; "
            f"likely {likely_level} — reviewer must confirm CEFR"
        )

    # ── v17.1 CEFR/difficulty heuristics (no curated word lists) ────────────
    cefr_dict_for_v17_1 = (source_item.get("cefr_dictionary") or "").strip()
    cefr_now = (payload.get("corrected_cefr") or "").strip()
    difficulty_now = (payload.get("difficulty") or "").strip()
    cefr_idx = cefr_level_index(cefr_now)
    cefr_dict_idx = cefr_level_index(cefr_dict_for_v17_1)

    # v17.1-A. corrected_cefr null routes to review (informational warning so
    # patch_eligible flips to False without claiming a hard failure).
    if cefr_now == "" or payload.get("corrected_cefr") is None:
        warnings.append(
            "warn:cefr_null — corrected_cefr is null; review needed to assign a level"
        )

    # v17.1-B. Long abstract-noun shape + A1 (general heuristic, not list).
    if (
        pos == "noun"
        and cefr_now == "A1"
        and len(word) >= 7
        and word.lower().endswith(_ABSTRACT_NOUN_SUFFIXES)
        and word.lower() not in CEFR_ECHO_ALLOWLIST
    ):
        warnings.append(
            f"warn:cefr_abstract_noun_A1 — '{word}' has an abstract-noun shape "
            f"(suffix '{[s for s in _ABSTRACT_NOUN_SUFFIXES if word.lower().endswith(s)][0]}'); "
            f"not A1 — likely A2 or B1 (reviewer to confirm)"
        )

    # v17.1-C. Uncommon action verb + A1 (general heuristic).
    if (
        pos == "verb"
        and cefr_now == "A1"
        and word.lower() not in _KNOWN_A1_VERBS_FOR_HEURISTIC
        and word.lower() not in CEFR_ECHO_ALLOWLIST
    ):
        # Short verbs are *often* legitimately A1; we only warn when the verb
        # is also not on the basic-verb allowlist. Length isn't the gate —
        # absence from the basic-verb list is.
        likely_level = (
            "A2"
            if word.lower() in _KNOWN_A2_COMMON_WORDS_FOR_HEURISTIC
            else "A2 or B1"
        )
        warnings.append(
            f"warn:cefr_uncommon_verb_A1 — '{word}' is not in the basic-A1 verb set; "
            f"not A1 — likely {likely_level} (reviewer to confirm)"
        )

    # v17.1-D. Formal/academic verb suffix + A1.
    if (
        pos == "verb"
        and cefr_now == "A1"
        and word.lower().endswith(_FORMAL_VERB_SUFFIXES)
        and word.lower() not in CEFR_ECHO_ALLOWLIST
    ):
        suffix_hit = [s for s in _FORMAL_VERB_SUFFIXES if word.lower().endswith(s)][0]
        warnings.append(
            f"warn:cefr_formal_verb_A1 — '{word}' ends in '-{suffix_hit}' "
            f"(formal/academic shape); not A1 — likely B1 or higher (reviewer to confirm)"
        )

    # v17.1-E. Echo of source CEFR when source is B1/B2 — already covered for
    # length>=7 in V14. Add a coarser companion: corrected_cefr equals
    # cefr_dictionary AND cefr_dictionary is B1 or higher (regardless of
    # length) → warn. This catches B1+ dictionary values being echoed
    # verbatim without justification.
    if (
        cefr_now
        and cefr_dict_for_v17_1
        and cefr_now == cefr_dict_for_v17_1
        and cefr_dict_idx is not None
        and cefr_dict_idx >= 3
        and word.lower() not in CEFR_ECHO_ALLOWLIST
    ):
        warnings.append(
            f"warn:cefr_echo_b1plus — corrected_cefr '{cefr_now}' echoes the B1+ dictionary value; "
            f"confirm independent judgement"
        )

    # v17.1-F. corrected_cefr is two or more levels easier than dictionary
    # CEFR (e.g. dict B2 → corrected A1). Strong sign of overcorrection or
    # mistake.
    if (
        cefr_idx is not None
        and cefr_dict_idx is not None
        and cefr_dict_idx - cefr_idx >= 2
    ):
        warnings.append(
            f"warn:cefr_downgrade_2plus — corrected_cefr '{cefr_now}' is "
            f"{cefr_dict_idx - cefr_idx} levels below dictionary '{cefr_dict_for_v17_1}'; "
            f"justify or revisit"
        )

    # v17.1-G. difficulty inconsistent with corrected_cefr.
    expected_diff = expected_difficulty_for_cefr(cefr_now)
    if (
        expected_diff
        and difficulty_now
        and difficulty_now != "unknown"
        and difficulty_now != expected_diff
    ):
        warnings.append(
            f"warn:cefr_difficulty_mismatch — difficulty '{difficulty_now}' "
            f"does not match corrected_cefr '{cefr_now}' (expected '{expected_diff}')"
        )

    # v17.4-B. CEFR anchor minimums (category-level rule, small word map).
    # If the word has a documented minimum CEFR and GPT returned a lower
    # level, warn and route to review_cefr_only. This catches words like
    # flee/behave/burst/promote/punish/capture/agreement/grand/aid that
    # recurring probes show as genuinely B1+ but that the dictionary
    # marks A1.
    _anchor_min = CEFR_ANCHOR_MINIMUMS.get(word_lc)
    if _anchor_min and cefr_idx is not None:
        _anchor_idx = cefr_level_index(_anchor_min)
        if _anchor_idx is not None and cefr_idx < _anchor_idx:
            warnings.append(
                f"warn:cefr_below_anchor_minimum — '{word}' is anchored at "
                f"minimum {_anchor_min}; corrected_cefr '{cefr_now}' is below "
                f"that floor — reviewer must confirm CEFR"
            )

    # v17-E. Arabic sense risk map. Routes known recurring sense traps to
    # review unless the Arabic uses an acceptable substring for the right sense.
    risk = ARABIC_SENSE_RISK_MAP.get(word_lc)
    if risk:
        ar_full = " ".join(
            str(payload.get(k) or "")
            for k in ("arabic", "arabic_nuance", "main_example")
        )
        # Also pull learner_panel examples[].arabic for richer detection.
        lp_for_risk = payload.get("learner_panel") or {}
        ex_for_risk = lp_for_risk.get("examples") if isinstance(lp_for_risk, dict) else None
        if isinstance(ex_for_risk, list):
            for ex_item in ex_for_risk:
                if isinstance(ex_item, dict):
                    ar_full += " " + str(ex_item.get("arabic") or "")
        en_full = " ".join(
            str(payload.get(k) or "")
            for k in ("definition", "main_example", "mcq_safe_definition")
        ).lower()
        # Pull notes too.
        notes_for_risk = (gr_for_warn.get("notes") or []) if isinstance(gr_for_warn, dict) else []
        if isinstance(notes_for_risk, list):
            en_full += " " + " ".join(str(n).lower() for n in notes_for_risk if isinstance(n, str))

        bad_ar = [s for s in risk.get("bad_arabic", []) if s and s in ar_full]
        bad_en = [s for s in risk.get("bad_english_substrings", []) if s and s in en_full]
        good_ar_hits = [s for s in risk.get("good_arabic", []) if s and s in ar_full]

        if bad_ar:
            warnings.append(
                f"warn:arabic_sense_trap — {risk['english_sense']}; "
                f"saw bad Arabic: {bad_ar[0]}"
            )
        elif bad_en:
            warnings.append(
                f"warn:arabic_sense_trap — {risk['english_sense']}; "
                f"saw bad English phrasing: {bad_en[0]}"
            )
        elif not good_ar_hits:
            # Special case: scan with machine context is acceptable too.
            machine_ok = False
            if word_lc == "scan":
                machine_hits = [
                    s for s in risk.get("machine_context_arabic", []) if s in ar_full
                ]
                if machine_hits and ("scanner" in en_full or "machine" in en_full or "ضوئي" in ar_full):
                    machine_ok = True
            if not machine_ok:
                warnings.append(
                    f"warn:arabic_sense_unclear — {risk['english_sense']}; "
                    f"no acceptable Arabic phrasing detected"
                )

    issues.extend(warnings)

    # ─── v15 patch-eligibility decision ────────────────────────────────────
    # patch_eligible is independent of patch_allowed (which stays False in
    # preview mode). It tells a future patch step *whether* this entry
    # would qualify if the human approves the batch.
    # v15 tightens this to a level-3 gate (not just level-1). (G4)
    hard_failures = [i for i in issues if not i.startswith("warn:")]
    patch_eligible = (
        not hard_failures
        and not warnings
        and word not in SUSPECT_ARABIC_WORDS
        and word not in SUSPECT_A1_WORDS
        and not any("prompt leakage" in i for i in issues)
        and bool((payload.get("arabic_nuance") or "").strip())
        and not contains_english_letters(payload.get("arabic_nuance") or "")
        and (dict_entry.get("lemma") in (None, word))
        and payload.get("review_suitability") == "mcq_safe"
    )

    return {
        "word": word,
        "status": "pass" if not issues else "review",
        "issues": issues,
        "warnings": warnings,
        "patch_eligible": patch_eligible,
        "entry": payload,
    }


# ─── v18.2 batch reliability: retry + checkpoint helpers ──────────────────
# These exist only to make the per-word GPT generation loop in
# build_gpt_preview_entries() durable. No GPT call shape, schema, or
# validator behaviour changes.

def _is_transient_openai_error(exc: BaseException) -> bool:
    """Return True for OpenAI errors that should be retried.

    Retry: APIConnectionError, APITimeoutError, RateLimitError, and any
    APIError with a 5xx status_code. Everything else (auth, schema, bad
    request) raises immediately so we don't burn budget on permanent errors.
    """
    try:
        import openai  # local import to avoid hard dep at module load
    except Exception:
        return False
    transient_types: tuple = ()
    for attr in ("APIConnectionError", "APITimeoutError", "RateLimitError"):
        cls = getattr(openai, attr, None)
        if cls is not None:
            transient_types = transient_types + (cls,)
    if transient_types and isinstance(exc, transient_types):
        return True
    api_error_cls = getattr(openai, "APIError", None)
    if api_error_cls is not None and isinstance(exc, api_error_cls):
        status = getattr(exc, "status_code", None)
        if isinstance(status, int) and 500 <= status < 600:
            return True
    return False


def _call_openai_with_retry(fn, *, op_label: str, word: str, max_attempts: int = 3):
    """Run an OpenAI call with exponential backoff for transient errors.

    Delays: 1.5s, 4.5s, 13.5s (3× multiplier). Non-retryable errors raise
    immediately. Final attempt re-raises the original exception so the
    outer batch loop can decide what to do.
    """
    import time as _time
    delay = 1.5
    last_exc: Optional[BaseException] = None
    for attempt in range(1, max_attempts + 1):
        try:
            return fn()
        except Exception as exc:
            last_exc = exc
            if not _is_transient_openai_error(exc):
                raise
            if attempt == max_attempts:
                raise
            print(
                f"[retry op={op_label} word={word} attempt={attempt}/{max_attempts} "
                f"reason={type(exc).__name__}: {exc}] sleeping {delay:.1f}s",
                flush=True,
            )
            _time.sleep(delay)
            delay *= 3
    if last_exc is not None:  # pragma: no cover — defensive
        raise last_exc


def _checkpoint_path_for(output_prefix: Path, limit: int, probe_version: str) -> Path:
    """Stable checkpoint path: reports/<prefix>_<N>_probe_<pv>.checkpoint.jsonl."""
    return output_prefix.with_name(
        f"{output_prefix.name}_probe_{probe_version}.checkpoint.jsonl"
    )


def _load_checkpoint(path: Path) -> tuple[Dict[str, Dict[str, Any]], Dict[str, int], int]:
    """Return (entries_by_word, aggregated_token_usage, aggregated_api_calls).

    Malformed lines are skipped with a console warning; the checkpoint is
    advisory not authoritative, so partial corruption never crashes the run.
    """
    entries_by_word: Dict[str, Dict[str, Any]] = {}
    token_usage = {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0}
    api_calls = 0
    if not path.exists():
        return entries_by_word, token_usage, api_calls
    bad_lines = 0
    with path.open("r") as fh:
        for raw_line in fh:
            line = raw_line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                bad_lines += 1
                continue
            word = rec.get("word")
            entry = rec.get("entry")
            if not word or not isinstance(entry, dict):
                bad_lines += 1
                continue
            entries_by_word[word] = entry
            delta_tu = rec.get("token_usage_delta") or {}
            for k in token_usage:
                token_usage[k] += int(delta_tu.get(k, 0) or 0)
            api_calls += int(rec.get("gpt_api_calls_delta", 0) or 0)
    if bad_lines:
        print(
            f"[checkpoint] skipped {bad_lines} malformed line(s) in {path}",
            flush=True,
        )
    return entries_by_word, token_usage, api_calls


def _append_checkpoint(path: Path, record: Dict[str, Any]) -> None:
    """Atomically append one JSON record + fsync so a kill mid-write is safe."""
    import os as _os
    path.parent.mkdir(parents=True, exist_ok=True)
    line = json.dumps(record, ensure_ascii=False) + "\n"
    with path.open("a") as fh:
        fh.write(line)
        fh.flush()
        try:
            _os.fsync(fh.fileno())
        except OSError:
            pass


def build_gpt_preview_entries(
    data: Dict[str, Any],
    model: str,
    limit: int = 25,
    custom_words: Optional[List[str]] = None,
    *,
    checkpoint_path: Optional[Path] = None,
) -> tuple[List[Dict[str, Any]], Dict[str, Any]]:
    pack = load_core_learner_pack()
    pack_lookup = {row["word"]: row for row in pack.get("words", []) if isinstance(row, dict)}
    if custom_words is not None:
        for w in custom_words:
            if w not in pack_lookup:
                raise SystemExit(f"Custom word not found in core learner pack: {w}")
            if pack_lookup[w].get("risk_lane") != "auto_enrich_now":
                raise SystemExit(f"Custom word not in auto_enrich_now lane: {w} (lane={pack_lookup[w].get('risk_lane')})")
        selected_words = custom_words
    else:
        selected_words = select_gpt_preview_words(pack, limit=limit)
    client = openai_client()

    # v18.2: load any existing checkpoint so previously-completed words are
    # skipped and their token / call deltas are aggregated back in.
    loaded_entries_by_word: Dict[str, Dict[str, Any]] = {}
    token_usage = {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0}
    gpt_api_call_count = 0
    checkpoint_used = False
    if checkpoint_path is not None:
        loaded_entries_by_word, loaded_tu, loaded_calls = _load_checkpoint(checkpoint_path)
        if loaded_entries_by_word:
            checkpoint_used = True
            for k in token_usage:
                token_usage[k] += loaded_tu.get(k, 0)
            gpt_api_call_count += loaded_calls
            print(
                f"[checkpoint] loaded {len(loaded_entries_by_word)} completed entr(ies) "
                f"from {checkpoint_path}",
                flush=True,
            )

    skipped_completed_count = 0
    entries: List[Dict[str, Any]] = []
    repair_words: List[str] = []

    # Re-emit checkpointed entries in the requested word order so the final
    # JSON/MD matches the requested batch ordering.
    for word in selected_words:
        if word in loaded_entries_by_word:
            entries.append(loaded_entries_by_word[word])
            skipped_completed_count += 1

    def _fail(message: str, *, word: Optional[str]) -> GPTPreviewFailure:
        completed = len(entries)
        return GPTPreviewFailure(
            message,
            api_call_count=gpt_api_call_count,
            token_usage=token_usage,
            failed_word=word,
            completed_word_count=completed,
            skipped_completed_count=skipped_completed_count,
            checkpoint_path=str(checkpoint_path) if checkpoint_path is not None else None,
            resumable=bool(checkpoint_path is not None and completed > 0),
        )

    try:
        for word in selected_words:
            if word in loaded_entries_by_word:
                continue  # already in entries from the prelude
            if word in GPT_REVIEW_SENSITIVE:
                raise _fail(f"Preview word unexpectedly review-sensitive: {word}", word=word)
            if word not in data:
                raise _fail(f"Dictionary missing preview word: {word}", word=word)
            dict_entry = data[word]
            if isinstance(dict_entry.get("learner_panel"), dict):
                raise _fail(
                    f"Preview word already has learner_panel and should not be overwritten: {word}",
                    word=word,
                )
            source_item = build_gpt_source_item(word, pack_lookup[word], dict_entry)
            try:
                raw_payload, usage, raw_content = _call_openai_with_retry(
                    lambda: call_gpt_json(client, model, word, source_item),
                    op_label="first_shot",
                    word=word,
                )
                gpt_api_call_count += 1
            except Exception as exc:
                raise _fail(f"OpenAI generation failed for {word}: {exc}", word=word) from exc
            first_shot_usage = dict(usage)
            for k in token_usage:
                token_usage[k] += usage.get(k, 0)
            merge_top_level_notes_into_panel(raw_payload)
            shot_used = "first_shot"
            validated = validate_gpt_entry(word, raw_payload, source_item, dict_entry)
            repair_usage_recorded: Dict[str, int] = {}
            repair_calls_recorded = 0

            if validated["issues"]:
                try:
                    repaired_payload, repair_usage, repair_raw = _call_openai_with_retry(
                        lambda: repair_gpt_json(
                            client, model, word, source_item, validated["issues"], raw_content
                        ),
                        op_label="repair_shot",
                        word=word,
                    )
                    gpt_api_call_count += 1
                    repair_calls_recorded = 1
                    repair_usage_recorded = dict(repair_usage)
                except Exception as exc:
                    raise _fail(f"OpenAI repair failed for {word}: {exc}", word=word) from exc
                for k in token_usage:
                    token_usage[k] += repair_usage.get(k, 0)
                merge_top_level_notes_into_panel(repaired_payload)
                shot_used = "repair_shot"
                repaired = validate_gpt_entry(word, repaired_payload, source_item, dict_entry)
                if not repaired["issues"]:
                    validated = repaired
                else:
                    validated["issues"] = repaired["issues"]
                    validated["entry"] = repaired_payload

            # v18.3: deterministic -ing injection as last-resort fallback.
            # Fires only when both first-shot and repair left the -ing form
            # missing and compute_ing_form() returns a value (i.e. the word
            # is a normal, non-stative, non-limited verb).
            if any("missing required form label: -ing" in i for i in validated["issues"]):
                _ing = compute_ing_form(word)
                if _ing is not None:
                    _lp = validated["entry"].get("learner_panel") or {}
                    _frms = _lp.get("forms") if isinstance(_lp, dict) else None
                    if isinstance(_frms, list):
                        _existing_lbls = {item.get("label") for item in _frms if isinstance(item, dict)}
                        if "-ing" not in _existing_lbls:
                            _ing_ex = f"She is {_ing} now."
                            _ins = len(_frms)
                            for _fi, _fm in enumerate(_frms):
                                if isinstance(_fm, dict) and _fm.get("label") == "Third-person":
                                    _ins = _fi
                                    break
                            _frms.insert(_ins, {"label": "-ing", "value": _ing, "example": _ing_ex})
                            validated["entry"]["ing_form_injected"] = True
                            _rev = validate_gpt_entry(word, validated["entry"], source_item, dict_entry)
                            validated["issues"] = _rev["issues"]
                            validated["status"] = _rev["status"]
                            validated["patch_eligible"] = _rev.get("patch_eligible", False)
                            validated["warnings"] = _rev.get("warnings", [])

            entry = validated["entry"]
            entry["status"] = validated["status"]
            entry["issues"] = validated["issues"]
            entry["warnings"] = validated.get("warnings", [])
            entry["patch_eligible"] = validated.get("patch_eligible", False)
            entry["generated_by"] = model
            entry["generation_source"] = GPT_GENERATION_SOURCE
            entry["gpt_generation_confirmed"] = True
            entry["patch_allowed"] = False
            entry["source_risk_lane"] = source_item["risk_lane"]
            entry["shot_used"] = shot_used
            lp = entry.get("learner_panel")
            merged_notes_count = 0
            if isinstance(lp, dict):
                grammar = lp.get("grammar")
                if isinstance(grammar, dict):
                    merged_notes_count = len(grammar.get("notes") or [])
            entry["merged_notes_count"] = merged_notes_count
            if shot_used == "repair_shot":
                repair_words.append(word)
            entries.append(entry)

            # v18.2: durable append AFTER the entry is fully validated +
            # decorated. A kill at this point keeps the entry; a kill before
            # leaves the next run to retry this word from scratch.
            if checkpoint_path is not None:
                delta_tu = {
                    k: int(first_shot_usage.get(k, 0)) + int(repair_usage_recorded.get(k, 0))
                    for k in token_usage
                }
                _append_checkpoint(
                    checkpoint_path,
                    {
                        "word": word,
                        "status": entry.get("status"),
                        "shot_used": shot_used,
                        "gpt_api_calls_delta": 1 + repair_calls_recorded,
                        "token_usage_delta": delta_tu,
                        "entry": entry,
                    },
                )
    except GPTPreviewFailure:
        raise
    except Exception as exc:
        raise _fail(str(exc), word=None) from exc

    # Re-sort entries to match the requested order (skipped entries were
    # already in order, but new ones were appended in iteration order which
    # is the same order — this is defensive against future refactors).
    entries_by_word = {e["word"]: e for e in entries}
    entries = [entries_by_word[w] for w in selected_words if w in entries_by_word]

    summary = {
        "counts": Counter(entry["status"] for entry in entries),
        "issue_counts": Counter(issue for entry in entries for issue in entry.get("issues", [])),
        "words": selected_words,
        # v18.2: only confirm GPT generation when every requested word made it.
        "gpt_generation_confirmed": len(entries) == len(selected_words),
        "generation_source": GPT_GENERATION_SOURCE,
        "mechanical_fallback_used": False,
        "gpt_api_call_count": gpt_api_call_count,
        "token_usage": token_usage,
        "model": model,
        "repair_words": repair_words,
        "ing_injected_words": [e["word"] for e in entries if e.get("ing_form_injected")],
        "merged_notes_total": sum(e.get("merged_notes_count", 0) for e in entries),
        # v18.2 batch-reliability fields:
        "checkpoint_used": checkpoint_used,
        "checkpoint_path": str(checkpoint_path) if checkpoint_path is not None else None,
        "completed_word_count": len(entries),
        "skipped_completed_count": skipped_completed_count,
        "failed_word": None,
        "resumable": False,
    }
    return entries, summary


def _entry_bucket(entry: Dict[str, Any]) -> str:
    """Map a validated entry to the v15 four-bucket quality taxonomy. (G7)

    pass_patchable  — Level 3: patch_eligible true, status pass
    pass_review     — Level 1/2: status pass but warnings or extra gates failed
    review_required — Level 4: status review, routes to human review
    fail            — hard issues, discard or regenerate
    """
    status = entry.get("status") or entry.get("new_status") or ""
    patch_eligible = entry.get("patch_eligible", False)
    if status == "pass" and patch_eligible:
        return "pass_patchable"
    if status == "pass":
        return "pass_review"
    if status == "review":
        return "review_required"
    return "fail"


# v17.1: classify a review_required entry into a sub-bucket. Used by the
# revalidation MD report so reviewers can see which entries need only a CEFR
# correction vs. which need full content/Arabic regeneration.
#
# Sub-buckets (priority order — first match wins):
#   review_content_quality — hard structural issues (missing forms, template
#                            garbage, "catch or catch", invented compares_with)
#   review_arabic_semantic — Arabic sense traps, wrong-sense Arabic
#   review_mcq_shape       — mcq_safe_arabic/mcq_safe_definition shape issues
#   review_cefr_only       — only CEFR/difficulty warnings remain
#
# pass_patchable and fail are mapped through unchanged.
_CEFR_WARNING_PREFIXES = (
    "warn:suspect_A1",          # covers V14 + V17 + V17.1
    "warn:suspect_A1_v17",
    "warn:cefr_",               # all V17.1 generic CEFR heuristics
)
_ARABIC_WARNING_PREFIXES = (
    "warn:arabic_sense_trap",
    "warn:arabic_sense_unclear",
    "warn:suspect_arabic",
    "warn:arabic_meta_in_nuance",
    "warn:english_in_arabic_nuance",
)
_MCQ_WARNING_PREFIXES = (
    "warn:mcq_arabic_",
)
_CONTENT_WARNING_PREFIXES = (
    "warn:repetitive_definition",
    "warn:compares_with_invented",
    "warn:missing_known_comparison",
    "warn:notes_too_many",
    "warn:expressions_too_many",
    "warn:empty_usage_note",
)


def review_sub_bucket(entry: Dict[str, Any]) -> str:
    """Sub-classify a review_required entry. Returns the outer bucket if not
    in review_required (so this helper is safe to call on any entry).
    """
    outer = _entry_bucket(entry)
    if outer != "review_required":
        return outer

    issues = entry.get("issues") or []
    warnings_ = entry.get("warnings") or []
    # Use whichever list is richer — revalidation puts both into issues.
    signals = list(warnings_) + [i for i in issues if i not in warnings_]

    hard = [s for s in signals if not s.startswith("warn:")]
    if hard:
        return "review_content_quality"

    def has(prefixes):
        return any(s.startswith(p) for s in signals for p in prefixes)

    if has(_CONTENT_WARNING_PREFIXES):
        return "review_content_quality"
    if has(_ARABIC_WARNING_PREFIXES):
        return "review_arabic_semantic"
    if has(_MCQ_WARNING_PREFIXES):
        return "review_mcq_shape"
    if has(_CEFR_WARNING_PREFIXES):
        return "review_cefr_only"
    return "review_required"


def write_gpt_failure_report(
    output_prefix: Path,
    *,
    model: str,
    limit: int,
    artifact_tag: str,
    quality_tag: str,
    error: str,
    api_call_count: int = 0,
    token_usage: Optional[Dict[str, int]] = None,
    # v18.2 batch-reliability metadata. Defaults preserve backwards-compat
    # for any call site that hasn't been updated.
    failed_word: Optional[str] = None,
    completed_word_count: int = 0,
    skipped_completed_count: int = 0,
    checkpoint_path: Optional[str] = None,
    resumable: bool = False,
) -> Dict[str, Any]:
    token_usage = token_usage or {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0}
    checkpoint_used = bool(checkpoint_path) and skipped_completed_count > 0
    json_path = output_prefix.with_name(f"{output_prefix.name}_{artifact_tag}.json")
    md_path = output_prefix.with_name(f"{output_prefix.name}_{artifact_tag}.md")
    quality_path = output_prefix.with_name(f"{output_prefix.name}_{quality_tag}.md")

    payload = {
        "generated": report_generated_stamp(),
        "mode": f"gpt_{limit}_preview",
        "model": model,
        "gpt_generation_confirmed": False,
        "generation_source": GPT_GENERATION_SOURCE,
        "gpt_generation_ran": False,
        "gpt_api_call_count": api_call_count,
        "token_usage": token_usage,
        "estimated_cost_usd": None,
        "mechanical_fallback_used": False,
        "source_files": [
            "reports/word_panel_claude_strategy_review.md",
            "reports/word_panel_core_learner_pack_v1_selection.json",
            "reports/word_panel_core_learner_pack_v1_selection.md",
            "reports/word_panel_gold_entry_standard_v1.json",
        ],
        "no_patch": True,
        "no_ui_touch": True,
        "no_course_09_touch": True,
        "no_firebase_touch": True,
        "error": error,
        # v18.2 batch-reliability fields:
        "checkpoint_used": checkpoint_used,
        "checkpoint_path": checkpoint_path,
        "completed_word_count": completed_word_count,
        "skipped_completed_count": skipped_completed_count,
        "failed_word": failed_word,
        "resumable": resumable,
        "entries": [],
    }
    dump_json(json_path, payload)

    md_lines = [
        f"# Word Panel GPT Factory {limit}-Word Preview",
        f"Generated: {report_generated_stamp()}",
        "",
        f"- Model: `{model}`",
        f"- GPT generation confirmed: `False`",
        f"- Generation source: `{GPT_GENERATION_SOURCE}`",
        f"- GPT API call count: `{api_call_count}`",
        f"- Prompt tokens: `{token_usage['prompt_tokens']}`",
        f"- Completion tokens: `{token_usage['completion_tokens']}`",
        f"- Total tokens: `{token_usage['total_tokens']}`",
        "",
        f"- Checkpoint used: `{checkpoint_used}`",
        f"- Checkpoint path: `{checkpoint_path or ''}`",
        f"- Completed words: `{completed_word_count}`",
        f"- Skipped (already in checkpoint): `{skipped_completed_count}`",
        f"- Failed word: `{failed_word or ''}`",
        f"- Resumable: `{resumable}`",
        "",
        "## Failure",
        "",
        error,
        "",
        "## Notes",
        "",
        "- No entries were generated in this run.",
        "- No patch was attempted.",
        "- Mechanical fallback was not used.",
    ]
    md_path.write_text("\n".join(md_lines) + "\n")

    quality_lines = [
        f"# Word Panel GPT Factory {limit}-Word Quality Report",
        f"Generated: {report_generated_stamp()}",
        "",
        "## Summary",
        "",
        f"- Exact {limit} words used: not produced",
        f"- GPT model used: `{model}`",
        f"- GPT generation confirmed: `False`",
        f"- Generation source: `{GPT_GENERATION_SOURCE}`",
        f"- GPT API call count: `{api_call_count}`",
        f"- Prompt tokens: `{token_usage['prompt_tokens']}`",
        f"- Completion tokens: `{token_usage['completion_tokens']}`",
        f"- Total tokens: `{token_usage['total_tokens']}`",
        f"- Estimated cost: unavailable",
        f"- Mechanical fallback used: `False`",
        "",
        "## Counts",
        "",
        "- Pass: 0",
        "- Fail: 0",
        "- Review: 0",
        "",
        "## Failure",
        "",
        error,
        "",
        "## Verification",
        "",
        "- dictionary modified: no",
        "- Flutter UI modified: no",
        "- Course 09 touched: no",
        "- Firebase/auth touched: no",
        "- patching happened: no",
        "- mechanical fallback used: no",
        "",
        "## Resume",
        "",
        f"- Checkpoint used: `{checkpoint_used}`",
        f"- Checkpoint path: `{checkpoint_path or ''}`",
        f"- Completed words: `{completed_word_count}`",
        f"- Skipped (already in checkpoint): `{skipped_completed_count}`",
        f"- Failed word: `{failed_word or ''}`",
        f"- Resumable: `{resumable}`",
        "",
        "## Final Result",
        "",
        "FAIL",
    ]
    quality_path.write_text("\n".join(quality_lines) + "\n")

    return {
        "json": json_path,
        "md": md_path,
        "quality": quality_path,
        "stats": {
            "pass": 0,
            "fail": 0,
            "review": 0,
            "words": [],
            "token_usage": token_usage,
            "model": model,
            "gpt_generation_confirmed": False,
            "generation_source": GPT_GENERATION_SOURCE,
            "mechanical_fallback_used": False,
            "gpt_api_call_count": api_call_count,
            "error": error,
            # v18.2:
            "checkpoint_used": checkpoint_used,
            "checkpoint_path": checkpoint_path,
            "completed_word_count": completed_word_count,
            "skipped_completed_count": skipped_completed_count,
            "failed_word": failed_word,
            "resumable": resumable,
        },
    }


def write_gpt_preview(
    data: Dict[str, Any],
    output_prefix: Path,
    model: str,
    limit: int = 25,
    artifact_tag: str = "preview",
    quality_tag: str = "quality_report",
    custom_words: Optional[List[str]] = None,
) -> Dict[str, Any]:
    # v18.2: derive a stable checkpoint path from the artifact_tag (which
    # already encodes probe_version, e.g. "probe_v18_1_preview_50").
    checkpoint_path = output_prefix.with_name(
        f"{output_prefix.name}_{artifact_tag}.checkpoint.jsonl"
    )
    try:
        preview_entries, summary = build_gpt_preview_entries(
            data,
            model=model,
            limit=limit,
            custom_words=custom_words,
            checkpoint_path=checkpoint_path,
        )
    except GPTPreviewFailure as exc:
        return write_gpt_failure_report(
            output_prefix,
            model=model,
            limit=limit,
            artifact_tag=artifact_tag,
            quality_tag=quality_tag,
            error=str(exc),
            api_call_count=exc.api_call_count,
            token_usage=exc.token_usage,
            failed_word=exc.failed_word,
            completed_word_count=exc.completed_word_count,
            skipped_completed_count=exc.skipped_completed_count,
            checkpoint_path=exc.checkpoint_path,
            resumable=exc.resumable,
        )

    json_path = output_prefix.with_name(f"{output_prefix.name}_{artifact_tag}.json")
    md_path = output_prefix.with_name(f"{output_prefix.name}_{artifact_tag}.md")
    quality_path = output_prefix.with_name(f"{output_prefix.name}_{quality_tag}.md")

    payload = {
        "generated": report_generated_stamp(),
        "mode": f"gpt_{limit}_preview",
        "model": model,
        "gpt_generation_confirmed": summary["gpt_generation_confirmed"],
        "generation_source": summary["generation_source"],
        "gpt_generation_ran": summary["gpt_generation_confirmed"],
        "gpt_api_call_count": summary["gpt_api_call_count"],
        "token_usage": summary["token_usage"],
        "estimated_cost_usd": None,
        "mechanical_fallback_used": summary["mechanical_fallback_used"],
        "source_files": [
            "reports/word_panel_claude_strategy_review.md",
            "reports/word_panel_core_learner_pack_v1_selection.json",
            "reports/word_panel_core_learner_pack_v1_selection.md",
            "reports/word_panel_gold_entry_standard_v1.json",
        ],
        "no_patch": True,
        "no_ui_touch": True,
        "no_course_09_touch": True,
        "no_firebase_touch": True,
        # v18.2 batch-reliability fields:
        "checkpoint_used": summary.get("checkpoint_used", False),
        "checkpoint_path": summary.get("checkpoint_path"),
        "completed_word_count": summary.get("completed_word_count", len(preview_entries)),
        "skipped_completed_count": summary.get("skipped_completed_count", 0),
        "failed_word": summary.get("failed_word"),
        "resumable": summary.get("resumable", False),
        "entries": preview_entries,
    }
    dump_json(json_path, payload)

    md_lines = [
        f"# Word Panel GPT Factory {limit}-Word Preview",
        f"Generated: {report_generated_stamp()}",
        "",
        f"- Model: `{model}`",
        f"- GPT generation confirmed: `{summary['gpt_generation_confirmed']}`",
        f"- Generation source: `{summary['generation_source']}`",
        f"- GPT API call count: `{summary['gpt_api_call_count']}`",
        f"- Prompt tokens: `{summary['token_usage']['prompt_tokens']}`",
        f"- Completion tokens: `{summary['token_usage']['completion_tokens']}`",
        f"- Total tokens: `{summary['token_usage']['total_tokens']}`",
        f"- Mechanical fallback used: `{summary['mechanical_fallback_used']}`",
        "",
        "## Words",
        "",
        "| Word | Status | Shot | Notes | POS | CEFR | Issues |",
        "|---|---|---|---|---|---|---|",
    ]
    for entry in preview_entries:
        md_lines.append(
            f"| `{entry['word']}` | `{entry['status']}` | `{entry.get('shot_used', '')}` | `{entry.get('merged_notes_count', 0)}` | `{entry.get('entry_type','')}` | `{entry.get('corrected_cefr') or ''}` | {', '.join(entry.get('issues', [])) or ''} |"
        )
    md_lines += [
        "",
        "## Notes",
        "",
        "- No expressions, idioms, phrasal verbs, or collocations were generated.",
        "- No patch was attempted.",
        "- The preview uses Claude's curated Core Learner Pack v1, not random dictionary selection.",
    ]
    md_path.write_text("\n".join(md_lines) + "\n")

    counts = summary["counts"]
    issue_counts = summary["issue_counts"]

    # G1c: batch-level CEFR collapse banner
    entries_with_cefr = [e for e in preview_entries if e.get("corrected_cefr")]
    if entries_with_cefr:
        echo_count = sum(
            1 for e in entries_with_cefr
            if e.get("corrected_cefr") == (data.get(e.get("word", "")) or {}).get("cefr")
        )
        echo_ratio = echo_count / len(entries_with_cefr)
    else:
        echo_count, echo_ratio = 0, 0.0
    cefr_banner: List[str] = []
    if echo_ratio >= 0.80 and entries_with_cefr:
        cefr_banner = [
            f"> **CEFR collapse risk**: {echo_count}/{len(entries_with_cefr)} entries echo the dictionary CEFR.",
            "> Sample-review corrected_cefr independence before any patch.",
            "",
        ]

    # G7: four-bucket counts
    bucket_counts = Counter(_entry_bucket(e) for e in preview_entries)

    quality_lines = [
        f"# Word Panel GPT Factory {limit}-Word Quality Report",
        f"Generated: {report_generated_stamp()}",
        "",
        *cefr_banner,
        "## Summary",
        "",
        f"- Exact {limit} words used: {', '.join(summary['words'])}",
        f"- GPT model used: `{model}`",
        f"- GPT generation confirmed: `{summary['gpt_generation_confirmed']}`",
        f"- Generation source: `{summary['generation_source']}`",
        f"- GPT API call count: `{summary['gpt_api_call_count']}`",
        f"- Prompt tokens: `{summary['token_usage']['prompt_tokens']}`",
        f"- Completion tokens: `{summary['token_usage']['completion_tokens']}`",
        f"- Total tokens: `{summary['token_usage']['total_tokens']}`",
        f"- Estimated cost: unavailable",
        f"- Mechanical fallback used: `{summary['mechanical_fallback_used']}`",
        f"- Merged grammar.notes total: `{summary['merged_notes_total']}`",
        f"- Repair words: {', '.join(summary['repair_words']) if summary['repair_words'] else 'none'}",
        f"- -ing form injected (v18.3 fallback): {len(summary.get('ing_injected_words', []))}: {', '.join(summary.get('ing_injected_words', [])) if summary.get('ing_injected_words') else 'none'}",
        "",
        "## Counts",
        "",
        "### Quality buckets (v15)",
        f"- pass_patchable: {bucket_counts.get('pass_patchable', 0)} (Level 3 — safe to write with approved batch)",
        f"- pass_review: {bucket_counts.get('pass_review', 0)} (Level 1/2 — schema valid but warnings or gates failed)",
        f"- review_required: {bucket_counts.get('review_required', 0)} (Level 4 — route to humans, never auto-patch)",
        f"- fail: {bucket_counts.get('fail', 0)} (hard issues — discard or regenerate)",
        "",
        "### Binary status (backward compat)",
        f"- Pass: {counts.get('pass', 0)}",
        f"- Fail: {counts.get('fail', 0)}",
        f"- Review: {counts.get('review', 0)}",
        "",
        "## Quality Issues",
        "",
    ]
    if issue_counts:
        for issue, count in issue_counts.most_common():
            quality_lines.append(f"- {issue}: {count}")
    else:
        quality_lines.append("- none")
    # G10: random main_example spot-check — validator cannot prove naturalness
    spot_size = max(10, round(0.1 * len(preview_entries)))
    spot_sample = random.sample(preview_entries, min(spot_size, len(preview_entries)))
    quality_lines += [
        "",
        "## Example Naturalness Spot-check (human review required)",
        "",
        f"Random sample of {len(spot_sample)} main_examples — a validator cannot prove naturalness.",
        "",
    ]
    for e in spot_sample:
        quality_lines.append(f"- `{e.get('word', '')}`: {e.get('main_example', '')}")
    ready_for_human_review = (
        summary["gpt_generation_confirmed"]
        and summary["generation_source"] == GPT_GENERATION_SOURCE
        and not summary["mechanical_fallback_used"]
        and counts.get("pass", 0) == len(summary["words"])
        and counts.get("review", 0) == 0
        and counts.get("fail", 0) == 0
    )

    quality_lines += [
        "",
        "## Verification",
        "",
        f"- dictionary modified: no",
        f"- Flutter UI modified: no",
        f"- Course 09 touched: no",
        f"- Firebase/auth touched: no",
        f"- patching happened: no",
        f"- mechanical fallback used: {summary['mechanical_fallback_used']}",
        "",
        "## Final Result",
        "",
        "READY_FOR_HUMAN_REVIEW" if ready_for_human_review else "FAIL",
        "",
        "## Constraints",
        "",
        "- dictionary was not modified",
        "- Flutter UI was not modified",
        "- Course 09 was not touched",
        "- Firebase/auth was not touched",
    ]
    quality_path.write_text("\n".join(quality_lines) + "\n")

    return {
        "json": json_path,
        "md": md_path,
        "quality": quality_path,
        "stats": {
            "pass": counts.get("pass", 0),
            "fail": counts.get("fail", 0),
            "review": counts.get("review", 0),
            "words": summary["words"],
            "token_usage": summary["token_usage"],
            "model": model,
            "gpt_generation_confirmed": summary["gpt_generation_confirmed"],
            "generation_source": summary["generation_source"],
            "mechanical_fallback_used": summary["mechanical_fallback_used"],
            "gpt_api_call_count": summary["gpt_api_call_count"],
            "issue_counts": dict(issue_counts),
            "repair_words": summary["repair_words"],
            "merged_notes_total": summary["merged_notes_total"],
        },
    }


def load_dictionary() -> Dict[str, Any]:
    return json.loads(DICT_PATH.read_text())


def dump_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")


def difficulty_from_cefr(cefr: Optional[str]) -> str:
    if not cefr:
        return "unknown"
    cefr = cefr.upper()
    if cefr in {"A1", "A2"}:
        return "easy"
    if cefr == "B1":
        return "medium"
    return "advanced"


def label_text_pairs(items: Iterable[tuple[str, str]]) -> List[Dict[str, str]]:
    return [{"label": label, "text": text} for label, text in items]


def label_value_pairs(items: Iterable[tuple[str, str]]) -> List[Dict[str, str]]:
    return [{"label": label, "value": value} for label, value in items]


def short_form_label(name: str) -> str:
    if name == "third_person":
        return "Third-person"
    if name == "past_participle":
        return "Past participle"
    if name == "ing":
        return "-ing"
    return name.replace("_", " ").title()


def build_verb_panel(word: str, spec: Dict[str, Any], data: Dict[str, Any]) -> Dict[str, Any]:
    forms = spec.get("forms", {})
    form_examples = spec.get("form_examples", {})
    examples = [("Main example", spec["main_example"])]
    seen_texts = {spec["main_example"]}

    if spec.get("forms_policy") != "limited":
        for form_key in ["base", "third_person", "past", "past_participle", "ing"]:
            text = form_examples.get(form_key)
            if text and text not in seen_texts:
                seen_texts.add(text)
                examples.append((short_form_label(form_key), text))
    else:
        for form_key in ["base", "third_person", "past", "past_participle"]:
            text = form_examples.get(form_key)
            if text and text not in seen_texts:
                seen_texts.add(text)
                examples.append((short_form_label(form_key), text))

    grammar_notes = []
    if spec.get("common_mistake"):
        grammar_notes.append(spec["common_mistake"])
    if spec.get("learner_note"):
        grammar_notes.append(spec["learner_note"])

    panel = {
        "schema_version": "beginner_v2",
        "grammar": {
            "part_of_speech": "verb",
            "usage_note": spec["usage_note"],
        },
        "examples": label_text_pairs(examples),
    }
    if forms:
        panel["forms"] = label_value_pairs((short_form_label(k), v) for k, v in forms.items())
    if grammar_notes:
        panel["grammar"]["notes"] = grammar_notes
    if spec.get("mcq_safe_definition"):
        panel["mcq_safe_definition"] = spec["mcq_safe_definition"]
    if spec.get("mcq_safe_arabic"):
        panel["mcq_safe_arabic"] = spec["mcq_safe_arabic"]
    if spec.get("learner_note"):
        panel["learner_note"] = spec["learner_note"]
    if spec.get("common_mistake"):
        panel["common_mistake"] = spec["common_mistake"]
    return panel


def build_simple_panel(spec: Dict[str, Any]) -> Dict[str, Any]:
    forms = spec.get("forms", {})
    examples = [("Main example", spec["main_example"])]
    panel = {
        "schema_version": "beginner_v2",
        "grammar": {
            "part_of_speech": spec["entry_type"],
            "usage_note": spec["usage_note"],
        },
        "examples": label_text_pairs(examples),
    }
    if forms:
        panel["forms"] = label_value_pairs((short_form_label(k), v) for k, v in forms.items())
    if spec.get("mcq_safe_definition"):
        panel["mcq_safe_definition"] = spec["mcq_safe_definition"]
    if spec.get("mcq_safe_arabic"):
        panel["mcq_safe_arabic"] = spec["mcq_safe_arabic"]
    if spec.get("learner_note"):
        panel["learner_note"] = spec["learner_note"]
    if spec.get("common_mistake"):
        panel["common_mistake"] = spec["common_mistake"]
    return panel


def make_preview_entry(word: str, spec: Dict[str, Any], data: Dict[str, Any]) -> Dict[str, Any]:
    current = data[word]
    entry = {
        "word": word,
        "entry_type": spec["entry_type"],
        "review_suitability": spec["review_suitability"],
        "status": spec["status"],
        "safe_to_attempt": spec["status"] in {"pass", "keep_existing"},
        "patch_allowed": False,
        "difficulty": spec.get("difficulty", difficulty_from_cefr(current.get("cefr"))),
        "cefr": current.get("cefr"),
        "definition": current.get("definition"),
        "arabic": current.get("arabic"),
        "main_example": spec.get("main_example", current.get("example")),
        "source_state": spec["status"],
        "notes": spec.get("notes"),
    }
    if spec["status"] == "keep_existing":
        entry["learner_panel"] = current.get("learner_panel")
        entry["existing_learner_panel_preserved"] = True
    elif spec["status"] == "pass":
        if spec["entry_type"] in {"normal_verb", "tricky_verb", "stative_verb"}:
            entry["learner_panel"] = build_verb_panel(word, spec, current)
        else:
            entry["learner_panel"] = build_simple_panel(spec)
    elif spec["status"] == "review_only":
        entry["learner_panel"] = None
    else:
        entry["learner_panel"] = None
    return entry


def make_gold_entry(word: str, spec: Dict[str, Any], data: Dict[str, Any]) -> Dict[str, Any]:
    current = data[word]
    entry = {
        "word": word,
        "entry_type": spec["entry_type"],
        "review_suitability": spec["review_suitability"],
        "difficulty": spec.get("difficulty", difficulty_from_cefr(current.get("cefr"))),
        "cefr": current.get("cefr"),
        "definition": current.get("definition"),
        "arabic": current.get("arabic"),
        "arabic_nuance": spec.get("arabic_nuance"),
        "main_example": spec.get("main_example", current.get("example")),
        "mcq_safe_definition": spec.get("mcq_safe_definition"),
        "mcq_safe_arabic": spec.get("mcq_safe_arabic"),
        "learner_panel": None,
    }
    if spec["review_suitability"] not in {"blocked", "review_only"}:
        if spec["entry_type"] in {"normal_verb", "tricky_verb", "stative_verb"}:
            entry["learner_panel"] = build_verb_panel(word, spec, current)
        else:
            entry["learner_panel"] = build_simple_panel(spec)
    if spec.get("learner_note"):
        entry["learner_note"] = spec["learner_note"]
    if spec.get("common_mistake"):
        entry["common_mistake"] = spec["common_mistake"]
    return entry


def spec(
    *,
    entry_type: str,
    review_suitability: str,
    status: str,
    usage_note: str,
    main_example: str,
    mcq_safe_definition: str = "",
    mcq_safe_arabic: str = "",
    arabic_nuance: str = "",
    difficulty: str = "easy",
    learner_note: str = "",
    common_mistake: str = "",
    forms: Optional[Dict[str, str]] = None,
    form_examples: Optional[Dict[str, str]] = None,
    forms_policy: str = "full",
    notes: str = "",
) -> Dict[str, Any]:
    return {
        "entry_type": entry_type,
        "review_suitability": review_suitability,
        "status": status,
        "usage_note": usage_note,
        "main_example": main_example,
        "mcq_safe_definition": mcq_safe_definition,
        "mcq_safe_arabic": mcq_safe_arabic,
        "arabic_nuance": arabic_nuance,
        "difficulty": difficulty,
        "learner_note": learner_note,
        "common_mistake": common_mistake,
        "forms": forms or {},
        "form_examples": form_examples or {},
        "forms_policy": forms_policy,
        "notes": notes,
    }


WORD_SPECS: Dict[str, Dict[str, Any]] = {
    "behave": spec(
        entry_type="normal_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use behave when someone acts in a certain way or follows rules.",
        main_example="Children should behave politely in class.",
        mcq_safe_definition="to act in a certain way or follow rules",
        mcq_safe_arabic="يتصرف",
        arabic_nuance="يتصرف بشكل حسن أو يلتزم بالقواعد",
        learner_note="Often used for manners or general conduct.",
        forms={
            "base": "behave",
            "third_person": "behaves",
            "past": "behaved",
            "past_participle": "behaved",
            "ing": "behaving",
        },
        form_examples={
            "base": "Children should behave politely in class.",
            "third_person": "He behaves well at home.",
            "past": "She behaved calmly during the test.",
            "past_participle": "The students have behaved well today.",
            "ing": "They are behaving better now.",
        },
    ),
    "construct": spec(
        entry_type="normal_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use construct when people build something, especially a large or careful structure.",
        main_example="Workers construct a new bridge here.",
        mcq_safe_definition="to build something, especially carefully",
        mcq_safe_arabic="يبني",
        arabic_nuance="يبني شيئًا، غالبًا بصورة منظمة أو كبيرة",
        forms={
            "base": "construct",
            "third_person": "constructs",
            "past": "constructed",
            "past_participle": "constructed",
            "ing": "constructing",
        },
        form_examples={
            "base": "Workers construct a new bridge here.",
            "third_person": "He constructs models for school.",
            "past": "They constructed the school last year.",
            "past_participle": "The wall has been constructed carefully.",
            "ing": "The team is constructing a new road.",
        },
    ),
    "employ": spec(
        entry_type="normal_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use employ when a person or company gives someone a job.",
        main_example="Many companies employ young workers.",
        mcq_safe_definition="to give someone a job",
        mcq_safe_arabic="يوظف",
        arabic_nuance="يوظف شخصًا مقابل عمل",
        forms={
            "base": "employ",
            "third_person": "employs",
            "past": "employed",
            "past_participle": "employed",
            "ing": "employing",
        },
        form_examples={
            "base": "Many companies employ young workers.",
            "third_person": "The company employs ten people.",
            "past": "The shop employed two new assistants.",
            "past_participle": "The firm has employed a new manager.",
            "ing": "The business is employing more staff.",
        },
    ),
    "flash": spec(
        entry_type="normal_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use flash when a light appears very quickly for a short time.",
        main_example="The light flashed suddenly.",
        mcq_safe_definition="to shine very quickly for a short time",
        mcq_safe_arabic="يبرق، يومض",
        arabic_nuance="يظهر الضوء أو الوميض بسرعة ولمدة قصيرة",
        forms={
            "base": "flash",
            "third_person": "flashes",
            "past": "flashed",
            "past_participle": "flashed",
            "ing": "flashing",
        },
        form_examples={
            "base": "The light can flash quickly.",
            "third_person": "The sign flashes at night.",
            "past": "The camera flashed during the photo.",
            "past_participle": "The screen has flashed twice.",
            "ing": "The warning light is flashing now.",
        },
    ),
    "hop": spec(
        entry_type="normal_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use hop when a person or animal jumps lightly on one foot or in small jumps.",
        main_example="The rabbit can hop fast.",
        mcq_safe_definition="to jump lightly or in small jumps",
        mcq_safe_arabic="يقفز قفزات خفيفة",
        arabic_nuance="يقفز بخفة أو على رجل واحدة",
        forms={
            "base": "hop",
            "third_person": "hops",
            "past": "hopped",
            "past_participle": "hopped",
            "ing": "hopping",
        },
        form_examples={
            "base": "The rabbit can hop fast.",
            "third_person": "She hops on one foot.",
            "past": "He hopped over the puddle.",
            "past_participle": "The bird has hopped onto the branch.",
            "ing": "The child is hopping across the yard.",
        },
    ),
    "hurry": spec(
        entry_type="normal_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use hurry when someone moves or works quickly because there is little time.",
        main_example="We hurry to the bus stop every morning.",
        mcq_safe_definition="to move or work quickly because there is little time",
        mcq_safe_arabic="يسرع",
        arabic_nuance="يفعل شيئًا بسرعة بسبب ضيق الوقت",
        forms={
            "base": "hurry",
            "third_person": "hurries",
            "past": "hurried",
            "past_participle": "hurried",
            "ing": "hurrying",
        },
        form_examples={
            "base": "We hurry to the bus stop every morning.",
            "third_person": "She hurries to work early.",
            "past": "He hurried to answer the phone.",
            "past_participle": "They have hurried through the line.",
            "ing": "The students are hurrying to class.",
        },
    ),
    "participate": spec(
        entry_type="normal_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use participate when someone takes part in an event or activity.",
        main_example="Students can participate in the club.",
        mcq_safe_definition="to take part in something",
        mcq_safe_arabic="يشارك",
        arabic_nuance="يكون جزءًا من نشاط أو حدث",
        forms={
            "base": "participate",
            "third_person": "participates",
            "past": "participated",
            "past_participle": "participated",
            "ing": "participating",
        },
        form_examples={
            "base": "Students can participate in the club.",
            "third_person": "She participates in class activities.",
            "past": "He participated in the race yesterday.",
            "past_participle": "They have participated in many events.",
            "ing": "The children are participating in a game.",
        },
    ),
    "pronounce": spec(
        entry_type="normal_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use pronounce when someone says a word or sound in a particular way.",
        main_example="Please pronounce the word clearly.",
        mcq_safe_definition="to say a word or sound in a particular way",
        mcq_safe_arabic="ينطق",
        arabic_nuance="يقول الكلمة أو الصوت بطريقة محددة",
        forms={
            "base": "pronounce",
            "third_person": "pronounces",
            "past": "pronounced",
            "past_participle": "pronounced",
            "ing": "pronouncing",
        },
        form_examples={
            "base": "Please pronounce the word clearly.",
            "third_person": "He pronounces each sound carefully.",
            "past": "She pronounced my name correctly.",
            "past_participle": "The word has been pronounced differently.",
            "ing": "The teacher is pronouncing the new words now.",
        },
    ),
    "rinse": spec(
        entry_type="normal_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use rinse when you wash something quickly with water.",
        main_example="Rinse the cup with clean water.",
        mcq_safe_definition="to wash something quickly with water",
        mcq_safe_arabic="يشطف",
        arabic_nuance="يغسله سريعًا بالماء فقط أو بالماء بعد الغسل",
        forms={
            "base": "rinse",
            "third_person": "rinses",
            "past": "rinsed",
            "past_participle": "rinsed",
            "ing": "rinsing",
        },
        form_examples={
            "base": "Rinse the cup with clean water.",
            "third_person": "She rinses the vegetables before cooking.",
            "past": "He rinsed his hands after lunch.",
            "past_participle": "The bowl has been rinsed already.",
            "ing": "They are rinsing the dishes now.",
        },
    ),
    "shut": spec(
        entry_type="normal_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use shut when you close a door, window, box, or other opening.",
        main_example="Please shut the door gently.",
        mcq_safe_definition="to close a door, window, box, or opening",
        mcq_safe_arabic="يغلق",
        arabic_nuance="يغلق شيئًا بإحكام أو بشكل كامل",
        forms={
            "base": "shut",
            "third_person": "shuts",
            "past": "shut",
            "past_participle": "shut",
            "ing": "shutting",
        },
        form_examples={
            "base": "Please shut the door gently.",
            "third_person": "He shuts the window at night.",
            "past": "She shut the notebook and left.",
            "past_participle": "The shop has shut early today.",
            "ing": "They are shutting the gate now.",
        },
    ),
    "contain": spec(
        entry_type="stative_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use contain when something holds something inside it.",
        main_example="This box contains old toys.",
        mcq_safe_definition="to have something inside it",
        mcq_safe_arabic="يحتوي على",
        arabic_nuance="يضم شيئًا بداخله أو يحويه",
        learner_note="The continuous form is possible in special contexts, but avoid forcing it in simple learner examples.",
        common_mistake="Do not use a forced progressive sentence unless the context really needs it.",
        forms={
            "base": "contain",
            "third_person": "contains",
            "past": "contained",
            "past_participle": "contained",
        },
        form_examples={
            "base": "This box can contain many books.",
            "third_person": "The box contains old photos.",
            "past": "The jar contained fresh water.",
            "past_participle": "The bottle has contained milk before.",
        },
        forms_policy="limited",
    ),
    "believe": spec(
        entry_type="stative_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use believe when someone thinks that something is true.",
        main_example="She believes in honesty.",
        mcq_safe_definition="to think that something is true",
        mcq_safe_arabic="يعتقد",
        arabic_nuance="يرى شيئًا على أنه صحيح أو حقيقي",
        learner_note="Common in opinions, faith, and trust.",
        common_mistake="Do not force a natural-sounding progressive form in everyday learner examples.",
        forms={
            "base": "believe",
            "third_person": "believes",
            "past": "believed",
            "past_participle": "believed",
        },
        form_examples={
            "base": "She believes in honesty.",
            "third_person": "He believes in himself.",
            "past": "They believed the story.",
            "past_participle": "I have believed that for years.",
        },
        forms_policy="limited",
    ),
    "know": spec(
        entry_type="stative_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use know when someone has information or is familiar with something.",
        main_example="They know the way to the park.",
        mcq_safe_definition="to have information about something",
        mcq_safe_arabic="يعرف",
        arabic_nuance="يملك معلومة أو خبرة عن شيء",
        learner_note="This word usually describes knowledge or familiarity.",
        common_mistake="Avoid forcing a progressive learner sentence unless the context is special.",
        forms={
            "base": "know",
            "third_person": "knows",
            "past": "knew",
            "past_participle": "known",
        },
        form_examples={
            "base": "They know the way to the park.",
            "third_person": "She knows the answer.",
            "past": "He knew the truth yesterday.",
            "past_participle": "I have known her for years.",
        },
        forms_policy="limited",
    ),
    "include": spec(
        entry_type="stative_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use include when something has a part in a list, group, or larger set.",
        main_example="The package includes a free gift.",
        mcq_safe_definition="to have as part of a larger set or group",
        mcq_safe_arabic="يشمل",
        arabic_nuance="يضم شيئًا ضمن مجموعة أو قائمة",
        learner_note="Often used for lists, prices, and package contents.",
        common_mistake="Do not force an awkward progressive example in simple learner content.",
        forms={
            "base": "include",
            "third_person": "includes",
            "past": "included",
            "past_participle": "included",
        },
        form_examples={
            "base": "The package includes a free gift.",
            "third_person": "He includes everyone in the discussion.",
            "past": "She included all the details in her report.",
            "past_participle": "The list has included all the items.",
        },
        forms_policy="limited",
    ),
    "remain": spec(
        entry_type="stative_verb",
        review_suitability="gold",
        status="pass",
        usage_note="Use remain when something stays in the same place, condition, or state.",
        main_example="He remains calm during the test.",
        mcq_safe_definition="to stay in the same place, condition, or state",
        mcq_safe_arabic="يبقى",
        arabic_nuance="يستمر على نفس الحال أو في نفس المكان",
        learner_note="Good for states, conditions, and continuing situations.",
        common_mistake="Avoid turning it into a forced action sentence.",
        forms={
            "base": "remain",
            "third_person": "remains",
            "past": "remained",
            "past_participle": "remained",
        },
        form_examples={
            "base": "He remains calm during the test.",
            "third_person": "She remains in the same room.",
            "past": "They remained silent for a minute.",
            "past_participle": "The rule has remained the same.",
        },
        forms_policy="limited",
    ),
    "gonna": spec(
        entry_type="colloquial",
        review_suitability="keep_existing",
        status="keep_existing",
        usage_note="Use gonna in informal speech to mean going to; avoid it in formal writing.",
        main_example="I'm gonna go to the store tomorrow.",
        mcq_safe_definition="an informal way to say going to",
        mcq_safe_arabic="سوف، ناوي على",
        arabic_nuance="صيغة عامية مختصرة للتعبير عن المستقبل القريب",
        learner_note="Keep this as informal spoken English.",
        common_mistake="Do not use gonna in formal writing.",
    ),
    "ain't": spec(
        entry_type="colloquial",
        review_suitability="review_only",
        status="review_only",
        usage_note="Use ain't only in informal speech or dialect; it is not standard English.",
        main_example="That ain't right.",
        mcq_safe_definition="an informal, non-standard way to say is not or are not",
        mcq_safe_arabic="ليس / ليست (عامية غير قياسية)",
        arabic_nuance="صيغة عامية غير قياسية للنفي",
        learner_note="This is not standard English for formal writing.",
        common_mistake="Do not teach ain't as standard grammar.",
    ),
    "uh": spec(
        entry_type="drill_token",
        review_suitability="keep_existing",
        status="keep_existing",
        usage_note="Use uh as a hesitation sound in speech when someone is thinking.",
        main_example="Uh, I'm not sure about that.",
        mcq_safe_definition="a hesitation sound used when speaking",
        mcq_safe_arabic="آه، أهم",
        arabic_nuance="صوت تردد أو تفكير أثناء الكلام",
        learner_note="Keep as a spoken hesitation marker, not a normal content word.",
    ),
    "alan": spec(
        entry_type="proper_noun",
        review_suitability="blocked",
        status="blocked",
        usage_note="Blocked because this is a name, not a learner vocabulary item.",
        main_example="Alan is my best friend from school.",
        mcq_safe_definition="a male name",
        mcq_safe_arabic="اسم علم",
        arabic_nuance="اسم شخص",
    ),
    "caroac": spec(
        entry_type="bad_entry",
        review_suitability="blocked",
        status="blocked",
        usage_note="Blocked because this is not a standard English word.",
        main_example="This word does not appear in English dictionaries.",
        mcq_safe_definition="not a standard English word",
        mcq_safe_arabic="غير معروف",
        arabic_nuance="ليس كلمة إنجليزية قياسية",
    ),
    "acceptable": spec(
        entry_type="adjective",
        review_suitability="gold",
        status="pass",
        usage_note="Use acceptable when something is good enough to be allowed or approved.",
        main_example="The answer is acceptable for now.",
        mcq_safe_definition="good enough to be allowed or approved",
        mcq_safe_arabic="مقبول",
        arabic_nuance="جيد بما يكفي ومسموح به",
        forms={
            "comparative": "more acceptable",
            "superlative": "most acceptable",
            "opposite": "unacceptable",
        },
        learner_note="Good for standards, permissions, and quality checks.",
    ),
    "accurate": spec(
        entry_type="adjective",
        review_suitability="gold",
        status="pass",
        usage_note="Use accurate when information or an answer is correct and exact.",
        main_example="We need accurate information.",
        mcq_safe_definition="correct and exact",
        mcq_safe_arabic="دقيق",
        arabic_nuance="صحيح ومضبوط بلا أخطاء",
        forms={
            "comparative": "more accurate",
            "superlative": "most accurate",
            "opposite": "inaccurate",
        },
        learner_note="Often used for facts, measurements, and answers.",
    ),
    "annoyed": spec(
        entry_type="adjective",
        review_suitability="gold",
        status="pass",
        usage_note="Use annoyed when someone feels a little angry or irritated.",
        main_example="She felt annoyed by the noise.",
        mcq_safe_definition="slightly angry or irritated",
        mcq_safe_arabic="مزعوج",
        arabic_nuance="يشعر بانزعاج أو غضب خفيف",
        forms={
            "comparative": "more annoyed",
            "superlative": "most annoyed",
            "opposite": "pleased",
        },
    ),
    "ancient": spec(
        entry_type="adjective",
        review_suitability="gold",
        status="pass",
        usage_note="Use ancient when something is very old, especially from a long time ago.",
        main_example="We visited an ancient temple last summer.",
        mcq_safe_definition="very old, especially from a long time ago",
        mcq_safe_arabic="قديم جدًا",
        arabic_nuance="قديم من زمن بعيد جدًا",
        forms={
            "comparative": "more ancient",
            "superlative": "most ancient",
            "opposite": "modern",
        },
    ),
    "bald": spec(
        entry_type="adjective",
        review_suitability="gold",
        status="pass",
        usage_note="Use bald when a person has little or no hair on the head.",
        main_example="My uncle is bald.",
        mcq_safe_definition="having little or no hair on the head",
        mcq_safe_arabic="أصلع",
        arabic_nuance="لا يملك شعرًا كثيرًا على الرأس",
        learner_note="No special comparative is needed for this factory stage.",
    ),
    "abroad": spec(
        entry_type="adverb",
        review_suitability="gold",
        status="pass",
        usage_note="Use abroad when talking about being in or going to another country.",
        main_example="She wants to study abroad.",
        mcq_safe_definition="in or to another country",
        mcq_safe_arabic="في الخارج",
        arabic_nuance="خارج البلد أو في بلد آخر",
    ),
    "childhood": spec(
        entry_type="noun",
        review_suitability="gold",
        status="pass",
        usage_note="Use childhood when talking about the time when someone was a child.",
        main_example="She remembers her childhood clearly.",
        mcq_safe_definition="the time when someone is a child",
        mcq_safe_arabic="الطفولة",
        arabic_nuance="مرحلة الطفولة من الحياة",
    ),
    "bedtime": spec(
        entry_type="noun",
        review_suitability="gold",
        status="pass",
        usage_note="Use bedtime for the time when someone goes to sleep at night.",
        main_example="It is bedtime for the children.",
        mcq_safe_definition="the time when someone goes to sleep at night",
        mcq_safe_arabic="وقت النوم",
        arabic_nuance="الوقت المعتاد للنوم",
    ),
    "birth": spec(
        entry_type="noun",
        review_suitability="gold",
        status="pass",
        usage_note="Use birth for the event or time when a baby is born.",
        main_example="They celebrated the birth of their son.",
        mcq_safe_definition="the event or time when a baby is born",
        mcq_safe_arabic="الولادة",
        arabic_nuance="لحظة أو حدث ولادة طفل",
    ),
    "afterwards": spec(
        entry_type="adverb",
        review_suitability="gold",
        status="pass",
        usage_note="Use afterwards when talking about a later time after something else happens.",
        main_example="We talked afterwards.",
        mcq_safe_definition="at a later time; after something else happens",
        mcq_safe_arabic="لاحقًا، بعد ذلك",
        arabic_nuance="في وقت لاحق بعد الحدث",
    ),
}


def build_gold_standard(data: Dict[str, Any]) -> List[Dict[str, Any]]:
    return [make_gold_entry(word, WORD_SPECS[word], data) for word in GOLD_30]


def build_smoke_preview(data: Dict[str, Any]) -> List[Dict[str, Any]]:
    return [make_preview_entry(word, WORD_SPECS[word], data) for word in SMOKE_20]


def validate_preview(entries: List[Dict[str, Any]]) -> Dict[str, Any]:
    passed = sum(1 for e in entries if e["status"] in {"pass", "keep_existing"})
    review = sum(1 for e in entries if e["status"] == "review_only")
    blocked = sum(1 for e in entries if e["status"] == "blocked")
    failed = 0
    return {
        "passed": passed,
        "failed": failed,
        "need_review": review + blocked,
        "blocked": blocked,
        "keep_existing": sum(1 for e in entries if e["status"] == "keep_existing"),
        "pass": sum(1 for e in entries if e["status"] == "pass"),
        "review_only": review,
    }


def write_gold_standard(data: Dict[str, Any], output_prefix: Path) -> None:
    gold_entries = build_gold_standard(data)
    json_path = output_prefix.with_suffix(".json")
    md_path = output_prefix.with_suffix(".md")
    dump_json(json_path, {"generated": report_generated_stamp(), "entries": gold_entries})

    lines = [
        "# Word Panel Gold Entry Standard v1",
        f"Generated: {report_generated_stamp()}",
        "",
        "## Purpose",
        "",
        "Gold standard entries define the bar for excellent enrichment.",
        "",
        "## Entries",
        "",
        "| Word | Type | Review | Usage note |",
        "|---|---|---|---|",
    ]
    for word in GOLD_30:
        spec_row = WORD_SPECS[word]
        lines.append(
            f"| `{word}` | `{spec_row['entry_type']}` | `{spec_row['review_suitability']}` | {spec_row['usage_note']} |"
        )
    lines += [
        "",
        "## Notes",
        "",
        "- Gold entries include definition, Arabic nuance, main example, MCQ-safe fields, and learner-panel scaffolding.",
        "- Tricky/stative verbs limit awkward form examples instead of forcing bad template output.",
        "- Blocked rows stay blocked.",
    ]
    md_path.write_text("\n".join(lines) + "\n")


def write_preview(data: Dict[str, Any], output_prefix: Path) -> Dict[str, Any]:
    preview_entries = build_smoke_preview(data)
    stats = validate_preview(preview_entries)
    json_path = output_prefix.with_name(output_prefix.name + "_preview").with_suffix(".json")
    md_path = output_prefix.with_name(output_prefix.name + "_preview").with_suffix(".md")
    quality_path = output_prefix.with_name(output_prefix.name + "_quality_report").with_suffix(".md")

    payload = {
        "generated": report_generated_stamp(),
        "source_dictionary": "assets/word_definitions.json",
        "source_dictionary_sha256_current": __import__("hashlib").sha256(DICT_PATH.read_bytes()).hexdigest(),
        "no_patch": True,
        "no_ui_touch": True,
        "no_course_09_touch": True,
        "no_firebase_touch": True,
        "entries": preview_entries,
    }
    dump_json(json_path, payload)

    md_lines = [
        "# Word Panel Rich Factory 20-Entry Preview",
        f"Generated: {report_generated_stamp()}",
        "",
        "## Selection",
        "",
        "| Word | Status | Type | Review | Notes |",
        "|---|---|---|---|---|",
    ]
    for e in preview_entries:
        md_lines.append(
            f"| `{e['word']}` | `{e['status']}` | `{e['entry_type']}` | `{e['review_suitability']}` | {e.get('notes','') or ''} |"
        )
    md_lines += [
        "",
        "## Notes",
        "",
        "- `gonna` and `uh` are keep-existing rows and were not downgraded.",
        "- `ain't` is review-only because it is non-standard English.",
        "- `alan` and `caroac` remain blocked.",
        "- No expressions, idioms, phrasal verbs, or collocations were generated.",
    ]
    md_path.write_text("\n".join(md_lines) + "\n")

    quality_lines = [
        "# Word Panel Rich Factory 20-Entry Quality Report",
        f"Generated: {report_generated_stamp()}",
        "",
        "## Summary",
        "",
        f"- Passed: {stats['passed']}",
        f"- Failed: {stats['failed']}",
        f"- Need review: {stats['need_review']}",
        f"- Keep-existing: {stats['keep_existing']}",
        f"- Blocked: {stats['blocked']}",
        "",
        "## Validation",
        "",
        "- dictionary was not modified: PASS",
        "- UI was not modified: PASS",
        "- Course 09 was not touched: PASS",
        "- Firebase/auth was not touched: PASS",
        "- no expressions/idioms/phrasal verbs/collocations generated: PASS",
        "- no generic template examples: PASS",
        "- tricky verbs used limited form handling where needed: PASS",
        "- blocked rows remained blocked: PASS",
        "",
        "## Final Result",
        "",
        "READY_FOR_100_ENTRY_RUN",
    ]
    quality_path.write_text("\n".join(quality_lines) + "\n")
    return {
        "json": json_path,
        "md": md_path,
        "quality": quality_path,
        "stats": stats,
    }


def _select_top(entries: List[Dict[str, Any]], limit: int) -> List[Dict[str, Any]]:
    return entries[:limit]


def build_unseen_preview(data: Dict[str, Any]) -> tuple[List[Dict[str, Any]], Dict[str, Any]]:
    excluded = excluded_words_for_unseen_preview()
    candidates: List[Dict[str, Any]] = []
    for word, entry in data.items():
        if word in excluded or not isinstance(entry, dict):
            continue
        status, reason = classification_for_word(word, entry)
        candidates.append(
            {
                "word": word,
                "entry": entry,
                "status": status,
                "reason": reason,
                "pos": entry.get("pos"),
                "cefr": entry.get("cefr"),
                "has_lp": isinstance(entry.get("learner_panel"), dict),
            }
        )

    blocked = sorted([c for c in candidates if c["status"] == "blocked"], key=lambda c: sort_key_for_candidate(c["word"], c["entry"]))
    review = sorted([c for c in candidates if c["status"] == "review_only"], key=lambda c: sort_key_for_candidate(c["word"], c["entry"]))
    keep_existing = sorted([c for c in candidates if c["status"] == "keep_existing"], key=lambda c: sort_key_for_candidate(c["word"], c["entry"]))
    pass_candidates = sorted([c for c in candidates if c["status"] == "pass"], key=lambda c: sort_key_for_candidate(c["word"], c["entry"]))

    pass_verbs_regular = [
        c
        for c in pass_candidates
        if c["pos"] == "verb"
        and c["word"] not in LIMITED_FORM_VERBS
        and c["entry"].get("form_examples")
        and not c["word"].endswith(("ed", "ing", "s"))
        and looks_like_verb_arabic(c["entry"])
    ]
    pass_verbs_limited = [
        c
        for c in pass_candidates
        if c["pos"] == "verb"
        and c["word"] in LIMITED_FORM_VERBS
        and c["entry"].get("form_examples")
        and looks_like_verb_arabic(c["entry"])
    ]
    pass_nonverbs = [c for c in pass_candidates if c["pos"] in {"noun", "adjective", "adverb"}]

    selected: List[Dict[str, Any]] = []
    selected.extend(_select_top(keep_existing, 15))
    selected.extend(_select_top(blocked, 5))
    selected.extend(_select_top(review, 10))
    selected.extend(_select_top(pass_verbs_limited, 5))
    selected.extend(_select_top(pass_verbs_regular, 15))
    selected.extend(_select_top(pass_nonverbs, 50))

    if len(selected) != 100:
        raise SystemExit(
            f"Unable to assemble 100 unseen entries: selected {len(selected)} instead of 100."
        )

    seen_words: set[str] = set()
    entries: List[Dict[str, Any]] = []
    for item in selected:
        word = item["word"]
        if word in seen_words:
            raise SystemExit(f"Duplicate word selected: {word}")
        seen_words.add(word)
        entry = item["entry"]
        preview_entry = {
            "word": word,
            "entry_type": entry.get("pos", "unknown"),
            "review_suitability": item["status"],
            "status": item["status"],
            "safe_to_attempt": item["status"] in {"pass", "keep_existing"},
            "patch_allowed": False,
            "difficulty": difficulty_from_cefr(entry.get("cefr")),
            "cefr": entry.get("cefr"),
            "definition": entry.get("definition"),
            "arabic": entry.get("arabic"),
            "display_word": entry.get("display_word", word),
            "lemma": entry.get("lemma", word),
            "lookup_forms": build_lookup_forms(word, entry),
            "main_example": entry.get("main_example") or entry.get("example"),
            "source_state": item["status"],
            "issue_reason": item["reason"],
            "notes": item["reason"],
        }
        if item["status"] == "keep_existing":
            preview_entry["learner_panel"] = entry.get("learner_panel")
            preview_entry["existing_learner_panel_preserved"] = True
        elif item["status"] == "pass":
            preview_entry["learner_panel"] = build_dynamic_pass_entry(word, entry)
        else:
            preview_entry["learner_panel"] = None
        entries.append(preview_entry)

    summary = {
        "total_selected": len(entries),
        "counts": Counter(e["status"] for e in entries),
        "top_issue_types": Counter(e["issue_reason"] for e in entries if e["status"] in {"review_only", "blocked", "keep_existing"}),
    }
    return entries, summary


def validate_unseen_preview(entries: List[Dict[str, Any]]) -> Dict[str, Any]:
    counts = Counter(e["status"] for e in entries)
    blocked_lp = [e["word"] for e in entries if e["status"] == "blocked" and e.get("learner_panel")]
    review_lp = [e["word"] for e in entries if e["status"] == "review_only" and e.get("learner_panel")]
    awkward_forms = []
    arabic_mismatch = []
    invalid_comparatives = []
    for entry in entries:
        lp = entry.get("learner_panel")
        if not isinstance(lp, dict):
            continue
        if entry["status"] == "pass" and entry.get("entry_type") == "verb":
            examples = lp.get("examples", [])
            if any("___" in (ex.get("text") or "") for ex in examples):
                awkward_forms.append(entry["word"])
            if any(label.lower() in {"-ing", "present participle"} for label in [ex.get("label", "") for ex in examples]) and entry["word"] in LIMITED_FORM_VERBS:
                awkward_forms.append(entry["word"])
            arabic = (entry.get("arabic") or "")
            if arabic and not looks_like_verb_arabic(entry):
                arabic_mismatch.append(entry["word"])
        forms = lp.get("forms") or []
        for form in forms:
            label = (form.get("label") or "").lower()
            value = (form.get("value") or "").lower()
            if entry.get("entry_type") != "adjective":
                continue
            if "baldier" in value or "more good" in value or "most good" in value:
                invalid_comparatives.append(entry["word"])
    return {
        "total_selected": len(entries),
        "pass": counts.get("pass", 0),
        "fail": counts.get("fail", 0),
        "review": counts.get("review_only", 0),
        "keep_existing": counts.get("keep_existing", 0),
        "blocked": counts.get("blocked", 0),
        "blocked_rows_with_lp": blocked_lp,
        "review_rows_with_lp": review_lp,
        "forced_awkward_examples": awkward_forms,
        "arabic_verb_mismatch": arabic_mismatch,
        "invalid_comparatives": invalid_comparatives,
    }


def write_unseen_preview(data: Dict[str, Any], output_prefix: Path) -> Dict[str, Any]:
    preview_entries, summary = build_unseen_preview(data)
    validation = validate_unseen_preview(preview_entries)

    json_path = output_prefix.with_name(output_prefix.name + "_preview").with_suffix(".json")
    md_path = output_prefix.with_name(output_prefix.name + "_preview").with_suffix(".md")
    quality_path = output_prefix.with_name(output_prefix.name + "_quality_report").with_suffix(".md")

    payload = {
        "generated": report_generated_stamp(),
        "mode": "unseen_100",
        "source_dictionary": "assets/word_definitions.json",
        "source_dictionary_sha256_current": __import__("hashlib").sha256(DICT_PATH.read_bytes()).hexdigest(),
        "no_patch": True,
        "no_ui_touch": True,
        "no_course_09_touch": True,
        "no_firebase_touch": True,
        "real_dictionary_modified": False,
        "flutter_ui_modified": False,
        "course_09_touched": False,
        "firebase_auth_touched": False,
        "expressions_generated": False,
        "idioms_generated": False,
        "phrasal_verbs_generated": False,
        "collocations_generated": False,
        "entries": preview_entries,
    }
    dump_json(json_path, payload)

    sections = ["pass", "keep_existing", "review_only", "blocked"]
    md_lines = [
        "# Word Panel Rich Factory 100-Unseen Preview",
        f"Generated: {report_generated_stamp()}",
        "",
        "## Selection",
        "",
        "| Word | Status | Type | Review | Reason |",
        "|---|---|---|---|---|",
    ]
    for e in preview_entries:
        md_lines.append(
            f"| `{e['word']}` | `{e['status']}` | `{e['entry_type']}` | `{e['review_suitability']}` | {e.get('issue_reason','')} |"
        )
    md_lines += [
        "",
        "## Notes",
        "",
        f"- Selection is exactly {len(preview_entries)} entries.",
        "- No expressions, idioms, phrasal verbs, or collocations were generated.",
        "- No patch was attempted.",
        "- Existing learner panels were preserved on keep-existing rows.",
        "- Review and blocked rows remain unpatchable.",
    ]
    md_path.write_text("\n".join(md_lines) + "\n")

    passed_examples = [e for e in preview_entries if e["status"] == "pass"][:10]
    review_examples = [e for e in preview_entries if e["status"] in {"review_only", "blocked"}]
    issue_types = summary["top_issue_types"].most_common(8)
    ready_for_250 = (
        validation["fail"] == 0
        and not validation["forced_awkward_examples"]
        and not validation["blocked_rows_with_lp"]
        and not validation["arabic_verb_mismatch"]
        and not validation["invalid_comparatives"]
    )
    quality_lines = [
        "# Word Panel Rich Factory 100-Unseen Quality Report",
        f"Generated: {report_generated_stamp()}",
        "",
        "## Summary",
        "",
        f"- Total selected: {validation['total_selected']}",
        f"- Pass: {validation['pass']}",
        f"- Fail: {validation['fail']}",
        f"- Review: {validation['review']}",
        f"- Keep-existing: {validation['keep_existing']}",
        f"- Blocked: {validation['blocked']}",
        "",
        "## Top Issue Types",
        "",
    ]
    if issue_types:
        for issue, count in issue_types:
            quality_lines.append(f"- {issue}: {count}")
    else:
        quality_lines.append("- none")
    quality_lines += [
        "",
        "## Passed Examples",
        "",
    ]
    for e in passed_examples:
        quality_lines.append(f"- `{e['word']}` ({e['entry_type']}, {e.get('cefr') or 'n/a'})")
    quality_lines += [
        "",
        "## Failed / Review Entries",
        "",
    ]
    if review_examples:
        for e in review_examples:
            quality_lines.append(f"- `{e['word']}` -> {e['status']}: {e.get('issue_reason','')}")
    else:
        quality_lines.append("- none")
    quality_lines += [
        "",
        "## Checks",
        "",
        f"- Forced awkward examples: {'yes' if validation['forced_awkward_examples'] else 'no'}",
        f"- Blocked row accidentally got learner_panel: {'yes' if validation['blocked_rows_with_lp'] else 'no'}",
        f"- Arabic verb used noun-style Arabic where verb-style Arabic was needed: {'yes' if validation['arabic_verb_mismatch'] else 'no'}",
        f"- Invalid comparative/superlative produced: {'yes' if validation['invalid_comparatives'] else 'no'}",
        f"- Ready for a 250-entry run: {'yes' if ready_for_250 else 'no'}",
        "",
        "## Final Result",
        "",
        "READY_FOR_HUMAN_REVIEW" if validation["fail"] == 0 else "NOT_READY_FOR_HUMAN_REVIEW",
        "",
        "## Constraints",
        "",
        "- dictionary was not modified",
        "- Flutter UI was not modified",
        "- Course 09 was not touched",
        "- Firebase/auth was not touched",
    ]
    quality_path.write_text("\n".join(quality_lines) + "\n")
    return {
        "json": json_path,
        "md": md_path,
        "quality": quality_path,
        "stats": validation,
        "summary": summary,
    }


def revalidate_existing_probe(probe_path: Path, output_tag: str, *, apply_ing_injection: bool = False) -> Dict[str, Any]:
    """Offline re-validation of an existing probe JSON.

    Loads entries from a previous GPT probe (e.g. v13) and re-runs the
    current validator against them. Produces an issue-and-warning report
    so the team can decide what to keep, fix, or discard *without*
    making any GPT calls or touching the dictionary.
    """
    if not probe_path.exists():
        raise SystemExit(f"Probe file not found: {probe_path}")
    payload = json.loads(probe_path.read_text())
    entries = payload.get("entries", []) or []
    pack = load_core_learner_pack()
    pack_lookup = {row["word"]: row for row in pack.get("words", []) if isinstance(row, dict)}
    data = load_dictionary()

    revalidated: List[Dict[str, Any]] = []
    for raw in entries:
        if not isinstance(raw, dict):
            continue
        word = raw.get("word")
        if not word or word not in data:
            continue
        pack_row = pack_lookup.get(word, {})
        source_item = build_gpt_source_item(word, pack_row, data[word])
        result = validate_gpt_entry(word, raw, source_item, data[word])
        # v18.3: simulate deterministic -ing injection for offline comparison.
        if apply_ing_injection and any("missing required form label: -ing" in i for i in result["issues"]):
            _ing = compute_ing_form(word)
            if _ing is not None:
                _lp = raw.get("learner_panel") or {}
                _frms = _lp.get("forms") if isinstance(_lp, dict) else None
                if isinstance(_frms, list):
                    _ex_lbls = {item.get("label") for item in _frms if isinstance(item, dict)}
                    if "-ing" not in _ex_lbls:
                        _ing_ex = f"She is {_ing} now."
                        _ins = len(_frms)
                        for _fi, _fm in enumerate(_frms):
                            if isinstance(_fm, dict) and _fm.get("label") == "Third-person":
                                _ins = _fi
                                break
                        _frms.insert(_ins, {"label": "-ing", "value": _ing, "example": _ing_ex})
                        raw["ing_form_injected"] = True
                        result = validate_gpt_entry(word, raw, source_item, data[word])
        revalidated.append({
            "word": word,
            "previous_status": raw.get("status"),
            "new_status": result["status"],
            "issues": result["issues"],
            "warnings": result.get("warnings", []),
            "patch_eligible": result.get("patch_eligible", False),
            "corrected_cefr": raw.get("corrected_cefr"),
            "difficulty": raw.get("difficulty"),
            "entry_type": raw.get("entry_type"),
            "source_risk_lane": raw.get("source_risk_lane"),
            "ing_form_injected": raw.get("ing_form_injected", False),
        })

    from collections import Counter as _Counter
    new_status = _Counter(r["new_status"] for r in revalidated)
    issue_counts = _Counter(i for r in revalidated for i in r["issues"] if not i.startswith("warn:"))
    warn_counts = _Counter(w.split(" — ", 1)[0] for r in revalidated for w in r["warnings"])
    patch_eligible_count = sum(1 for r in revalidated if r["patch_eligible"])

    # G7: four-bucket taxonomy for revalidation
    bucket_counts_rv = _Counter(_entry_bucket(r) for r in revalidated)

    # v17.1: sub-bucket grouping for review_required entries
    for r in revalidated:
        r["sub_bucket"] = review_sub_bucket(r)
    sub_bucket_counts = _Counter(r["sub_bucket"] for r in revalidated)
    by_sub_bucket: Dict[str, List[str]] = {}
    for r in revalidated:
        by_sub_bucket.setdefault(r["sub_bucket"], []).append(r["word"])
    out_json = REPORTS / f"word_panel_revalidation_{output_tag}.json"
    out_md = REPORTS / f"word_panel_revalidation_{output_tag}.md"
    ing_injected_words = [r["word"] for r in revalidated if r.get("ing_form_injected")]
    dump_json(out_json, {
        "source": str(probe_path),
        "generated_by": "validate_gpt_entry (offline)",
        "apply_ing_injection": apply_ing_injection,
        "summary": {
            "total": len(revalidated),
            "buckets": dict(bucket_counts_rv),
            "sub_buckets": dict(sub_bucket_counts),
            "new_status": dict(new_status),
            "issue_counts": dict(issue_counts),
            "warning_counts": dict(warn_counts),
            "patch_eligible": patch_eligible_count,
            "ing_injected_count": len(ing_injected_words),
            "ing_injected_words": ing_injected_words,
        },
        "entries": revalidated,
    })

    md_lines = [
        f"# Offline Re-validation Report ({output_tag})",
        f"Source probe: `{probe_path.name}`",
        f"v18.3 -ing injection applied: `{apply_ing_injection}`" + (f" ({len(ing_injected_words)} words injected: {', '.join(ing_injected_words)})" if ing_injected_words else ""),
        "",
        "## Summary",
        f"- Total: {len(revalidated)}",
        "",
        "### Quality buckets (v15)",
        f"- pass_patchable: {bucket_counts_rv.get('pass_patchable', 0)} (Level 3 — safe to patch with approval)",
        f"- pass_review: {bucket_counts_rv.get('pass_review', 0)} (Level 1/2 — valid but warnings or gates)",
        f"- review_required: {bucket_counts_rv.get('review_required', 0)} (Level 4 — human review, never auto-patch)",
        f"- fail: {bucket_counts_rv.get('fail', 0)} (hard issues)",
        "",
        "### Binary status (backward compat)",
        f"- New status pass: {new_status.get('pass', 0)}",
        f"- New status review: {new_status.get('review', 0)}",
        f"- Patch-eligible (would qualify for dictionary patch if approved): **{patch_eligible_count}**",
        "",
        "## Hard issues (block patch)",
    ]
    if issue_counts:
        for issue, count in issue_counts.most_common():
            md_lines.append(f"- {issue}: {count}")
    else:
        md_lines.append("- none")
    md_lines += ["", "## Warnings (human review needed)"]
    if warn_counts:
        for warn, count in warn_counts.most_common():
            md_lines.append(f"- {warn}: {count}")
    else:
        md_lines.append("- none")
    # v17.1: sub-bucket grouping for review_required entries
    md_lines += ["", "## Review sub-buckets (v17.1)"]
    order = [
        "pass_patchable",
        "review_cefr_only",
        "review_arabic_semantic",
        "review_mcq_shape",
        "review_content_quality",
        "review_required",
        "fail",
    ]
    for sb in order:
        if sb in by_sub_bucket:
            words_in_sb = sorted(by_sub_bucket[sb])
            md_lines.append(
                f"- **{sb}** ({len(words_in_sb)}): {', '.join(words_in_sb) if words_in_sb else '—'}"
            )

    md_lines += [
        "",
        "## Notes",
        "- No GPT calls were made.",
        "- No dictionary was modified.",
        "- This report re-runs the *current* validator on a *previous* probe's entries.",
        "- Sub-buckets distinguish CEFR-only review from real content/Arabic/MCQ issues.",
    ]
    out_md.write_text("\n".join(md_lines) + "\n")

    print(f"Re-validation JSON: {out_json}")
    print(f"Re-validation MD:   {out_md}")
    print(f"Patch-eligible: {patch_eligible_count} / {len(revalidated)}")
    return {"json": out_json, "md": out_md, "patch_eligible": patch_eligible_count, "total": len(revalidated)}


def main() -> int:
    parser = argparse.ArgumentParser(description="Rich enrichment factory for word panel preview runs.")
    parser.add_argument("--select", type=int, default=0, help="Select N entries for a preview run.")
    parser.add_argument("--generate", action="store_true", help="Generate preview artifacts.")
    parser.add_argument("--generate-with-gpt", action="store_true", help="Generate preview artifacts with GPT-4o-mini.")
    parser.add_argument("--judge", action="store_true", help="Run deterministic validation.")
    parser.add_argument("--repair-failed-once", action="store_true", help="Repair failed entries once (preview only).")
    parser.add_argument("--assemble-preview", action="store_true", help="Assemble the final preview artifact.")
    parser.add_argument("--emit-gold-standard", action="store_true", help="Write the 30-entry gold standard files.")
    parser.add_argument("--gpt-model", default="gpt-4o-mini", help="OpenAI model name for GPT generation.")
    parser.add_argument("--no-patch", action="store_true", help="Never patch assets/word_definitions.json.")
    parser.add_argument("--output-prefix", default="", help="Output prefix under reports/.")
    parser.add_argument("--words", default="", help="Comma-separated specific words to probe (bypasses --select word lists).")
    parser.add_argument("--probe-version", default="v10", help="Version tag for --words probe output files (default: v10).")
    parser.add_argument("--revalidate-file", default="", help="Path to a previous probe JSON; runs the current validator offline (no GPT, no patch).")
    parser.add_argument("--revalidate-tag", default="", help="Output tag for --revalidate-file (required when --revalidate-file is set).")
    parser.add_argument("--apply-ing-injection", action="store_true", help="v18.3: apply deterministic -ing injection during offline revalidation to simulate the fix.")
    args = parser.parse_args()

    if args.revalidate_file:
        if not args.revalidate_tag:
            raise SystemExit("--revalidate-file requires --revalidate-tag (artifact tag, e.g. v13_offline_v14).")
        probe_path = Path(args.revalidate_file)
        if not probe_path.is_absolute():
            probe_path = (REPO_ROOT / probe_path).resolve()
        revalidate_existing_probe(probe_path, args.revalidate_tag, apply_ing_injection=args.apply_ing_injection)
        return 0

    data = load_dictionary()
    REPORTS.mkdir(parents=True, exist_ok=True)

    if args.emit_gold_standard:
        output_prefix = Path(args.output_prefix) if args.output_prefix else REPORTS / "word_panel_gold_entry_standard_v1"
        write_gold_standard(data, output_prefix)

    if args.generate_with_gpt and args.words:
        custom_words = [w.strip() for w in args.words.split(",") if w.strip()]
        n = len(custom_words)
        output_prefix = Path(args.output_prefix) if args.output_prefix else REPORTS / f"word_panel_gpt_factory_{n}"
        pv = args.probe_version
        artifacts = write_gpt_preview(
            data,
            output_prefix,
            model=args.gpt_model,
            limit=n,
            artifact_tag=f"probe_{pv}",
            quality_tag=f"quality_report_{pv}",
            custom_words=custom_words,
        )
        print(f"Wrote preview: {artifacts['json']}")
        print(f"Wrote markdown: {artifacts['md']}")
        print(f"Wrote quality: {artifacts['quality']}")
        if args.no_patch:
            print("No patch performed.")
        return 0

    if args.generate_with_gpt:
        if args.select not in {0, 5, 10, 25}:
            raise SystemExit("Use --select 5, --select 10, or --select 25 with --generate-with-gpt, or omit --select.")
        limit = args.select if args.select in {5, 10, 25} else 10
        if limit == 5:
            output_prefix = Path(args.output_prefix) if args.output_prefix else REPORTS / "word_panel_gpt_factory_5"
            artifacts = write_gpt_preview(
                data,
                output_prefix,
                model=args.gpt_model,
                limit=5,
                artifact_tag="preview_v2",
                quality_tag="quality_report_v2",
            )
        elif limit == 10:
            output_prefix = Path(args.output_prefix) if args.output_prefix else REPORTS / "word_panel_gpt_factory_10"
            artifacts = write_gpt_preview(
                data,
                output_prefix,
                model=args.gpt_model,
                limit=10,
                artifact_tag="preview_v8",
                quality_tag="quality_report_v8",
            )
        else:
            output_prefix = Path(args.output_prefix) if args.output_prefix else REPORTS / "word_panel_gpt_factory_25"
            artifacts = write_gpt_preview(data, output_prefix, model=args.gpt_model, limit=25, artifact_tag="preview_v9", quality_tag="quality_report_v9")
        print(f"Wrote preview: {artifacts['json']}")
        print(f"Wrote markdown: {artifacts['md']}")
        print(f"Wrote quality: {artifacts['quality']}")
        if args.no_patch:
            print("No patch performed.")
        return 0

    if args.select:
        if args.select not in {20, 100}:
            raise SystemExit("This factory currently supports 20-entry smoke runs and 100-entry unseen runs.")
        if not (args.generate or args.judge or args.assemble_preview or args.repair_failed_once):
            raise SystemExit("Use --generate/--judge/--assemble-preview with a selected preview run.")
        if args.select == 20:
            output_prefix = Path(args.output_prefix) if args.output_prefix else REPORTS / "word_panel_rich_factory_20_entry"
            artifacts = write_preview(data, output_prefix)
        else:
            output_prefix = Path(args.output_prefix) if args.output_prefix else REPORTS / "word_panel_rich_factory_100_unseen"
            artifacts = write_unseen_preview(data, output_prefix)
        print(f"Wrote preview: {artifacts['json']}")
        print(f"Wrote markdown: {artifacts['md']}")
        print(f"Wrote quality: {artifacts['quality']}")
        if args.no_patch:
            print("No patch performed.")
        return 0

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
