import 'package:flutter_test/flutter_test.dart';

import 'package:ez_english_app/providers/favourites_provider.dart';

void main() {
  test('SavedWordRef stores lightweight review metadata', () {
    final savedAt = DateTime.utc(2026, 5, 17, 12);
    final ref = SavedWordRef(
      key: 'run',
      clickedForm: 'running',
      lessonKey: '1_1_main_story',
      savedAt: savedAt,
    );

    final json = ref.toJson();
    expect(json['key'], 'run');
    expect(json['clickedForm'], 'running');
    expect(json['lessonKey'], '1_1_main_story');
    expect(json['savedAt'], savedAt.toIso8601String());

    final restored = SavedWordRef.fromJson(json);

    expect(restored, isNotNull);
    expect(restored!.key, 'run');
    expect(restored.clickedForm, 'running');
    expect(restored.lessonKey, '1_1_main_story');
    expect(restored.savedAt, savedAt);
  });
}
