import 'package:flutter/material.dart';

import '../models/inventory_item.dart';

class InventoryCard extends StatelessWidget {
  const InventoryCard({super.key, required this.item, this.onTap});

  final InventoryItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemCode,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.itemName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${item.quantity} ${item.unit}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: item.isLowStock
                          ? colors.errorContainer
                          : colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.isLowStock ? '재고 부족' : '정상',
                      style: TextStyle(
                        color: item.isLowStock
                            ? colors.onErrorContainer
                            : colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '안전재고 ${item.safetyStock} ${item.unit}',
                style: theme.textTheme.bodyMedium,
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 20,
                runSpacing: 6,
                children: [
                  Text('LOT  ${item.lotNo}'),
                  Text('위치  ${item.location}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
