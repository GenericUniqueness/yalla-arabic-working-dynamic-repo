import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'app_language.dart';

export 'app_language.dart';

class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  static AppStrings of(BuildContext context, {bool listen = true}) {
    final settings = Provider.of<SettingsProvider>(context, listen: listen);
    return AppStrings(settings.appLanguage);
  }

  bool get isArabic => language.isArabic;

  String get appTitle => isArabic ? 'يلا عربي' : 'Yalla Arabic';
  String get splashTagline => isArabic
      ? 'تعلّم العربية بالفصحى من خلال الاستماع'
      : 'Learn Al-Fusha through listening';

  String get home => isArabic ? 'الرئيسية' : 'Home';
  String get review => isArabic ? 'المراجعة' : 'Review';
  String get progress => isArabic ? 'التقدم' : 'Progress';
  String get settings => isArabic ? 'الإعدادات' : 'Settings';
  String get about => isArabic ? 'حول التطبيق' : 'About';

  String get homeHeadline => isArabic ? 'الدورات الرئيسية' : 'Main Courses';
  String get homeSubtitle => isArabic
      ? 'تعلّم العربية الفصحى من خلال دروس تعتمد على الاستماع.'
      : 'Learn Modern Standard Arabic through listening-first lessons.';
  String get lessonsPlaceholder => isArabic
      ? 'ستظهر دروس العربية الفصحى هنا.'
      : 'Modern Standard Arabic lessons will appear here.';
  String levelLabel(String level) => isArabic ? 'المستوى $level' : level;
  String get start => isArabic ? 'ابدأ' : 'Start';
  String get continueLabel => isArabic ? 'تابع' : 'Continue';
  String get comingSoon => isArabic ? 'قريبًا' : 'Coming soon';
  String get noLessonsYet => isArabic ? 'لا توجد دروس بعد' : 'No lessons yet';
  String get nowPlaying => isArabic ? 'قيد التشغيل الآن' : 'Now Playing';
  String get play => isArabic ? 'تشغيل' : 'Play';
  String get pause => isArabic ? 'إيقاف مؤقت' : 'Pause';

  String get reviewTitle => isArabic ? 'مراجعة العربية' : 'Arabic Review';
  String get practiceArabicWords =>
      isArabic ? 'تدرّب على كلمات عربية' : 'Practice Arabic words';
  String get chooseEnglishMeaning =>
      isArabic ? 'اختر المعنى بالإنجليزية' : 'Choose the English meaning';
  String get startPractice => isArabic ? 'ابدأ التدريب' : 'Start practice';
  String get correct => isArabic ? 'صحيح' : 'Correct';
  String get tryAgain => isArabic ? 'حاول مرة أخرى' : 'Try again';
  String get next => isArabic ? 'التالي' : 'Next';
  String get score => isArabic ? 'النتيجة' : 'Score';
  String get chooseLevel => isArabic ? 'اختر المستوى' : 'Choose level';
  String get allLevelsShort => isArabic ? 'الكل' : 'All';
  String get numberOfQuestions =>
      isArabic ? 'عدد الكلمات / الأسئلة' : 'Number of words/questions';
  String get reviewSubtitle => isArabic
      ? 'احفظ الكلمات والعبارات العربية لمراجعتها هنا.'
      : 'Save Arabic words and phrases to review them here.';
  String get randomReviewTitle =>
      isArabic ? 'تدريب مفردات عربي' : 'Arabic Vocabulary Review';
  String get randomReviewSubtitle => isArabic
      ? 'تدرّب على كلمات عربية باختيار المعنى بالإنجليزية.'
      : 'Practice Arabic words by choosing the English meaning.';
  String get savedBatches => isArabic ? 'المجموعات المحفوظة' : 'Saved Batches';
  String get savedArabicWords =>
      isArabic ? 'كلمات عربية محفوظة' : 'Saved Arabic Words';
  String get savedLessons => isArabic ? 'الدروس المحفوظة' : 'Saved Lessons';
  String get arabicToEnglish =>
      isArabic ? 'العربية إلى الإنجليزية' : 'Arabic to English';
  String get vocabularyQuiz => isArabic ? 'تدريب المفردات' : 'Vocabulary Quiz';
  String get reviewSavedWords => isArabic
      ? 'راجع الكلمات والعبارات العربية المحفوظة.'
      : 'Review saved Arabic words and phrases.';
  String get nothingSavedYet =>
      isArabic ? 'لا توجد عناصر محفوظة بعد' : 'Nothing saved yet';
  String get reviewDataUnavailable => isArabic
      ? 'بيانات مراجعة العربية غير متاحة بعد.'
      : 'Arabic review data is not available yet.';
  String get couldNotBuildQuiz => isArabic
      ? 'تعذّر إنشاء التدريب الآن.'
      : 'Could not build a practice session right now.';
  String get couldNotBuildSavedWordsQuiz => isArabic
      ? 'تعذّر إنشاء أسئلة من الكلمات المحفوظة. جرّب حفظ كلمات أكثر.'
      : 'Could not build questions from saved words. Try saving more words.';
  String get couldNotRebuildBatch => isArabic
      ? 'تعذّر إعادة إنشاء هذه المجموعة.'
      : 'Could not rebuild this batch.';
  String get practiceThisBatch =>
      isArabic ? 'تدرّب على هذه المجموعة' : 'Practice this batch';
  String get deleteBatch => isArabic ? 'احذف المجموعة' : 'Delete batch';
  String get deleteBatchQuestion =>
      isArabic ? 'حذف المجموعة؟' : 'Delete batch?';
  String get cannotBeUndone =>
      isArabic ? 'لا يمكن التراجع عن هذا.' : 'This cannot be undone.';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get removeSavedLesson =>
      isArabic ? 'إزالة الدرس المحفوظ' : 'Remove saved lesson';
  String get unsaveArabicWord =>
      isArabic ? 'إزالة الكلمة العربية' : 'Unsave Arabic word';
  String get arabicLookupComingSoon => isArabic
      ? 'البحث عن الكلمات العربية قريبًا.'
      : 'Arabic lookup coming soon.';
  String get savedArabicForm =>
      isArabic ? 'الصيغة العربية المحفوظة' : 'Saved Arabic form';

  String get theme => isArabic ? 'المظهر' : 'Theme';
  String get appLanguage => isArabic ? 'لغة التطبيق' : 'App language';
  String get dailyGoal => isArabic ? 'الهدف اليومي' : 'Daily goal';
  String get listenFor => isArabic ? 'استمع لمدة' : 'Listen for';
  String minPerDay(int minutes) =>
      isArabic ? '$minutes دقيقة / يوم' : '$minutes min / day';
  String get general => isArabic ? 'عام' : 'General';
  String get keepScreenOn => isArabic ? 'إبقاء الشاشة مضاءة' : 'Keep screen on';
  String get showTranslation => isArabic ? 'عرض الترجمة' : 'Show translation';
  String get notifications => isArabic ? 'الإشعارات' : 'Notifications';
  String get dailyReminder =>
      isArabic ? 'تذكير يومي الساعة 6 مساءً' : 'Daily reminder at 6 PM';
  String get downloads => isArabic ? 'التنزيلات' : 'Downloads';
  String get myDownloads => isArabic ? 'تنزيلاتي' : 'My Downloads';
  String get noOfflineLessons =>
      isArabic ? 'لا توجد دروس بلا إنترنت' : 'No offline lessons';
  String get noDownloadsYet =>
      isArabic ? 'لا توجد تنزيلات بعد' : 'No downloads yet';
  String cachedOnDevice(String size) =>
      isArabic ? '$size مخزنة على الجهاز' : '$size cached on device';
  String get downloadsWorkOffline => isArabic
      ? 'تعمل الدروس المنزلة دون إنترنت'
      : 'Downloaded lessons play without internet';
  String get downloadEmptyHint => isArabic
      ? 'اضغط رمز التنزيل بجانب أي درس\nأو شغّله ليتم تنزيله تلقائيًا'
      : 'Tap the download icon next to any lesson\nor just play it; it downloads automatically';
  String get deleteAll => isArabic ? 'حذف الكل' : 'Delete all';
  String get deleteAllDownloads =>
      isArabic ? 'حذف كل التنزيلات؟' : 'Delete all downloads?';
  String get deleteAllDownloadsBody => isArabic
      ? 'سيتم حذف كل الصوت المنزّل من جهازك. يمكنك تنزيله مرة أخرى في أي وقت.'
      : 'All downloaded audio will be removed from your device. You can re-download anytime.';
  String deleteLessonQuestion(int id) =>
      isArabic ? 'حذف الدرس $id؟' : 'Delete Lesson $id?';
  String lessonCount(int count) => isArabic
      ? '$count ${count == 1 ? 'درس' : 'دروس'}'
      : '$count lesson${count == 1 ? '' : 's'}';
  String wordCount(int count) => isArabic
      ? '$count ${count == 1 ? 'كلمة' : 'كلمات'}'
      : '$count word${count == 1 ? '' : 's'}';
  String get privacy => isArabic ? 'الخصوصية' : 'Privacy';
  String get aboutApp => isArabic ? 'حول التطبيق' : 'About the App';
  String get aboutSubtitle => isArabic
      ? 'طريقة تعلّم العربية وقصة التطبيق'
      : 'Arabic learning method and background';

  String get pauseQuizQuestion =>
      isArabic ? 'إيقاف التدريب مؤقتًا؟' : 'Pause practice?';
  String answeredCount(int current, int total) => isArabic
      ? 'أجبت عن $current من $total سؤال.'
      : 'You answered $current of $total questions.';
  String get keepGoing => isArabic ? 'تابع' : 'Keep going';
  String get saveBatchExit =>
      isArabic ? 'احفظ المجموعة واخرج' : 'Save batch & exit';
  String get exitWithoutSaving =>
      isArabic ? 'اخرج دون حفظ' : 'Exit without saving';
  String get nameThisBatch => isArabic ? 'اسم هذه المجموعة' : 'Name this batch';
  String get batchNameHint =>
      isArabic ? 'مثال: تدريب B1' : 'e.g. B1 practice set';
  String get skip => isArabic ? 'تخطي' : 'Skip';
  String get save => isArabic ? 'حفظ' : 'Save';
  String batchSaved(String name) =>
      isArabic ? 'تم حفظ المجموعة "$name"' : 'Batch "$name" saved';
  String get randomBatch => isArabic ? 'مجموعة عشوائية' : 'Random Batch';
  String cefrBatch(String level) => isArabic ? 'مجموعة $level' : '$level Batch';
  String get saveThisBatch =>
      isArabic ? 'احفظ هذه المجموعة' : 'Save this batch';
  String get done => isArabic ? 'تم' : 'Done';
  String scoreLine(int correct, int total) =>
      isArabic ? '$correct / $total صحيح' : '$correct / $total correct';
  String get excellent => isArabic ? 'ممتاز!' : 'Excellent!';
  String get wellDone => isArabic ? 'أحسنت!' : 'Well done!';
  String get keepPracticing =>
      isArabic ? 'استمر في التدريب!' : 'Keep practising!';
  String get reviewTheseWords =>
      isArabic ? 'راجع هذه الكلمات' : 'Review these words';
  String wordsToReview(int count) =>
      isArabic ? 'كلمات للمراجعة ($count):' : 'Words to review ($count):';
  String get saveMissed => isArabic ? 'احفظ الأخطاء' : 'Save missed';
  String get saved => isArabic ? 'تم الحفظ' : 'Saved';

  String get progressEmpty => isArabic
      ? 'ابدأ الاستماع لترى تقدمك هنا.'
      : 'Start listening to see your progress here.';
  String get courses => isArabic ? 'الدورات' : 'Courses';
  String get listeningToday => isArabic ? 'استماع اليوم' : 'listening today';
  String dayStreak(int days) =>
      isArabic ? '$days يوم متتالٍ' : '$days day streak';
  String get todayAppTime => isArabic ? 'وقت التطبيق اليوم' : 'Today app time';
  String get todayListeningTime =>
      isArabic ? 'وقت الاستماع اليوم' : 'Today listening time';
  String get totalAppTime => isArabic ? 'إجمالي وقت التطبيق' : 'Total app time';
  String get totalListeningTime =>
      isArabic ? 'إجمالي وقت الاستماع' : 'Total listening time';
  String get bestStreak => isArabic ? 'أفضل سلسلة' : 'Best streak';
  String days(int count) => isArabic ? '$count يوم' : '$count days';
  String lessonsDone(int done, int total) =>
      isArabic ? '$done / $total دروس' : '$done / $total lessons';

  String get deleteDownloadQuestion =>
      isArabic ? 'حذف التنزيل؟' : 'Delete download?';
  String removeOfflineAudio(String title) => isArabic
      ? 'إزالة الصوت بلا إنترنت لـ "$title"؟'
      : 'Remove offline audio for "$title"?';
  String get downloadedTapToDelete =>
      isArabic ? 'تم التنزيل - اضغط للحذف' : 'Downloaded - tap to delete';
  String get downloadForOffline =>
      isArabic ? 'تنزيل للاستماع بلا إنترنت' : 'Download for offline';
  String lessonTitle(int id, String title) => isArabic
      ? 'الدرس ${id.toString().padLeft(2, "0")} $title'
      : 'Lesson ${id.toString().padLeft(2, "0")} $title';

  String get close => isArabic ? 'إغلاق' : 'Close';
  String get lookupBody => isArabic
      ? 'ستشرح الإصدارات القادمة كلمات وعبارات الفصحى بالإنجليزية للمساعدة.'
      : 'Future versions will explain Al-Fusha words and phrases in English.';
}

extension AppStringsContext on BuildContext {
  AppStrings get l10n => AppStrings.of(this);
  TextDirection get appTextDirection =>
      watch<SettingsProvider>().appLanguage.textDirection;
}
