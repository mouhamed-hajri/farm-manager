import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/animal.dart';
import '../../models/family_tree_node.dart';
import '../../models/species.dart';
import '../../providers/animal_provider.dart';
import '../../providers/species_provider.dart';
import '../../theme/app_theme.dart';

const double _kNodeWidth = 120.0;
const double _kNodeGap = 32.0;
const double _kConnH = 40.0;
const double _kMateSize = 60.0;

// ─── Screen ──────────────────────────────────────────────────────────────────

class FamilyTreeScreen extends ConsumerWidget {
  const FamilyTreeScreen({super.key, required this.speciesId});
  final String speciesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speciesAsync = ref.watch(speciesByIdProvider(speciesId));
    final animalsAsync = ref.watch(animalsBySpeciesProvider(speciesId));
    final species = speciesAsync.asData?.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Arbre — ${species?.nameFr ?? '…'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Légende',
            onPressed: () => _showLegend(context),
          ),
        ],
      ),
      body: animalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (animals) {
          final hasLinks = animals.any(
            (a) => a.motherId != null && animals.any((b) => b.id == a.motherId),
          );
          if (animals.length < 2 || !hasLinks) {
            return _EmptyState(emoji: species?.iconEmoji ?? '🐾');
          }
          final roots = FamilyTreeBuilder.build(animals);
          if (roots.isEmpty) {
            return _EmptyState(emoji: species?.iconEmoji ?? '🐾');
          }
          return InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(300),
            minScale: 0.2,
            maxScale: 3.0,
            constrained: false,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < roots.length; i++) ...[
                    if (i > 0) const SizedBox(width: _kNodeGap * 3),
                    _FamilyUnit(node: roots[i], species: species),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLegend(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Légende'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegendRow(color: AppColors.green, label: 'Actif'),
            _LegendRow(
                color: const Color(0xFFE65100), label: 'Vendu'),
            _LegendRow(color: Colors.grey, label: 'Mort/e'),
            const SizedBox(height: 10),
            const Text(
              'Bordure ambrée = bélier / taureau désigné',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Appuyez sur un animal pour voir sa fiche.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ]),
      );
}

// ─── FamilyUnit ───────────────────────────────────────────────────────────────

class _FamilyUnit extends StatelessWidget {
  const _FamilyUnit({required this.node, this.species});
  final FamilyTreeNode node;
  final Species? species;

