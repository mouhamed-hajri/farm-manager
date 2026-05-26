import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/animal.dart';
import '../../models/sale.dart';
import '../../providers/core_providers.dart';
import '../../theme/app_theme.dart';

class FatherSelectionScreen extends ConsumerStatefulWidget {
  const FatherSelectionScreen({
    super.key,
    required this.userId,
    required this.speciesId,
    required this.eventDate,
  });

  final String userId;
  final String speciesId;

  /// The date of the breeding event. Males who were dead, sold, or not yet
  /// born at this date are filtered out.
  final DateTime eventDate;

  @override
  ConsumerState<FatherSelectionScreen> createState() =>
      _FatherSelectionScreenState();
}

class _FatherSelectionScreenState extends ConsumerState<FatherSelectionScreen> {
  String _search = '';
  late Future<List<_AvailableMale>> _malesFuture;

  String get _eventDateStr =>
      widget.eventDate.toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _malesFuture = _loadAvailableMales();
  }

  Future<List<_AvailableMale>> _loadAvailableMales() async {
    final animalRepo = ref.read(animalRepositoryProvider);
    final saleRepo = ref.read(saleRepositoryProvider);

    final males = await animalRepo.getMalesForSpecies(
        widget.userId, widget.speciesId);
    final allSales = await saleRepo.watchAllSales(widget.userId).first;
    final saleDateByAnimal = <String, String>{
      for (final s in allSales)
        if (s.linkedAnimalId != null && s.scope == SaleScope.animal)
          s.linkedAnimalId!: s.saleDate,
    };

    final out = <_AvailableMale>[];
    for (final m in males) {
      // Not born yet at event date → exclude.
      if (m.birthDate != null && m.birthDate!.compareTo(_eventDateStr) > 0) {
        continue;
      }

      if (m.status == AnimalStatus.dead) {
        final d = m.deathDate;
        if (d == null) {
          // Death date missing → show conservatively.
          out.add(_AvailableMale(animal: m, offDate: null, offType: 'dead'));
        } else if (d.compareTo(_eventDateStr) > 0) {
          out.add(_AvailableMale(animal: m, offDate: d, offType: 'dead'));
        }
        // Died on or before event date → exclude.
        continue;
      }

      if (m.status == AnimalStatus.sold) {
        final d = saleDateByAnimal[m.id];
        if (d == null) {
          // Sale date missing → show conservatively.
          out.add(_AvailableMale(animal: m, offDate: null, offType: 'sold'));
        } else if (d.compareTo(_eventDateStr) > 0) {
          out.add(_AvailableMale(animal: m, offDate: d, offType: 'sold'));
        }
        // Sold on or before event date → exclude.
        continue;
      }

      // Active
      out.add(_AvailableMale(animal: m, offDate: null, offType: 'active'));
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir le père'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              'Mâles disponibles au $_eventDateStr',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // "Père inconnu" pinned at top
          InkWell(
            onTap: () => Navigator.pop(context, null),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey,
                    radius: 22,
                    child: Icon(Icons.help_outline, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text('Père inconnu',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const Divider(height: 0),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Chercher par ID ou surnom…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<_AvailableMale>>(
              future: _malesFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var males = snap.data ?? [];
                if (_search.isNotEmpty) {
                  males = males
                      .where((m) =>
                          m.animal.farmId.toLowerCase().contains(_search) ||
                          (m.animal.nickname
                                  ?.toLowerCase()
                                  .contains(_search) ??
                              false))
                      .toList();
                }
                males.sort((a, b) {
                  final ba = a.animal.birthDate;
                  final bb = b.animal.birthDate;
                  if (ba == null && bb == null) return 0;
                  if (ba == null) return -1;
                  if (bb == null) return 1;
                  return ba.compareTo(bb);
                });
                if (males.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aucun mâle disponible au $_eventDateStr.\n\n'
                        'Changez la date d\'accouplement ou ajoutez un mâle.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: males.length,
                  itemBuilder: (_, i) => _MaleCard(
                    male: males[i],
                    onTap: () => Navigator.pop(context, males[i].animal),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal wrapper carrying the off-farm date (if any) alongside the animal.
class _AvailableMale {
  _AvailableMale({
    required this.animal,
    required this.offDate,
    required this.offType,
  });
  final Animal animal;

  /// 'YYYY-MM-DD' death or sale date, null when active or when data missing.
  final String? offDate;

  /// 'active', 'dead', or 'sold'.
  final String offType;
}

class _MaleCard extends StatelessWidget {
  const _MaleCard({required this.male, required this.onTap});
  final _AvailableMale male;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isInactive = male.offType != 'active';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isInactive ? 0.7 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo area
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: _photo(),
                ),
              ),
              // Info area
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      male.animal.farmId,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (male.animal.nickname?.isNotEmpty ?? false)
                      Text(
                        male.animal.nickname!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    Row(
                      children: [
                        if (male.animal.ageLabel != null)
                          Flexible(
                            child: Text(male.animal.ageLabel!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ),
                      ],
                    ),
                    if (isInactive) ...[
                      const SizedBox(height: 2),
                      _statusBadge(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge() {
    final isSold = male.offType == 'sold';
    final color = isSold ? AppColors.blue : AppColors.red;
    final label = male.offDate == null
        ? (isSold ? 'Vendu' : 'Décédé')
        : (isSold ? 'Vendu ${male.offDate}' : 'Décédé ${male.offDate}');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _photo() {
    if (male.animal.photoCloudUrl != null) {
      return Image.network(
        male.animal.photoCloudUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _placeholder(),
      );
    }
    if (male.animal.photoLocalPath != null) {
      return Image.file(
        File(male.animal.photoLocalPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: AppColors.green.withValues(alpha: 0.08),
        child: const Center(
          child: Text('♂', style: TextStyle(fontSize: 44, color: AppColors.green)),
        ),
      );
}
