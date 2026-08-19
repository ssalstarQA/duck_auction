// 기본 스모크 테스트입니다.
//
// Flutter가 프로젝트 생성 시 넣어주는 기본 템플릿 테스트는 존재하지 않는
// `MyApp`(카운터 앱)을 참조해서 `flutter analyze`에 error를 남겼어요.
// 덕옥션 앱(DuckAuctionApp)은 실행 시 Firebase 초기화가 필요해서, 위젯을
// 그대로 pump 하면 테스트 환경에서 초기화가 실패합니다. 그래서 지금은 항상
// 통과하는 자리표시 테스트로 대체해 두었어요. 실제 위젯 테스트가 필요하면
// firebase_core 목업(setupFirebaseAuthMocks 등)을 붙여 따로 작성하면 됩니다.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('앱 스모크 테스트(자리표시)', () {
    expect(1 + 1, 2);
  });
}
