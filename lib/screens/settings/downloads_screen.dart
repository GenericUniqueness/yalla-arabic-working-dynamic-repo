import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../models/course.dart';
import '../../providers/course_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/theme_provider.dart';
import '../lessons/player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final dl = context.watch<DownloadProvider>();
    final courses = context.watch<CourseProvider>().courses;
    final downloaded = dl.downloadedLessons;
    final l10n = context.l10n;

    // Group by course
    final Map<int, List<Lesson>> byCourse = {};
    for (final item in downloaded) {
      byCourse.putIfAbsent(item.course.id, () => []).add(item.lesson);
    }

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        backgroundColor: th.bg,
        leading: BackButton(color: th.textPrimary),
        title: Text(l10n.myDownloads,
            style: TextStyle(color: th.textPrimary, fontSize: 16)),
      ),
      body: Column(
        children: [
          // ── Storage summary ────────────────────────────────────────────────
          FutureBuilder<int>(
            future: dl.totalCacheBytes(),
            builder: (context, snap) {
              final size = snap.data ?? 0;
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: th.card, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Icon(Icons.storage_rounded, color: th.accent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            size > 0
                                ? l10n.cachedOnDevice(_formatBytes(size))
                                : l10n.noDownloadsYet,
                            style: TextStyle(
                                color: th.textPrimary,
                                fontWeight: FontWeight.w600),
                          ),
                          if (size > 0)
                            Text(l10n.downloadsWorkOffline,
                                style:
                                    TextStyle(color: th.textSub, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (size > 0)
                      TextButton(
                        onPressed: () => _confirmDeleteAll(context, th, dl),
                        child: Text(l10n.deleteAll,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13)),
                      ),
                  ],
                ),
              );
            },
          ),

          // ── Downloaded list ────────────────────────────────────────────────
          if (downloaded.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_for_offline_outlined,
                        color: th.textSub.withValues(alpha: 0.35), size: 64),
                    const SizedBox(height: 16),
                    Text(l10n.noDownloadsYet,
                        style: TextStyle(color: th.textSub, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(l10n.downloadEmptyHint,
                        style: TextStyle(
                            color: th.textSub.withValues(alpha: 0.6),
                            fontSize: 13,
                            height: 1.5),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  for (final courseId in byCourse.keys) ...[
                    _CourseSection(
                      th: th,
                      course: courses.firstWhere((c) => c.id == courseId),
                      lessons: byCourse[courseId]!,
                      dl: dl,
                    ),
                    const SizedBox(height: 12),
                  ]
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDeleteAll(
      BuildContext context, AppTheme th, DownloadProvider dl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: th.card,
        title: Text(AppStrings.of(context, listen: false).deleteAllDownloads,
            style: TextStyle(color: th.textPrimary)),
        content: Text(
            AppStrings.of(context, listen: false).deleteAllDownloadsBody,
            style: TextStyle(color: th.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.of(context, listen: false).cancel,
                style: TextStyle(color: th.textSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              dl.deleteAll();
              Navigator.pop(context);
            },
            child: Text(AppStrings.of(context, listen: false).deleteAll,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _CourseSection extends StatelessWidget {
  final AppTheme th;
  final Course course;
  final List<Lesson> lessons;
  final DownloadProvider dl;

  const _CourseSection({
    required this.th,
    required this.course,
    required this.lessons,
    required this.dl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration:
                    BoxDecoration(color: th.accent, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '${course.id}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                course.title,
                style: TextStyle(
                    color: th.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
              color: th.card, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: lessons.asMap().entries.map((e) {
              final isLast = e.key == lessons.length - 1;
              return _LessonDownloadTile(
                th: th,
                lesson: e.value,
                dl: dl,
                showDivider: !isLast,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _LessonDownloadTile extends StatelessWidget {
  final AppTheme th;
  final Lesson lesson;
  final DownloadProvider dl;
  final bool showDivider;

  const _LessonDownloadTile({
    required this.th,
    required this.lesson,
    required this.dl,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cachedTypes = lesson.availableTypes
        .where((t) => dl.isPathCached(DownloadProvider.audioPath(
            lesson.courseId, lesson.id, t.assetFolder)))
        .toList();
    final typeLabel = cachedTypes.map((t) => t.displayName).join(', ');

    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: th.accent.withValues(alpha: 0.15),
            child:
                Icon(Icons.download_done_rounded, color: th.accent, size: 18),
          ),
          title: Text(
            l10n.lessonTitle(lesson.id, lesson.title),
            style: TextStyle(
                color: th.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14),
          ),
          subtitle: Text(typeLabel,
              style: TextStyle(color: th.textSub, fontSize: 12)),
          trailing: IconButton(
            icon:
                Icon(Icons.delete_outline_rounded, color: th.textSub, size: 22),
            onPressed: () => _confirmDelete(context),
          ),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => PlayerScreen(lesson: lesson))),
        ),
        if (showDivider)
          Divider(
              height: 1, color: th.textSub.withValues(alpha: 0.1), indent: 16),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: th.card,
        title: Text(
            AppStrings.of(context, listen: false)
                .deleteLessonQuestion(lesson.id),
            style: TextStyle(color: th.textPrimary)),
        content: Text(
            AppStrings.of(context, listen: false)
                .removeOfflineAudio(lesson.title),
            style: TextStyle(color: th.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.of(context, listen: false).cancel,
                style: TextStyle(color: th.textSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              context.read<DownloadProvider>().deleteLesson(lesson);
              Navigator.pop(context);
            },
            child: Text(AppStrings.of(context, listen: false).delete,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
