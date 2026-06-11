import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../models/course.dart';
import '../../models/quiz_models.dart';
import '../../models/review_question.dart';
import '../../providers/audio_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/favourites_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/quiz_storage_service.dart';
import '../lessons/lesson_list_screen.dart';
import '../lessons/player_screen.dart';
import '../tracking/tracking_screen.dart';
import '../settings/settings_screen.dart';
import '../../services/review_question_builder.dart';
import '../../services/word_definition_service.dart';
import '../review/vocab_review_screen.dart';

// Ordered CEFR filter options shown in the quiz card.
const _cefrFilterOptions = ['All', 'A1', 'A2', 'B1', 'B2'];

// CEFR badge colour — delegates to single source of truth in AppColors
Color _cefrColor(String? level) => AppColors.cefrColor(level);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final l10n = context.l10n;
    final screens = [
      const _CourseListScreen(),
      const _ReviewScreen(),
      const TrackingScreen(),
      const SettingsScreen(),
    ];

    final scaffold = Scaffold(
      backgroundColor: th.bg,
      body: screens[_selectedIndex],
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected ? th.accent : th.textSub,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              );
            }),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          backgroundColor: th.playerBar,
          indicatorColor: th.accent.withValues(alpha: 0.18),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_rounded, color: th.textSub),
              selectedIcon: Icon(Icons.home_rounded, color: th.accent),
              label: l10n.home,
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_rounded, color: th.textSub),
              selectedIcon: Icon(Icons.auto_stories_rounded, color: th.accent),
              label: l10n.review,
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded, color: th.textSub),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: th.accent),
              label: l10n.progress,
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_rounded, color: th.textSub),
              selectedIcon: Icon(Icons.settings_rounded, color: th.accent),
              label: l10n.settings,
            ),
          ],
        ),
      ),
    );

    return scaffold;
  }
}

// ── Course List ───────────────────────────────────────────────────────────────

class _CourseListScreen extends StatelessWidget {
  const _CourseListScreen();

  // Delegates to AppColors.cefr — single source of truth for CEFR colours
  static Color _levelColor(String level) => AppColors.cefrColor(level);

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final audio = context.watch<AudioProvider>();
    final l10n = context.l10n;

