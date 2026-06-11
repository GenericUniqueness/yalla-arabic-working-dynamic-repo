import 'package:flutter/material.dart';
import '../../providers/theme_provider.dart';

class _Tip {
  final IconData icon;
  final String title;
  final String body;

  const _Tip({required this.icon, required this.title, required this.body});
}

const _tips = [
  _Tip(
    icon: Icons.touch_app_rounded,
    title: 'Tap any word to understand it',
    body:
        'Tap any English word to see its meaning, Arabic translation, and pronunciation. Save it for review later.',
  ),
  _Tip(
    icon: Icons.repeat_rounded,
    title: 'Repeat sentences and listen again',
    body:
        'Long-press any sentence to repeat it as many times as you like. Repetition builds fluency.',
  ),
  _Tip(
    icon: Icons.headphones_rounded,
    title: 'The core method',
    body:
        'Repeated comprehensible listening — not grammar first. Listen to each lesson 3–5 times while walking, driving, or exercising.',
  ),
];

/// Full-screen overlay shown the first time a logged-in user opens any lesson.
/// [onDone] is called only after the user taps "Got it" on the final tip.
/// Marking the flag as complete is the caller's responsibility.
class LessonCoachTour extends StatefulWidget {
  final AppTheme th;
  final VoidCallback onDone;

  const LessonCoachTour({
    super.key,
    required this.th,
    required this.onDone,
  });

  @override
  State<LessonCoachTour> createState() => _LessonCoachTourState();
}

class _LessonCoachTourState extends State<LessonCoachTour>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late final AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_step == _tips.length - 1) {
      widget.onDone();
      return;
    }
    await _ctrl.reverse();
    if (!mounted) return;
    setState(() => _step++);
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final th = widget.th;
    final tip = _tips[_step];
    final isLast = _step == _tips.length - 1;
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
                      // Step counter
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: Text(
                            '${_step + 1} / ${_tips.length}',
                            style: TextStyle(
                              color: th.textSub.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                        child: Icon(tip.icon, color: th.accent, size: 36),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          tip.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: th.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Body
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          tip.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: th.textSub,
                            fontSize: 14,
                            height: 1.55,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Step dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_tips.length, (i) {
                          final isActive = i == _step;
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
                      // CTA button — same style on every step
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: th.accent,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              isLast ? 'Got it' : 'Next →',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
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
