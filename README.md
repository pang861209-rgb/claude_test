# 약먹핑 💊💗

약 먹은 사진을 찍어 **인증할 때까지 알림이 계속 오는** 개인용 복약 인증 iOS 앱.
아침·저녁 2회 복약을 응원·칭찬 톤으로 챙겨주고, 캘린더로 기록을 돌아볼 수 있어요.

> 기획서 기준 **P0 요구사항** 전체 구현 + 인터랙션/애니메이션 강화 버전.

## 스택

| 항목 | 내용 |
|---|---|
| 플랫폼 | iOS 17+ (iPhone 전용, 세로 고정) |
| UI | SwiftUI |
| 데이터 | SwiftData (기기 내 로컬 저장, 서버·계정 없음) |
| 사진 | 앱 Documents/photos에 JPEG 저장, DB엔 상대 경로만 |
| 알림 | UserNotifications 로컬 알림 (`.timeSensitive`) |
| 카메라 | UIImagePickerController(camera) — 실시간 촬영만, 앨범 선택 불가 |
| 빌드 | **Xcode 16+** (file system synchronized groups 사용, objectVersion 77) |

## 구현된 기능 (P1)

- **잠금화면·홈 위젯** (`YakmeokpingWidget` 타겟) — 잠금화면 원형/직사각형 + 홈 small. 아침/저녁 하트 상태·시간·streak 표시. App Group(`group.com.yakmeokping.app`) UserDefaults 스냅샷으로 앱과 동기화, 상태 변화 시 즉시 갱신 + 30분 자체 갱신.
- **앱 아이콘** — 오리지널 핑핑이 얼굴 (스크립트 생성, 1024px).
- **지연 완료 뱃지** — 예정 +2시간 이후 인증 시 "늦어도 해냈어요! 💜" (칭찬 톤 유지, 완료 시점의 예정 시각 스냅샷으로 판정).
- **Dynamic Type** — 모든 폰트가 시스템 글자 크기 설정을 따라 스케일.
- **커스텀 알림 사운드** — 밝은 벨 아르페지오 (`notification_chime.wav`, 스크립트 합성).

## 구현된 기능 (P0.5 — 루프 구멍 메우기)

UX 아키텍처 리뷰(`docs/UX-ARCHITECTURE.md`) 반영분:

- **온보딩 + 권한 프라이밍** — 첫 실행 3장 온보딩(핑핑이 인사 → 동작 설명 → 시간 설정). 시스템 권한 팝업은 "알림 받고 시작하기"를 누른 뒤에만 표시.
- **자정 넘김 귀속 (기획 §10)** — 새벽 03시 이전에 어제 저녁이 미인증이면 홈에 "어제 저녁 약 인증" 카드 노출, 인증은 어제 기록으로 귀속. 알림 탭도 dayKey 기반으로 원래 날짜에 귀속.
- **조기 인증 (`soon` 상태)** — 슬롯 시각 2시간 전부터 조용한 "미리 인증하기" 버튼. 일찍 먹는 날을 자연스럽게 흡수.
- **희소 후속 알림** — 12회(1시간) 배치 이후 +90분/+120분/+180분에 부담 없는 톤의 후속 알림 3개. 인증 시 함께 취소.
- **축하 화면 개선** — 핑핑이가 폴짝 등장, 2.8초 + 탭으로 즉시 닫기.
- **사진 AI 판독 (소프트 게이트)** — Apple Vision 내장 분류로 기기 내 판독(서버·비용 없음). 약으로 안 보이면 "다시 찍기 / 그래도 인증" 선택지 제공 — 오탐이 정직한 인증을 막지 않도록 경고까지만.
- **카메라 전용 강제** — 카메라 불가 환경에서 앨범 폴백 제거, 안내 화면으로 대체.

## 구현된 기능 (P0)

- **P0-1 스케줄 설정** — 아침/저녁 시각·on/off 토글. 변경 시 알림 전체 재예약.
- **P0-2 반복 알림** — 복용 시각부터 5분 간격 12개(1시간) 예약, 앱 열 때 미인증이면 다음 배치로 연장. 문구는 회차별 순차 변화. 인증 즉시 해당 슬롯 알림 전체 취소.
- **P0-3 사진 인증** — 카메라 → 미리보기 → 확정 → 사진 저장·기록 완료·알림 취소 → 축하 애니메이션. 알림 탭 시 해당 슬롯 카메라로 직행.
- **P0-4 홈 화면** — 오늘 날짜, 슬롯 카드 2개(대기/지금 먹을 시간/완료), streak(하루 2회 모두 완료한 날만 카운트).
- **P0-5 캘린더 히스토리** — 월간 뷰, 날짜별 아침/저녁 하트 2개, 날짜 상세(완료 시각·인증 사진), 월간 완료율 %.

## 인터랙션·애니메이션 강화

앱에 흥미를 갖고 약 먹기에 집중할 수 있도록 반응형 효과를 넣었어요:

