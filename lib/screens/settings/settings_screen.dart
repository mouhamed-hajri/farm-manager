import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_settings.dart';
import '../../providers/core_providers.dart';
import '../../providers/language_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final settings = ref.watch(settingsProvider).asData?.value;
    final isAr = locale.languageCode == 'ar';
    final isSimple = settings?.isSimpleMode ?? true;

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
            trailing: Switch(
              value: isAr,
              onChanged: (v) => ref
                  .read(languageProvider.notifier)
                  .setLanguage(v ? 'ar' : 'fr'),
            ),
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
          if (ref.watch(currentUserProvider)?.email != null)
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(ref.watch(currentUserProvider)!.email!),
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
}
