import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../models/course.dart';
import '../../providers/download_provider.dart';
import '../../providers/favourites_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/theme_provider.dart';
import 'player_screen.dart';

class LessonListScreen extends StatelessWidget {
  final Course course;
  const LessonListScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final favs = context.watch<FavouritesProvider>();
    final progress = context.watch<ProgressProvider>();
    final dl = context.watch<DownloadProvider>();
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        backgroundColor: th.bg,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: th.accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${course.id}',
                style: TextStyle(
                    color: th.bg, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(course.title,
                  style: TextStyle(color: th.textPrimary, fontSize: 16),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        leading: BackButton(color: th.textPrimary),
      ),
      body: course.lessons.isEmpty
          ? Center(
              child:
                  Text(l10n.noLessonsYet, style: TextStyle(color: th.textSub)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: course.lessons.length,
              itemBuilder: (context, index) {
                final lesson = course.lessons[index];
                final lessonKey = '${course.id}_${lesson.id}';
                final prog = progress.getLessonProgress(lessonKey);
                final isFav = favs.isFavourite(course.id, lesson.id);
                final isDownloaded = dl.isLessonDownloaded(lesson);
                final isDownloading = dl.isLessonDownloading(lesson);
                final dlProgress = dl.lessonProgress(lesson);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: th.card, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        leading: CircleAvatar(
                          backgroundColor: th.accent.withValues(alpha: 0.2),
                          child: Icon(Icons.play_arrow_rounded,
                              color: th.accent, size: 20),
                        ),
                        title: Text(
                          l10n.lessonTitle(lesson.id, lesson.title),
                          style: TextStyle(
                              color: th.textPrimary,
                              fontWeight: FontWeight.w500),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _DownloadButton(
                              th: th,
                              lesson: lesson,
                              isDownloaded: isDownloaded,
                              isDownloading: isDownloading,
                              progress: dlProgress,
                              onDownload: () => dl.downloadLesson(lesson),
                              onDelete: () =>
                                  _confirmDelete(context, th, lesson, dl),
                            ),
                            IconButton(
                              icon: Icon(
                                isFav
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: isFav ? th.accent : th.textSub,
                              ),
                              onPressed: () => context
                                  .read<FavouritesProvider>()
                                  .toggle(course.id, lesson.id),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PlayerScreen(lesson: lesson))),
                      ),
                      if (prog > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: prog,
                              minHeight: 3,
                              backgroundColor:
                                  th.textSub.withValues(alpha: 0.15),
                              color: prog >= 0.9 ? Colors.green : th.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppTheme th, Lesson lesson, DownloadProvider dl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: th.card,
        title: Text(
            AppStrings.of(context, listen: false).deleteDownloadQuestion,
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
              dl.deleteLesson(lesson);
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

class _DownloadButton extends StatelessWidget {
  final AppTheme th;
  final Lesson lesson;
  final bool isDownloaded;
  final bool isDownloading;
  final double progress;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _DownloadButton({
    required this.th,
    required this.lesson,
    required this.isDownloaded,
    required this.isDownloading,
    required this.progress,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (isDownloading) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 2,
              color: th.accent,
            ),
          ),
        ),
      );
    }
    if (isDownloaded) {
      return IconButton(
        icon: Icon(Icons.download_done_rounded, color: th.accent, size: 22),
        tooltip: l10n.downloadedTapToDelete,
        onPressed: onDelete,
      );
    }
    return IconButton(
      icon: Icon(Icons.download_rounded, color: th.textSub, size: 22),
      tooltip: l10n.downloadForOffline,
      onPressed: onDownload,
    );
  }
}
