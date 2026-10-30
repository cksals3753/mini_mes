import 'package:flutter/material.dart';

class InventorySummary extends StatelessWidget {
  const InventorySummary({
    super.key,
    required this.total,
    required this.lowStock,
  });

  final int total;
  final int lowStock;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _tile(
            context,
            '전체 재고 기록',
            total,
            colors.primaryContainer,
            colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _tile(
            context,
            '재고 부족',
            lowStock,
            colors.errorContainer,
            colors.onErrorContainer,
          ),
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    String label,
    int count,
    Color background,
    Color foreground,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: foreground)),
          const SizedBox(height: 8),
          Text(
            '$count개',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
