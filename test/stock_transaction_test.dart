import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_mes/data/mock_inventory.dart';
import 'package:mini_mes/main.dart';
import 'package:mini_mes/providers/inventory_provider.dart';
import 'package:mini_mes/screens/inventory_detail_screen.dart';
import 'package:mini_mes/widgets/inventory_card.dart';
import 'package:mini_mes/widgets/inventory_summary.dart';

Future<void> openItem(WidgetTester tester, String code) async {
  await tester.pumpWidget(const ProviderScope(child: MyApp()));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), code);
  await tester.pump();
  await tester.tap(find.byType(InventoryCard));
  await tester.pumpAndSettle();
}

Future<void> process(
  WidgetTester tester,
  String amount, {
  bool incoming = true,
}) async {
  await tester.ensureVisible(find.byType(SegmentedButton<bool>));
  await tester.tap(find.text(incoming ? '입고' : '출고'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('stockAmount')), amount);
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  test('copyWith는 원본을 유지하고 새 객체를 생성한다', () {
    final original = mockInventory.first;
    final updated = original.copyWith(quantity: 0);
    expect(updated, isNot(same(original)));
    expect(original.quantity, 120);
    expect(updated.quantity, 0);
    expect(updated.id, original.id);
    expect(updated.itemCode, original.itemCode);
    expect(updated.itemName, original.itemName);
    expect(updated.lotNo, original.lotNo);
    expect(updated.safetyStock, original.safetyStock);
    expect(updated.unit, original.unit);
    expect(updated.location, original.location);
  });

  testWidgets('상세 화면은 외부 Provider 변경도 즉시 반영한다', (tester) async {
    await openItem(tester, 'RM-002');
    final context = tester.element(find.byType(InventoryDetailScreen));
    final container = ProviderScope.containerOf(context);
    final pending = container
        .read(inventoryProvider.notifier)
        .changeStock('2', 12, true);
    await tester.pump(const Duration(milliseconds: 400));
    await pending;
    await tester.pumpAndSettle();
    expect(find.text('30 개'), findsNWidgets(2));
    expect(find.text('재고 상태 · 정상'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('30 개'), findsOneWidget);
    expect(
      tester.widget<InventorySummary>(find.byType(InventorySummary)).lowStock,
      3,
    );
  });

  testWidgets('입고 후 안전재고 경계와 목록·상세·요약 동기화', (tester) async {
    await openItem(tester, 'RM-002');
    await process(tester, '12');
    expect(find.text('30 개'), findsNWidgets(2));
    expect(find.text('재고 상태 · 정상'), findsOneWidget);
    expect(find.text('입고 처리가 완료되었습니다.'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('30 개'), findsOneWidget);
    expect(find.text('정상'), findsOneWidget);
    expect(
      tester.widget<InventorySummary>(find.byType(InventorySummary)).lowStock,
      3,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'RM-002',
    );
    await tester.tap(find.byType(InventoryCard));
    await tester.pumpAndSettle();
    expect(find.text('30 개'), findsNWidgets(2));
    await process(tester, '1', incoming: false);
    expect(find.text('29 개'), findsOneWidget);
    expect(find.text('재고 상태 · 재고 부족'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('29 개'), findsOneWidget);
    expect(
      tester.widget<InventorySummary>(find.byType(InventorySummary)).lowStock,
      4,
    );
    expect(
      mockInventory.singleWhere((item) => item.itemCode == 'RM-002').quantity,
      18,
    );
  });

  testWidgets('현재고 초과 출고 차단, 전량 출고, 0 재고 출고 차단과 재입고', (tester) async {
    await openItem(tester, 'RM-002');
    await process(tester, '19', incoming: false);
    expect(find.text('현재고를 초과하여 출고할 수 없습니다.'), findsOneWidget);
    expect(find.text('18 개'), findsOneWidget);
    await process(tester, '18', incoming: false);
    expect(find.text('0 개'), findsOneWidget);
    await process(tester, '1', incoming: false);
    expect(find.text('현재고를 초과하여 출고할 수 없습니다.'), findsOneWidget);
    expect(find.text('0 개'), findsOneWidget);
    await process(tester, '1');
    expect(find.text('1 개'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('1 개'), findsOneWidget);
  });

  testWidgets('빈 값, 0, 음수, 소수, 문자, 너무 큰 수는 처리하지 않는다', (tester) async {
    await openItem(tester, 'RM-002');
    for (final input in ['', '0', '-1', '1.5', 'abc', '1e3', ' 1 ']) {
      await process(tester, input);
      expect(find.text('수량은 양의 정수로 입력해 주세요.'), findsOneWidget);
      expect(find.text('18 개'), findsOneWidget);
    }
    await process(tester, '9007199254740991');
    expect(find.text('처리 가능한 수량 범위를 초과했습니다.'), findsOneWidget);
    expect(find.text('18 개'), findsOneWidget);
  });
}
