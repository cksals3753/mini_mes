import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/inventory_item.dart';
import '../repositories/inventory_repository.dart' as repository;
import '../repositories/mock_inventory_repository.dart';

final inventoryRepositoryProvider = Provider<repository.InventoryRepository>(
  (ref) => MockInventoryRepository(),
);

final inventoryProvider =
    AsyncNotifierProvider<InventoryNotifier, List<InventoryItem>>(
      InventoryNotifier.new,
      // 오류는 화면에서 표시하고 사용자가 명시적으로 재시도한다.
      retry: (retryCount, error) => null,
    );

class InventoryNotifier extends AsyncNotifier<List<InventoryItem>> {
  static const maxQuantity = repository.maxInventoryQuantity;
  bool _isSubmitting = false;

  @override
  Future<List<InventoryItem>> build() =>
      ref.watch(inventoryRepositoryProvider).fetchInventory();

  String? validateStockChange(String id, int amount, bool isIncoming) {
    final items = state.asData?.value;
    if (items == null) return '재고 조회가 완료된 후 다시 시도해 주세요.';
    return repository.validateStockChange(items, id, amount, isIncoming);
  }

  Future<String?> changeStock(String id, int amount, bool isIncoming) async {
    if (_isSubmitting) return '이미 처리 중입니다.';
    final error = validateStockChange(id, amount, isIncoming);
    if (error != null) return error;
    _isSubmitting = true;
    final store = ref.read(inventoryRepositoryProvider);
    try {
      final items = await store.changeStock(id, amount, isIncoming);
      if (ref.mounted) state = AsyncData(List.unmodifiable(items));
      return null;
    } on repository.InventoryRepositoryException catch (error) {
      return error.message;
    } catch (_) {
      return '입출고 처리에 실패했습니다. 다시 시도해 주세요.';
    } finally {
      _isSubmitting = false;
    }
  }
}
