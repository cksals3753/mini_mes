import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inventory_provider.dart';
import '../widgets/inventory_async_status.dart';
import 'inventory_detail_screen.dart';
import '../widgets/inventory_card.dart';
import '../widgets/inventory_summary.dart';
import '../widgets/item_stock_totals.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);
    if (inventory.isLoading || inventory.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('재고 관리')),
        body: InventoryAsyncStatus(
          error: inventory.isLoading ? null : inventory.error,
          onRetry: () => ref.invalidate(inventoryProvider),
        ),
      );
    }
    final items = inventory.requireValue;
    final query = _query.trim().toLowerCase();
    final filteredItems = items
        .where(
          (item) =>
              item.itemCode.toLowerCase().contains(query) ||
              item.itemName.toLowerCase().contains(query),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('재고 관리')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InventorySummary(
                          total: items.length,
                          lowStock: items
                              .where((item) => item.isLowStock)
                              .length,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          decoration: InputDecoration(
                            labelText: '품목코드 또는 품목명 검색',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: '검색어 지우기',
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ItemStockTotals(items: filteredItems),
                        const SizedBox(height: 20),
                        Text(
                          '재고 목록 · ${filteredItems.length}개',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text('각 LOT·위치의 수량이 안전재고 미만이면 재고 부족으로 표시합니다.'),
                      ],
                    ),
                  ),
                ),
                if (filteredItems.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 40),
                          SizedBox(height: 12),
                          Text('검색 결과가 없습니다.'),
                          SizedBox(height: 4),
                          Text('품목코드나 품목명을 다시 확인해 주세요.'),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) => InventoryCard(
                        key: ValueKey(filteredItems[index].id),
                        item: filteredItems[index],
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => InventoryDetailScreen(
                                itemId: filteredItems[index].id,
                              ),
                            ),
                          );
                        },
                      ),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
