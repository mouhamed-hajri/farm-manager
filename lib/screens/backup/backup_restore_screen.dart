import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/core_providers.dart';
import '../../providers/sync_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/big_button.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState
    extends ConsumerState<BackupRestoreScreen> {
  String? _lastBackupDate;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        ref.read(syncStateProvider.notifier).refreshPendingCount());
  }

  Future<void> _loadLastBackup() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final date = await ref.read(firebaseServiceProvider).getLastBackupDate(user.uid);
    if (mounted) setState(() => _lastBackupDate = date);
  }

  Future<void> _backup() async {
    await ref.read(syncStateProvider.notifier).sync();
    await ref.read(syncStateProvider.notifier).refreshPendingCount();
    await _loadLastBackup();
    if (mounted) {
      final s = ref.read(syncStateProvider);
      final msg = s.status == SyncStatus.success
          ? (s.lastUploadedCount > 0
              ? '${s.lastUploadedCount} éléments synchronisés'
              : 'Tout est à jour')
          : 'Échec : ${s.errorMessage ?? ""}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor:
            s.status == SyncStatus.success ? AppColors.green : AppColors.red,
      ));
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer depuis le cloud ?'),
        content: const Text(
            'Cela télécharge toutes vos données du cloud. Les données locales en conflit seront écrasées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue, foregroundColor: Colors.white),
              child: const Text('Restaurer')),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref.read(syncStateProvider.notifier).restore();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.success
            ? '${result.restoredAnimals} animaux, ${result.restoredExpenses} dépenses restaurés'
            : 'Échec : ${result.error ?? ""}'),
        backgroundColor: result.success ? AppColors.green : AppColors.red,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);
    final isBusy = syncState.status == SyncStatus.syncing;

    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(syncState),
          const SizedBox(height: 24),
          const Text('Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          BigButton(
            label: 'Sauvegarder maintenant',
            icon: Icons.cloud_upload,
            color: AppColors.green,
            isLoading: isBusy,
            onPressed: isBusy ? null : _backup,
          ),
          const SizedBox(height: 12),
          BigButton(
            label: 'Restaurer depuis le cloud',
            icon: Icons.cloud_download,
            color: AppColors.blue,
            isLoading: isBusy,
            onPressed: isBusy ? null : _restore,
          ),
        ],
      ),
    );
  }

  Widget _statusCard(SyncState s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statut',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _row(Icons.cloud_done, 'Dernière sauvegarde',
                _lastBackupDate ?? 'Jamais',
                _lastBackupDate != null ? AppColors.green : Colors.grey),
            const SizedBox(height: 8),
            _row(Icons.pending, 'En attente',
                '${s.pendingCount}',
                s.pendingCount > 0 ? AppColors.blue : AppColors.green),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Color color) => Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text('$label : ', style: TextStyle(color: Colors.grey[600])),
          Expanded(
              child: Text(value,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color))),
        ],
      );
}
