#!/usr/bin/env python3
"""
Core Learner Pack Selector — pedagogical filter for word_definitions.json.

Report-only: never modifies assets/word_definitions.json or any Flutter UI.
Reads the dictionary and applies deterministic + pedagogical rules to classify
every entry as: auto_enrich_now, review_safe, review_sensitive,
redirect_required, keep_existing, or blocked.

Lane meanings:
  auto_enrich_now     — safe base-form learner vocabulary, OK to send to GPT
  review_safe         — needs human eyes before GPT (suspect-A1, B2+, low-value POS,
                        ambiguous tiny words, number words)
  review_sensitive    — content concern (violence/alcohol/insult/body/religion/
                        identity), do not auto-enrich
  redirect_required   — inflected form; should not get a standalone learner panel
                        — UI should redirect to the lemma instead
  keep_existing       — already has a rich learner_panel
  blocked             — bad/empty entries, transcript noise, proper nouns,
                        acronyms, brands, nationalities, demographic terms

Outputs:
  reports/word_panel_core_learner_pack_vN_selection.json
  reports/word_panel_core_learner_pack_vN_selection.md

Usage:
  python3 scripts/word_panel_core_learner_pack_selector.py
  python3 scripts/word_panel_core_learner_pack_selector.py --max 100 --output-version 2
  python3 scripts/word_panel_core_learner_pack_selector.py --pos verb --max 50
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
DICT_PATH = REPO_ROOT / "assets" / "word_definitions.json"
REPORTS = REPO_ROOT / "reports"

# ─── Pedagogical deny lists ──────────────────────────────────────────────────

VIOLENCE_WORDS = {
    "stab", "punch", "kill", "shoot", "slap", "strangle", "wound",
    "assault", "murder", "massacre", "bludgeon", "throttle", "maim",
    "torture", "execute", "lynching", "strangulation",
}

ALCOHOL_WORDS = {
    "wine", "beer", "whiskey", "whisky", "vodka", "rum", "gin", "bourbon",
    "champagne", "lager", "ale", "mead", "brandy", "tequila", "cider",
    "cocktail", "booze", "liquor",
}

INSULT_WORDS = {
    "idiot", "moron", "imbecile", "fool", "jerk", "bastard", "dimwit",
    "blockhead", "nitwit", "dunce",
}

BODY_FUNCTION_WORDS = {
    "fart", "burp", "vomit", "poop", "pee", "urinate", "defecate",
    "excrete", "sweat", "spit",
}

RELIGIOUS_SENSITIVE = {
    "god", "allah", "jesus", "bible", "quran", "koran", "prayer", "mosque",
    "church", "temple", "priest", "imam", "crusade", "jihad", "pilgrimage",
    "blasphemy",
    # v18.1: V18 200-word diagnostic surfaced "worship" reaching auto_enrich_now.
    # Religion-as-practice terms should route to review_sensitive, never auto.
    "worship", "pray", "preach", "sermon", "ritual", "sacred", "holy",
    "faith", "salvation", "scripture", "sin",
    # V20 hardening: these surfaced in GPT batch-500 as ordinary nouns even
    # though they are religion/sect/practice terms needing human review.
    "baptist", "hinduism", "islam", "taoist", "taoism", "vipashana",
    "vipassana", "zoroastrian", "zoroastrianism", "zerastrianisms",
}

TRANSCRIPT_NOISE = {
    # True filler / non-word / drill noise. These have no learner value and
    # should be `blocked`. Keep this list to genuinely useless tokens; do not
    # put useful informal contractions here.
    # v17.3: removed `gonna, wanna, gotta, kinda, sorta, dunno, ain't,
    # lemme, gimme, outta, lotta` — those are useful informal contractions
    # and now route to `review_safe` via INFORMAL_USEFUL_SLANG.
    "tink", "cajol", "caroac",
    "uh", "um", "hmm", "hm", "hmmm", "uhh", "ohh", "shh", "psst",
    "mhm", "ugh", "yep", "nope", "doin",
    "innit", "yo", "nah",
}

# v17.3: useful informal contractions / slang. These are *not* filler — an
# Arabic learner encountering "gonna" or "wanna" in real listening input
# benefits from a panel that explains "going to" / "want to" etc. But the
# UX shape (CEFR, MCQ, exact-sense Arabic) is uncertain and the register is
# informal-only. Route to `review_safe` so a human decides whether to enrich
# (with informal-register note) or mark `keep_existing` if the dictionary
# already has a rich panel. Never sent to GPT automatically. Never blocked.
INFORMAL_USEFUL_SLANG = {
    "gonna", "wanna", "gotta", "kinda", "sorta", "dunno", "ain't",
    "lemme", "gimme", "outta", "lotta",
}

# Demographic / identity / nationality / religion-as-identity terms.
# Not necessarily offensive — but the meanings are loaded and the panel
# format (definition + Arabic + main example) is the wrong UX for them.
IDENTITY_DEMOGRAPHIC_WORDS = {
    "american", "british", "english", "french", "german", "italian",
    "spanish", "russian", "chinese", "japanese", "korean", "indian",
    "pakistani", "egyptian", "arab", "arabic", "saudi", "syrian",
    "lebanese", "turkish", "iranian", "iraqi", "kurdish", "african",
    "asian", "european",
    # v17.2: additional nationality/demographic terms common in dictionaries.
    # These route to review_sensitive (identity_demographic), not to blocked —
    # a human reviewer decides whether to enrich them.
    "canadian", "mexican", "australian", "brazilian", "polish", "irish",
    "scottish", "welsh", "dutch", "swiss", "swedish", "norwegian", "finnish",
    "greek", "portuguese", "moroccan", "nigerian", "kenyan",
    "latino", "latina", "hispanic",
    "muslim", "christian", "jew", "jewish", "hindu", "buddhist",
    "catholic", "protestant", "atheist",
    "black", "white", "race", "racial", "ethnic", "ethnicity",
    "gay", "lesbian", "queer", "straight", "transgender", "trans",
    "bisexual",
    "male", "female",  # ambiguous — treat as identity-loaded for learner UI
    "disabled", "handicapped", "retarded",
}

SEXUAL_OR_BODY_WORDS = {
    "sex", "sexual", "sexy", "nude", "naked", "porn", "erotic",
    "penis", "vagina", "breast", "nipple", "butt", "buttocks",
    "anal", "oral", "orgasm",
}

VULGAR_WORDS = {
    "shit", "fuck", "damn", "hell", "ass", "asshole", "bitch",
    "crap", "piss", "dick", "cock", "pussy",
}

# Known brands and proper-noun-like commercial tokens.
BRAND_WORDS = {
    "coke", "pepsi", "nike", "adidas", "google", "facebook", "twitter",
    "instagram", "youtube", "tiktok", "amazon", "apple", "microsoft",
    "samsung", "iphone", "ipad", "android", "windows", "uber", "lyft",
    "spotify", "netflix",
    # V20 hardening: lower-cased brand/app keys in the dictionary can bypass
    # all-caps/acronym checks.
    "bmw", "suzuki", "skype",
}

PLACE_OR_PROPER_NAME_WORDS = {
    "alaska", "arabia", "boston", "columbia", "delhi", "manchester",
    "okinawa", "petersburg", "rajasthan", "texas", "varanasi",
}

# v18.1: irregular past / past-participle forms that the dictionary key may
# present without a `lemma` redirect. These must route to redirect_required
# so the UI sends users to the lemma instead of generating a standalone panel.
# Category list, not a per-word hack — the surface form check is below.
IRREGULAR_PAST_FORMS = {
    "strode", "stunk", "swum", "sprang", "sprung", "spat", "trod", "trodden",
    "shrunk", "shrunken", "stricken", "sworn", "slung", "slunk", "stung",
    "rung", "wrung", "clung", "flung", "fled", "fed", "led", "wept", "swept",
    "crept", "leapt", "knelt", "dealt", "knelt", "shorn", "smitten",
    "bound", "ground", "wound", "found",
}

# v18.1: non-word noise/nonce coinages that V18 leaked into auto_enrich_now.
# Keep tight; uncertain cases stay in review_safe via existing routes.
NON_WORD_NOISE = {
    "bragg", "krash", "unforce",
    # V20 hardening: batch-500 exposed misspellings/non-standard tokens that
    # had plausible POS/CEFR metadata but should never be GPT-approved.
    "ashir", "bumminable", "frazes", "jbar", "trimaris", "zidartha",
}

# v18.1: words with technically-valid dictionary entries but very low
# learner-pack value (archaic, low-frequency, niche slang). Route to
# review_safe — a human decides whether to enrich, not GPT.
LOW_VALUE_REVIEW = {
    "loll", "emote",
}

# Suspect-A1 list: words the dictionary may label A1 but which are clearly
# beyond A1 for an Arabic learner. These get routed to review_safe so a
# human (or a higher-tier model) decides the correct CEFR before GPT
# generates a panel.
SUSPECT_A1: set[str] = {
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
    "embassy", "campaign", "constitution", "republic", "monarchy",
    "ideology", "philosophy", "psychology", "sociology", "anatomy",
    "metaphor", "syntax", "lexicon", "fiscal", "monetary", "compound",
    "harness", "consequence",
}

# Ambiguous tiny tokens — short, high-frequency, multi-sense words where
# a single learner panel will mislead. Better as review_safe.
AMBIGUOUS_TINY_WORDS: set[str] = {
    "set", "run", "get", "let", "fit", "hit", "cut", "bit", "lot",
    "bat", "tap", "lap", "lip", "log", "dog", "cat",
    "saw", "see", "say", "had", "has", "did", "do",
    "by", "of", "an", "as", "is", "to", "at", "be", "or",
}

# Suspicious Arabic mappings already known from the v13 audit.
# These English words must be flagged review_safe so the Arabic
# rendering is checked manually before GPT enrichment.
SUSPECT_ARABIC_WORDS: set[str] = {
    "dial", "scooter", "boot", "orphan", "everyday", "exist",
    "depend", "flash",
}

NUMBER_WORDS = {
    "zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
    "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
    "sixteen", "seventeen", "eighteen", "nineteen", "twenty", "thirty",
    "forty", "fifty", "sixty", "seventy", "eighty", "ninety", "hundred",
    "thousand", "million", "billion",
}

# Known CEFR overrides — dictionary labels wrong for these.
# Any word in this set is likely mislabelled A1 in the dictionary.
CEFR_OVERRIDES: dict[str, str] = {
    "vilify": "C1",
    "ruff": "C1",
    "tack": "B2",
    "gland": "B2",
    "gong": "B2",
    "ruby": "B2",
    "cobra": "B2",
    "depot": "B1",
    "punish": "B1",
    "crime": "B1",
    "panic": "B1",
    "pity": "B1",
    "organ": "B1",
    "consume": "B1",
    "expose": "B1",
    "promote": "B1",
    "capture": "B1",
    "churn": "B1",
    "spoil": "B1",
    "frighten": "A2",
    "warn": "A2",
    "vote": "A2",
    "spread": "A2",
    "mention": "A2",
    "combine": "A2",
    "scan": "A2",
    "float": "A2",
    "spill": "A2",
    "applaud": "A2",
    "explore": "A2",
    "perform": "A2",
    "graduate": "A2",
    "sneeze": "A2",
    "hobby": "A2",
    "guest": "A2",
    "diary": "A2",
    "favor": "A2",
    "field": "A2",
    "medal": "A2",
    "label": "A2",
    "coast": "A2",
    "cloth": "A2",
    "chore": "A2",
    "cheek": "A2",
    "brake": "A2",
    "angle": "A2",
    "globe": "A2",
    "herd": "A2",
    "lime": "A2",
    "pile": "A2",
    "tail": "A2",
    "tick": "A2",
    "host": "A2",
    "gear": "A2",
    "suit": "A2",
    "peach": "A2",
    "belly": "A2",
    "boxer": "A2",
    "goose": "A2",
    "raft": "A2",
    "pinch": "A2",
    "cheat": "A2",
}

# POS values that should not be auto-enriched.
SKIP_POS = {
    "pronoun", "preposition", "conjunction", "interjection", "other",
    "proper noun", "proper_noun", "informal",
}

POS_ORDER = {"verb": 0, "noun": 1, "adjective": 2, "adverb": 3}
CEFR_ORDER = {"A1": 0, "A2": 1, "B1": 2, "B2": 3, "C1": 4, "C2": 5}


# ─── v18.1: dictionary-aware helpers ─────────────────────────────────────────
# Populated by select_candidates() before lane classification runs.
DICTIONARY_WORDS: set[str] = set()


def _verb_entry_exists(word: str) -> bool:
    """True if `word` exists in the loaded dictionary as a verb candidate."""
    return word in DICTIONARY_WORDS


def looks_like_third_person_s_inflection(word: str, entry: dict[str, Any]) -> bool:
    """v18.1 — dictionary-aware 3rd-person -s/-es detection.

    Returns True if `word` looks like the 3rd-person singular of a base verb
    that already exists in the dictionary. This catches the V18 leak set:
    slips→slip, argues→argue, resists→resist, analyzes→analyze,
    concocts→concoct, concludes→conclude, allocates→allocate.

    Category-level rule; never a per-word list.
    """
    pos = (entry.get("pos") or "").lower()
    if pos != "verb":
        return False
    w = word.lower()
    if len(w) < 4:
        return False
    if not w.endswith("s"):
        return False
    # Try common base candidates and require a *verb* dictionary entry.
    candidates: list[str] = []
    if w.endswith("ies") and len(w) >= 5:
        candidates.append(w[:-3] + "y")  # tries → try
    if w.endswith("es") and len(w) >= 4:
        candidates.append(w[:-2])        # argues → argue
        candidates.append(w[:-1])        # analyzes → analyze
    if w.endswith("s") and not w.endswith("ss") and len(w) >= 4:
        candidates.append(w[:-1])        # slips → slip
    for base in candidates:
        if base == w:
            continue
        if base in DICTIONARY_WORDS:
            return True
    return False


# ─── Classification helpers ──────────────────────────────────────────────────

def actual_cefr(word: str, entry: dict[str, Any]) -> str | None:
    return CEFR_OVERRIDES.get(word) or entry.get("cefr")


def cefr_rank(word: str, entry: dict[str, Any]) -> int:
    cefr = actual_cefr(word, entry)
    if not cefr:
        return 99
    return CEFR_ORDER.get(cefr.upper(), 99)


def is_proper_noun(word: str, entry: dict[str, Any]) -> bool:
    pos = entry.get("pos", "")
    definition = (entry.get("definition") or "").lower()
    if word in PLACE_OR_PROPER_NAME_WORDS:
        return True
    if pos in {"proper noun", "proper_noun"}:
        return True
    place_markers = (
        "a large city", "a major city", "a holy city", "the largest state",
        "a large state", "a group of islands", "a large region",
        "a poetic or historical name", "also a university name",
    )
    if any(marker in definition for marker in place_markers):
        return True
    if "language spoken in" in definition:
        return True
    if pos == "other" and any(
        phrase in definition
        for phrase in ("a common", "a male", "a female", "a girl's", "a boy's", "this is a", "is a name", "given name", "first name")
    ):
        return True
    if "name" in definition and pos in {"noun", "other", ""}:
        # Only flag if definition is very short (just a name description)
        if len(definition) < 50:
            return True
    return False


def is_bad_entry(word: str, entry: dict[str, Any]) -> bool:
    definition = (entry.get("definition") or "").lower()
    arabic = (entry.get("arabic") or "")
    pos = entry.get("pos")
    if not pos:
        return True
    if "not a standard english word" in definition:
        return True
    if "not standard english" in definition:
        return True
    if "not a common english word" in definition:
        return True
    if "not a complete english word" in definition:
        return True
    if "does not appear to be a standard english word" in definition:
        return True
    if "may be a proper name or misspelling" in definition:
        return True
    if "may be a misspelling" in definition:
        return True
    if "did you mean" in definition:
        return True
    if len(definition.strip()) < 6:
        return True
    if arabic == "غير موجودة":
        return True
    return False


def is_archaic_or_obsolete(word: str, entry: dict[str, Any]) -> bool:
    """v18.1: definitions explicitly marked archaic/obsolete/old-english.

    Category-level rule. Catches `triest` ("An old English form meaning
    'you try' (archaic, rarely used today).") and similar without a per-word
    list. Routes to review_safe — never auto-enrich, never block.
    """
    definition = (entry.get("definition") or "").lower()
    if not definition:
        return False
    markers = (
        "archaic", "old english", "obsolete", "rarely used today",
        "no longer used", "old form of",
    )
    return any(m in definition for m in markers)


def is_inflected_form(word: str, entry: dict[str, Any]) -> bool:
    lemma = entry.get("lemma")
    if lemma and lemma != word:
        return True
    # v18.1: irregular past/past-participle forms (strode, stunk, ...).
    if word.lower() in IRREGULAR_PAST_FORMS:
        return True
    # v18.1: dictionary-aware 3rd-person -s/-es check (slips, argues,
    # resists, analyzes, concocts, concludes, allocates, ...).
    if looks_like_third_person_s_inflection(word, entry):
        return True
    definition = (entry.get("definition") or "").lower().strip()
    pos = entry.get("pos")
    for prefix in (
        "past tense of", "past form of", "present form of",
        "third person singular of", "the present form of",
        "the past form of", "the past tense of", "past participle of",
    ):
        if definition.startswith(prefix):
            return True
    if "third person singular" in definition:
        return True
    if "in the past" in definition and pos == "verb":
        return True
    # If the entry's own forms dict lists this word as the third-person form,
    # the entry key IS the inflected form, not the base.
    forms = entry.get("forms") or {}
    if word.endswith("s") and word in (forms.get("third_s"), forms.get("present_s")):
        return True
    # Definition starts with a capitalised verb ending in -s → likely third-person form
    # e.g. "Puts things..." for "puts", "Asks someone..." for "begs"
    if pos == "verb" and word.endswith("s") and len(word) > 3:
        first_word = definition.split()[0] if definition.split() else ""
        if first_word.endswith(("s", "es")) and len(first_word) >= 3:
            return True
    if pos == "verb" and word.endswith(("ed", "ing")) and len(word) > 4:
        return True
    if definition.startswith("more than one "):
        return True
    return False


def is_acronym_or_all_caps(word: str) -> bool:
    return len(word) <= 4 and word.upper() == word and not word[0].islower()


def content_concern(word: str, entry: dict[str, Any]) -> str | None:
    if word in VIOLENCE_WORDS:
        return "violence"
    if word in ALCOHOL_WORDS:
        return "alcohol"
    if word in INSULT_WORDS:
        return "insult"
    if word in BODY_FUNCTION_WORDS:
        return "body_function"
    if word in RELIGIOUS_SENSITIVE:
        return "religious_sensitive"
    if word in SEXUAL_OR_BODY_WORDS:
        return "sexual_body"
    if word in VULGAR_WORDS:
        return "vulgar"
    if word in IDENTITY_DEMOGRAPHIC_WORDS:
        return "identity_demographic"
    return None


def is_brand_or_commercial(word: str) -> bool:
    return word in BRAND_WORDS


def is_suspect_a1(word: str, entry: dict[str, Any]) -> bool:
    if word in SUSPECT_A1:
        return True
    cefr_dict = (entry.get("cefr") or "").upper()
    # Multi-syllable abstract noun labeled A1 by the dictionary is almost
    # always wrong. Cheap proxy: long word with Latin suffix.
    if cefr_dict == "A1" and len(word) >= 9 and word.endswith(
        ("tion", "sion", "ity", "ment", "ness", "ology", "ography", "graphy")
    ):
        return True
    return False


def is_ambiguous_tiny(word: str) -> bool:
    if word in AMBIGUOUS_TINY_WORDS:
        return True
    return False


def is_suspect_arabic(word: str) -> bool:
    return word in SUSPECT_ARABIC_WORDS


def is_transcript_noise(word: str) -> bool:
    if word in TRANSCRIPT_NOISE:
        return True
    # Short non-alphabetic or unusual tokens
    if len(word) <= 2 and word.isalpha():
        return True
    if any(c.isdigit() for c in word):
        return True
    return False


def is_informal_useful_slang(word: str) -> bool:
    """v17.3: useful informal contractions that should land in review_safe,
    not blocked. Curated list only; never sent to GPT automatically."""
    return word in INFORMAL_USEFUL_SLANG


def is_number_word(word: str) -> bool:
    return word in NUMBER_WORDS


def is_low_value_pos(word: str, entry: dict[str, Any]) -> bool:
    pos = (entry.get("pos") or "").lower()
    return pos in SKIP_POS


def has_rich_learner_panel(entry: dict[str, Any]) -> bool:
    lp = entry.get("learner_panel")
    if not isinstance(lp, dict):
        return False
    # A panel with just a redirect or a very short grammar section is not "rich"
    schema = lp.get("schema_version", "")
    if "redirect" in schema:
        return False  # redirect panels are thin, may need enrichment
    # A panel is rich if it has at least examples or forms
    has_examples = bool(lp.get("examples"))
    has_forms = bool(lp.get("forms"))
    has_grammar_note = bool((lp.get("grammar") or {}).get("usage_note"))
    return has_examples or has_forms or has_grammar_note


# ─── Lane assignment ─────────────────────────────────────────────────────────

def assign_lane(word: str, entry: dict[str, Any]) -> tuple[str, str]:
    """Return (lane, reason).

    v17.3 ordering principles:
      1. Hard structural rejects (bad/missing/inflected/acronym/proper-noun/brand)
         must come before any sensitivity / slang / CEFR check.
      2. Existing rich `learner_panel` (curated by a human or a previous batch)
         beats any noise/slang/sensitivity heuristic — never override curated
         data because the headword happens to look like slang.
      3. Sensitive content lands in `review_sensitive`, not `blocked` — a
         human decides whether to enrich.
      4. Useful slang / borderline / ambiguous / suspect-CEFR / B2+ go to
         `review_safe` — never auto-enriched, never silently blocked.
      5. True filler/noise/acronyms/brands/proper-nouns go to `blocked`.
      6. Unknown shape (no rule matched) falls through to `auto_enrich_now`
         only when the entry has POS, valid CEFR, valid definition, and no
         lemma redirect. Anything weirder above was already routed.
    """

    # 1. Hard structural rejects — must run first so a malformed entry is
    #    never inspected for slang/CEFR/sensitivity (avoids crashes).
    if is_bad_entry(word, entry):
        return "blocked", "bad entry (definition missing or flagged)"

    if is_acronym_or_all_caps(word):
        return "blocked", "acronym or all-caps token"

    if is_proper_noun(word, entry):
        return "blocked", "proper noun or name"

    if is_brand_or_commercial(word):
        return "blocked", "brand or commercial proper noun"

    if is_inflected_form(word, entry):
        return "redirect_required", "inflected form — UI should redirect to lemma"

    # v18.1: non-word noise / nonce coinages (bragg, krash, unforce).
    # Must come before the curated-rich-panel check; these never deserve
    # an auto-enriched panel even if a panel exists.
    if word.lower() in NON_WORD_NOISE:
        return "blocked", "non-word noise or nonce coinage (v18.1 block)"

    # 2. Honor curated rich panels before any noise/slang/sensitivity check.
    #    A slang or filler word that already has a rich learner_panel was
    #    curated deliberately; do not stomp it.
    if has_rich_learner_panel(entry):
        return "keep_existing", "already has a rich learner_panel"

    # 3. True filler / transcript noise → blocked.
    if is_transcript_noise(word):
        return "blocked", "transcript noise or drill token"

    # 4. Useful informal slang/contractions → review_safe (never blocked).
    if is_informal_useful_slang(word):
        return "review_safe", "useful informal contraction — register/CEFR uncertain, human decides"

    # 5. Low-value POS (pronoun/preposition/conjunction/interjection/other).
    if is_low_value_pos(word, entry):
        return "review_safe", f"POS '{entry.get('pos')}' not suitable for full learner panel"

    # 6. Content sensitivity (identity / religion / sex / vulgar / violence /
    #    alcohol / insult / body-function) → review_sensitive, not blocked.
    concern = content_concern(word, entry)
    if concern:
        return "review_sensitive", f"content concern: {concern}"

    # 7. Pedagogically tricky but normal vocabulary → review_safe.
    if is_number_word(word):
        return "review_safe", "number word — near-zero MCQ value"

    if is_ambiguous_tiny(word):
        return "review_safe", "ambiguous tiny / high-frequency token — multi-sense risk"

    if is_suspect_a1(word, entry):
        return "review_safe", "suspect-A1 — dictionary CEFR likely too low for learner UI"

    if is_suspect_arabic(word):
        return "review_safe", "known suspicious Arabic mapping — manual check before GPT"

    cefr_actual = actual_cefr(word, entry)
    cefr_level = cefr_rank(word, entry)

    # Very rare/advanced words
    if cefr_level >= CEFR_ORDER.get("C1", 4):
        return "review_safe", f"actual CEFR is {cefr_actual or 'unknown'} — too advanced for first pack"

    # B2 words are borderline — review_safe
    if cefr_level == CEFR_ORDER.get("B2", 3):
        return "review_safe", f"actual CEFR is B2 — lower priority for first pack"

    # 8. Unknown-shape safety net. Anything still without a CEFR or POS
    #    falls back to review_safe rather than auto_enrich_now — when in
    #    doubt, route to a human.
    if not cefr_actual or not (entry.get("pos") or "").strip():
        return "review_safe", "no actual CEFR / no POS — defer to human review"

    # 9. v18.1: low-learner-value words (loll, emote, archaic/jargon)
    #    → review_safe. Keep curated list small and category-led.
    if word.lower() in LOW_VALUE_REVIEW:
        return "review_safe", "low_learner_value — archaic/niche; reviewer decides"

    # 10. v18.1: explicitly archaic/obsolete entries (definition-driven, no
    #     per-word list) → review_safe. Catches triest, hath, doth, etc.
    if is_archaic_or_obsolete(word, entry):
        return "review_safe", "archaic_or_obsolete — definition marked archaic/old form"

    return "auto_enrich_now", "safe base-form learner vocabulary"


# ─── Priority assignment ─────────────────────────────────────────────────────

def assign_priority(word: str, entry: dict[str, Any], lane: str) -> str:
    if lane not in {"auto_enrich_now"}:
        return "low"
    cefr_actual = actual_cefr(word, entry) or ""
    pos = entry.get("pos", "")
    definition_len = len(entry.get("definition") or "")
    if cefr_actual.upper() == "A1" and pos in {"verb", "noun"}:
        return "high"
    if cefr_actual.upper() in {"A1", "A2"}:
        return "medium"
    return "medium"


def mcq_suitable(word: str, entry: dict[str, Any], lane: str) -> bool:
    if lane in {"blocked", "review_sensitive"}:
        return False
    if lane == "keep_existing":
        return True  # already enriched, MCQ builder can use it
    pos = entry.get("pos", "")
    if pos in {"verb", "noun", "adjective", "adverb"}:
        return True
    return False


# ─── Why useful ──────────────────────────────────────────────────────────────

def why_useful(word: str, entry: dict[str, Any]) -> str:
    pos = entry.get("pos", "")
    cefr = actual_cefr(word, entry) or "?"
    definition = (entry.get("definition") or "").strip()
    first_sentence = definition.split(".")[0].rstrip() if definition else ""
    return f"{cefr} {pos}. {first_sentence}."


# ─── Main selection ──────────────────────────────────────────────────────────

def select_candidates(
    data: dict[str, Any],
    pos_filter: str | None,
    max_count: int,
    skip_keep_existing: bool,
) -> list[dict[str, Any]]:
    # v18.1: populate the module-level dictionary lookup that
    # looks_like_third_person_s_inflection() consults. Done once before any
    # classification so 3rd-person -s words can be redirected to their lemma.
    DICTIONARY_WORDS.clear()
    DICTIONARY_WORDS.update(k.lower() for k in data.keys() if isinstance(k, str))

    results = []

    for word, entry in data.items():
        if not isinstance(entry, dict):
            continue
        if len(word) < 2:
            continue
        if not word.isalpha():
            continue

        if pos_filter and entry.get("pos") != pos_filter:
            continue

        lane, reason = assign_lane(word, entry)

        if skip_keep_existing and lane == "keep_existing":
            continue

        priority = assign_priority(word, entry, lane)
        cefr_dict = entry.get("cefr")
        cefr_actual = actual_cefr(word, entry)

        results.append({
            "word": word,
            "pos": entry.get("pos"),
            "cefr_dictionary": cefr_dict,
            "cefr_actual": cefr_actual,
            "definition": entry.get("definition"),
            "arabic": entry.get("arabic"),
            "why_useful": why_useful(word, entry),
            "risk_lane": lane,
            "priority": priority,
            "has_learner_panel": has_rich_learner_panel(entry),
            "mcq_suitable": mcq_suitable(word, entry, lane),
            "concern": reason if lane not in {"auto_enrich_now", "keep_existing"} else None,
        })

    # Sort: auto_enrich_now first, then by CEFR, then POS, then word length
    lane_order = {
        "auto_enrich_now": 0,
        "keep_existing": 1,
        "review_safe": 2,
        "redirect_required": 3,
        "review_sensitive": 4,
        "blocked": 5,
    }
    results.sort(key=lambda r: (
        lane_order.get(r["risk_lane"], 9),
        CEFR_ORDER.get((r.get("cefr_actual") or "").upper(), 99),
        POS_ORDER.get(r.get("pos") or "", 9),
        len(r["word"]),
        r["word"],
    ))

    return results[:max_count] if max_count > 0 else results


# ─── Output ──────────────────────────────────────────────────────────────────

def write_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def write_md(path: Path, results: list[dict[str, Any]], version: int) -> None:
    from collections import Counter
    counts = Counter(r["risk_lane"] for r in results)

    lines = [
        f"# Core Learner Pack v{version} — Selector Output",
        f"Generated by: word_panel_core_learner_pack_selector.py",
        "",
        "## Summary",
        "",
        f"| Lane | Count |",
        f"|------|-------|",
    ]
    for lane in ["auto_enrich_now", "review_safe", "redirect_required", "review_sensitive", "keep_existing", "blocked"]:
        lines.append(f"| `{lane}` | {counts.get(lane, 0)} |")
    lines += [
        "",
        "## auto_enrich_now words",
        "",
        "| Word | POS | CEFR actual | Why useful |",
        "|------|-----|-------------|------------|",
    ]
    for r in results:
        if r["risk_lane"] == "auto_enrich_now":
            lines.append(
                f"| `{r['word']}` | {r.get('pos') or '-'} | {r.get('cefr_actual') or '-'} | {r.get('why_useful', '')[:80]} |"
            )
    lines += [
        "",
        "## review_safe words",
        "",
        "| Word | POS | Concern |",
        "|------|-----|---------|",
    ]
    for r in results:
        if r["risk_lane"] == "review_safe":
            lines.append(f"| `{r['word']}` | {r.get('pos') or '-'} | {r.get('concern') or ''} |")
    lines += [
        "",
        "## review_sensitive words",
        "",
        "| Word | POS | Concern |",
        "|------|-----|---------|",
    ]
    for r in results:
        if r["risk_lane"] == "review_sensitive":
            lines.append(f"| `{r['word']}` | {r.get('pos') or '-'} | {r.get('concern') or ''} |")
    lines += [
        "",
        "## Constraints",
        "",
        "- assets/word_definitions.json was not modified",
        "- Flutter UI was not modified",
        "- Course 09 was not touched",
        "- Firebase/auth was not touched",
    ]
    path.write_text("\n".join(lines) + "\n")


# ─── CLI ──────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Pedagogical selector for Core Learner Pack enrichment batches."
    )
    parser.add_argument(
        "--max", type=int, default=200,
        help="Maximum number of words to include in output (0 = all). Default: 200."
    )
    parser.add_argument(
        "--pos", type=str, default=None,
        help="Filter to a specific POS: verb, noun, adjective, adverb."
    )
    parser.add_argument(
        "--output-version", type=int, default=2,
        help="Output file version number (used in filename). Default: 2 (v1 is reserved for the manually curated pack)."
    )
    parser.add_argument(
        "--skip-keep-existing", action="store_true",
        help="Omit entries that already have a rich learner_panel."
    )
    parser.add_argument(
        "--auto-only", action="store_true",
        help="Output only auto_enrich_now entries."
    )
    parser.add_argument(
        "--strict-preflight", action="store_true",
        help="v18.1: when set, every emitted auto_enrich_now word must pass "
             "a re-check (lane==auto_enrich_now, lemma matches, not inflected, "
             "not proper noun/brand/noise/sensitive). Violators are dropped "
             "with a console warning. Use with --auto-only for production GPT runs."
    )
    args = parser.parse_args()

    if not DICT_PATH.exists():
        print(f"ERROR: dictionary not found at {DICT_PATH}")
        return 1

    print(f"Loading dictionary from {DICT_PATH} ...")
    data = json.loads(DICT_PATH.read_text())
    print(f"Loaded {len(data)} entries.")

    results = select_candidates(
        data,
        pos_filter=args.pos,
        max_count=args.max,
        skip_keep_existing=args.skip_keep_existing,
    )

    if args.auto_only:
        results = [r for r in results if r["risk_lane"] == "auto_enrich_now"]

    # v18.1: strict preflight — re-verify every emitted auto_enrich_now row.
    # Drops anything that slipped through, prints a console warning per drop.
    # Category-level filter; uses existing classifier predicates only.
    if args.strict_preflight:
        clean: list[dict[str, Any]] = []
        dropped: list[tuple[str, str]] = []
        for r in results:
            w = r["word"]
            entry = data.get(w) or {}
            reasons: list[str] = []
            if r["risk_lane"] != "auto_enrich_now":
                reasons.append(f"lane={r['risk_lane']}")
            lemma = entry.get("lemma")
            if lemma and lemma != w:
                reasons.append(f"lemma_redirect→{lemma}")
            if is_bad_entry(w, entry):
                reasons.append("bad_entry")
            if is_inflected_form(w, entry):
                reasons.append("inflected")
            if is_proper_noun(w, entry):
                reasons.append("proper_noun")
            if is_brand_or_commercial(w):
                reasons.append("brand")
            if is_acronym_or_all_caps(w):
                reasons.append("acronym")
            if w.lower() in NON_WORD_NOISE:
                reasons.append("non_word_noise")
            if content_concern(w, entry):
                reasons.append(f"sensitive:{content_concern(w, entry)}")
            if reasons:
                dropped.append((w, ",".join(reasons)))
            else:
                clean.append(r)
        if dropped:
            print(f"strict-preflight: dropped {len(dropped)} candidate(s):")
            for w, reason in dropped:
                print(f"  - {w}: {reason}")
        results = clean

    v = args.output_version
    json_path = REPORTS / f"word_panel_core_learner_pack_v{v}_selection.json"
    md_path = REPORTS / f"word_panel_core_learner_pack_v{v}_selection.md"

    from collections import Counter
    counts = Counter(r["risk_lane"] for r in results)
    payload = {
        "name": f"Core Learner Pack v{v}",
        "generated_by": "word_panel_core_learner_pack_selector.py",
        "summary": {
            "total": len(results),
            "auto_enrich_now": counts.get("auto_enrich_now", 0),
            "review_safe": counts.get("review_safe", 0),
            "redirect_required": counts.get("redirect_required", 0),
            "review_sensitive": counts.get("review_sensitive", 0),
            "keep_existing": counts.get("keep_existing", 0),
            "blocked": counts.get("blocked", 0),
        },
        "words": results,
    }

    REPORTS.mkdir(parents=True, exist_ok=True)
    write_json(json_path, payload)
    write_md(md_path, results, v)

    print(f"Wrote JSON: {json_path}")
    print(f"Wrote MD:   {md_path}")
    print()
    print("Summary:")
    for lane, count in sorted(counts.items(), key=lambda x: x[0]):
        print(f"  {lane:25s} {count}")

    # Print first 10 auto_enrich_now for quick inspection
    auto = [r for r in results if r["risk_lane"] == "auto_enrich_now"][:10]
    if auto:
        print()
        print("First 10 auto_enrich_now:")
        for r in auto:
            print(f"  {r['word']:20s} {r.get('pos'):10s} {r.get('cefr_actual') or '?':4s}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
