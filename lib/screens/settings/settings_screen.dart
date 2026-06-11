import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/download_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/notification_service.dart';
import 'about_screen.dart';
import 'downloads_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final settings = context.watch<SettingsProvider>();
    final progress = context.watch<ProgressProvider>();
    final l10n = context.l10n;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settings,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // ── App Language ───────────────────────────────────────────────
            _buildSectionContainer(th, l10n.appLanguage, [
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildLanguagePicker(context, th, settings),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Theme ──────────────────────────────────────────────────────
            Text(
              l10n.theme,
              style: TextStyle(
                color: th.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _buildThemePicker(context, th),
            const SizedBox(height: 20),

            // ── Daily Goal ─────────────────────────────────────────────────
            _buildSectionContainer(th, l10n.dailyGoal, [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.listenFor,
                      style: TextStyle(color: th.textSub, fontSize: 14),
                    ),
                    Text(
                      l10n.minPerDay(progress.dailyGoalMinutes),
                      style: TextStyle(
                        color: th.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  trackHeight: 4,
                  activeTrackColor: th.accent,
                  inactiveTrackColor: th.textSub.withValues(alpha: 0.2),
                  thumbColor: th.accent,
                  overlayColor: th.accent.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: progress.dailyGoalMinutes.toDouble().clamp(10, 300),
                  min: 10,
                  max: 300,
                  divisions: 29, // snaps every ~10 minutes
                  onChanged: (v) => progress.setDailyGoalMinutes(v.round()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '10m',
                      style: TextStyle(color: th.textSub, fontSize: 11),
                    ),
                    Text(
                      '300m',
                      style: TextStyle(color: th.textSub, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── General ────────────────────────────────────────────────────
            _buildSectionContainer(th, l10n.general, [
              _buildSwitchTile(
                th,
                l10n.keepScreenOn,
                settings.neverSleep,
                (v) => settings.setNeverSleep(v),
              ),
              Divider(color: th.textSub.withValues(alpha: 0.15), height: 1),
              _buildSwitchTile(
                th,
                l10n.showTranslation,
                settings.showArabicTranslation,
                (v) => settings.setShowArabicTranslation(v),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Notifications ──────────────────────────────────────────────
            _buildSectionContainer(th, l10n.notifications, [
              _buildSwitchTile(
                th,
                l10n.dailyReminder,
                settings.dailyNotification,
                (v) async {
                  await settings.setDailyNotification(v);
                  if (v) {
                    await NotificationService.scheduleDailyReminder();
                  } else {
                    await NotificationService.cancelReminder();
                  }
                },
              ),
            ]),
            const SizedBox(height: 20),

            // ── Downloads ──────────────────────────────────────────────────
            _buildSectionContainer(
                th, l10n.downloads, [_DownloadsTile(th: th)]),
            const SizedBox(height: 20),

            // ── Privacy ────────────────────────────────────────────────────
            _buildSectionContainer(th, l10n.privacy, [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Icon(
                  Icons.privacy_tip_outlined,
                  color: th.accent,
                  size: 22,
                ),
                title: Text(
                  l10n.privacy,
                  style: TextStyle(color: th.textPrimary, fontSize: 15),
                ),
                trailing: Icon(Icons.chevron_right, color: th.textSub),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── About ──────────────────────────────────────────────────────
            _buildSectionContainer(th, l10n.about, [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: th.accent,
                  size: 22,
                ),
                title: Text(
                  l10n.aboutApp,
                  style: TextStyle(color: th.textPrimary, fontSize: 15),
                ),
                subtitle: Text(
                  l10n.aboutSubtitle,
                  style: TextStyle(color: th.textSub, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: th.textSub),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguagePicker(
    BuildContext context,
    AppTheme th,
    SettingsProvider settings,
  ) {
    final selected = settings.appLanguage;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SegmentedButton<AppLanguage>(
        segments: const [
          ButtonSegment(
            value: AppLanguage.english,
            label: Text('English'),
          ),
          ButtonSegment(
            value: AppLanguage.arabic,
            label: Text('العربية'),
          ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? th.accent
                : th.bg.withValues(alpha: 0.7),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : th.textPrimary,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? th.accent
                  : th.textSub.withValues(alpha: 0.25),
            ),
          ),
        ),
        onSelectionChanged: (values) {
          if (values.isNotEmpty) {
            settings.setAppLanguage(values.first);
          }
        },
      ),
    );
  }

  Widget _buildThemePicker(BuildContext context, AppTheme th) {
    final themeProvider = context.watch<ThemeProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        color: th.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(
              4,
              (i) => _buildThemeTile(context, themeProvider, th, i),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              4,
              (i) => _buildThemeTile(context, themeProvider, th, i + 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile(
    BuildContext context,
    ThemeProvider themeProvider,
    AppTheme th,
    int i,
  ) {
    final t = ThemeProvider.themes[i];
    final selected = themeProvider.index == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<ThemeProvider>().setTheme(i),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: t.bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected ? t.accent : Colors.grey.withValues(alpha: 0.3),
                  width: selected ? 2.5 : 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: t.accent.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.name,
              style: TextStyle(
                color: selected ? t.accent : th.textSub,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer(
    AppTheme th,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: th.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: th.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    AppTheme th,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(label, style: TextStyle(color: th.textPrimary, fontSize: 15)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: th.accent,
      activeTrackColor: th.accent.withValues(alpha: 0.4),
      inactiveTrackColor: th.textSub.withValues(alpha: 0.3),
    );
  }
}

class _DownloadsTile extends StatelessWidget {
  final AppTheme th;
  const _DownloadsTile({required this.th});

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadProvider>();
    final count = dl.downloadedLessons.length;
    final l10n = context.l10n;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        Icons.download_for_offline_rounded,
        color: th.accent,
        size: 22,
      ),
      title: Text(
        l10n.myDownloads,
        style: TextStyle(color: th.textPrimary, fontSize: 15),
      ),
      subtitle: FutureBuilder<int>(
        future: dl.totalCacheBytes(),
        builder: (context, snap) {
          final size = snap.data ?? 0;
          final label = count == 0
              ? l10n.noOfflineLessons
              : '${l10n.lessonCount(count)} · ${_formatBytes(size)}';
          return Text(label, style: TextStyle(color: th.textSub, fontSize: 12));
        },
      ),
      trailing: Icon(Icons.chevron_right, color: th.textSub),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DownloadsScreen()),
      ),
    );
  }
}
