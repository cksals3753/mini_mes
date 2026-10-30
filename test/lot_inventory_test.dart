import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_mes/data/mock_inventory.dart';
import 'package:mini_mes/main.dart';
import 'package:mini_mes/repositories/inventory_repository.dart';
import 'package:mini_mes/repositories/mock_inventory_repository.dart';
import 'package:mini_mes/widgets/inventory_card.dart';
import 'package:mini_mes/widgets/inventory_summary.dart';

import 'stock_transaction_test.dart' show process;

void main() {
  test('동일 품목의 서로 다른 LOT와 동일 LOT의 다른 위치가 고유 ID를 가진다', () {
    final items = mockInventory
        .where((item) => item.itemCode == 'RM-001')
        .toList();
    expect(items.length, 5);
    expect(items.map((item) => item.lotNo).toSet().length, 4);
    expect(items.map((item) => item.id).toSet().length, 5);
    final split = items.where((item) => item.lotNo == 'LOT-261001');
    expect(split.map((item) => item.location).toSet().length, 2);
    expect(items.fold<int>(0, (sum, item) => sum + item.quantity), 355);
  });

  test('품목 합계가 충분해도 선택 레코드 초과 출고는 거절한다', () async {
    final store = MockInventoryRepository(delay: Duration.zero);
    final before = await store.fetchInventory();
    await expectLater(
      store.changeStock('14', 26, false),
      throwsA(isA<InventoryRepositoryException>()),
    );
    expect(await store.fetchInventory(), same(before));
  });

  test('ID로 입출고하고 다른 LOT·위치의 객체와 수량을 유지한다', () async {
    final store = MockInventoryRepository(delay: Duration.zero);
    final before = await store.fetchInventory();
    final after = await store.changeStock('14', 25, false);
    for (final original in before) {
      final updated = after.singleWhere((item) => item.id == original.id);
      if (original.id == '14') {
        expect(updated.quantity, 0);
        expect(updated.isLowStock, isTrue);
      } else {
        expect(updated, same(original));
        expect(updated.quantity, original.quantity);
      }
    }
    expect(
      after
          .where((item) => item.itemCode == 'RM-001')
          .fold<int>(0, (sum, item) => sum + item.quantity),
      330,
    );
    await store.changeStock('14', 20, true);
    final fetched = await store.fetchInventory();
    expect(fetched.singleWhere((item) => item.id == '14').isLowStock, isFalse);
    expect(fetched.singleWhere((item) => item.id == '1').quantity, 120);
  });

  testWidgets('합계·검색·선택 위치 상세와 출고 후 부족 상태가 동기화된다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'RM-001');
    await tester.pumpAndSettle();
    expect(find.text('재고 목록 · 5개'), findsOneWidget);
    await tester.tap(find.text('품목별 재고 합계'));
    await tester.pumpAndSettle();
    expect(find.text('합계 355 장 · 5개 재고 기록'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('14')),
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('14')));
    await tester.pumpAndSettle();
    expect(find.text('A-03-01'), findsOneWidget);
    expect(find.text('LOT-261001'), findsOneWidget);
    await process(tester, '26', incoming: false);
    expect(find.text('현재고를 초과하여 출고할 수 없습니다.'), findsOneWidget);
    await process(tester, '25', incoming: false);
    expect(find.text('0 장'), findsOneWidget);
    expect(find.text('재고 상태 · 재고 부족'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InventoryCard>(find.byKey(const ValueKey('14')))
          .item
          .quantity,
      0,
    );
    final scrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('품목별 재고 합계'),
      -400,
      scrollable: scrollable,
    );
    expect(find.text('합계 330 장 · 5개 재고 기록'), findsOneWidget);
    expect(
      tester.widget<InventorySummary>(find.byType(InventorySummary)).lowStock,
      5,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'RM-001',
    );
  });
}
