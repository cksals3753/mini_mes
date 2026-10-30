# Mini MES Flutter 학습 정리 (STEP 1~6)

> **목적:** React·TypeScript 경험이 있는 Flutter 입문자가 Mini MES를 만들며 배운 내용을 복습하고, **왜 이런 구조로 코드를 작성했는지** 설명할 수 있도록 정리한 문서입니다.  
> **환경:** Flutter 3.47.9 / Dart 3.13.7 / `flutter_riverpod` 3.4.3  
> **범위:** STEP 1~6, Mock 데이터 기반. 실제 REST API·DB 연동 전 단계.  
> **검증:** 사용자가 보고한 `flutter analyze` 문제 없음, `flutter test` 23개 통과.  
> **주의:** 이 문서는 작업 결과 설명을 기반으로 작성했습니다. 실제 소스 파일을 직접 읽어 검증한 문서는 아니므로, 아래 코드는 **학습용 예시**이며 프로젝트 코드와 세부 구현이 다를 수 있습니다.

---

## 0. 먼저 큰 그림 이해하기

Mini MES는 공장의 **재고를 조회하고 입고·출고를 처리하는 작은 앱**입니다.

현재 주요 기능:

- 재고 목록 조회 및 품목코드·품목명 검색
- 재고 부족 표시 (`quantity < safetyStock`)
- 재고 상세 화면 이동
- 입고·출고 수량 입력과 검증
- Riverpod으로 목록·상세의 재고 상태 공유
- 비동기 로딩·오류·재시도·중복 제출 방지
- 동일 품목의 여러 LOT 및 위치별 재고 관리
- 품목별 재고 합계 표시
- Mock Repository를 통한 실패 시뮬레이션 및 테스트

### 전체 구조

```text
main.dart
  └─ ProviderScope
      └─ InventoryScreen (재고 목록 / 검색)
          ├─ InventorySummary (전체 기록·부족 기록 요약)
          ├─ ItemStockTotals (품목별 합계)
          ├─ InventoryCard (LOT·위치별 카드)
          └─ Navigator.push
              └─ InventoryDetailScreen (입고·출고)

InventoryScreen / InventoryDetailScreen
       │ ref.watch / ref.read
       ▼
InventoryNotifier (AsyncNotifier)
       │ Repository 호출
       ▼
InventoryRepository (추상 계약)
       │ 구현체 주입
       ▼
MockInventoryRepository
       │
       ▼
메모리 재고 데이터
```

**핵심 원칙:** 화면은 보여주고 입력을 받는 데 집중합니다. 재고 상태 변경은 Notifier가 담당하고, 데이터 조회·저장은 Repository가 담당합니다.

---

## 1. STEP 1 — Flutter 화면과 상태의 기초

### 무엇을 만들었나요?

10개의 Mock 재고를 카드로 표시하고, 품목코드·품목명 검색, 부족 재고 강조, 전체/부족 요약을 구현했습니다. 이후 단계에서 데이터가 확장되어 현재는 총 14개 재고 레코드입니다.

주요 파일:

- `lib/models/inventory_item.dart`
- `lib/data/mock_inventory.dart`
- `lib/screens/inventory_screen.dart`
- `lib/widgets/inventory_card.dart`
- `lib/widgets/inventory_summary.dart`

### Flutter에서 Widget이란?

Flutter의 UI 구성 단위입니다. React의 컴포넌트와 비슷합니다.

```dart
class InventoryCard extends StatelessWidget {
  const InventoryCard({super.key, required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    return Text(item.itemName);
  }
}
```

React와 비교하면:

```tsx
function InventoryCard({ item }: { item: InventoryItem }) {
  return <div>{item.itemName}</div>;
}
```

`build()`는 화면을 구성하는 Widget을 반환합니다. **`build()`가 다시 실행되는 것과 화면의 모든 픽셀이 다시 그려지는 것은 다릅니다.** Flutter는 새 Widget 구성을 비교해 필요한 부분을 갱신합니다.

### StatelessWidget과 StatefulWidget

