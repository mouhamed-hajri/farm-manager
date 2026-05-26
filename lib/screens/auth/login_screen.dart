import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/l10n.dart';
import '../../providers/core_providers.dart';
import '../../widgets/big_button.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(firebaseAuthProvider).signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() { _error = _authErrorMsg(e.code); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authErrorMsg(String code) {
    final l = context.l10n;
    switch (code) {
      case 'user-not-found': return l.loginErrUserNotFound;
      case 'wrong-password': return l.loginErrWrongPassword;
      case 'invalid-email': return l.loginErrInvalidEmail;
      case 'too-many-requests': return l.loginErrTooManyRequests;
      default: return l.loginErrGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.agriculture, size: 80, color: AppColors.green),
                  const SizedBox(height: 12),
                  Text(l.loginTitle,
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.green)),
                  const SizedBox(height: 8),
                  Text(l.loginSubtitle,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l.loginEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? l.loginEmailRequired : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: l.loginPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? l.loginPasswordShort : null,
                  ),
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
                          const Icon(Icons.error_outline, color: AppColors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!,
                              style: const TextStyle(color: AppColors.red))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  BigButton(
                    label: l.loginButton,
                    icon: Icons.login,
                    onPressed: _login,
                    isLoading: _loading,
                    color: AppColors.green,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        _loading ? null : () => context.go('/signup'),
                    child: Text(l.loginNoAccount),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
