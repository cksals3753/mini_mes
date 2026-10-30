class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.itemCode,
    required this.itemName,
    required this.lotNo,
    required this.quantity,
    required this.safetyStock,
    required this.unit,
    required this.location,
  });

  /// 품목·LOT·위치별 재고 레코드 한 건의 고유 식별자. 입출고 대상 키.
  final String id;

  /// 여러 LOT와 위치에서 공통으로 사용하는 품목 식별 코드. 합계의 그룹 키.
  final String itemCode;
  final String itemName;

  /// 생산/입고 배치 번호. 같은 LOT가 여러 위치에 존재할 수 있다.
  final String lotNo;
  final int quantity;
  final int safetyStock;
  final String unit;

  /// 이 레코드의 물리적 보관 위치.
  final String location;

  InventoryItem copyWith({
    String? id,
    String? itemCode,
    String? itemName,
    String? lotNo,
    int? quantity,
    int? safetyStock,
    String? unit,
    String? location,
  }) => InventoryItem(
    id: id ?? this.id,
    itemCode: itemCode ?? this.itemCode,
    itemName: itemName ?? this.itemName,
    lotNo: lotNo ?? this.lotNo,
    quantity: quantity ?? this.quantity,
    safetyStock: safetyStock ?? this.safetyStock,
    unit: unit ?? this.unit,
    location: location ?? this.location,
  );

  bool get isLowStock => quantity < safetyStock;
}