- `StatelessWidget`: 자신이 직접 변경할 로컬 `State` 객체를 갖지 않는 UI. 부모나 Provider의 데이터가 달라지면 **다시 build될 수 있습니다**.
- `StatefulWidget`: 별도 `State` 객체를 가지며, `setState()`를 통해 로컬 상태 변경을 알릴 수 있습니다.

초기 검색어는 목록 화면에서만 쓰이므로 `StatefulWidget`에 보관했습니다.

```dart
String _query = '';

void onSearchChanged(String value) {
  setState(() {
    _query = value;
  });
}
```

React의 `useState`와 비슷합니다.

```tsx
const [query, setQuery] = useState("");
```

**왜 검색어를 전역 상태로 만들지 않았을까요?** 검색어는 목록 화면의 입력 상태일 뿐, 다른 화면이 공유할 필요가 없기 때문입니다. 공유하지 않아도 되는 상태를 전역으로 올리면 코드가 복잡해집니다.

### Dart 문법 간단 비교

| Dart | TypeScript/React | 의미 |
|---|---|---|
| `final String name` | `readonly name: string`과 유사 | 변수에 다른 값을 재할당하지 않음 |
| `required this.item` | 필수 props | 생성 시 반드시 전달 |
| `item.isLowStock` (`get`) | getter | 계산된 속성 |
| `.where(...)` | `.filter(...)` | 조건 필터링 |
| `.map(...)` | `.map(...)` | 목록 변환 |
| `dispose()` | `useEffect` cleanup과 유사 | Controller 등 자원 정리 |

`final`은 참조 재할당을 막는 개념입니다. 참조하는 객체 내부까지 자동으로 깊은 불변성이 보장되는 것은 아닙니다.

---

## 2. STEP 2 — 목록에서 상세 화면으로 이동

### 무엇을 만들었나요?

재고 카드를 누르면 해당 품목의 상세 화면으로 이동하고, 뒤로 돌아오면 기존 검색 상태를 유지하도록 했습니다.

핵심 API:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => InventoryDetailScreen(itemId: item.id),
  ),
);
```

위 코드는 **현재 화면 위에 새 Route를 쌓는 동작**입니다.

```text
이동 전: [재고 목록]
이동 후: [재고 목록, 재고 상세]
뒤로:    [재고 목록]
```

React Router와 달리 Flutter의 기본 Navigator는 **화면(Route) 스택**이라는 개념이 눈에 잘 드러납니다.

### 왜 `itemId`를 전달하나요?

초기에는 `InventoryItem` 객체를 전달했습니다. 이후 Riverpod 도입 후에는 `itemId`로 최신 데이터를 조회하도록 변경했습니다.

```dart
InventoryDetailScreen(itemId: item.id)
```

이 방식의 이유:

1. 목록에서 객체를 전달하면, 상세 화면이 그 당시의 수량을 계속 들고 있을 위험이 있습니다.
2. `itemId`를 전달하면 상세 화면이 공유 저장소에서 **현재 값**을 다시 조회할 수 있습니다.
3. 다른 곳에서 재고가 변경되어도 상세 화면을 동기화하기 쉽습니다.

React에서 상세 페이지에 `/inventory/:id`를 전달하고 해당 ID로 데이터를 조회하는 방식과 유사합니다.

### 콜백 `VoidCallback?`

```dart
final VoidCallback? onTap;
```

`VoidCallback`은 인자를 받지 않고 값을 반환하지 않는 함수 타입입니다. `?`는 `null` 허용을 의미합니다.

TypeScript의 `onTap?: () => void`와 비슷합니다.

---

## 3. STEP 3 — 입고·출고와 불변 업데이트

### 무엇을 만들었나요?

상세 화면에서 입고 또는 출고 수량을 입력하고 재고를 변경했습니다.

기본 검증:

- 수량은 양의 정수
- 출고 수량은 해당 재고 레코드의 현재고 이하
- 변경 후 재고 부족 여부 즉시 반영

예시:

```text
LOT-A 현재고 100 EA
입고 20 EA → 120 EA
출고 30 EA → 90 EA
출고 150 EA → 거절 (재고 부족)
```

### 왜 `copyWith`를 쓰나요?

`InventoryItem`을 직접 수정하는 대신 **수정된 새 객체**를 만듭니다.

```dart
class InventoryItem {
  final String id;
  final int quantity;

