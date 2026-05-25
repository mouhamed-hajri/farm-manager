import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../models/animal.dart';
import '../../models/female_rating.dart';
import '../../providers/core_providers.dart';

class FemaleRankingScreen extends ConsumerWidget {
  const FemaleRankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final rankingAsync = ref.watch(femaleRankingProvider(user.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Classement femelles')),
      body: rankingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (ranking) => ranking.isEmpty
            ? const Center(
                child: Text('Aucune femelle enregistrée',
                    style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ranking.length,
                itemBuilder: (ctx, i) {
                  final (animal, rating) = ranking[i];
                  return _RankCard(
                    rank: i + 1,
                    animal: animal,
                    rating: rating,
                  );
                },
              ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.rank,
    required this.animal,
    required this.rating,
  });

  final int rank;
  final Animal animal;
  final FemaleRating? rating;

  @override
  Widget build(BuildContext context) {
    final hasRating = rating?.composite != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: hasRating ? null : Colors.grey[900],
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                hasRating ? '#$rank' : '—',
                style: TextStyle(
                  color: hasRating ? Colors.amber : Colors.grey[600],
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
        subtitle: hasRating
            ? Text(
                _subtitle(rating!),
                style: const TextStyle(fontSize: 11),
              )
            : Text('Pas encore notée',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        trailing: hasRating
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StarRow(score: rating!.composite!, size: 14),
                  Text(
                    rating!.composite!.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.green),
                  ),
                ],
              )
            : null,
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
