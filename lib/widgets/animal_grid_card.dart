import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/animal.dart';
import '../models/female_rating.dart';
import '../models/species.dart';
import '../providers/core_providers.dart';
import '../theme/app_theme.dart';

class AnimalGridCard extends ConsumerWidget {
  const AnimalGridCard({super.key, required this.animal, required this.species});

  final Animal animal;
  final Species? species;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FemaleRating? rating = animal.gender == AnimalGender.female
        ? ref.watch(femaleRatingProvider(animal.id)).asData?.value
        : null;
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (animal.status) {
      case AnimalStatus.sold:
        statusColor = AppColors.blue;
        statusLabel = 'Vendu';
        statusIcon = Icons.sell;
        break;
      case AnimalStatus.dead:
        statusColor = AppColors.red;
        statusLabel = 'Décédé';
        statusIcon = Icons.dangerous;
        break;
      default:
        statusColor = AppColors.green;
        statusLabel = 'Actif';
        statusIcon = Icons.check_circle;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/animals/animal/${animal.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Square photo at top
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _photo(),
                    // Gender badge top-right
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          animal.gender == AnimalGender.male ? '♂' : '♀',
                          style: TextStyle(
                            fontSize: 16,
                            color: animal.gender == AnimalGender.male
                                ? AppColors.blue
                                : Colors.pink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Status chip bottom-left
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon,
                                size: 11, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              statusLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Star rating badge bottom-right (females only)
                    if (rating?.composite != null)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                rating!.composite!.toStringAsFixed(1),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Caption
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          animal.farmId,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (animal.ageLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            animal.ageLabel!,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                          ),
                        ),
                    ],
                  ),
                  if (animal.nickname?.isNotEmpty ?? false)
                    Text(
                      animal.nickname!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo() {
    if (animal.photoLocalPath != null &&
        File(animal.photoLocalPath!).existsSync()) {
      return Image.file(File(animal.photoLocalPath!), fit: BoxFit.cover);
    }
    if (animal.photoCloudUrl?.isNotEmpty ?? false) {
      return CachedNetworkImage(
        imageUrl: animal.photoCloudUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(
            child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))),
        errorWidget: (_, __, ___) => _emojiPlaceholder(),
      );
    }
    return _emojiPlaceholder();
  }

  Widget _emojiPlaceholder() => Container(
        color: AppColors.green.withValues(alpha: 0.1),
        child: Center(
          child: Text(
            species?.iconEmoji ?? '🐾',
            style: const TextStyle(fontSize: 56),
          ),
        ),
      );
}