  const InventoryItem({
    required this.id,
    required this.quantity,
  });

  InventoryItem copyWith({int? quantity}) {
    return InventoryItem(
      id: id,
      quantity: quantity ?? this.quantity,
    );
  }
}
```

사용:

```dart
final updated = item.copyWith(quantity: 90);
```

React에서 다음처럼 불변 업데이트하는 것과 같은 사고방식입니다.

```tsx
const updated = { ...item, quantity: 90 };
```

**이유:** 이전 값과 새 값을 명확하게 구분할 수 있어 상태 변경 추적과 테스트가 쉬워집니다.

단, 위 `copyWith`는 개념 설명을 위한 축약 코드입니다. 실제 프로젝트의 모든 필드가 보존되도록 작성해야 합니다.

### STEP 3의 한계

처음에는 목록 화면이 재고를 소유하고, 상세 화면에 콜백을 전달해 값을 변경했습니다.

```text
목록이 상태 보유
   ↓ 콜백 전달
상세에서 변경 요청
   ↓
목록 상태 갱신
```

작은 앱에서는 충분하지만, 화면이 많아질수록 콜백 전달과 상태 동기화가 복잡해집니다. 이것이 STEP 4에서 Riverpod을 도입한 이유입니다.

---

## 4. STEP 4 — Riverpod으로 공유 상태 관리

### Riverpod은 무엇인가요?

여러 Widget이 같은 상태를 읽고, 변경할 수 있도록 도와주는 Flutter/Dart 상태 관리 라이브러리입니다.

React의 Context + `useReducer` 조합과 비슷한 역할을 할 수 있지만, 정확히 같은 API나 생명주기를 갖는 것은 아닙니다.

### `ProviderScope`를 앱 최상단에 두는 이유

```dart
void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
```

하위 Widget이 Provider를 사용하고, Provider 상태를 관리할 수 있는 범위를 제공하기 위해서입니다.

### Notifier가 재고를 소유하도록 변경

```text
변경 전
InventoryScreen → 상태 보유 → 상세에 콜백 전달

변경 후
InventoryScreen ─┐
                 ├→ InventoryNotifier → 재고 상태
InventoryDetail ─┘
```

이제 목록과 상세가 같은 재고 상태를 바라봅니다.

### `ref.watch`와 `ref.read`

```dart
final inventory = ref.watch(inventoryProvider);
```

`watch`는 상태를 **구독**합니다. Provider가 변경되면 해당 값을 사용하는 Widget이 다시 빌드될 수 있습니다.

```dart
ref.read(inventoryProvider.notifier).someAction();
```

`read`는 **구독하지 않고 현재 Provider에 접근**합니다. 버튼 클릭이나 제출 이벤트에서 변경 메서드를 호출할 때 자주 사용합니다.

기억하기:

- **화면에 값을 보여줄 때:** `watch`
- **버튼을 눌러 명령을 실행할 때:** `read`

단, 실제 코드에서 어떤 Provider의 어떤 타입을 읽는지에 따라 접근 방식은 달라질 수 있습니다.

### 왜 검색어는 Riverpod으로 옮기지 않았나요?

검색어와 `TextEditingController`는 해당 목록 화면에만 필요합니다. 반면 재고 수량은 목록과 상세 모두에서 필요합니다.

| 상태 | 권장 소유 위치 | 이유 |
|---|---|---|
| 재고 목록·수량 | Riverpod | 여러 화면이 공유 |
| 검색어 | 목록 화면 로컬 State | 목록에서만 사용 |
| 수량 입력값 | 상세 화면 로컬 State | 입력 폼에서만 사용 |
| 출고 검증·변경 | Notifier/Repository 계약에 맞게 분담 | 업무 로직의 일관성 |

**상태 관리의 핵심은 모든 상태를 전역으로 옮기는 것이 아니라, 필요한 범위에 올바르게 배치하는 것입니다.**

---

## 5. STEP 5 — 비동기 Repository와 오류 처리

### 왜 Repository를 도입했나요?

STEP 4까지는 Notifier가 Mock 데이터를 직접 다루는 구조였습니다. 실제 서비스에서는 서버 API를 호출해야 합니다.

Repository는 **데이터를 어디서 어떻게 가져오는지**를 UI와 상태 관리에서 분리합니다.

```text
UI → InventoryNotifier → InventoryRepository → Mock 구현
                                           ↘ 향후 HTTP 구현
