#!/usr/bin/env python3
"""Extract unique Arabic words from content.json files for glossary generation."""

import json
import re
import sys
from pathlib import Path
from collections import Counter

BLOCKED_WORDS = {
    'انا', 'انت', 'انتم', 'هو', 'هي', 'هم', 'هن', 'هذا', 'هذه', 'ذلك',
    'تلك', 'هنا', 'هناك', 'من', 'في', 'على', 'عن', 'الى', 'او', 'و',
    'ف', 'ثم', 'يا', 'ما', 'لا', 'لم', 'لن', 'ان', 'كان', 'كانت',
    'لكن', 'كل', 'قد', 'لقد', 'مع', 'بين', 'كما', 'اذا', 'الذي',
    'التي', 'الذين', 'اي', 'اين', 'ايضا', 'الان', 'الناس', 'اما',
    'بخير', 'بعض', 'بالي', 'جدا', 'شيء', 'صحيح', 'فقط', 'كيف',
    'لله', 'ماذا', 'نعم', 'والله', 'يعني', 'يوم', 'اليوم',
    'تم', 'هيه', 'اوه', 'طيب', 'يلا', 'خلينا',
}


def extract_arabic_words(text):
    words = re.split(r'[^\u0600-\u06FF]+', text)
    return [w for w in words if len(w) >= 2]


def normalize_arabic(word):
    word = re.sub(r'^ال', '', word)
    word = re.sub(r'(هم|هن|كما|كم|ها|ه|ي|نا|تم|تن)$', '', word)
    return word.strip()


def process_content_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    word_counter = Counter()
    for sentence in data.get('sentences', []):
        arabic = sentence.get('arabic', '')
        words = extract_arabic_words(arabic)
        for word in words:
            normalized = normalize_arabic(word)
            if normalized and len(normalized) >= 2:
                word_counter[normalized] += 1
    return word_counter


def main():
    base = Path(__file__).parent.parent / 'assets' / 'courses'
    content_files = sorted(base.glob('**/content.json'))
    
    all_words = Counter()
    for filepath in content_files:
        words = process_content_file(filepath)
        all_words.update(words)
    
    content_words = {
        word: count for word, count in all_words.items()
        if word not in BLOCKED_WORDS and len(word) >= 3
    }
    
    sorted_words = sorted(content_words.items(), key=lambda x: -x[1])
    
    output = Path(__file__).parent.parent / 'reports' / 'unique_words.json'
    output.parent.mkdir(exist_ok=True)
    with open(output, 'w', encoding='utf-8') as f:
        json.dump({
            'total_unique': len(sorted_words),
            'words': [{'word': w, 'count': c} for w, c in sorted_words],
        }, f, ensure_ascii=False, indent=2)
    
    print(f"Total unique content words: {len(sorted_words)}")
    print(f"Saved to {output}")


if __name__ == '__main__':
    main()
