import 'package:flutter/material.dart';
import '../models/crop.dart';
import '../theme/app_theme.dart';

/// A preset value the picker can return. When the user taps a tile, the parent
/// gets a [CropPreset] which it uses to pre-fill the form fields.
class CropPreset {
  const CropPreset({
    required this.nameFr,
    required this.nameAr,
    required this.iconEmoji,
    required this.kind,
    required this.lifecycle,
  });

  final String nameFr;
  final String nameAr;
  final String iconEmoji;
  final String kind;       // CropKind.tree / crop / vegetable / other
  final String lifecycle;  // CropLifecycle.perennial / annual

  /// Built-in catalog. The user can always pick "Autre" and type a custom name.
  static const catalog = <CropPreset>[
    CropPreset(
        nameFr: 'Olives', nameAr: 'زيتون', iconEmoji: '🫒',
        kind: CropKind.tree, lifecycle: CropLifecycle.perennial),
    CropPreset(
        nameFr: 'Oranges', nameAr: 'برتقال', iconEmoji: '🍊',
        kind: CropKind.tree, lifecycle: CropLifecycle.perennial),
    CropPreset(
        nameFr: 'Citrons', nameAr: 'ليمون', iconEmoji: '🍋',
        kind: CropKind.tree, lifecycle: CropLifecycle.perennial),
    CropPreset(
        nameFr: 'Grenades', nameAr: 'رمان', iconEmoji: '🍎',
        kind: CropKind.tree, lifecycle: CropLifecycle.perennial),
    CropPreset(
        nameFr: 'Figues', nameAr: 'تين', iconEmoji: '🌳',
        kind: CropKind.tree, lifecycle: CropLifecycle.perennial),
    CropPreset(
        nameFr: 'Blé', nameAr: 'قمح', iconEmoji: '🌾',
        kind: CropKind.crop, lifecycle: CropLifecycle.annual),
    CropPreset(
        nameFr: 'Orge', nameAr: 'شعير', iconEmoji: '🌾',
        kind: CropKind.crop, lifecycle: CropLifecycle.annual),
  ];
}

/// A 2-column grid of preset crops + a final "Autre" tile that lets the user
/// enter a custom name.
class CropKindGridPicker extends StatelessWidget {
  const CropKindGridPicker({
    super.key,
    required this.selectedNameFr,
    required this.onPick,
    required this.onCustomTap,
  });

  /// Used to highlight the currently-selected preset (matched by nameFr).
  final String selectedNameFr;

  /// Fires when the user taps one of the preset tiles.
  final ValueChanged<CropPreset> onPick;

  /// Fires when the user taps "Autre" — parent should reveal manual fields.
  final VoidCallback onCustomTap;

  @override
  Widget build(BuildContext context) {
    final isCustom = selectedNameFr.isNotEmpty &&
        !CropPreset.catalog.any((p) => p.nameFr == selectedNameFr);

    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2.4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ...CropPreset.catalog.map((p) {
          final selected = p.nameFr == selectedNameFr;
          return _tile(
            label: p.nameFr,
            emoji: p.iconEmoji,
            selected: selected,
            onTap: () => onPick(p),
          );
        }),
        _tile(
          label: 'Autre',
          emoji: '➕',
          selected: isCustom,
          onTap: onCustomTap,
        ),
      ],
    );
  }

  Widget _tile({
    required String label,
    required String emoji,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? AppColors.green.withValues(alpha: 0.15)
          : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.green : Colors.grey.shade300,
              width: selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? AppColors.green : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
