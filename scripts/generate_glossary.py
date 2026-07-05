#!/usr/bin/env python3
"""Generate glossary entries for top content words.

Reads the unique words list and the existing glossary, then generates
new entries for words not yet in the glossary. Uses a template-based
approach for common word patterns.
"""

import json
import re
from pathlib import Path


# Common Arabic root patterns and their English meanings
ROOT_PATTERNS = {
    # From existing glossary
    'و ص ف': {'meaning': 'describing', 'words': ['وصف', 'وصفها', 'سأصف']},
    'ك ت ب': {'meaning': 'writing', 'words': ['كتب', 'كتاب', 'كاتب', 'مكتب']},
    'ك ل م': {'meaning': 'speech', 'words': ['كلمة', 'كلام', 'تكلم']},
    'ف ر د': {'meaning': 'individual', 'words': ['فرد', 'مفرد', 'مفردة']},
    'د ر س': {'meaning': 'studying', 'words': ['درس', 'درس', 'مدرسة']},
    'ج م ل': {'meaning': 'beauty', 'words': ['جميل', 'جمال', 'جميل']},
    'ك ب ر': {'meaning': 'bigness', 'words': ['كبير', 'كبر', 'أكبر']},
    'ص غ ر': {'meaning': 'smallness', 'words': ['صغير', 'صغر', 'أصغر']},
    'ح ج م': {'meaning': 'size', 'words': ['حجم', 'حجم']},
    'ل و ن': {'meaning': 'color', 'words': ['لون', 'ألوان', 'ملون']},
    'ب ي ض': {'meaning': 'whiteness', 'words': ['أبيض', 'بياض', 'بيضاء']},
    'س و د': {'meaning': 'blackness', 'words': ['أسود', 'سوداء', 'سود']},
    'ح م ر': {'meaning': 'redness', 'words': ['أحمر', 'حمرة', 'حمراء']},
    'ز ر ق': {'meaning': 'blueness', 'words': ['أزرق', 'زرقة', 'زرقاء']},
    'خ ض ر': {'meaning': 'greenness', 'words': ['أخضر', 'خضراء', 'خضار']},
    'ط و ل': {'meaning': 'length', 'words': ['طويل', 'طول', 'أطول']},
    'ق ص ر': {'meaning': 'shortness', 'words': ['قصير', 'قصر', 'أقصر']},
    'ص ف ح': {'meaning': 'page/surface', 'words': ['صفحة', 'صفح', 'تصفح']},
    'س أ ل': {'meaning': 'asking', 'words': ['سؤال', 'سأل', 'مسؤول']},
    # New roots for lesson 7 & 10
    'ع م ل': {'meaning': 'working', 'words': ['عمل', 'يعمل', 'عميل']},
    'ج م ع': {'meaning': 'gathering', 'words': ['جمع', 'مجتمع', 'جماعة']},
    'ت ع ل م': {'meaning': 'learning', 'words': ['تعلم', 'طالب', 'دراسة']},
    'ه ر ب': {'meaning': 'family', 'words': ['أسرة', '的家庭']},
    'ن ص ر': {'meaning': 'victory/help', 'words': ['نصر', 'نصر']},
    'ع ل م': {'meaning': 'knowledge', 'words': ['علم', 'عالم', 'معلوم']},
    'ش ك ل': {'meaning': 'form/shape', 'words': ['شكل', 'شكل']},
    'ب ن ي': {'meaning': 'building', 'words': ['بنى', 'ابن', 'ابنة']},
    'ج ل س': {'meaning': 'sitting', 'words': ['جلس', 'جلوس']},
    'ق ع د': {'meaning': 'sitting/staying', 'words': ['قعد', 'جالس']},
    'ذ ه ب': {'meaning': 'going', 'words': ['ذهب', 'ذهاب']},
    'ج أ ء': {'meaning': 'coming', 'words': ['جاء', 'مجيء']},
    'أ ك ل': {'meaning': 'eating', 'words': ['أكل', 'طعام']},
    'ش ر ب': {'meaning': 'drinking', 'words': ['شرب', 'شراب']},
    'ن ظ ر': {'meaning': 'looking', 'words': ['نظر', 'نظرة']},
    'س م ع': {'meaning': 'hearing', 'words': ['سمع', 'سماع']},
    'ك ل م': {'meaning': 'speaking', 'words': ['تكلم', 'كلام']},
    'ف ت ح': {'meaning': 'opening', 'words': ['فتح', 'مفتاح']},
    'غ ل ق': {'meaning': 'closing', 'words': ['غلق', 'مقفل']},
    'ب دأ': {'meaning': 'beginning', 'words': ['بدأ', 'بداية']},
    'خ لص': {'meaning': 'finishing', 'words': ['خلص', 'انتهى']},
    'ص و ر': {'meaning': 'picture', 'words': ['صورة', 'تصوير']},
    'ف ي د': {'meaning': 'benefit', 'words': ['فيديو', 'فيديوهات']},
    'ت و ص ل': {'meaning': 'connecting', 'words': ['تواصل', 'التواصل']},
    'إ ج م ا ع ي': {'meaning': 'social', 'words': ['اجتماعي', 'اجتماعية']},
    'ر س ا ل ة': {'meaning': 'message', 'words': ['رسالة', 'رسائل']},
    'م و ق ع': {'meaning': 'site/platform', 'words': ['موقع', 'مواقع']},
    'ش ا ئ ع': {'meaning': 'spreading', 'words': [' منتشر', 'انتشار']},
    'و ق ت': {'meaning': 'time', 'words': ['وقت', 'وقتاً']},
    'س ا ع ة': {'meaning': 'hour', 'words': ['ساعة', 'ساعات']},
    'ي و م': {'meaning': 'day', 'words': ['يوم', 'أيام', 'اليوم']},
    'ص ب ا ح': {'meaning': 'morning', 'words': ['صباح', 'صباحاً']},
    'ل ي ل': {'meaning': 'night', 'words': ['ليل', 'ليلاً', 'الليل']},
    'ش م س': {'meaning': 'sun', 'words': ['شمس', 'مشمس']},
    'ق م ر': {'meaning': 'moon', 'words': ['قمر', 'قمري']},
    'م ا ء': {'meaning': 'water', 'words': ['ماء', 'مياه']},
    'أ ر ض': {'meaning': 'earth/ground', 'words': ['أرض', 'أراضي']},
    'س م ا ء': {'meaning': 'sky', 'words': ['سماء', 'سماوات']},
    'ج ب ل': {'meaning': 'mountain', 'words': ['جبل', 'جبال']},
    'ب ح ر': {'meaning': 'sea', 'words': ['بحر', 'بحار']},
    'ن ه ر': {'meaning': 'river', 'words': ['نهر', 'أنهار']},
    'ش ج ر': {'meaning': 'tree', 'words': ['شجرة', 'شجر', 'أشجار']},
    'و ر د': {'meaning': 'rose/flower', 'words': ['وردة', 'ورود']},
    'ز ر ع': {'meaning': 'agriculture', 'words': ['زراعة', 'مزارع']},
    'د و ل ة': {'meaning': 'country/state', 'words': ['دولة', 'دول']},
    'ع ا ل م': {'meaning': 'world', 'words': ['عالم', 'عالمي']},
    'ب ش ر': {'meaning': 'human', 'words': ['بشر', 'إنسان']},
    'ر ج ل': {'meaning': 'man/foot', 'words': ['رجل', 'رجال']},
    'م ر أ ة': {'meaning': 'woman', 'words': ['امرأة', 'نساء']},
    'ط ف ل': {'meaning': 'child', 'words': ['طفل', 'أطفال']},
    'أ ب': {'meaning': 'father', 'words': ['أب', 'والد', 'أبي']},
    'أ م': {'meaning': 'mother', 'words': ['أم', 'والدة', 'أمي']},
    'أ خ': {'meaning': 'brother', 'words': ['أخ', 'إخوة', 'أخو']},
    'أ خ ت': {'meaning': 'sister', 'words': ['أخت', 'إخوة', 'أختي']},
    'ب ن': {'meaning': 'son/building', 'words': ['ابن', 'ابناء', 'بنت']},
    'ب ن ت': {'meaning': 'daughter', 'words': ['بنت', 'بنات']},
    'ع م': {'meaning': 'uncle', 'words': ['عم', 'عمي', 'أعمام']},
    'خ ا ل': {'meaning': 'maternal uncle', 'words': ['خال', 'خالي', 'خالات']},
    'ج د': {'meaning': 'grandfather', 'words': ['جد', 'جدي', 'أجداد']},
    'ج د ة': {'meaning': 'grandmother', 'words': ['جدة', 'جدتي', 'جدات']},
    'ز و ج': {'meaning': 'spouse', 'words': ['زوج', 'زوجة', 'زواج']},
    'ع ا يل ة': {'meaning': 'family', 'words': ['عائلة', 'أسرة']},
    'ق ر ي ب': {'meaning': 'relative', 'words': ['قريب', 'أقارب', 'قرابة']},
    'ص ح ب': {'meaning': 'friend/companion', 'words': ['صاحب', 'أصدقاء', 'صداقة']},
    'م ع ل م': {'meaning': 'teacher', 'words': ['معلم', 'معلمون', 'مدرسة']},
    'ط ا ل ب': {'meaning': 'student', 'words': ['طالب', 'طلاب', 'طالبة']},
    'ج ا م ع ة': {'meaning': 'university', 'words': ['جامعة', 'جامعات']},
    'م د ر س ة': {'meaning': 'school', 'words': ['مدرسة', 'مدارس']},
    'ع م ل': {'meaning': 'work', 'words': ['عمل', 'يعمل', 'عامل']},
    'م ه ن ة': {'meaning': 'profession', 'words': ['مهنة', 'مهن', 'مهنتها']},
    'م ه ن د س': {'meaning': 'engineer', 'words': ['مهندس', 'مهندسة']},
    'ط ب ي ب': {'meaning': 'doctor', 'words': ['طبيب', 'طبيبة', 'أطباء']},
    'م ح ا س ب': {'meaning': 'accountant', 'words': ['محاسب', 'محاسبة']},
    'ص ح ف ي': {'meaning': 'journalist', 'words': ['صحفي', 'صحفية']},
    'م ب ر م ج': {'meaning': 'programmer', 'words': ['مبرمج', 'برمجة']},
    'ر ج ل أ ع م ا ل': {'meaning': 'businessman', 'words': ['رجل أعمال']},
    'م ت ق ا ع د': {'meaning': 'retired', 'words': ['متقاعد', 'تقاعد']},
    'ط ب ا خ ة': {'meaning': 'cook', 'words': ['طباخة', 'طبخ']},
    'م ط ع م': {'meaning': 'restaurant', 'words': ['مطعم', 'مطاعم']},
    'م س ت ش ف ى': {'meaning': 'hospital', 'words': ['مستشفى', 'مستشفيات']},
    'ر ب ة ب ي ت': {'meaning': 'housewife', 'words': ['ربة بيت']},
    'م ت ز و ج': {'meaning': 'married', 'words': ['متزوج', 'متزوجة', 'زواج']},
    'ع ا ز ب': {'meaning': 'single', 'words': ['عازب', 'عازبة']},
    'م ت ع ل م': {'meaning': 'educated', 'words': ['متeducated', 'تعليم']},
    'ص غ ي ر': {'meaning': 'young/small', 'words': ['صغير', 'صغرى', 'صغيرة']},
    'ك ب ي ر': {'meaning': 'old/big', 'words': ['كبير', 'كبرى', 'كبيرة']},
    'ع ج و ز': {'meaning': 'elderly', 'words': ['عجوز', 'عجائز']},
    'ش ا ب': {'meaning': 'young man', 'words': ['شاب', 'شباب']},
    'ف ت ا ة': {'meaning': 'girl', 'words': ['فتاة', 'فتيات']},
    'و ل د': {'meaning': 'boy/son', 'words': ['ولد', 'ولدين', 'ولدان']},
    'ب ن ي ة': {'meaning': 'building', 'words': ['بناية', 'مباني']},
    'ش ا ئ ع': {'meaning': 'spreading', 'words': ['شائع', 'منتشر']},
    'ك ت ا ب': {'meaning': 'book', 'words': ['كتاب', 'كتب', 'كتبها']},
    'و ر ق': {'meaning': 'paper/leaf', 'words': ['ورق', 'أوراق']},
    'غ ل ا ف': {'meaning': 'cover', 'words': ['غلاف', 'اغلفة']},
    'ص و ر ة': {'meaning': 'picture', 'words': ['صورة', 'صور']},
    'م و ض و ع': {'meaning': 'topic', 'words': ['موضوع', 'مواضيع']},
    'م ق د م': {'meaning': 'presenter', 'words': ['مقدم', 'مقدمة']},
    'أ ل ف': {'meaning': 'author', 'words': ['مؤلف', 'تأليف']},
    'ع ل م': {'meaning': 'knowledge', 'words': ['علم', 'علوم', 'عالم']},
    'ب ح ث': {'meaning': 'research', 'words': ['بحث', 'بحوث']},
    'ن ش ر': {'meaning': 'publishing', 'words': ['نشر', 'ناشر']},
    'ط ب ع': {'meaning': 'printing', 'words': ['طبع', 'طابعة']},
    'ق ر ا ء ة': {'meaning': 'reading', 'words': ['قراءة', 'يقرأ']},
    'ك ت ا ب ة': {'meaning': 'writing', 'words': ['كتابة', 'يكتب']},
    'ل غ ة': {'meaning': 'language', 'words': ['لغة', 'لغات', 'اللغة']},
    'ت ر ج م ة': {'meaning': 'translation', 'words': ['ترجمة', 'ترجم']},
    'م ع ن ى': {'meaning': 'meaning', 'words': ['معنى', 'معنى', 'معنى']},
    'ح ك ي': {'meaning': 'story', 'words': ['حكاية', 'حكايات']},
    'ف ل م': {'meaning': 'movie', 'words': ['فيلم', 'أفلام']},
    'أ غ ن ي ة': {'meaning': 'song', 'words': ['أغنية', 'أغاني']},
    'م و س ي ق ى': {'meaning': 'music', 'words': ['موسيقى']},
    'ر ي ا ض ة': {'meaning': 'sport', 'words': ['رياضة', 'رياضات']},
    'ص ح ة': {'meaning': 'health', 'words': ['صحة', 'صحي']},
    'ط ع ا م': {'meaning': 'food', 'words': ['طعام', 'أكل']},
    'م ب ل غ': {'meaning': 'amount', 'words': ['مبلغ', 'مبالغ']},
    'ف ل س': {'meaning': 'money', 'words': ['فلس', 'أموال']},
    'س و ق': {'meaning': 'market', 'words': ['سوق', 'أسواق']},
    'م ع ر ف ة': {'meaning': 'knowledge', 'words': ['معرفة', 'معرفة']},
    'ت ج ر ب ة': {'meaning': 'experience', 'words': ['تجربة', 'تجارب']},
}


