import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/theme_provider.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final l10n = context.l10n;
    final sections = l10n.isArabic ? _arabicSections() : _englishSections();

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        backgroundColor: th.bg,
        leading: BackButton(color: th.textPrimary),
        title: Text(
          l10n.privacy,
          style: TextStyle(color: th.textPrimary, fontSize: 16),
        ),
      ),
      body: Directionality(
        textDirection: l10n.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: th.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: th.textSub.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.isArabic ? 'خصوصية يلا عربي' : 'Yalla Arabic Privacy',
                    style: TextStyle(
                      color: th.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.isArabic
                        ? 'نسخة تطوير خاصة للتعلّم المحلي.'
                        : 'Private dev build for local learning.',
                    style: TextStyle(color: th.textSub, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final section in sections)
              _section(th, section.title, section.body, l10n.isArabic),
          ],
        ),
      ),
    );
  }

  List<_PrivacySection> _englishSections() {
    return const [
      _PrivacySection(
        'Accounts',
        'This Yalla Arabic dev app runs as a local guest. Email/password login, '
            'Google login, and production Firebase startup are not used here.',
      ),
      _PrivacySection(
        'Learning data',
        'Settings, progress, saved words, review batches, and review history '
            'are stored locally on this device for the copied dev app.',
      ),
      _PrivacySection(
        'Downloads and cache',
        'Lesson text, audio cache, and offline downloads may be stored locally '
            'to improve playback and offline use.',
      ),
      _PrivacySection(
        'Analytics',
        'This copied dev app should not send production account data. Do not '
            'enter secrets, production credentials, or private Firebase values.',
      ),
    ];
  }

  List<_PrivacySection> _arabicSections() {
    return const [
      _PrivacySection(
        'الحسابات',
        'تعمل نسخة يلا عربي التطويرية كمستخدم محلي. لا يتم استخدام تسجيل '
            'الدخول بالبريد الإلكتروني أو Google أو تشغيل Firebase الإنتاجي هنا.',
      ),
      _PrivacySection(
        'بيانات التعلّم',
        'تُحفظ الإعدادات والتقدم والكلمات المحفوظة ومجموعات المراجعة وسجل '
            'المراجعة محليًا على هذا الجهاز لنسخة التطوير المنسوخة.',
      ),
      _PrivacySection(
        'التنزيلات والتخزين المؤقت',
        'قد تُحفظ نصوص الدروس وذاكرة الصوت والتنزيلات بلا إنترنت محليًا '
            'لتحسين التشغيل والاستخدام دون اتصال.',
      ),
      _PrivacySection(
        'التحليلات',
        'يجب ألا ترسل نسخة التطوير المنسوخة بيانات حساب إنتاجية. لا تُدخل '
            'أسرارًا أو بيانات اعتماد إنتاجية أو قيم Firebase خاصة.',
      ),
    ];
  }

  Widget _section(
    AppTheme th,
    String title,
    String body,
    bool isArabic,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: th.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(color: th.textSub, fontSize: 14, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection {
  final String title;
  final String body;

  const _PrivacySection(this.title, this.body);
}
