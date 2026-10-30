import 'package:flutter/material.dart';

import '../models/inventory_item.dart';

/// 검색된 품목의 모든 LOT·위치를 합산한다. 동일 품목의 단위는 같다고 가정한다.
class ItemStockTotals extends StatelessWidget {
  const ItemStockTotals({super.key, required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<InventoryItem>>{};
    for (final item in items) {
      groups.putIfAbsent(item.itemCode, () => []).add(item);
    }
    if (groups.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('품목별 재고 합계'),
      subtitle: Text('${groups.length}개 품목 · 검색 결과 기준'),
      children: [
        for (final entry in groups.entries)
          ListTile(
            key: ValueKey('total-${entry.key}'),
            contentPadding: EdgeInsets.zero,
            title: Text('${entry.key} · ${entry.value.first.itemName}'),
            subtitle: Text(
              '합계 ${entry.value.fold<int>(0, (sum, item) => sum + item.quantity)} ${entry.value.first.unit} · ${entry.value.length}개 재고 기록',
            ),
          ),
      ],
    );
  }
}
