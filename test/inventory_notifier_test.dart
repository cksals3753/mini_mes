import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_mes/data/mock_inventory.dart';
import 'package:mini_mes/providers/inventory_provider.dart';
import 'package:mini_mes/repositories/mock_inventory_repository.dart';

void main() {
  late ProviderContainer container;
  late InventoryNotifier notifier;

  setUp(() async {
    container = ProviderContainer(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(
          MockInventoryRepository(delay: Duration.zero),
        ),
      ],
    );
    notifier = container.read(inventoryProvider.notifier);
    await container.read(inventoryProvider.future);
  });
  tearDown(() => container.dispose());

  test('Mock 초기화와 컨테이너별 독립 상태', () async {
    expect(container.read(inventoryProvider).requireValue, mockInventory);
    final other = ProviderContainer(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(
          MockInventoryRepository(delay: Duration.zero),
        ),
      ],
    );
    await other.read(inventoryProvider.future);
    addTearDown(other.dispose);
    await notifier.changeStock('2', 12, true);
    expect(other.read(inventoryProvider).requireValue[1].quantity, 18);
    expect(mockInventory[1].quantity, 18);
  });

  test('입고와 출고는 새 목록과 객체로 갱신하고 다른 품목은 유지한다', () async {
    final before = container.read(inventoryProvider).requireValue;
    expect(await notifier.changeStock('2', 12, true), isNull);
    final after = container.read(inventoryProvider).requireValue;
    expect(after, isNot(same(before)));
    expect(after[1], isNot(same(before[1])));
    expect(after[0], same(before[0]));
    expect(before[1].quantity, 18);
    expect(after[1].quantity, 30);
    expect(after[1].isLowStock, isFalse);
    expect(() => after.clear(), throwsUnsupportedError);
    expect(await notifier.changeStock('2', 1, false), isNull);
    expect(
      container.read(inventoryProvider).requireValue[1].isLowStock,
      isTrue,
    );
  });

  test('전량 출고 후 0 재고에서 출고 차단, 재입고 가능', () async {
    expect(await notifier.changeStock('2', 18, false), isNull);
    expect(container.read(inventoryProvider).requireValue[1].quantity, 0);
    expect(await notifier.changeStock('2', 1, false), isNotNull);
    expect(await notifier.changeStock('2', 1, true), isNull);
    expect(container.read(inventoryProvider).requireValue[1].quantity, 1);
  });

  test('잘못된 요청은 상태를 변경하지 않는다', () async {
    final before = container.read(inventoryProvider).requireValue;
    expect(await notifier.changeStock('missing', 1, true), isNotNull);
    for (final incoming in [true, false]) {
      for (final amount in [0, -1, InventoryNotifier.maxQuantity + 1]) {
        expect(await notifier.changeStock('2', amount, incoming), isNotNull);
      }
    }
    expect(await notifier.changeStock('2', 19, false), isNotNull);
    expect(
      await notifier.changeStock('2', InventoryNotifier.maxQuantity, true),
      isNotNull,
    );
    expect(container.read(inventoryProvider).requireValue, same(before));
  });

  test('정확한 정수 최대 경계에서 입고 초과 차단', () async {
    expect(
      await notifier.changeStock('9', InventoryNotifier.maxQuantity, true),
      isNull,
    );
    expect(await notifier.changeStock('9', 1, true), isNotNull);
    expect(
      await notifier.changeStock('9', InventoryNotifier.maxQuantity, false),
      isNull,
    );
    expect(container.read(inventoryProvider).requireValue[8].quantity, 0);
  });
}
