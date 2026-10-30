import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_mes/main.dart';
import 'package:mini_mes/providers/inventory_provider.dart';
import 'package:mini_mes/repositories/mock_inventory_repository.dart';
import 'package:mini_mes/widgets/inventory_card.dart';

void main() {
  test('Repository는 재조회 시 변경 유지, 실패 시 변경하지 않음', () async {
    final store = MockInventoryRepository(delay: Duration.zero);
    await store.changeStock('2', 12, true);
    expect((await store.fetchInventory())[1].quantity, 30);
    store.failNextChange = true;
    await expectLater(store.changeStock('2', 1, false), throwsException);
    expect((await store.fetchInventory())[1].quantity, 30);
  });

  test('Notifier 중복 요청 차단과 재조회 저장 상태 유지', () async {
    final store = MockInventoryRepository(
      delay: const Duration(milliseconds: 1),
    );
    final container = ProviderContainer(
      overrides: [inventoryRepositoryProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await container.read(inventoryProvider.future);
    final notifier = container.read(inventoryProvider.notifier);
    final first = notifier.changeStock('2', 12, true);
    expect(await notifier.changeStock('2', 12, true), '이미 처리 중입니다.');
    expect(await first, isNull);
    container.invalidate(inventoryProvider);
    expect((await container.read(inventoryProvider.future))[1].quantity, 30);
  });

  testWidgets('조회 로딩, 오류와 수동 재시도', (tester) async {
    final store = MockInventoryRepository()..failNextFetch = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [inventoryRepositoryProvider.overrideWithValue(store)],
        child: const MyApp(),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('재고 조회에 실패했습니다.'), findsOneWidget);
    await tester.tap(find.text('재시도'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('재고 목록 · 14개'), findsOneWidget);
  });

  testWidgets('처리 중 비활성화, 실패 후 재시도와 수량 동기화', (tester) async {
    final store = MockInventoryRepository()..failNextChange = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [inventoryRepositoryProvider.overrideWithValue(store)],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'RM-002');
    await tester.pump();
    await tester.tap(find.byType(InventoryCard));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('stockAmount')));
    await tester.enterText(find.byKey(const ValueKey('stockAmount')), '12');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('처리 중...'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .onSelectionChanged,
      isNull,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('입출고 처리에 실패했습니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('18 개'), findsOneWidget);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('30 개'), findsNWidgets(2));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('30 개'), findsOneWidget);
    final fetched = await tester.runAsync(store.fetchInventory);
    expect(fetched![1].quantity, 30);
  });
}
