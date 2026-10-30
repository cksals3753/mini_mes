import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_mes/data/mock_inventory.dart';
import 'package:mini_mes/main.dart';
import 'package:mini_mes/screens/inventory_detail_screen.dart';
import 'package:mini_mes/widgets/inventory_card.dart';
import 'package:mini_mes/widgets/inventory_summary.dart';

void main() {
  test('Mock 데이터와 안전재고 경계값', () {
    expect(mockInventory.length, 14);
    expect(mockInventory.map((item) => item.id).toSet().length, 14);
    expect(mockInventory.where((item) => item.isLowStock).length, 4);
    expect(
      mockInventory.singleWhere((item) => item.itemCode == 'PT-003').isLowStock,
      isFalse,
    );
    expect(
      mockInventory.singleWhere((item) => item.quantity == 0).isLowStock,
      isTrue,
    );
  });

  testWidgets('검색, 부족 표시, 전체 요약, 검색 초기화', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
    final summary = tester.widget<InventorySummary>(
      find.byType(InventorySummary),
    );
    expect(summary.total, 14);
    expect(summary.lowStock, 4);
    expect(find.text('재고 목록 · 14개'), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' rm-002 ');
    await tester.pump();
    expect(find.text('스테인리스 봉재'), findsOneWidget);
    expect(find.byType(InventoryCard), findsOneWidget);
    expect(find.text('재고 부족'), findsNWidgets(2));
    expect(
      tester.widget<InventorySummary>(find.byType(InventorySummary)).total,
      14,
    );

    await tester.enterText(find.byType(TextField), '베어링');
    await tester.pump();
    expect(find.text('베어링 6204'), findsOneWidget);
    expect(find.text('정상'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '없는 품목');
    await tester.pump();
    expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
    await tester.tap(find.byTooltip('검색어 지우기'));
    await tester.pump();
    expect(find.text('재고 목록 · 14개'), findsOneWidget);
  });

  for (final code in ['RM-002', 'PT-003']) {
    testWidgets('$code 상세 이동, 데이터 전달, 뒤로 가기와 검색 상태 유지', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MyApp()));
      await tester.pumpAndSettle();
      final item = mockInventory.singleWhere((item) => item.itemCode == code);
      await tester.enterText(find.byType(TextField), code);
      await tester.pump();
      await tester.tap(find.byType(InventoryCard));
      await tester.pumpAndSettle();

      final detail = tester.widget<InventoryDetailScreen>(
        find.byType(InventoryDetailScreen),
      );
      expect(detail.itemId, item.id);
      for (final value in [
        item.itemCode,
        item.itemName,
        item.lotNo,
        '${item.quantity} ${item.unit}',
        '${item.safetyStock} ${item.unit}',
        item.unit,
        item.location,
        '재고 상태 · ${item.isLowStock ? '재고 부족' : '정상'}',
      ]) {
        expect(find.text(value), findsWidgets);
      }
      expect(find.byType(BackButton), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(InventoryDetailScreen)))
            .canPop(),
        isTrue,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(InventoryDetailScreen), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        code,
      );
      expect(find.text('재고 목록 · 1개'), findsOneWidget);
      final summary = tester.widget<InventorySummary>(
        find.byType(InventorySummary),
      );
      expect(summary.total, 14);
      expect(summary.lowStock, 4);

      // AppBar의 뒤로 가기와 동일한 Navigator.pop도 경로를 제거한다.
      await tester.tap(find.byType(InventoryCard));
      await tester.pumpAndSettle();
      Navigator.pop(tester.element(find.byType(InventoryDetailScreen)));
      await tester.pumpAndSettle();
      expect(find.byType(InventoryDetailScreen), findsNothing);
      expect(find.text('재고 목록 · 1개'), findsOneWidget);
    });
  }

  testWidgets('좁은 모바일 화면에서 스크롤하여 마지막 품목 확인', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('포장 박스'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('포장 박스'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
