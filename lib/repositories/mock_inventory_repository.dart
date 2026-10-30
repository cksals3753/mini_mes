import '../data/mock_inventory.dart';
import '../models/inventory_item.dart';
import 'inventory_repository.dart';

class MockInventoryRepository implements InventoryRepository {
  MockInventoryRepository({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;
  List<InventoryItem> _items = List.unmodifiable(mockInventory);

  // 테스트에서 다음 요청 한 번만 실패시키는 설정.
  bool failNextFetch = false;
  bool failNextChange = false;

  @override
  Future<List<InventoryItem>> fetchInventory() async {
    await Future<void>.delayed(delay);
    if (failNextFetch) {
      failNextFetch = false;
      throw const InventoryRepositoryException('재고 조회에 실패했습니다.');
    }
    return _items;
  }

  @override
  Future<List<InventoryItem>> changeStock(
    String id,
    int amount,
    bool isIncoming,
  ) async {
    await Future<void>.delayed(delay);
    if (failNextChange) {
      failNextChange = false;
      throw const InventoryRepositoryException('입출고 처리에 실패했습니다. 다시 시도해 주세요.');
    }
    // 지연 이후 최신 저장소를 기준으로 검증하므로 동시 요청도 음수 재고를 만들지 않는다.
    final error = validateStockChange(_items, id, amount, isIncoming);
    if (error != null) throw InventoryRepositoryException(error);
    _items = List.unmodifiable([
      for (final item in _items)
        if (item.id == id)
          item.copyWith(
            quantity: item.quantity + (isIncoming ? amount : -amount),
          )
        else
          item,
    ]);
    return _items;
  }
}