  @override
  Widget build(BuildContext context) {
    final totalW = FamilyTreeBuilder.subtreeWidth(node);

    final childWidgets = <Widget>[
      ...node.maleOffspring.map((m) => _NodeCard(animal: m, species: species)),
      ...node.femaleSubtrees
          .map((sub) => _FamilyUnit(node: sub, species: species)),
    ];

    final childWidths = [
      ...List.filled(node.maleOffspring.length, _kNodeWidth),
      ...node.femaleSubtrees.map(FamilyTreeBuilder.subtreeWidth),
    ];

    return SizedBox(
      width: totalW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Parent row ──
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NodeCard(animal: node.female, species: species),
                if (node.mate != null) ...[
                  const SizedBox(width: 8),
                  _MateNode(mate: node.mate!, species: species),
                ],
              ],
            ),
          ),
          // ── Connector + children ──
          if (childWidgets.isNotEmpty) ...[
            SizedBox(
              width: totalW,
              height: _kConnH,
              child: CustomPaint(
                painter: _LinePainter(
                  totalWidth: totalW,
                  childWidths: childWidths,
                  gap: _kNodeGap,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < childWidgets.length; i++) ...[
                  if (i > 0) const SizedBox(width: _kNodeGap),
                  childWidgets[i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── LinePainter ─────────────────────────────────────────────────────────────

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.totalWidth,
    required this.childWidths,
    required this.gap,
  });

  final double totalWidth;
  final List<double> childWidths;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final parentX = size.width / 2;
    final midY = size.height / 2;

    // Vertical drop from parent down to mid
    canvas.drawLine(Offset(parentX, 0), Offset(parentX, midY), paint);

    if (childWidths.length == 1) {
      // Single child: straight line
      final childCx = (totalWidth - childWidths.first) / 2 + childWidths.first / 2;
      canvas.drawLine(Offset(parentX, midY), Offset(childCx, midY), paint);
      canvas.drawLine(Offset(childCx, midY), Offset(childCx, size.height), paint);
      return;
    }

    // Compute child centers
    double cursor = 0;
    final centers = <double>[];
    for (int i = 0; i < childWidths.length; i++) {
      centers.add(cursor + childWidths[i] / 2);
      cursor += childWidths[i] + (i < childWidths.length - 1 ? gap : 0);
    }
    final rowWidth = cursor;
    final offsetX = (totalWidth - rowWidth) / 2;
    final adjusted = centers.map((c) => c + offsetX).toList();

    // Horizontal crossbar
    canvas.drawLine(
      Offset(adjusted.first, midY),
      Offset(adjusted.last, midY),
      paint,
    );

    // Vertical drop to each child
    for (final cx in adjusted) {
      canvas.drawLine(Offset(cx, midY), Offset(cx, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.totalWidth != totalWidth || old.childWidths.length != childWidths.length;
}

// ─── NodeCard ─────────────────────────────────────────────────────────────────

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.animal, this.species});
  final Animal animal;
  final Species? species;

  @override
  Widget build(BuildContext context) {
    final isMale = animal.gender == AnimalGender.male;
    final statusColor = _statusColor(animal.status);

    return GestureDetector(
      onTap: () => context.push('/animals/animal/${animal.id}'),
      child: SizedBox(
        width: _kNodeWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 3),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(child: _photoWidget()),
            ),
            const SizedBox(height: 5),
            Text(
              isMale ? '♂' : '♀',
              style: TextStyle(
                fontSize: 13,
                color: isMale ? AppColors.blue : Colors.pink.shade400,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              animal.farmId,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (animal.nickname?.isNotEmpty == true)
              Text(
                animal.nickname!,
                style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _photoWidget() {
    if (animal.photoLocalPath != null) {
      final f = File(animal.photoLocalPath!);
      if (f.existsSync()) {
        return Image.file(f, fit: BoxFit.cover);
      }
    }
    if (animal.photoCloudUrl?.isNotEmpty == true) {
      return CachedNetworkImage(
        imageUrl: animal.photoCloudUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => _emojiBox(),
      );
    }
    return _emojiBox();
  }

  Widget _emojiBox() => Container(
        color: AppColors.green.withValues(alpha: 0.08),
        child: Center(
          child: Text(
            species?.iconEmoji ?? '🐾',
            style: const TextStyle(fontSize: 28),
          ),
        ),
      );

  static Color _statusColor(String status) {
    switch (status) {
      case AnimalStatus.sold:
        return const Color(0xFFE65100);
      case AnimalStatus.dead:
        return Colors.grey;
      default:
        return AppColors.green;
    }
  }
}

// ─── MateNode ─────────────────────────────────────────────────────────────────

class _MateNode extends StatelessWidget {
  const _MateNode({required this.mate, this.species});
  final Animal mate;
  final Species? species;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        mate.isBreeder ? Colors.amber.shade700 : AppColors.blue.withValues(alpha: 0.5);
    final borderWidth = mate.isBreeder ? 3.0 : 2.0;

    return GestureDetector(
      onTap: () => context.push('/animals/animal/${mate.id}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _kMateSize,
            height: _kMateSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: borderWidth),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.3),
                  blurRadius: 4,
                ),
              ],
            ),
            child: ClipOval(child: _photoWidget()),
          ),
          const SizedBox(height: 3),
          Text(
            '♂',
            style: TextStyle(
              fontSize: 11,
              color: mate.isBreeder ? Colors.amber.shade700 : AppColors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            mate.farmId,
            style: const TextStyle(fontSize: 8),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _photoWidget() {
    if (mate.photoLocalPath != null) {
      final f = File(mate.photoLocalPath!);
      if (f.existsSync()) return Image.file(f, fit: BoxFit.cover);
    }
    if (mate.photoCloudUrl?.isNotEmpty == true) {
      return CachedNetworkImage(
        imageUrl: mate.photoCloudUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => _emojiBox(),
      );
    }
    return _emojiBox();
  }

  Widget _emojiBox() => Container(
        color: AppColors.blue.withValues(alpha: 0.07),
        child: Center(
          child: Text(
            species?.iconEmoji ?? '🐾',
            style: const TextStyle(fontSize: 20),
          ),
        ),
      );
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            const Text(
              'Pas encore d\'arbre généalogique',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Renseignez la mère des animaux nés sur l\'élevage pour visualiser l\'arbre familial.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      );
}
