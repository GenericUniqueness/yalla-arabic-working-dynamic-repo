import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;
  bool _resending = false;
  String? _message;
  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final auth = context.watch<AuthProvider>();
    final email = auth.user?.email ?? 'your email';

    return Scaffold(
      backgroundColor: th.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: th.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: th.textSub.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: th.accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mark_email_unread_rounded,
                          color: th.accent, size: 34),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Verify your email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: th.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We sent a verification link to $email. Open the link, then come back and refresh.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: th.textSub,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: th.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: th.accent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 14, color: th.textSub),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Check your Spam or Promotions folder if you don't see the email. Google sign-in avoids this.",
                              style: TextStyle(
                                  color: th.textSub,
                                  fontSize: 12,
                                  height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_isError ? AppColors.error : th.accent)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_isError ? AppColors.error : th.accent)
                                .withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isError ? AppColors.error : th.textPrimary,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _checking ? null : _checkVerification,
                        icon: _checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded,
                                color: Colors.white),
                        label: const Text(
                          'I verified, refresh',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: th.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _resending ? null : _resend,
                        icon: _resending
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: th.accent,
                                ),
                              )
                            : Icon(Icons.mark_email_read_rounded,
                                color: th.accent),
                        label: Text(
                          'Resend verification email',
                          style: TextStyle(
                              color: th.textPrimary,
                              fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                              color: th.textSub.withValues(alpha: 0.25)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: auth.signOut,
                      child: Text('Use a different account',
                          style: TextStyle(color: th.textSub)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkVerification() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    final error = await context.read<AuthProvider>().reloadUser();
    if (!mounted) return;
    final verified = context.read<AuthProvider>().user?.emailVerified == true;
    setState(() {
      _checking = false;
      _isError = error != null || !verified;
      _message = error ??
          (verified
              ? 'Email verified. Opening Yalla Arabic...'
              : 'Not verified yet. Use the link in your email, then refresh again.');
    });
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _message = null;
    });
    final error = await context.read<AuthProvider>().sendEmailVerification();
    if (!mounted) return;
    setState(() {
      _resending = false;
      _isError = error != null;
      _message = error ?? 'Verification email sent. Check your inbox.';
    });
  }
}
