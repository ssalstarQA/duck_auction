Duck Auction 결제/낙찰 시나리오 테스트 패치

적용 방법:
- 압축을 풀고 lib 폴더를 기존 프로젝트에 덮어씌우세요.
- master@duckauction.com 계정으로 로그인 후 마이페이지 > 개발자 모드에서 사용하세요.

추가 내용:
- 관리자 메뉴에 결제/낙찰 시나리오 테스트 추가
- 1순위 24시간 결제대기
- 1순위 미결제/포기 시 2순위 승계 또는 유찰
- 2순위 12시간 결제대기
- 2순위 미결제/포기 시 3순위 승계 또는 유찰
- 3순위 12시간 결제대기
- 3순위 미결제 시 유찰
- 결제완료 / 배송중 / 거래완료 테스트 상태 추가
- 미결제/포기 시 paymentWarningCount 증가용 필드 기록

주의:
- 실제 결제 API/푸시 발송은 아직 연결하지 않았습니다.
- Firestore products 문서의 status/paymentRank/paymentDeadlineAt/paymentTestScenario 필드를 테스트용으로 업데이트합니다.
