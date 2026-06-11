import 'dart:convert';

import 'package:ez_english_app/services/word_definition_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WordDefinitionService.load();
  });

  test('Arabic normalisation strips marks and normalises alef variants', () {
    expect(
      WordDefinitionService.normaliseArabic('إِعْلَانــات آمنة'),
      'اعلانات امنة',
    );
  });

  test('temporary Arabic vocabulary prefers longest confident matches', () {
    final matches = WordDefinitionService.matchArabicTerms(
      'رأيت لوحات اعلانات وصورة سيارة',
    );

    final surfaces = matches.map((match) => match.surfaceText).toList();
    final headwords =
        matches.map((match) => match.entry.englishHeadword).toSet();

    expect(surfaces, contains('لوحات اعلانات'));
    expect(surfaces.where((surface) => surface == 'اعلانات'), isEmpty);
    expect(headwords, contains('billboards'));
    expect(headwords, contains('car'));
  });

  test('temporary Arabic vocabulary skips tiny common words safely', () {
    final matches = WordDefinitionService.matchArabicTerms('في على من');

    expect(matches, isEmpty);
  });

  test('temporary Arabic vocabulary finds matches in integrated lessons',
      () async {
    final lesson07 = await _lessonMatchSummary(
      'assets/courses/course_01/lesson_07/main_story/content.json',
    );
    final lesson10 = await _lessonMatchSummary(
      'assets/courses/course_01/lesson_10/main_story/content.json',
    );

    expect(lesson07.totalMatches, greaterThan(0));
    expect(lesson10.totalMatches, greaterThan(0));
    expect(lesson07.uniqueSurfaces.length, greaterThanOrEqualTo(5));
    expect(lesson10.uniqueSurfaces.length, greaterThanOrEqualTo(5));

    print(
      'CLICKABLE_VOCAB lesson_07 occurrences=${lesson07.totalMatches} '
      'unique=${lesson07.uniqueSurfaces.length} '
      'examples=${lesson07.examples.join(' | ')}',
    );
    print(
      'CLICKABLE_VOCAB lesson_10 occurrences=${lesson10.totalMatches} '
      'unique=${lesson10.uniqueSurfaces.length} '
      'examples=${lesson10.examples.join(' | ')}',
    );
  });
}

Future<
    ({
      int totalMatches,
      Set<String> uniqueSurfaces,
      List<String> examples,
    })> _lessonMatchSummary(String assetPath) async {
  final raw = await rootBundle.loadString(assetPath);
  final payload = jsonDecode(raw) as Map<String, dynamic>;
  final unique = <String>{};
  final examples = <String>[];
  var total = 0;

  for (final sentence in payload['sentences'] as List<dynamic>) {
    final line = sentence as Map<String, dynamic>;
    final arabic = line['arabic'] as String? ?? '';
    for (final match in WordDefinitionService.matchArabicTerms(arabic)) {
      total++;
      final label = '${match.surfaceText} -> ${match.entry.englishHeadword}';
      unique.add(label);
      if (examples.length < 8 && !examples.contains(label)) {
        examples.add(label);
      }
    }
  }

  return (
    totalMatches: total,
    uniqueSurfaces: unique,
    examples: examples,
  );
}
