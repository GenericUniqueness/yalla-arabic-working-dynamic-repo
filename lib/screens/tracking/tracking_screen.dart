import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../providers/course_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/app_usage_time_service.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  String _formatTime(int seconds) {
    if (seconds < 3600) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return '${m}m ${s}s';
    }
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final courses = context.watch<CourseProvider>().courses;
    final l10n = context.l10n;
    return Consumer2<ProgressProvider, AppUsageTimeService>(
      builder: (context, progress, appUsage, _) {
        final hasActivity =
            progress.totalSeconds > 0 || appUsage.totalSeconds > 0;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.progress,
                    // The bottom navigation owns the compact label; this
                    // screen title follows the selected app language.
                    style: TextStyle(
                        color: th.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),

                if (!hasActivity) ...[
                  // First-day empty state
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: th.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.headphones_rounded,
                            color: th.accent.withValues(alpha: 0.6), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          l10n.progressEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: th.textSub, fontSize: 15, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  // ── Daily goal ring + streak badge (separated) ──────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Daily goal ring — shows today's listening fraction only
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress.dailyGoalSeconds > 0
                                  ? (progress.todaySeconds /
                                          progress.dailyGoalSeconds)
                                      .clamp(0.0, 1.0)
                                  : 0,
                              strokeWidth: 8,
                              backgroundColor:
                                  th.textSub.withValues(alpha: 0.15),
                              color: th.accent,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _formatTime(progress.todaySeconds),
                                  style: TextStyle(
                                      color: th.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(l10n.listeningToday,
                                    style: TextStyle(
                                        color: th.textSub, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Stats column with streak as a separate visual badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: progress.currentStreak > 0
                                    ? th.accent.withValues(alpha: 0.15)
                                    : th.textSub.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_fire_department,
                                      color: progress.currentStreak > 0
                                          ? th.accent
                                          : th.textSub,
                                      size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.dayStreak(progress.currentStreak),
                                    style: TextStyle(
                                        color: progress.currentStreak > 0
                                            ? th.accent
                                            : th.textSub,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(l10n.todayAppTime,
                                _formatTime(appUsage.todaySeconds), th),
                            const SizedBox(height: 10),
                            _InfoRow(l10n.todayListeningTime,
                                _formatTime(progress.todaySeconds), th),
                            const SizedBox(height: 10),
                            _InfoRow(l10n.totalAppTime,
                                _formatTime(appUsage.totalSeconds), th),
                            const SizedBox(height: 10),
                            _InfoRow(l10n.totalListeningTime,
                                _formatTime(progress.totalSeconds), th),
                            const SizedBox(height: 10),
                            _InfoRow(l10n.dailyGoal,
                                _formatTime(progress.dailyGoalSeconds), th),
                            const SizedBox(height: 10),
                            _InfoRow(l10n.bestStreak,
                                l10n.days(progress.bestStreak), th),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Course progress ─────────────────────────────────────────
                Text(l10n.courses,
                    style: TextStyle(
                        color: th.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                ...courses.map((course) {
                  final listened = progress.getCourseSeconds(course.id);
                  final total = course.totalDurationSeconds;

                  final lessonKeys = course.lessons
                      .map((l) => '${course.id}_${l.id}')
                      .toList();
                  final completedLessons = lessonKeys
                      .where((k) => (progress.getLessonProgress(k)) > 0.5)
                      .length;
                  final completionFraction = course.lessons.isEmpty
                      ? 0.0
                      : completedLessons / course.lessons.length;

                  final levelColor = AppColors.cefrColor(course.level);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: th.card,
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  course.lessons.isEmpty
                                      ? l10n.noLessonsYet
                                      : course.title,
                                  style: TextStyle(
                                      color: th.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: levelColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(course.level,
                                  style: TextStyle(
                                      color: levelColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: completionFraction,
                            minHeight: 5,
                            backgroundColor: th.textSub.withValues(alpha: 0.15),
                            color: th.accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.lessonsDone(
                                completedLessons,
                                course.lessons.length,
                              ),
                              style: TextStyle(color: th.textSub, fontSize: 12),
                            ),
                            Text(
                              total > 0
                                  ? '${_formatTime(listened)} / ${_formatTime(total)}'
                                  : _formatTime(listened),
                              style: TextStyle(
                                  color: listened > 0 ? th.accent : th.textSub,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final AppTheme th;
  const _InfoRow(this.label, this.value, this.th);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: th.textSub, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: th.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
