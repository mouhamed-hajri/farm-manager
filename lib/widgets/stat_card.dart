import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.onTap,
    this.delta,
    this.deltaPositive,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  // Optional "vs last month" style subline, e.g. "+45 TND vs mois dernier"
  final String? delta;
  final bool? deltaPositive;

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppColors.blue;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null)
                    Icon(icon, color: cardColor, size: 22),
                  if (icon != null) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cardColor,
                ),
              ),
              if (delta != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      (deltaPositive ?? true)
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 12,
                      color: (deltaPositive ?? true)
                          ? AppColors.green
                          : AppColors.red,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        delta!,
                        style: TextStyle(
                          fontSize: 11,
                          color: (deltaPositive ?? true)
                              ? AppColors.green
                              : AppColors.red,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
