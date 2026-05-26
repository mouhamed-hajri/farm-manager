import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/l10n.dart';
import '../../providers/core_providers.dart';
import '../../widgets/big_button.dart';
import '../../theme/app_theme.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _checking = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Send a fresh link on arrival so the user always has one to click,
    // whether they got here from signup or from logging into an account that
    // was never verified.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendVerification());
  }

  Future<void> _sendVerification() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(firebaseAuthProvider).currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.green,
          content: Text(context.l10n.verifyResent),
        ));
      }
    } catch (_) {
      // Firebase throttles repeated sends — ignore, the earlier link is valid.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.currentUser?.reload();
      if (auth.currentUser?.emailVerified ?? false) {
        if (mounted) context.go('/home');
      } else {
        setState(() => _error = context.l10n.verifyNotYet);
      }
    } catch (e) {
      setState(() => _error = context.l10n.loginErrGeneric);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final email = ref.watch(currentUserProvider)?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_unread_outlined,
                    size: 80, color: AppColors.green),
                const SizedBox(height: 16),
                Text(l.verifyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green)),
                const SizedBox(height: 12),
                Text(l.verifySubtitle(email),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(l.verifyInstructions,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!,
                                style:
                                    const TextStyle(color: AppColors.red))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                BigButton(
                  label: l.verifyCheckButton,
                  icon: Icons.check_circle_outline,
                  onPressed: _checkVerified,
                  isLoading: _checking,
                  color: AppColors.green,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _sending ? null : _sendVerification,
                  icon: const Icon(Icons.refresh),
                  label: Text(l.verifyResendButton),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(firebaseAuthProvider).signOut(),
                  icon: const Icon(Icons.logout, color: AppColors.red),
                  label: Text(l.verifyLogout,
                      style: const TextStyle(color: AppColors.red)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
