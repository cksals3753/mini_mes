# Mini MES STEP 1~6 인수인계 프롬프트

아래 내용을 새 대화에 붙여 넣고 마지막에 다음 작업 요구사항을 작성하세요.

```text
저는 React/TypeScript 개발자이며 Flutter를 처음 배우고 있습니다.
Flutter 기반 스마트팩토리 MES 모바일 재고 관리 앱인 mini_mes를 개발하고 있습니다.

STEP 1~6을 구현한 상태입니다. 다음 작업 전에 프로젝트의 실제 코드와 설정을 먼저 확인하고, 기존 기능을 유지하면서 요청 범위만 변경해 주세요.

[개발 환경]
- Flutter 3.47.9 / Dart 3.13.7
- flutter_riverpod 3.4.3
- Material 3 기반 모바일 우선 UI
- Chrome에서 실행
- 실제 HTTP API, 백엔드, DB 없음
- 비동기 Mock Repository 사용

[현재 디렉터리 구조]
lib/
  main.dart
  models/
    inventory_item.dart
  data/
    mock_inventory.dart
  repositories/
    inventory_repository.dart
    mock_inventory_repository.dart
  providers/
    inventory_provider.dart
  screens/
    inventory_screen.dart
    inventory_detail_screen.dart
  widgets/
    inventory_card.dart
    inventory_summary.dart
    inventory_async_status.dart
    item_stock_totals.dart

test/
  widget_test.dart
  stock_transaction_test.dart
  inventory_notifier_test.dart
  async_inventory_test.dart
  lot_inventory_test.dart

[STEP 1 — 재고 목록]
- InventoryItem 모델과 Mock 데이터 구현
- 품목코드·품목명 검색
- 검색어 지우기 및 결과 없음 안내
- quantity < safetyStock이면 재고 부족 표시
- 상단 전체 재고 기록 수와 부족 기록 수 표시
- 검색 중에도 상단 요약은 전체 데이터 기준
- models/data/screens/widgets로 코드 분리

[STEP 2 — 상세 화면 이동]
- 카드 전체를 InkWell로 터치 가능하게 구현
- InventoryCard에 VoidCallback? onTap 제공
- Navigator.push와 MaterialPageRoute로 상세 이동
- AppBar 기본 뒤로 가기와 Navigator.pop 사용
- 목록으로 돌아오면 검색 상태 유지
- 현재 상세 화면은 객체 대신 itemId를 전달받음

[STEP 3 — 입고·출고]
- 상세 화면에 입고·출고 선택 및 수량 입력 폼 구현
- 양의 정수만 처리
- 빈 값, 0, 음수, 소수, 문자, 지수 표기, 공백 포함 입력 거절
- 현재고 초과 출고 차단
- 전량 출고 허용, 0 재고에서 추가 출고 차단
- Chrome의 정확한 정수 범위를 고려해 최대 수량 검증
- InventoryItem의 final 필드와 copyWith를 통한 불변 업데이트

[STEP 4 — Riverpod 상태 분리]
- 최상위 ProviderScope 적용
- 재고 목록과 변경 로직을 InventoryNotifier로 이동
- 검색어는 InventoryScreen의 로컬 상태로 유지
- 상세 화면은 itemId로 Provider의 최신 데이터를 조회
- ref.watch로 상태 구독
- ref.read로 Notifier 메서드 호출
- 폼 입력과 입출고 선택 상태는 상세 화면의 로컬 상태

[STEP 5 — 비동기 Repository]
- InventoryRepository 추상 인터페이스:
  - Future<List<InventoryItem>> fetchInventory()
  - Future<List<InventoryItem>> changeStock(
      String id, int amount, bool isIncoming
    )
- MockInventoryRepository:
  - Future.delayed로 기본 400ms 지연
  - 메모리에 재고 저장
  - 입출고 결과가 다음 조회에도 유지
  - failNextFetch, failNextChange로 다음 요청 한 번 실패 가능
- inventoryRepositoryProvider로 Repository 주입
- 테스트에서 overrideWithValue로 교체 가능
- inventoryProvider는 AsyncNotifierProvider 사용
- 조회 상태는 AsyncValue로 loading/data/error 구분
- 조회 오류 시 재시도 버튼 제공
- ref.invalidate(inventoryProvider)로 재조회
- Provider의 자동 재시도는 비활성화하고 수동 재시도 사용
- 입출고 중 입력·선택·제출 버튼 비활성화
- Notifier에서도 중복 요청 차단
- 입출고 중 기존 조회 데이터 유지
- 실패 시 기존 재고와 입력값 유지
- 성공 시 목록·상세·합계·부족 상태 동기화
- 비동기 처리 후 mounted/ref.mounted 확인

[STEP 6 — 여러 LOT와 위치]
InventoryItem 필드:
- id: 특정 품목·LOT·위치의 재고 레코드 한 건을 식별하는 고유 키
- itemCode: 품목 코드, 합계 그룹 기준
- itemName: 품목명
- lotNo: 생산/입고 배치 번호
- quantity: 해당 레코드의 현재고
- safetyStock: 해당 레코드의 안전재고
- unit: 단위
- location: 해당 레코드의 보관 위치

중요한 도메인 규칙:
- 같은 itemCode에 여러 LOT가 존재할 수 있음
- 같은 LOT가 여러 위치에 존재할 수 있음
- 입출고는 반드시 선택한 재고 레코드 id 기준
- 다른 LOT 또는 위치의 재고는 변경하지 않음
- 품목 전체 합계가 충분해도 선택 레코드의 수량이 부족하면 출고 거절
- 부족 여부는 레코드별 quantity < safetyStock 기준
- 품목별 합계는 조회용이며 출고 가능 여부를 대신하지 않음
- 동일 품목의 단위는 같다고 가정
- 불필요하게 복잡한 도메인 모델은 만들지 않음

현재 Mock 데이터:
- 총 14개 재고 레코드, 10개 품목
- 초기 부족 레코드 4개
- RM-001 알루미늄 판재는 5개 레코드, 4개 LOT, 합계 355장
  - id 1: LOT-261001 / A-01-01 / 120장
  - id 11: LOT-261011 / A-01-01 / 60장
  - id 12: LOT-261012 / A-01-01 / 70장
  - id 13: LOT-261013 / A-01-01 / 80장
  - id 14: LOT-261001 / A-03-01 / 25장
- id 1의 안전재고는 50장, 추가한 id 11~14는 각각 20장
- 목록에 펼칠 수 있는 품목별 합계 UI 제공
- 합계는 검색 결과 기준으로 itemCode별 계산
- 기존 LOT·위치별 카드는 유지

[검증 상태]
마지막 작업 기준:
- flutter analyze: 문제 없음
- flutter test: 23개 모두 통과

테스트 범위:
- 검색·검색 초기화·모바일 스크롤
- 상세 이동·ID 전달·뒤로 가기·검색 상태 유지
- copyWith 불변성
- 입출고 및 안전재고 경계값
- 잘못된 수량·초과 출고 차단
- 조회 로딩·오류·재시도
- 중복 제출 차단
- Repository 메모리 저장 유지
- 컨테이너별 상태 격리
- 동일 품목의 여러 LOT와 동일 LOT의 여러 위치
- 선택한 id 외 레코드 불변성
- 합계·목록·상세·부족 상태 동기화

[작업 방식]
1. 실제 코드와 설치 버전을 먼저 확인해 주세요.
2. 기존 구조를 유지하고 최소 변경으로 구현해 주세요.
3. 요청과 관계없는 UI 리팩토링이나 기능은 추가하지 마세요.
4. 실제 HTTP API, DB, 추가 상태 관리 패키지는 별도 요청 없이 도입하지 마세요.
5. 변경에 맞는 테스트를 추가·보완해 주세요.
6. flutter analyze와 flutter test를 실행하고 문제를 수정해 주세요.
7. 완료 후 변경 파일, 변경 이유, 설계 판단, 검증 결과를 설명해 주세요.
8. Flutter 초보자가 이해할 수 있도록 React/TypeScript와 비교해 주세요.
   필요하면 React Context, 불변 업데이트, TanStack Query와 연결해 설명해 주세요.
9. Mock 데이터는 앱 재시작 시 초기화된다는 현재 동작을 유지해 주세요.

이번에 구현할 작업:
[여기에 STEP 7 요구사항을 작성]
```