    final nowPlayingItem = audio.currentQueueItem;
    Lesson? nowPlayingLesson;
    if (nowPlayingItem != null) {
      for (final course in context.read<CourseProvider>().courses) {
        if (course.id == nowPlayingItem.courseId) {
          for (final l in course.lessons) {
            if (l.id == nowPlayingItem.lessonId) {
              nowPlayingLesson = l;
              break;
            }
          }
          break;
        }
      }
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Image.asset(
                  'assets/branding/yallaarabic_logo_padded.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(width: 10),
                l10n.isArabic
                    ? Text(
                        l10n.appTitle,
                        style: TextStyle(
                          color: th.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Yalla',
                              style: TextStyle(
                                color: th.accent,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: ' Arabic',
                              style: TextStyle(
                                color: th.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                const Spacer(),
              ],
            ),
          ),
          if (nowPlayingLesson != null && nowPlayingItem != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                color: th.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: th.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  // Play/pause has its own tap target — avoids nested gesture conflict
                  IconButton(
                    icon: Icon(
                      audio.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      color: th.accent,
                      size: 34,
                    ),
                    tooltip: audio.isPlaying ? l10n.pause : l10n.play,
                    onPressed: () =>
                        context.read<AudioProvider>().togglePlayPause(),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        final typeFolder = nowPlayingItem.typeFolder;
                        LessonType? currentType;
                        try {
                          currentType = nowPlayingLesson!.availableTypes
                              .firstWhere((t) => t.assetFolder == typeFolder);
                        } catch (_) {
                          currentType = null;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(
                              lesson: nowPlayingLesson!,
                              initialType: currentType,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.nowPlaying,
                              style: TextStyle(
                                color: th.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              nowPlayingItem.title,
                              style: TextStyle(
                                color: th.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: th.textSub,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeHeadline,
                  style: TextStyle(
                    color: th.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Consumer<CourseProvider>(
              builder: (context, courseProvider, _) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: courseProvider.courses.length,
                itemBuilder: (context, index) {
                  final course = courseProvider.courses[index];
                  final levelColor = _levelColor(course.level);
                  final isComingSoon = course.lessons.isEmpty;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: th.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: th.accent.withValues(alpha: 0.2),
                        child: Text(
                          '${course.id}',
                          style: TextStyle(
                            color: th.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        isComingSoon ? l10n.noLessonsYet : course.title,
                        style: TextStyle(
                          color: th.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          isComingSoon
                              ? l10n.lessonsPlaceholder
                              : course.description,
                          style: TextStyle(color: th.textSub, fontSize: 13),
                        ),
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: levelColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.levelLabel(course.level),
                              style: TextStyle(
                                color: levelColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isComingSoon) ...[
                            const SizedBox(height: 6),
                            Text(
                              l10n.comingSoon,
                              style: TextStyle(
                                color: th.textSub,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonListScreen(course: course),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review Tab ────────────────────────────────────────────────────────────────

class _ReviewScreen extends StatelessWidget {
  const _ReviewScreen();

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final favs = context.watch<FavouritesProvider>();
    final courses = context.watch<CourseProvider>().courses;
    final l10n = context.l10n;

    final favourited = <({Course course, Lesson lesson})>[];
    for (final course in courses) {
      for (final lesson in course.lessons) {
        if (favs.isFavourite(course.id, lesson.id)) {
          favourited.add((course: course, lesson: lesson));
        }
      }
    }
    final savedWords = favs.savedWords;
    final isEmpty = favourited.isEmpty && savedWords.isEmpty;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.reviewTitle,
                  style: TextStyle(
                    color: th.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.reviewSubtitle,
                  style: TextStyle(color: th.textSub, fontSize: 13),
                ),
              ],
            ),
          ),
          if (isEmpty)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _RandomQuizCard(th: th),
                  _SavedBatchesCard(th: th),
                  const SizedBox(height: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bookmark_add_outlined,
                        color: th.textSub.withValues(alpha: 0.4),
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.nothingSavedYet,
                        style: TextStyle(color: th.textSub, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          l10n.reviewSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: th.textSub.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _RandomQuizCard(th: th),
                  _SavedBatchesCard(th: th),
                  _PracticeCard(th: th, savedWords: savedWords),
                  if (savedWords.isNotEmpty) ...[
                    _ReviewSectionHeader(
                      th: th,
                      icon: Icons.bookmark_rounded,
                      title: l10n.savedArabicWords,
                      count: savedWords.length,
                    ),
                    const SizedBox(height: 10),
                    ...savedWords.map(
                      (word) => _SavedWordTile(th: th, word: word),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (favourited.isNotEmpty) ...[
                    _ReviewSectionHeader(
                      th: th,
                      icon: Icons.star_rounded,
                      title: l10n.savedLessons,
                      count: favourited.length,
                    ),
                    const SizedBox(height: 10),
                    ...favourited.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: th.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: th.textSub.withValues(alpha: 0.08),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: th.accent.withValues(alpha: 0.16),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: th.accent,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            item.lesson.title,
                            style: TextStyle(
                              color: th.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            item.course.title,
                            style: TextStyle(color: th.textSub, fontSize: 12),
                          ),
                          trailing: IconButton(
                            tooltip: l10n.removeSavedLesson,
                            icon: Icon(
                              Icons.star_rounded,
                              color: th.accent,
                              size: 20,
                            ),
                            onPressed: () => context
                                .read<FavouritesProvider>()
                                .toggle(item.course.id, item.lesson.id),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(lesson: item.lesson),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Launch helpers ────────────────────────────────────────────────────────────

Future<void> _launchReview(
  BuildContext context,
  List<SavedWordRef> savedWords,
) async {
  await WordDefinitionService.load();
  if (!context.mounted) return;
  final l10n = AppStrings.of(context, listen: false);
  final session = ReviewQuestionBuilder.build(
    savedWords: savedWords,
    mode: ReviewMode.arabic,
  );
  if (session.isEmpty) {
    final th = context.read<ThemeProvider>().current;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.couldNotBuildSavedWordsQuiz),
        backgroundColor: th.accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VocabReviewScreen(session: session, isRandom: false),
    ),
  );
}

Future<void> _launchRandomReview(
  BuildContext context,
  int count,
  String? cefrFilter,
) async {
  await WordDefinitionService.load();
  if (!context.mounted) return;

  final batches = await QuizStorageService.loadBatches();
  final usedWordKeys = <String>{};
  for (final b in batches) {
    if (cefrFilter == null ||
        b.cefrFilter == null ||
        b.cefrFilter == cefrFilter) {
      usedWordKeys.addAll(b.wordKeys);
    }
  }

  if (!context.mounted) return;
  final l10n = AppStrings.of(context, listen: false);
  final session = ReviewQuestionBuilder.buildRandom(
    mode: ReviewMode.arabic,
    maxQuestions: count,
    cefrFilter: cefrFilter,
    usedWordKeys: usedWordKeys.isEmpty ? null : usedWordKeys,
  );
  if (session.isEmpty) {
    final th = context.read<ThemeProvider>().current;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.couldNotBuildQuiz),
        backgroundColor: th.accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  if (session.fillNote != null && context.mounted) {
    final th = context.read<ThemeProvider>().current;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(session.fillNote!),
        backgroundColor: th.accent.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VocabReviewScreen(session: session, isRandom: true),
    ),
  );
}

Future<void> _launchBatchReview(
  BuildContext context,
  QuizBatch batch,
) async {
  await WordDefinitionService.load();
  if (!context.mounted) return;
  final l10n = AppStrings.of(context, listen: false);
  final session = ReviewQuestionBuilder.buildFromKeys(
    wordKeys: batch.wordKeys,
    mode: ReviewMode.arabic,
    cefrFilter: batch.cefrFilter,
  );
  if (session.isEmpty) {
    final th = context.read<ThemeProvider>().current;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.couldNotRebuildBatch),
        backgroundColor: th.accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VocabReviewScreen(
        session: session,
        batchId: batch.id,
        batchName: batch.name,
        isRandom: true,
      ),
    ),
  );
}

class _RandomQuizCard extends StatefulWidget {
  final AppTheme th;
  const _RandomQuizCard({required this.th});

  @override
  State<_RandomQuizCard> createState() => _RandomQuizCardState();
}

class _RandomQuizCardState extends State<_RandomQuizCard> {
  double _count = 10;
  String _cefrFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final th = widget.th;
    final l10n = context.l10n;
    final count = _count.round();
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: th.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: th.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.translate_rounded, color: th.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.randomReviewTitle,
                style: TextStyle(
                  color: th.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.randomReviewSubtitle,
            style: TextStyle(color: th.textSub, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                l10n.numberOfQuestions,
                style: TextStyle(
                  color: th.textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: th.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: th.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: th.accent,
              inactiveTrackColor: th.accent.withValues(alpha: 0.2),
              thumbColor: th.accent,
              overlayColor: th.accent.withValues(alpha: 0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _count,
              min: 5,
              max: 100,
              divisions: 19,
              onChanged: (v) => setState(() => _count = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5', style: TextStyle(color: th.textSub, fontSize: 11)),
                Text('100', style: TextStyle(color: th.textSub, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.chooseLevel,
            style: TextStyle(
              color: th.textSub,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _cefrFilterOptions.map((opt) {
              final selected = _cefrFilter == opt;
              final color = opt == 'All' ? th.accent : _cefrColor(opt);
              final isLast = opt == _cefrFilterOptions.last;
              return Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: isLast ? 0 : 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _cefrFilter = opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? color : color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              selected ? color : color.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        opt == 'All' ? l10n.allLevelsShort : opt,
                        style: TextStyle(
                          color: selected ? Colors.white : color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _QuizButton(
              th: th,
              label: l10n.startPractice,
              icon: Icons.play_arrow_rounded,
              onTap: () => _launchRandomReview(
                context,
                count,
                _cefrFilter == 'All' ? null : _cefrFilter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Saved Batches Card ────────────────────────────────────────────────────────

class _SavedBatchesCard extends StatefulWidget {
  final AppTheme th;
  const _SavedBatchesCard({required this.th});

  @override
  State<_SavedBatchesCard> createState() => _SavedBatchesCardState();
}

class _SavedBatchesCardState extends State<_SavedBatchesCard> {
  List<QuizBatch>? _batches;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final batches = await QuizStorageService.loadBatches();
    if (mounted) setState(() => _batches = batches);
  }

  Future<void> _delete(String id) async {
    await QuizStorageService.deleteBatch(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final th = widget.th;
    final batches = _batches;
    final l10n = context.l10n;

    if (batches == null || batches.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: th.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: th.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              final opening = !_expanded;
              setState(() => _expanded = opening);
              if (opening) _load(); // refresh list whenever user opens the card
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.collections_bookmark_rounded,
                    color: th.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.savedBatches,
                      style: TextStyle(
                        color: th.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: th.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${batches.length}',
                      style: TextStyle(
                        color: th.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: th.textSub,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: batches
                    .map(
                      (batch) => _BatchTile(
                        th: th,
                        batch: batch,
                        onPlay: () => _launchBatchReview(context, batch),
                        onDelete: () => _delete(batch.id),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  final AppTheme th;
  final QuizBatch batch;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _BatchTile({
    required this.th,
    required this.batch,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        batch.cefrFilter != null ? _cefrColor(batch.cefrFilter) : th.accent;
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: th.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: th.textSub.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          if (batch.cefrFilter != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text(
                batch.cefrFilter!,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.name,
                  style: TextStyle(
                    color: th.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${l10n.wordCount(batch.wordKeys.length)} · ${l10n.arabicToEnglish}',
                  style: TextStyle(color: th.textSub, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.practiceThisBatch,
            icon: Icon(Icons.play_arrow_rounded, color: th.accent, size: 22),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: onPlay,
          ),
          IconButton(
            tooltip: l10n.deleteBatch,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 18,
            ),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: th.card,
                  title: Text(
                    l10n.deleteBatchQuestion,
                    style: TextStyle(color: th.textPrimary),
                  ),
                  content: Text(
                    l10n.cannotBeUndone,
                    style: TextStyle(color: th.textSub),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        l10n.cancel,
                        style: TextStyle(color: th.textSub),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                      child: Text(
                        l10n.delete,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Saved-Words Quiz Card ─────────────────────────────────────────────────────

class _PracticeCard extends StatelessWidget {
  final AppTheme th;
  final List<SavedWordRef> savedWords;

  const _PracticeCard({required this.th, required this.savedWords});

  @override
  Widget build(BuildContext context) {
    final hasEnough = savedWords.isNotEmpty;
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: th.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: th.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz_rounded, color: th.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.vocabularyQuiz,
                style: TextStyle(
                  color: th.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasEnough)
            Text(
              l10n.reviewSubtitle,
              style: TextStyle(color: th.textSub, fontSize: 13),
            )
          else ...[
            Text(
              l10n.reviewSavedWords,
              style: TextStyle(color: th.textSub, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _QuizButton(
                th: th,
                label: l10n.startPractice,
                icon: Icons.translate_rounded,
                onTap: () => _launchReview(context, savedWords),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _QuizButton extends StatelessWidget {
  final AppTheme th;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuizButton({
    required this.th,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: th.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: th.accent, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: th.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewSectionHeader extends StatelessWidget {
  final AppTheme th;
  final IconData icon;
  final String title;
  final int count;

  const _ReviewSectionHeader({
    required this.th,
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: th.accent, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: th.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: th.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: th.accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedWordTile extends StatelessWidget {
  final AppTheme th;
  final SavedWordRef word;

  const _SavedWordTile({required this.th, required this.word});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final clicked = word.clickedForm;
    final subtitle = clicked != null && clicked.toLowerCase() != word.key
        ? '${l10n.savedArabicForm}: "$clicked"'
        : l10n.arabicLookupComingSoon;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: th.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: th.textSub.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: th.accent.withValues(alpha: 0.16),
          child: Icon(Icons.translate_rounded, color: th.accent, size: 19),
        ),
        title: Text(
          word.key,
          style: TextStyle(
            color: th.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: th.textSub, fontSize: 12),
        ),
        trailing: IconButton(
          tooltip: l10n.unsaveArabicWord,
          icon: Icon(Icons.bookmark_rounded, color: th.accent, size: 22),
          onPressed: () =>
              context.read<FavouritesProvider>().toggleSavedWord(word.key),
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.arabicLookupComingSoon),
              backgroundColor: th.accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}
