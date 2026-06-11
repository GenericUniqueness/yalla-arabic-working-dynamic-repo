import 'package:ez_english_app/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('roundedMinutes avoids second-level analytics precision', () {
    expect(AnalyticsService.roundedMinutes(0), 0);
    expect(AnalyticsService.roundedMinutes(1), 1);
    expect(AnalyticsService.roundedMinutes(89), 1);
    expect(AnalyticsService.roundedMinutes(90), 2);
  });

  test('scoreBucket returns coarse score ranges', () {
    expect(AnalyticsService.scoreBucket(0, 0), 'no_score');
    expect(AnalyticsService.scoreBucket(3, 10), '0_39');
    expect(AnalyticsService.scoreBucket(5, 10), '40_59');
    expect(AnalyticsService.scoreBucket(7, 10), '60_79');
    expect(AnalyticsService.scoreBucket(9, 10), '80_100');
  });

  test('disabled collection blocks custom events in process', () async {
    await AnalyticsService.setCollectionEnabled(false);
    expect(
      await AnalyticsService.logListeningMilestone('10m'),
      isFalse,
    );
    await AnalyticsService.setCollectionEnabled(true);
  });
}
