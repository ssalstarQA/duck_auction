# 📌 토스페이먼츠 계약 확정 후 한 번에 할 일 (POST-TOSS TODO)

> 이 문서는 앱스토어 심사를 먼저 넣고, 토스 계약이 확정되면 SNS 로그인 실연동 +
> 결제 연동 + 임시 처리해둔 것들을 한 번에 마무리하기 위한 마스터 체크리스트예요.
> (작성 시점: 앱 버전 1.0.0+60 기준)

---

## A. SNS 로그인 (카카오·네이버·구글) 실서비스 연결

**근본 원인**: Play 스토어로 설치한 앱은 "Play 앱 서명 키"로 재서명되는데, 그 키의
SHA/키해시가 각 콘솔에 등록돼 있지 않아 카카오·네이버·구글 로그인이 실패함.
(로컬 릴리즈 APK = 업로드키 서명이라 그건 이미 등록돼 있어 동작함 → 코드 자체는 정상)

### 공통 선행 작업
- [ ] Play Console → 테스트 및 출시 → **앱 무결성 → 앱 서명 키 인증서**에서
      **SHA-1 / SHA-256** 복사해두기 (이게 세 곳 등록의 기준값)

### 구글
- [ ] Firebase 콘솔 → 프로젝트 설정 → Android 앱 → **SHA 인증서 지문**에 위 SHA-1 추가
- [ ] **google-services.json 다시 다운로드** → `android/app/google-services.json` 덮어쓰기
- [ ] (증상: `PlatformException(sign_in_failed, ...:10:)` = DEVELOPER_ERROR = SHA 불일치)

### 카카오
- [ ] 위 SHA-1을 **키 해시(base64)** 로 변환 (Claude가 계산해줌: base64(SHA-1 바이너리))
- [ ] 카카오 개발자 → 내 애플리케이션 → 플랫폼 → Android → **키 해시 추가**
- [ ] 네이티브 앱 키: `d5a6ccea8c6530aa9960040510384c1f` (이미 코드/매니페스트에 반영됨)

### 네이버
- [ ] 네이버 개발자 → 애플리케이션 → API 설정 → Android → **패키지명 `com.duckauction.app`** 등록 확인
- [ ] Client ID `dpxPDMk7MCKaUv4lgdKR` / Client Secret 값 재확인 (매니페스트·index.js)
- [ ] (증상: 새로 넣은 "네이버 토큰을 받지 못했어요..." 스낵바가 뜨면 콘솔 설정 문제)

### iOS
- [ ] 카카오·네이버·구글 iOS 로그인 실기기 테스트 (URL 스킴·plist는 이미 설정됨)
- [ ] 애플 로그인은 동작 확인됨 (Services ID `com.duckauction.signin`)

### 참고: Cloud Function 커스텀 토큰 권한
- [ ] 만약 함수 로그에 `iam.serviceAccounts.signBlob` / `IAM Service Account Credentials API`
      에러가 뜨면 → GCP IAM에서 함수 서비스계정(`203119332761-compute@developer.gserviceaccount.com`)에
      **"Service Account Token Creator"** 역할 부여 + **IAM Service Account Credentials API** 활성화

### 관련 파일
- `lib/screens/login_screen.dart` — _kakaoLogin / _naverLogin / _googleLogin / _appleLogin
- `functions/index.js` — exports.kakaoLogin / exports.naverLogin (커스텀 토큰 발급)
- `android/app/google-services.json`, `android/app/src/main/AndroidManifest.xml`

---

## B. 결제 (토스페이먼츠) 연동  ← 토스 계약 확정 후

- [ ] 토스 실연동 (결제창 / 정산 모델 확인)
- [ ] **정산 계좌**: 지금은 은행·계좌번호·예금주만 저장(users/{uid}/private/payoutAccount).
      토스 정산 모델 확정되면 → 예금주 == 판매자 본인 검증(1원 인증 또는 PG 계좌검증) 추가
- [ ] `betaMode` = false 로 전환 (config/app 문서) → 베타 결제 게이트 우회 해제
- 관련: `toss_checkout_screen`(home_screen.dart part), TradeReadinessScreen의 [정산계좌] 주석

---

## C. 정식 출시 전 정리할 임시 처리들

- [ ] **로그인 실패 안내 문구 되돌리기** — 현재 카카오·네이버·구글 실패 시
      "실제 연동을 준비 중이에요..." 안내 문구로 임시 표시 중(심사·사용자용).
      실연동 완료되면 정상 로그인되므로 이 문구는 자연히 안 뜨지만, 필요 시
      일반 재시도 문구로 정리. (login_screen.dart)
- [ ] `config/app.bypassAllVerification` = **false** 확인 (Firestore) — 인증 우회 해제
- [ ] `DuckAuctionStore.betaMode` = **false** (config/app) — 정식 모드
- [ ] `functions/index.js`의 recommendPrice 진단 로그(`console.log('[rec]...')`) 정리
- [ ] SNS 로그인 실연동 후, 심사용으로 숨겼던 버튼이 있으면 되살리기 (이번엔 안 숨김)

---

## 이미 완료된 것 (참고)
- 애플 로그인 (Services ID `.app` 오타 수정)
- 인증 메일 커스텀(배너·마스코트) — emailImage 함수 + sendVerificationEmail, 배포 완료
- 정산 계좌 등록 화면 + 경매 등록 전 필수화 (비공개 서브컬렉션 저장)
- SNS 로그인 시 이메일 인증 단계 숨김 (이메일/비번 가입자만 표시)
- AI 추천가: 분석 후 제목 포커스 튐 / 재토글 시 잔상 수정
- 게스트 안내 시트 여백, 크롭 화면 네비바, 스플래시 흰 화면 등 UI 수정