```

예시 인터페이스:

```dart
abstract class InventoryRepository {
  Future<List<InventoryItem>> fetchItems();
}
```

`Future<List<InventoryItem>>`는 **지금 바로 결과가 아니라, 나중에 재고 목록을 받을 것**이라는 뜻입니다.

TypeScript의 `Promise<InventoryItem[]>`와 유사합니다.

### `async` / `await`

```dart
Future<void> loadItems() async {
  final items = await repository.fetchItems();
  // 조회가 완료된 뒤 다음 코드 실행
}
```

React/TypeScript:

```tsx
async function loadItems() {
  const items = await repository.fetchItems();
}
```

### 왜 `AsyncNotifier`와 `AsyncValue`를 쓰나요?

비동기 조회에는 최소 세 가지 상태가 있습니다.

```text
조회 시작 → Loading
             ├→ Data (성공)
             └→ Error (실패)
```

`AsyncValue`는 이 상태를 명시적으로 표현합니다.

| Riverpod | React/TanStack Query와 비교 |
|---|---|
| `AsyncLoading` | 로딩 상태 |
| `AsyncData` | 조회 성공 데이터 |
| `AsyncError` | 조회 오류 |
| `ref.invalidate(...)` | Provider 무효화·재평가 요청 |

`ref.invalidate`와 TanStack Query의 `refetch()`는 정확히 같은 동작은 아닙니다. Provider의 생명주기와 구독 여부에 따라 재평가 시점이 달라질 수 있습니다.

### 조회 로딩과 출고 제출 중을 구분한 이유

재고 목록을 이미 보여주고 있는 상황에서 출고 버튼을 누른다고 전체 목록을 없애고 로딩 화면으로 바꾸면 사용성이 나빠집니다.

따라서:

- **조회 상태:** `AsyncValue`로 Loading/Data/Error 관리
- **제출 상태:** `_isSubmitting` 등 별도 상태로 버튼·입력 비활성화
- **실패 시:** 기존 재고와 입력값 유지
- **성공 시:** 목록·상세·부족 건수 갱신

이는 TanStack Query에서 `query`와 `mutation`의 상태를 별도로 다루는 것과 유사한 사고방식입니다.

### Mock Repository에 400ms 지연을 둔 이유

실제 네트워크는 즉시 응답하지 않습니다. `Future.delayed`로 지연을 주면 로딩 UI, 중복 클릭, 화면 전환 등의 문제를 서버 없이 테스트할 수 있습니다.

`failNextFetch`, `failNextChange` 같은 실패 시뮬레이션은 오류·재시도 동작을 재현 가능하게 만듭니다.

### 테스트에서 Repository를 교체하는 이유

```dart
inventoryRepositoryProvider.overrideWithValue(
  fakeRepository,
);
```

실제 데이터 저장소 대신 테스트용 구현을 주입하면 성공, 실패, 지연 등의 상황을 원하는 순서로 검증할 수 있습니다.

이것이 **의존성 주입(Dependency Injection)**의 실용적인 장점입니다.

---

## 6. STEP 6 — LOT와 위치별 재고

### 무엇이 달라졌나요?

`RM-001` 품목에 여러 LOT와 동일 LOT의 다른 위치 레코드를 추가했습니다. 전체 재고 레코드는 14건입니다.

예시:

| id | itemCode | lotNo | location | quantity |
|---|---|---|---|---:|
| INV-1 | RM-001 | LOT-A | A-01 | 100 |
| INV-2 | RM-001 | LOT-B | A-01 | 250 |
| INV-3 | RM-001 | LOT-C | B-01 | 40 |
| INV-4 | RM-001 | LOT-A | B-02 | 30 |

*위 수량·ID는 개념 설명용 예시이며 실제 Mock 데이터와 다를 수 있습니다.*

### 각 식별자가 의미하는 것

- `id`: **특정 재고 레코드 1건**의 고유 키
- `itemCode`: 품목 종류를 구분하는 코드, 품목별 합계 기준
- `lotNo`: 생산·입고 배치 번호
- `location`: 실제 보관 위치

**왜 출고를 `id` 기준으로 처리하나요?**

`RM-001`의 총재고가 충분해도, 사용자가 선택한 LOT·위치에 수량이 부족할 수 있기 때문입니다.

```text
RM-001 전체 합계: 420 EA
INV-1 (LOT-A / A-01): 100 EA

