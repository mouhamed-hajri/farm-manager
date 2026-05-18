import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/animal.dart';
import '../../providers/animal_provider.dart';
import '../../providers/species_provider.dart';
import '../../theme/app_theme.dart';

class SpeciesGridScreen extends ConsumerWidget {
  const SpeciesGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speciesAsync = ref.watch(speciesListProvider);
    final animalsAsync = ref.watch(allAnimalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animaux'),
        automaticallyImplyLeading: false,
      ),
      body: speciesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (species) {
          final animals = animalsAsync.asData?.value ?? const [];
          final activeCounts = <String, int>{};
          for (final a in animals) {
            if (a.status == AnimalStatus.active) {
              activeCounts[a.speciesId] = (activeCounts[a.speciesId] ?? 0) + 1;
            }
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: species.length + 1,
            itemBuilder: (context, i) {
              if (i == species.length) {
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/animals/species/new'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey[400]!,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Nouvelle espèce',
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }
              final s = species[i];
              final count = activeCounts[s.id] ?? 0;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/animals/species/${s.id}'),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.3)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.iconEmoji,
                              style: const TextStyle(fontSize: 48)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(s.nameFr,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(s.nameAr,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Text(s.idPrefix,
                          style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Colors.grey[600])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
