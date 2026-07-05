#!/usr/bin/env python3
"""Fix sentence breaking in content.json files.

Splits multi-sentence entries at natural boundaries so each
entry contains at most one sentence. Uses English punctuation as
the primary split signal, then aligns Arabic text proportionally.
"""

import json
import re
import sys
from pathlib import Path


def count_words(text: str) -> int:
    """Count meaningful words in a string."""
    words = text.split()
    return max(len([w for w in words if w.strip()]), 1)


def split_on_english_punctuation(text: str) -> list[str]:
    """Split English text at sentence boundaries (. ! ?).
    
    Keeps the delimiter with the preceding sentence.
    """
    if not text.strip():
        return [text]
    
    # Split on period/exclamation/question followed by space and capital letter
    parts = re.split(r'(?<=[.!?])\s+(?=[A-Z\u0600-\u06FF])', text.strip())
    parts = [p for p in parts if p.strip()]
    return parts if parts else [text]


def split_on_arabic_punctuation(text: str) -> list[str]:
    """Split Arabic text at sentence boundaries (؟ ! .)."""
    if not text.strip():
        return [text]
    
    parts = re.split(r'(?<=[؟!.])\s+', text.strip())
    parts = [p for p in parts if p.strip()]
    return parts if parts else [text]


def distribute_arabic_text(arabic: str, num_parts: int) -> list[str]:
    """Distribute Arabic text across N parts proportionally by word count.
    
    Used when Arabic text can't be split on punctuation but needs to
    align with English sentence splits.
    """
    if not arabic.strip() or num_parts <= 1:
        return [arabic]
    
    words = arabic.split()
    total = len(words)
    if total == 0:
        return [''] * num_parts
    
    words_per_part = total / num_parts
    parts = []
    
    for i in range(num_parts):
        start_idx = int(i * words_per_part)
        end_idx = int((i + 1) * words_per_part)
        part_words = words[start_idx:end_idx]
        parts.append(' '.join(part_words))
    
    return parts


def smart_split(arabic: str, english: str) -> tuple[list[str], list[str]]:
    """Smartly split Arabic and English text into aligned sentences.
    
    Strategy:
    1. Split English on punctuation (most reliable)
    2. Try splitting Arabic on punctuation
    3. If counts match, use both
    4. If counts differ, distribute the shorter one proportionally
    """
    en_parts = split_on_english_punctuation(english)
    ar_parts = split_on_arabic_punctuation(arabic)
    
    en_count = len(en_parts)
    ar_count = len(ar_parts)
    
    # If both have 1 part, no split needed
    if en_count <= 1 and ar_count <= 1:
        return [arabic], [english]
    
    # If counts match, use both
    if en_count == ar_count:
        return ar_parts, en_parts
    
    # If Arabic has more parts, use Arabic and distribute English
    if ar_count > en_count:
        # Try splitting English on commas too
        en_parts_loose = re.split(r'(?<=[,;])\s+', english.strip())
        en_parts_loose = [p for p in en_parts_loose if p.strip()]
        if len(en_parts_loose) == ar_count:
            return ar_parts, en_parts_loose
        # Pad English with empty strings
        while len(en_parts) < ar_count:
            en_parts.append('')
        return ar_parts, en_parts[:ar_count]
    
    # If English has more parts, use English and distribute Arabic
    # First try splitting Arabic on commas/semicolons
    ar_parts_loose = re.split(r'(?<=[،,;])\s+', arabic.strip())
    ar_parts_loose = [p for p in ar_parts_loose if p.strip()]
    if len(ar_parts_loose) == en_count:
        return ar_parts_loose, en_parts
    
    # Distribute Arabic text proportionally across English splits
    ar_distributed = distribute_arabic_text(arabic, en_count)
    return ar_distributed, en_parts


def split_entry(entry: dict) -> list[dict]:
    """Split a single content.json entry into multiple entries."""
    arabic = entry.get('arabic', '')
    english = entry.get('english', '')
    start = entry.get('start_time', 0.0)
    end = entry.get('end_time', start + 1.0)
    
    ar_parts, en_parts = smart_split(arabic, english)
    max_parts = max(len(ar_parts), len(en_parts))
    
    if max_parts <= 1:
        return [entry]
    
    total_duration = end - start
    total_words = count_words(arabic) + count_words(english)
    
    new_entries = []
    current_time = start
    
    for i in range(max_parts):
        ar_part = ar_parts[i] if i < len(ar_parts) else ''
        en_part = en_parts[i] if i < len(en_parts) else ''
        
        part_words = count_words(ar_part) + count_words(en_part)
        proportion = part_words / total_words if total_words > 0 else 1.0 / max_parts
        part_duration = max(total_duration * proportion, 0.3)  # Minimum 0.3s per part
        
        part_end = current_time + part_duration
        if i == max_parts - 1:
            part_end = end
        
        part_end = min(part_end, end)
        
        new_entry = {
            'id': 0,  # Renumbered later
            'english': en_part,
            'arabic': ar_part,
            'start_time': round(current_time, 3),
            'end_time': round(part_end, 3),
            'source_caption_type': entry.get('source_caption_type', 'human_ar_manual'),
            'english_alignment_confidence': entry.get('english_alignment_confidence', 'high'),
        }
        new_entries.append(new_entry)
        current_time = part_end
    
    return new_entries


def process_content_file(filepath: Path) -> dict:
    """Process a content.json file and split multi-sentence entries."""
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    original_count = len(data.get('sentences', []))
    new_sentences = []
    
    for entry in data.get('sentences', []):
        split = split_entry(entry)
        new_sentences.extend(split)
    
    # Renumber IDs
    for i, entry in enumerate(new_sentences):
        entry['id'] = i
    
    data['sentences'] = new_sentences
    new_count = len(new_sentences)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    return {
        'file': filepath.name,
        'original': original_count,
        'new': new_count,
        'added': new_count - original_count,
    }


def main():
    base = Path(__file__).parent.parent / 'assets' / 'courses'
    content_files = sorted(base.glob('**/content.json'))
    
    if not content_files:
        print("No content.json files found!")
        sys.exit(1)
    
    print("Fixing sentence breaking in content.json files...\n")
    
    for filepath in content_files:
        stats = process_content_file(filepath)
        print(f"  {stats['file']}: {stats['original']} -> {stats['new']} entries (+{stats['added']})")
    
    print("\nDone!")


if __name__ == '__main__':
    main()