INV-1에서 150 EA 출고 요청
→ 전체 합계는 충분하지만 선택 레코드는 부족
→ 출고 거절
```

`itemCode`만으로 출고하면 의도하지 않은 LOT까지 차감할 위험이 있습니다.

### 품목별 합계는 왜 조회용인가요?

품목별 합계는 현황 파악에 유용하지만, 실제 출고 대상은 특정 재고 레코드입니다.

```dart
final total = items
    .where((item) => item.itemCode == 'RM-001')
    .fold<int>(0, (sum, item) => sum + item.quantity);
```

`fold`는 TypeScript의 `reduce`와 비슷합니다.

```tsx
const total = items
  .filter(item => item.itemCode === "RM-001")
  .reduce((sum, item) => sum + item.quantity, 0);
```

**주의:** 검색 결과를 기준으로 합계를 계산한다면 UI에 '검색 결과 합계'인지 '품목 전체 합계'인지 명시해야 합니다.

### 안전재고는 어떤 단위인가요?

이번 프로젝트는 **레코드별 안전재고**를 유지했습니다.

```dart
bool get isLowStock => quantity < safetyStock;
```

실제 MES에서는 안전재고가 품목 전체, 창고, 위치 중 어떤 단위로 관리되는지 업무 정책에 따라 달라집니다. 현재 규칙이 모든 MES에 통용되는 것은 아닙니다.

---

## 7. MES 실무에서 꼭 알아야 할 두 가지

### 7-1. 동시 출고는 Flutter만으로 막을 수 없습니다

LOT-A에 재고가 100 EA 있고, A와 B가 동시에 각각 80 EA를 출고한다고 가정합니다.

두 기기 모두 100 EA를 보고 있어 프론트 검증을 통과할 수 있습니다.

**해결:** 서버가 트랜잭션과 동시성 제어로 출고 가능 여부를 검증하고 재고를 원자적으로 차감해야 합니다.

예시 SQL:

```sql
UPDATE inventory
SET quantity = quantity - 80
WHERE id = 'INV-1'
  AND quantity >= 80;
```

영향받은 행 수로 성공 여부를 판단할 수 있습니다. 실제 시스템에서는 거래 이력 기록 등도 같은 트랜잭션 범위에서 설계해야 합니다.

Flutter의 버튼 비활성화는 **같은 화면에서의 중복 클릭 방지**이지, 여러 사용자의 동시 출고를 해결하는 장치는 아닙니다.

### 7-2. 타임아웃은 반드시 실패가 아닙니다

```text
Flutter → 출고 요청 → 서버 DB 반영 완료
                         ↓
                     응답 유실
                         ↓
