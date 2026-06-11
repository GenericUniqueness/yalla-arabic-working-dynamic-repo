import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';

import '../../providers/audio_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/account_local_data_service.dart';
import '../../services/app_usage_time_service.dart';
import '../../services/daily_usage_service.dart';
import '../../services/firestore_progress_service.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  bool _isDeleting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        backgroundColor: th.bg,
        leading: BackButton(color: th.textPrimary),
        title: Text(
          'Delete Account',
          style: TextStyle(color: th.textPrimary, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.45),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Deleting your account is permanent and cannot be undone.',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'This will delete',
            style: TextStyle(
              color: th.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _item(th, 'Your Firebase sign-in account'),
          _item(th, 'Lesson progress, listening minutes, and streaks'),
          _item(th, 'Favorite lessons and saved words'),
          _item(th, 'Profile and onboarding data'),
          _item(th, 'Local quiz, review, and grammar practice history'),
          _item(th, 'Downloaded and cached lesson content on this device'),
          const SizedBox(height: 16),
          Text(
            auth.requiresPasswordForAccountDeletion
                ? 'You will need your current password to confirm your identity.'
                : 'Google will ask you to confirm the signed-in account.',
            style: TextStyle(color: th.textSub, fontSize: 14, height: 1.5),
          ),
          if (_error != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isDeleting ? null : _confirmAndDelete,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              disabledBackgroundColor: AppColors.error.withValues(alpha: 0.35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.delete_forever_rounded),
            label: Text(
              _isDeleting ? 'Deleting account...' : 'Delete Account',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(AppTheme th, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.remove_circle_outline, color: th.textSub, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: th.textSub, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    final auth = context.read<AuthProvider>();
    final currentUser = auth.user;
    if (currentUser == null) {
      setState(() => _error = 'Please sign in again before deleting.');
      return;
    }

    final confirmation = await showDialog<_DeletionConfirmation>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeletionConfirmationDialog(
        requiresPassword: auth.requiresPasswordForAccountDeletion,
      ),
    );
    if (confirmation == null || !mounted) return;

    final progress = context.read<ProgressProvider>();
    final appUsage = context.read<AppUsageTimeService>();
    final downloads = context.read<DownloadProvider>();
    final audio = context.read<AudioProvider>();

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    // For Google users, show an explanation before the OS account picker appears.
    if (!auth.requiresPasswordForAccountDeletion && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _GoogleReauthExplanationDialog(),
      );
      if (proceed != true || !mounted) {
        setState(() => _isDeleting = false);
        return;
      }
    }

    final reauthError = await auth.reauthenticateForAccountDeletion(
      password: confirmation.password,
    );
    if (!mounted) return;
    if (reauthError != null) {
      setState(() {
        _isDeleting = false;
        _error = reauthError == 'Cancelled' ? null : reauthError;
      });
      return;
    }

    await progress.suspendCloudSyncForAccountDeletion();
    await DailyUsageService.suspendCloudSyncForAccountDeletion(
      currentUser.uid,
    );

    try {
      if (audio.isPlaying) await audio.pause();
      await FirestoreProgressService.deleteCurrentUserData(currentUser.uid);
    } catch (error) {
      progress.resumeCloudSyncAfterAccountDeletionFailure();
      DailyUsageService.resumeCloudSyncAfterAccountDeletionFailure(
        currentUser.uid,
      );
      if (kDebugMode) {
        debugPrint('[AccountDeletion] Firestore deletion failed: $error');
      }
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error =
            'Your account data could not be deleted. Check your connection and try again.';
      });
      return;
    }

    final authDeleteError = await auth.deleteCurrentAccount();
    if (authDeleteError != null) {
      progress.resumeCloudSyncAfterAccountDeletionFailure();
      DailyUsageService.resumeCloudSyncAfterAccountDeletionFailure(
        currentUser.uid,
      );
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error =
            'Your learning data was removed, but account deletion did not finish. '
            'Please complete the deletion again without leaving this screen.';
      });
      return;
    }

    await appUsage.prepareForAccountDeletion(currentUser.uid);
    try {
      await AccountLocalDataService.clearAll();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[AccountDeletion] preference cleanup failed: $error');
      }
    }
    try {
      await downloads.deleteAll();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[AccountDeletion] cache cleanup failed: $error');
      }
    }
    audio.clearLesson();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

// Shown before the Google OS account picker so the user knows which account
// to choose. Does not weaken security — reauth still happens via Google.
class _GoogleReauthExplanationDialog extends StatelessWidget {
  const _GoogleReauthExplanationDialog();

  @override
  Widget build(BuildContext context) {
    final th = context.read<ThemeProvider>().current;
    return AlertDialog(
      backgroundColor: th.card,
      title: Text(
        'Confirm your Google account',
        style: TextStyle(color: th.textPrimary, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Google will ask you to choose an account. Select the same Google '
            'account you used to sign in to Yalla Arabic. This is just to '
            'confirm it is really you before the account is deleted.',
            style: TextStyle(color: th.textSub, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              'ستطلب منك Google اختيار حساب. اختر نفس حساب Google الذي '
              'استخدمته لتسجيل الدخول إلى يلا عربي. هذه خطوة للتحقق من '
              'هويتك فقط قبل حذف الحساب.',
              style: TextStyle(color: th.textSub, fontSize: 13, height: 1.55),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: th.textSub)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Continue',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _DeletionConfirmation {
  final String? password;

  const _DeletionConfirmation({this.password});
}

class _DeletionConfirmationDialog extends StatefulWidget {
  final bool requiresPassword;

  const _DeletionConfirmationDialog({required this.requiresPassword});

  @override
  State<_DeletionConfirmationDialog> createState() =>
      _DeletionConfirmationDialogState();
}

class _DeletionConfirmationDialogState
    extends State<_DeletionConfirmationDialog> {
  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  bool get _canDelete =>
      _confirmationController.text.trim() == 'DELETE' &&
      (!widget.requiresPassword || _passwordController.text.isNotEmpty);

  @override
  void dispose() {
    _confirmationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = context.read<ThemeProvider>().current;
    return AlertDialog(
      backgroundColor: th.card,
      title: Text(
        'Permanently delete account?',
        style: TextStyle(color: th.textPrimary, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action cannot be undone. Type DELETE to confirm.',
              style: TextStyle(color: th.textSub, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmationController,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: th.textPrimary),
              decoration: InputDecoration(
                labelText: 'Type DELETE',
                labelStyle: TextStyle(color: th.textSub),
                filled: true,
                fillColor: th.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.error),
                ),
              ),
            ),
            if (widget.requiresPassword) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: th.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Current password',
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: th.textSub)),
        ),
        TextButton(
          onPressed: _canDelete
              ? () => Navigator.pop(
                    context,
                    _DeletionConfirmation(
                      password: widget.requiresPassword
                          ? _passwordController.text
                          : null,
                    ),
                  )
              : null,
          child: const Text(
            'Delete Permanently',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}