def load_existing_glossary():
    """Load existing glossary entries."""
    path = Path(__file__).parent.parent / 'assets' / 'arabic_glossary.json'
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    existing = set()
    for entry in data.get('entries', []):
        for form in entry.get('surface_forms', []):
            existing.add(form)
    return data, existing


def load_top_words():
    """Load the unique words list."""
    path = Path(__file__).parent.parent / 'reports' / 'unique_words.json'
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data['words']


def find_root(word):
    """Try to find the root for a word based on known patterns."""
    for root, info in ROOT_PATTERNS.items():
        if word in info['words']:
            return root, info['meaning']
    return None, None


def generate_entry(word, count, root, meaning):
    """Generate a glossary entry for a word."""
    # Determine part of speech based on patterns
    pos = 'noun'
    if word.endswith(('ة', 'ات', 'ين', 'ون')):
        pos = 'noun'
    elif word.startswith(('ي', 'ت', 'ا')):
        pos = 'verb'
    elif word.endswith(('ي', 'ية')):
        pos = 'adjective'
    
    return {
        'surface_forms': [word],
        'lemma': word,
        'root': root if root else '',
        'pattern': '',
        'part_of_speech': pos,
        'english_meaning': meaning if meaning else '',
        'short_definition': f'({count} occurrences in lessons)',
        'lesson_example_arabic': '',
        'lesson_example_english': '',
        'synonyms': [],
        'antonyms': [],
        'review_status': 'generated',
        'root_family': {
            'core_meaning': meaning if meaning else '',
            'explanation': '',
            'related_words': []
        }
    }


def main():
    glossary, existing_forms = load_existing_glossary()
    top_words = load_top_words()
    
    new_entries = []
    for word_info in top_words[:150]:  # Top 150 words
        word = word_info['word']
        count = word_info['count']
        
        # Skip if already in glossary
        if word in existing_forms:
            continue
        
        # Skip very short words
        if len(word) < 3:
            continue
        
        # Try to find root
        root, meaning = find_root(word)
        
        # Generate entry
        entry = generate_entry(word, count, root, meaning)
        new_entries.append(entry)
    
    # Add new entries to glossary
    glossary['entries'].extend(new_entries)
    
    # Save updated glossary
    output_path = Path(__file__).parent.parent / 'assets' / 'arabic_glossary.json'
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(glossary, f, ensure_ascii=False, indent=2)
    
    print(f"Added {len(new_entries)} new glossary entries")
    print(f"Total entries: {len(glossary['entries'])}")


if __name__ == '__main__':
    main()