- **오리지널 마스코트 "핑핑이"** (`MascotView`) — SwiftUI 도형으로 직접 그린 캐릭터. 숨쉬듯 통통 움직이고, 눈을 깜빡이고, 약 먹을 시간이나 인증 완료 시 폴짝 뛰며 표정이 바뀜.
- **통통 튀는 버튼** (`BouncyButtonStyle`) + 햅틱 진동 — 모든 주요 버튼.
- **하트 터짐 효과** (`HeartBurstView`) — 인증 완료 시 화면에 하트가 사방으로 뿅.
- **시선 유도 wiggle** — "지금 먹을 시간" 카드가 주기적으로 살짝 흔들림.
- **등장 애니메이션** (`popIn`) — 카드/요소가 아래에서 튀어오르며 등장.
- **축하 파티클 화면** — 하트·반짝이 40개가 떠오르고 랜덤 칭찬 문구 표시 (2초 후 자동 복귀).

## 디자인

메인 핑크 `#FF8FC7` / 라이트핑크 `#FFE1F0` / 포인트 퍼플 `#C89AF5` / 배경 크림 `#FFF8FB`,
SF Pro Rounded, 큰 둥근 모서리, 하트·반짝이·리본 모티프. 모든 문구는 질책 없는 응원·칭찬 톤.

> **캐릭터 IP 관련**: 기획서 방침(§9)과 저작권 보호를 위해 특정 캐릭터(예: 시중 애니메이션 캐릭터)는 사용하지 않고, 같은 무드만 살린 **오리지널 마스코트**를 직접 구현했습니다.

## 프로젝트 구조

```
Yakmeokping/
├── YakmeokpingApp.swift          앱 진입점, SwiftData 컨테이너, 알림 델리게이트
├── Models/
│   ├── MedicationRecord.swift    복약 기록 (@Model), Slot/Status
│   └── AppSettings.swift         설정 (@Model)
├── Services/
│   ├── NotificationScheduling.swift  ★ 순수 예약 계산 로직 (단위 테스트 대상)
│   ├── NotificationManager.swift     UNUserNotificationCenter 연동
│   ├── PhotoStorage.swift            사진 리사이즈(1280)·저장·로드
│   ├── MedicationStore.swift         기록 CRUD, streak, 완료율
│   └── PermissionManager.swift       알림·카메라 권한
├── Design/
│   ├── Theme.swift               컬러·폰트·카드 스타일·칭찬 문구
│   ├── Haptics.swift             촉각 피드백
│   ├── Interactions.swift        버튼/등장/wiggle/하트버스트 효과
│   └── MascotView.swift          오리지널 마스코트
└── Views/
    ├── RootView.swift            탭 컨테이너 + 부트스트랩/foreground 로직
    ├── Home/                     홈·슬롯 카드·streak
    ├── Camera/                   카메라 캡처·인증 플로우
    ├── Celebration/              축하 파티클 화면
    ├── Calendar/                 월간 캘린더·날짜 상세
    └── Settings/                 설정 화면
YakmeokpingTests/
└── NotificationSchedulingTests.swift  알림 로직 단위 테스트
```

## 빌드 방법

1. **Xcode 16 이상**에서 `Yakmeokping.xcodeproj`를 연다.
2. Signing & Capabilities에서 본인 팀 선택.
   - **Time Sensitive Notifications** capability가 켜져 있어야 `.timeSensitive` 알림이 집중 모드를 뚫습니다(`Yakmeokping.entitlements`에 키 포함). 무료 계정에선 이 capability 서명이 제한될 수 있어요 → 서명 오류 시 해당 capability/entitlement를 잠시 빼고 테스트하세요.
3. 실기기(iPhone) 선택 후 Run. (카메라·timeSensitive 알림은 시뮬레이터에서 제대로 확인 불가)

### 테스트 실행

```
⌘U  (또는)  xcodebuild test -scheme Yakmeokping -destination 'platform=iOS Simulator,name=iPhone 15'
```

`NotificationSchedulingTests`가 식별자 규칙·5분 간격·문구 단계·연장 회차 계산 등을 검증합니다.

## 실기기 테스트 체크리스트 (기획서 §11-6)

- [ ] 설정한 시각에 알림 도착
- [ ] 미인증 시 5분 간격 반복 알림
- [ ] 인증 즉시 해당 슬롯 남은 알림 전부 중단
- [ ] 아침 인증이 저녁 알림에 영향 없음
- [ ] 알림 탭 → 카메라 직행
- [ ] 앱 완전 종료 상태에서도 알림 수신
- [ ] 재부팅 후 알림 유지
- [ ] 슬롯 off 시 해당 알림 안 옴
- [ ] 자정 넘겨 인증해도 "슬롯의 날짜" 기준으로 기록

## 이번 버전에서 하지 않은 것 (기획서 §3, P1/P2)

서버·계정·클라우드 동기화, 사진 진위 판별, 약 종류별 다중 슬롯, 보호자 알림, Android.
커스텀 사운드·사진 프레임 내보내기·위젯·지연 완료 구분은 P1로 남겨둠.

## 기획서와의 의도적 차이

- `AppSettings`의 시각을 `DateComponents` 대신 `Int(hour/minute)`로 저장 — SwiftData 조회 안정성. `morningComponents` 등 접근자로 동일하게 사용.
- `MedicationRecord`의 enum을 rawValue 문자열로 저장 — `#Predicate` 안정성. `slot`/`status` 계산 프로퍼티로 노출.
