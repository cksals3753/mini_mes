import '../models/inventory_item.dart';

abstract interface class InventoryRepository {
  Future<List<InventoryItem>> fetchInventory();
  Future<List<InventoryItem>> changeStock(
    String id,
    int amount,
    bool isIncoming,
  );
}

const maxInventoryQuantity = 9007199254740991;

String? validateStockChange(
  List<InventoryItem> items,
  String id,
  int amount,
  bool isIncoming,
) {
  final item = items.where((item) => item.id == id).firstOrNull;
  if (item == null) return '품목을 찾을 수 없습니다.';
  if (amount <= 0) return '수량은 양의 정수로 입력해 주세요.';
  if (amount > maxInventoryQuantity ||
      (isIncoming && amount > maxInventoryQuantity - item.quantity)) {
    return '처리 가능한 수량 범위를 초과했습니다.';
  }
  if (!isIncoming && amount > item.quantity) {
    return '현재고를 초과하여 출고할 수 없습니다.';
  }
  return null;
}

class InventoryRepositoryException implements Exception {
  const InventoryRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}
