import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'l10n/app_strings.dart';
import 'providers/auth_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/course_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/favourites_provider.dart';
import 'providers/download_provider.dart';
// Debug-only screen — gated by ContentSourceConfig.qaLessonLaunchEnabled
// which requires kDebugMode + dart-define YALLA_TRANSCRIPT_DEBUG=true + YALLA_QA_LESSON_KEY.
// The class is compiled into the binary but the widget tree is not entered in release builds.
import 'screens/debug/qa_lesson_launcher.dart';
import 'screens/debug/qa_word_panel_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/content_source_config.dart';
import 'services/notification_service.dart';
import 'services/audio_handler.dart';
import 'services/app_usage_time_service.dart';
import 'services/qa_build_config.dart';

late YallaAudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  audioHandler = await AudioService.init(
    builder: () => YallaAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.yallaarabic.dev.audio',
      androidNotificationChannelName: 'Yalla Arabic Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  runApp(YallaArabicApp(handler: audioHandler));
}

class YallaArabicApp extends StatelessWidget {
  final YallaAudioHandler handler;
  const YallaArabicApp({super.key, required this.handler});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, AppUsageTimeService>(
          create: (_) => AppUsageTimeService(),
          update: (_, auth, appUsage) {
            if (!QaBuildConfig.bypassAuth && auth.isLoading) {
              return appUsage!;
            }
            appUsage!.setUser(
              QaBuildConfig.bypassAuth
                  ? QaBuildConfig.guestUid
                  : auth.user?.uid,
              localOnly: QaBuildConfig.bypassAuth,
            );
            return appUsage;
          },
        ),
        ChangeNotifierProvider(create: (_) => AudioProvider(handler)),
        ChangeNotifierProxyProvider<AuthProvider, FavouritesProvider>(
          create: (_) => FavouritesProvider(),
          update: (_, auth, favs) {
            if (!QaBuildConfig.bypassAuth && auth.isLoading) {
              return favs!;
            }
            favs!.setUser(
              QaBuildConfig.bypassAuth
                  ? QaBuildConfig.guestUid
                  : auth.user?.uid,
              localOnly: QaBuildConfig.bypassAuth,
            );
            return favs;
          },
        ),
        ChangeNotifierProxyProvider3<AuthProvider, AudioProvider,
            FavouritesProvider, ProgressProvider>(
          create: (_) => ProgressProvider(),
          update: (_, auth, audio, favourites, progress) {
            final provider = progress!;
            provider.bindAudioProvider(audio);
            provider.bindFavouritesProvider(favourites);
            if (!QaBuildConfig.bypassAuth && auth.isLoading) {
              return provider;
            }
            provider.setUser(
              QaBuildConfig.bypassAuth
                  ? QaBuildConfig.guestUid
                  : auth.user?.uid,
              localOnly: QaBuildConfig.bypassAuth,
            );
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProxyProvider<CourseProvider, DownloadProvider>(
          create: (_) => DownloadProvider(),
          update: (_, courseProvider, downloads) {
            downloads!.setCourses(courseProvider.courses);
            return downloads;
          },
        ),
      ],
      child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, themeProvider, settingsProvider, _) {
          final th = themeProvider.current;
          final l10n = AppStrings(settingsProvider.appLanguage);
          return MaterialApp(
            title: l10n.appTitle,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.dark(
                primary: th.accent,
                secondary: th.accent,
                surface: th.card,
              ),
              scaffoldBackgroundColor: th.bg,
              useMaterial3: true,
            ),
            builder: (context, child) => Directionality(
              textDirection: settingsProvider.appLanguage.textDirection,
              child: child ?? const SizedBox.shrink(),
            ),
            home: ContentSourceConfig.qaLessonLaunchEnabled
                ? QaLessonLauncher(lessonKey: ContentSourceConfig.qaLessonKey)
                : QaBuildConfig.wordPanelQa
                    ? const QaWordPanelScreen()
                    : const HomeScreen(),
          );
        },
      ),
    );
  }
}
