import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../models/animal.dart';
import '../../models/female_rating.dart';
import '../../models/species.dart';
import '../../providers/core_providers.dart';
import '../../providers/species_provider.dart';

class FemaleRankingScreen extends ConsumerWidget {
  const FemaleRankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final rankingAsync = ref.watch(femaleRankingProvider(user.uid));
    final speciesAsync = ref.watch(speciesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Classement femelles')),
      body: rankingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (ranking) {
          // Keep only rated females
          final rated = ranking
              .where((r) => r.$2?.composite != null)
              .toList();

          if (rated.isEmpty) {
            return const Center(
              child: Text('Aucune femelle notée pour l\'instant',
                  style: TextStyle(color: Colors.grey)));
          }

          // Build species name map
          final speciesMap = <String, Species>{};
          speciesAsync.whenData((list) {
            for (final s in list) speciesMap[s.id] = s;
          });

          // Group by speciesId, preserving sort order (already sorted by composite desc)
          final groups = <String, List<(Animal, FemaleRating)>>{};
          final speciesOrder = <String>[];
          for (final (animal, rating) in rated) {
            if (!groups.containsKey(animal.speciesId)) {
              groups[animal.speciesId] = [];
              speciesOrder.add(animal.speciesId);
            }
            groups[animal.speciesId]!.add((animal, rating!));
          }

          // Build flat item list: header + cards per species
          final items = <_Item>[];
          for (final speciesId in speciesOrder) {
            final group = groups[speciesId]!;
            final species = speciesMap[speciesId];
            items.add(_Item.header(species?.nameFr ?? speciesId));
            for (int i = 0; i < group.length; i++) {
              final (animal, rating) = group[i];
              items.add(_Item.card(i + 1, animal, rating));
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              if (item.isHeader) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    item.header!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      letterSpacing: 0.8,
                    ),
                  ),
                );
              }
              return _RankCard(
                rank: item.rank!,
                animal: item.animal!,
                rating: item.rating!,
              );
            },
          );
        },
      ),
    );
  }
}

class _Item {
  _Item.header(String h) : isHeader = true, header = h, rank = null, animal = null, rating = null;
  _Item.card(int r, Animal a, FemaleRating rt) : isHeader = false, header = null, rank = r, animal = a, rating = rt;

  final bool isHeader;
  final String? header;
  final int? rank;
  final Animal? animal;
  final FemaleRating? rating;
}

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.rank,
    required this.animal,
    required this.rating,
  });

  final int rank;
  final Animal animal;
  final FemaleRating rating;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            _AnimalAvatar(animal: animal),
          ],
        ),
        title: Text(animal.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          _subtitle(rating),
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StarRow(score: rating.composite!, size: 14),
            Text(
              rating.composite!.toStringAsFixed(1),
              style: const TextStyle(fontSize: 11, color: Colors.green),
            ),
          ],
        ),
        onTap: () {},
      ),
    );
  }

  String _subtitle(FemaleRating r) {
    final parts = <String>[];
    if (r.birthsPerYear != null) {
      parts.add('${r.birthsPerYear!.toStringAsFixed(1)}/an');
    }
    if (r.survivalRate != null) {
      parts.add('${(r.survivalRate! * 100).toStringAsFixed(0)}% survie');
    }
    return parts.join(' · ');
  }
}

class _AnimalAvatar extends StatelessWidget {
  const _AnimalAvatar({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context) {
    if (animal.photoLocalPath != null) {
      final file = File(animal.photoLocalPath!);
      return CircleAvatar(
        radius: 18,
        backgroundImage: FileImage(file),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.green,
      child: Text(
        animal.farmId.isNotEmpty ? animal.farmId[0] : '?',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.score, this.size = 13});
  final double score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final full = score.floor();
    final hasHalf = (score - full) >= 0.25 && (score - full) < 0.75;
    final empty = 5 - full - (hasHalf ? 1 : 0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < full; i++)
          Icon(Icons.star, color: Colors.amber, size: size),
        if (hasHalf)
          Icon(Icons.star_half, color: Colors.amber, size: size),
        for (int i = 0; i < empty; i++)
          Icon(Icons.star_border, color: Colors.grey[400], size: size),
      ],
    );
  }
}