Flutter: 타임아웃 발생
```

서버는 출고를 처리했는데 앱만 응답을 못 받았을 수 있습니다.

따라서 타임아웃 직후 새 출고 요청을 무조건 보내면 중복 출고 위험이 있습니다.

실무 대응:

1. 출고 요청마다 고유 `requestId`(멱등성 키)를 부여합니다.
2. 서버는 같은 키의 요청을 중복 실행하지 않도록 보장합니다.
3. 타임아웃 시 앱은 **처리 결과 불확실** 상태로 표시합니다.
4. 거래 상태를 조회하거나 **같은 키**로 안전하게 재시도합니다.
5. 최종 결과 확인 후 서버 재고를 다시 조회합니다.

멱등성은 클라이언트가 키를 보내는 것만으로 보장되지 않습니다. **서버가 해당 키와 처리 결과를 원자적으로 관리**해야 합니다.

---

## 8. 테스트를 작성한 이유

`flutter analyze`는 정적 분석으로 문법·타입·일부 코드 문제를 찾습니다. `flutter test`는 작성한 테스트가 기대 동작을 만족하는지 확인합니다. **테스트 통과가 모든 버그가 없음을 의미하지는 않습니다.**

단계별 보고 결과:

| 단계 | 핵심 테스트 범위 | 보고된 누적 통과 |
|---|---|---:|
| STEP 1 | 목록·검색·부족 표시 | 3 |
| STEP 2 | 상세 이동·복귀·검색 유지 | 5 |
| STEP 3 | 입출고·수량 경계값 | 9 |
| STEP 4 | Notifier 불변성·상태 공유 | 15 |
| STEP 5 | 로딩·오류·재시도·중복 방지 | 19 |
| STEP 6 | LOT별 출고·다른 레코드 불변성·합계 | 23 |

특히 중요한 테스트:

- 출고 후 **선택한 `id`만** 변경되는지
- 다른 LOT 및 다른 위치의 재고가 유지되는지
- 조회 실패 후 재시도 가능한지
- 출고 실패 후 입력값과 기존 재고가 유지되는지
- 같은 출고 요청이 제출 중 중복 처리되지 않는지
- Repository를 재조회해도 변경된 Mock 수량이 유지되는지

---

## 9. React 개발자를 위한 핵심 대응표

| React / TypeScript | Flutter / Dart | 기억할 점 |
|---|---|---|
| React 컴포넌트 | Widget | UI 구성 단위 |
| JSX 반환 | `build()`에서 Widget 반환 | UI 선언 |
| `useState` | `StatefulWidget` + `setState` | 로컬 상태 |
| Props | 생성자 파라미터 | 부모에서 데이터 전달 |
| `useEffect` cleanup | `dispose()` | Controller 등 자원 정리 |
| React Router | Navigator | 화면 이동 |
| Context + reducer | Riverpod Notifier | 공유 상태 관리의 유사한 패턴 |
| `useContext`/구독 hook | `ref.watch` | Provider 값 구독 |
| 이벤트 핸들러에서 store action | `ref.read(...notifier)` | 명령 호출 |
| `Promise<T>` | `Future<T>` | 비동기 결과 |
| `async/await` | `async/await` | 비동기 문법 |
| TanStack Query의 조회 상태 | `AsyncValue` | 로딩·데이터·오류 표현 |
| API service/repository | Repository | 데이터 접근 분리 |
| 객체 spread | `copyWith` | 불변 업데이트 |
| `filter` / `reduce` | `where` / `fold` | 목록 처리 |

**주의:** 표는 이해를 돕는 비유입니다. 각 프레임워크의 생명주기, 캐시, 리렌더링 규칙이 완전히 같지는 않습니다.

---

## 10. 면접에서 프로젝트를 설명하는 방법

### Q1. Flutter를 얼마나 사용해 보셨나요?

> 기존에는 React와 TypeScript로 MES 화면을 개발했습니다. Flutter는 새롭게 학습하면서 Mini MES 재고 관리 앱을 직접 구현했습니다. Widget과 Navigator부터 시작해 Riverpod 상태 관리, 비동기 Repository, LOT·위치별 재고 처리까지 단계적으로 확장했습니다. 아직 실제 Flutter 운영 서비스 경험은 없지만, React에서 익힌 상태 분리와 API 설계 원칙을 Flutter에 적용해 보았습니다.

### Q2. 왜 Riverpod을 도입했나요?

> 처음에는 목록 화면이 재고 상태를 가지고 상세 화면에 콜백을 전달했습니다. 화면이 늘어날수록 상태 전달과 동기화가 복잡해질 수 있어, 재고 상태를 Notifier로 옮겼습니다. 목록과 상세는 같은 Provider를 구독하고, 검색어나 폼 입력처럼 화면에서만 쓰는 값은 로컬 상태로 유지했습니다.

### Q3. 왜 Repository를 분리했나요?

> UI와 상태 관리가 Mock 데이터 구현에 직접 의존하지 않도록 하기 위해서입니다. Repository 인터페이스를 두면 추후 HTTP 구현으로 교체하기 쉽고, 테스트에서는 Fake Repository를 주입해 오류·지연·재시도 상황을 재현할 수 있습니다.

### Q4. LOT별 재고를 어떻게 구분하나요?

> `itemCode`는 품목 식별과 합계 기준이고, `lotNo`는 배치 번호, `location`은 보관 위치입니다. 실제 출고는 고유한 재고 레코드 `id`를 기준으로 처리합니다. 전체 품목 재고가 충분해도 선택한 LOT·위치의 수량이 부족하면 출고를 거절합니다.

### Q5. Flutter에서 출고 중 타임아웃이 발생하면요?

> 타임아웃은 처리 결과가 불확실하다는 뜻이므로 무조건 재요청하지 않습니다. 서버에서 멱등성 키와 거래 상태 조회를 지원하도록 설계하고, 결과 확인 후 최신 재고를 다시 조회하겠습니다.

---

## 11. 앞으로 복습할 순서

1. **Widget 기본:** `StatelessWidget`, `StatefulWidget`, `build`, `setState`
2. **화면 이동:** `Navigator.push/pop`, `itemId` 전달
3. **상태 관리:** 로컬 State와 Riverpod의 역할, `watch/read`
4. **데이터 흐름:** UI → Notifier → Repository
5. **비동기 처리:** `Future`, `AsyncValue`, 오류·재시도
6. **MES 도메인:** 품목/LOT/위치 식별, 합계와 출고 기준
7. **실무 정합성:** 동시성, 멱등성, 타임아웃

### 직접 설명할 수 있는지 확인하기

- [ ] `StatelessWidget`도 다시 빌드될 수 있는 이유를 설명할 수 있다.
- [ ] `setState()`와 `ref.watch()`의 차이를 설명할 수 있다.
- [ ] 상세 화면에 객체 대신 `itemId`를 전달하는 이유를 설명할 수 있다.
- [ ] 재고를 불변 업데이트하는 이유를 설명할 수 있다.
- [ ] Notifier와 Repository의 역할을 구분할 수 있다.
- [ ] `AsyncValue`의 Loading/Data/Error를 설명할 수 있다.
- [ ] 조회 로딩과 출고 제출 상태를 따로 관리하는 이유를 설명할 수 있다.
- [ ] 같은 품목의 서로 다른 LOT·위치를 구분할 수 있다.
- [ ] 프론트 검증만으로 동시 출고를 막을 수 없는 이유를 설명할 수 있다.
- [ ] 출고 타임아웃이 곧 출고 실패가 아닌 이유를 설명할 수 있다.

---

## 12. 현재 프로젝트의 한계와 다음 단계

현재 Mini MES는 **학습용 Mock 앱**입니다.

- 앱 재시작 시 Mock 초기 데이터로 돌아옵니다.
- 실제 HTTP API, DB, 인증, 권한 처리는 없습니다.
- 여러 기기 간 데이터 동기화나 서버 측 동시성 제어는 구현하지 않았습니다.
- 단위 일치, 안전재고 기준, 재고 레코드의 고유성 규칙은 단순화했습니다.

다음 학습은 무작정 기능을 추가하기보다 **현재 소스를 직접 읽으면서 각 파일의 책임을 설명하는 코드 리뷰**가 좋습니다. 특히 `inventory_provider.dart`, `inventory_repository.dart`, `mock_inventory_repository.dart`, `inventory_screen.dart`, `inventory_detail_screen.dart`를 실제 코드와 대조해 보면 이해가 빨라집니다.

**한 줄 요약:** Flutter Widget은 UI를 만들고, Riverpod은 공유 상태를 관리하며, Repository는 데이터 접근을 분리합니다. 재고 정합성의 최종 책임은 실제 서버와 DB에 있습니다.
