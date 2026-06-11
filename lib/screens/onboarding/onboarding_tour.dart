import 'package:flutter/material.dart';
import '../../providers/theme_provider.dart';

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String titleAr;
  final String body;
  final String bodyAr;
  final String? buttonLabel;
  final String? buttonLabelAr;

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.titleAr,
    required this.body,
    required this.bodyAr,
    this.buttonLabel,
    this.buttonLabelAr,
  });
}

const List<_OnboardingStep> _steps = [
  _OnboardingStep(
    icon: Icons.auto_stories,
    title: 'Welcome to Yalla Arabic',
    titleAr: 'مرحباً بك في يلا عربي',
    body:
        'Free, no ads, no catch. Built for English speakers who want real Arabic — best for A1–B1 levels. Read each slide carefully — it explains how this app works.',
    bodyAr:
        'مجاني، بلا إعلانات، بلا شروط. مبني للناطقين بالإنجليزية الراغبين في عربية حقيقية — الأنسب لمستويات A1 إلى B1. اقرأ كل شريحة بعناية — ستشرح لك كيف يعمل التطبيق.',
  ),
  _OnboardingStep(
    icon: Icons.headphones,
    title: 'Listening is the core',
    titleAr: 'الاستماع هو الأساس',
    body:
        'This app is built around comprehensible input and repeated listening. Language enters through your ears. Listen to each audio 3–5 times minimum — while walking, driving, cooking, or exercising.',
    bodyAr:
        'هذا التطبيق مبني على المدخلات المفهومة والاستماع المتكرر. اللغة تدخل عبر أذنيك. استمع لكل تسجيل ٣–٥ مرات على الأقل — أثناء المشي أو القيادة أو الطهي أو الرياضة.',
  ),
  _OnboardingStep(
    icon: Icons.play_circle_outline_rounded,
    title: 'Start with the audio',
    titleAr: 'ابدأ بالصوت دائماً',
    body:
        'Open a lesson and listen first — do not start with grammar. Tap words only when needed; also try to understand from context. Repeat sentences and audios again and again.',
    bodyAr:
        'افتح درساً واستمع أولاً — لا تبدأ بالقواعد. اضغط على الكلمات عند الحاجة فقط؛ وحاول أيضاً أن تفهم من السياق. كرّر الجمل والتسجيلات مراراً.',
  ),
  _OnboardingStep(
    icon: Icons.bookmark_add_outlined,
    title: 'Save words, review later',
    titleAr: 'احفظ الكلمات وراجعها لاحقاً',
    body:
        'Tap any word to see its meaning, English help, and pronunciation. Save it for review. Use the Review tab for vocabulary quizzes — it helps listening, not replaces it.',
    bodyAr:
        'اضغط على أي كلمة لترى معناها والمساعدة الإنجليزية ونطقها. احفظها للمراجعة. تبويب المراجعة يساعد الاستماع ولا يبدله.',
  ),
  _OnboardingStep(
    icon: Icons.menu_book_rounded,
    title: 'Grammar helps — not the main method',
    titleAr: 'القواعد تساعد — وليست المنهج الرئيسي',
    body:
        'The Grammar tab gives structured practice by level. It is useful — but do not start there. Listening comes first. Grammar is a helper tool.',
    bodyAr:
        'تبويب القواعد يقدّم تدريباً منظّماً حسب المستوى. مفيد — لكن لا تبدأ به. الاستماع يأتي أولاً. القواعد أداة دعم.',
  ),
  _OnboardingStep(
    icon: Icons.info_outline_rounded,
    title: 'One last thing',
    titleAr: 'شيء أخير',
    body:
        'Open "About the App" in Settings to read the full method, a real example of how listening works, and extra guidance.',
    bodyAr:
        'افتح "عن التطبيق" في الإعدادات لقراءة المنهج الكامل ومثال حقيقي على كيفية عمل الاستماع وإرشادات إضافية.',
    buttonLabel: 'Open About →',
    buttonLabelAr: 'افتح عن التطبيق',
  ),
];

/// Full-screen onboarding tour overlay.
/// Shown as a Stack layer on top of HomeScreen.
/// Calls [onComplete] when the user finishes the tour.
/// Calls [onOpenAbout] on the final step button press.
class OnboardingTour extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onOpenAbout;
  final AppTheme th;

  const OnboardingTour({
    super.key,
    required this.onComplete,
    required this.onOpenAbout,
    required this.th,
  });

  @override
  State<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends State<OnboardingTour>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late final AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    final isLast = _currentStep == _steps.length - 1;
    if (isLast) {
      widget.onComplete();
      widget.onOpenAbout();
      return;
    }
    await _animCtrl.reverse();
    if (!mounted) return;
    setState(() => _currentStep++);
    _animCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final th = widget.th;
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;
    final screenWidth = MediaQuery.of(context).size.width;

    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                width: screenWidth * 0.88,
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: th.card,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 48,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Step counter + Skip
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 40),
                            Text(
                              '${_currentStep + 1} / ${_steps.length}',
                              style: TextStyle(
                                color: th.textSub.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Icon circle
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: th.accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(step.icon, color: th.accent, size: 36),
                      ),
                      const SizedBox(height: 16),
                      // English title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: th.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Arabic title — equal visual weight to English title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          step.titleAr,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: th.accent,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // English body
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          step.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: th.textSub,
                            fontSize: 14,
                            height: 1.55,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Arabic body — equal opacity and size to English body
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          step.bodyAr,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: th.textSub,
                            fontSize: 14,
                            height: 1.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Step dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_steps.length, (i) {
                          final isActive = i == _currentStep;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isActive ? 18 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? th.accent
                                  : th.textSub.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 18),
                      // Next / Open About button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _advance,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: th.accent,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              step.buttonLabel ?? 'Next →',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isLast)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                          child: Text(
                            step.buttonLabelAr ?? '',
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: th.textSub,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
