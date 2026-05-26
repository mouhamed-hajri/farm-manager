import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_settings.dart';
import '../../providers/core_providers.dart';
import '../../providers/language_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

final _userPhoneProvider = FutureProvider.autoDispose<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(firebaseServiceProvider).fetchUserPhone(user.uid);
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final settings = ref.watch(settingsProvider).asData?.value;
    final isAr = locale.languageCode == 'ar';
    final isSimple = settings?.isSimpleMode ?? true;
    final user = ref.watch(currentUserProvider);
    final phoneAsync = ref.watch(_userPhoneProvider);

    return Scaffold(
      appBar: AppBar(
          title: const Text('Plus'), automaticallyImplyLeading: false),
      body: ListView(
        children: [
          _section('Données'),
          ListTile(
            leading: const Icon(Icons.pets),
            title: const Text('Gérer les espèces'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/animals'),
          ),
          ListTile(
            leading: const Icon(Icons.grass),
            title: const Text('Gérer les cultures'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/cultures'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('Sauvegarde & restauration'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/backup'),
          ),
          _section('Préférences'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Langue / اللغة'),
            subtitle: Text(isAr ? 'العربية' : 'Français'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguagePicker(context, ref, locale.languageCode),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Mode'),
            subtitle: Text(isSimple
                ? 'Mode Simple — formulaires courts'
                : 'Mode Avancé — tous les champs'),
            trailing: Switch(
              value: !isSimple,
              onChanged: (v) async {
                if (settings == null) return;
                await ref.read(settingsRepositoryProvider).save(
                      settings.copyWith(
                          mode: v ? AppMode.advanced : AppMode.simple),
                    );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Devise'),
            subtitle: Text(settings?.currency ?? 'TND'),
          ),
          _section('Compte'),
          if (user?.email != null)
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(user!.email!),
              subtitle: const Text('Email — non modifiable',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Nom'),
            subtitle: Text(
              (user?.displayName?.isNotEmpty ?? false)
                  ? user!.displayName!
                  : 'Non renseigné',
              style: TextStyle(
                color: (user?.displayName?.isNotEmpty ?? false)
                    ? null
                    : Colors.grey,
              ),
            ),
            trailing: const Icon(Icons.edit, size: 18),
            onTap: () => _editDisplayName(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Téléphone'),
            subtitle: phoneAsync.when(
              loading: () => const Text('Chargement…',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              error: (_, __) => const Text('Erreur',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              data: (phone) => Text(
                (phone?.isNotEmpty ?? false) ? phone! : 'Non renseigné',
                style: TextStyle(
                  color: (phone?.isNotEmpty ?? false) ? null : Colors.grey,
                ),
              ),
            ),
            trailing: const Icon(Icons.edit, size: 18),
            onTap: () => _editPhone(context, ref, phoneAsync.asData?.value),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Modifier le mot de passe'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _changePassword(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.red),
            title: const Text('Se déconnecter',
                style: TextStyle(color: AppColors.red)),
            onTap: () async {
              await ref.read(firebaseAuthProvider).signOut();
            },
          ),
          const SizedBox(height: 24),
          const Center(child: Text('Version 2.0.0', style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editDisplayName(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final controller = TextEditingController(text: user.displayName ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier mon nom'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nom',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await user.updateDisplayName(controller.text.trim());
      await user.reload();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nom mis à jour')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _editPhone(
      BuildContext context, WidgetRef ref, String? current) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final controller = TextEditingController(text: current ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier mon téléphone'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Téléphone',
            hintText: '+216 XX XXX XXX',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      final newPhone = controller.text.trim();
      await ref
          .read(firebaseServiceProvider)
          .updateUserPhone(user.uid, newPhone.isEmpty ? null : newPhone);
      ref.invalidate(_userPhoneProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Téléphone mis à jour')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null || user.email == null) return;
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Modifier le mot de passe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe actuel',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    helperText: '6 caractères minimum',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!,
                      style: const TextStyle(
                          color: AppColors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (newCtrl.text.length < 6) {
                  setLocal(() =>
                      errorText = 'Le mot de passe doit avoir 6 caractères au moins');
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  setLocal(() =>
                      errorText = 'Les deux mots de passe ne correspondent pas');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newCtrl.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour')),
        );
      }
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'wrong-password' || 'invalid-credential' =>
          'Mot de passe actuel incorrect',
        'weak-password' => 'Nouveau mot de passe trop faible',
        'requires-recent-login' =>
          'Reconnectez-vous puis réessayez',
        _ => e.message ?? 'Erreur : ${e.code}',
      };
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
            letterSpacing: 0.8,
          ),
        ),
      );

  void _showLanguagePicker(
      BuildContext context, WidgetRef ref, String current) {
    const languages = [
      ('ar', 'العربية', '🇸🇦'),
      ('fr', 'Français', '🇫🇷'),
      ('en', 'English', '🇬🇧'),
      ('pt', 'Português', '🇧🇷'),
      ('ha', 'Hausa', '🇳🇬'),
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Langue / اللغة',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const Divider(height: 1),
            for (final (code, name, flag) in languages)
              ListTile(
                leading: Text(flag, style: const TextStyle(fontSize: 24)),
                title: Text(name,
                    style: const TextStyle(fontSize: 16)),
                trailing: current == code
                    ? const Icon(Icons.check_circle,
                        color: Colors.green)
                    : null,
                onTap: () {
                  ref
                      .read(languageProvider.notifier)
                      .setLanguage(code);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
