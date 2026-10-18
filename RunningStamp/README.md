# RunStamp HealthKit POC

RunStamp reads Apple Watch running workouts from Apple Health, analyzes heart-rate zone time, and renders a SwiftUI running poster.

## HealthKit Setup

The `RunStamp` target must have HealthKit enabled in Xcode under Signing & Capabilities.

The app also needs this Info.plist key:

- `NSHealthShareUsageDescription`: 한국어로 작성되어 있으며(타깃 빌드 설정 `INFOPLIST_KEY_NSHealthShareUsageDescription`), 러닝 운동·심박·거리·칼로리·경로·생년월일을 읽는 이유를 설명합니다.

RunStamp requests read access for workouts, heart rate, active energy burned, distance walking/running, workout routes, and date of birth (used to derive the heart-rate zone ceiling as 220 − age; a manual override lives in Settings).

Posters always show real HealthKit numbers. Runs without heart-rate samples (for example phone-only runs) render as a "light poster" with distance, time, pace, calories and route only. Sample data is used solely by SwiftUI previews.

## 온보딩

최초 실행 시 3장짜리 온보딩(포스터 예시 → 심박 존 분석·알림·공유 소개 → Apple 건강 연결)을 보여준 뒤 HealthKit 권한을 요청합니다. "나중에 할게요"를 고르면 홈의 Apple Health 카드에서 수동으로 연결할 수 있습니다. 완료 여부는 `AppPreferences.hasCompletedOnboarding`(UserDefaults `onboarding_completed_v1`)에 저장됩니다. 온보딩을 다시 보려면 앱을 삭제 후 재설치하세요.

## 문자열과 로컬라이제이션

- 프로젝트 개발 언어는 한국어(`developmentRegion = ko`)이며 `MyApp/Localizable.xcstrings` 문자열 카탈로그를 사용합니다. `SWIFT_EMIT_LOC_STRINGS = YES`라 SwiftUI `Text("…")` 리터럴과 `String(localized:)`가 빌드 시 카탈로그에 자동 추출됩니다.
- 뷰 밖(서비스·뷰모델·알림)에서 쓰는 문자열은 `MyApp/Utilities/AppStrings.swift`에 모여 있습니다. 영어를 추가할 때는 카탈로그에 `en`을 추가하고 번역만 채우면 됩니다.
- 포스터 안의 `RUNSTAMP`, `ZONE`, `FREE RUN` 같은 대문자 영문은 디자인 요소라 의도적으로 영어로 둡니다.

## 인스타그램 스토리 공유 설정

`instagram-stories://share`는 `source_application`에 Meta 앱 ID를 요구합니다. 값이 없으면 인스타그램 버전에 따라 공유가 거부되거나 스토리에 앱 출처가 붙지 않습니다.

1. https://developers.facebook.com 에서 앱을 만듭니다(유형: 소비자 / 기타).
2. 대시보드 상단의 **앱 ID**(숫자)를 복사합니다.
3. `RunningStamp/Info.plist`의 `MetaAppID` 값에 붙여 넣습니다.
4. 앱 설정 > 기본 설정에 iOS 플랫폼을 추가하고 번들 ID(`com.imdaeheun.RunStamp2026`)를 등록합니다.

`InstagramStoryService.isConfigured`가 false면 DEBUG 로그에 경고가 남습니다.

## 계측 (Analytics)

`MyApp/Services/Analytics.swift`에 퍼널 이벤트 11종이 정의되어 있고 호출 지점은 이미 심어져 있습니다.

| 이벤트 | 파라미터 | 위치 |
| --- | --- | --- |
| `app_launched` | – | `RunStampApp.init` |
| `onboarding_completed` | `health_connect` yes/later | 온보딩 마지막 장 |
| `health_authorization` | `result` granted/denied/unavailable | 권한 요청 결과 |
| `runs_loaded` | `count_bucket` | 러닝 목록 로드 |
| `run_opened` | `heart_rate`, `indoor` | 상세 화면 리포트 생성 |
| `poster_saved` | `format`, `heart_rate` | 이미지로 저장 |
| `poster_shared` | `format`, `heart_rate` | 공유 시트 |
| `instagram_story_share` | `result` opened/fallback_share_sheet | 인스타 스토리 버튼 |
| `poster_notification` | `action` scheduled/tapped | 러닝 종료 알림 |
| `pro_feature_locked` | `feature` | PRO 잠금 안내 노출 |
| `setting_changed` | `key` | 설정 변경 |

건강 수치(거리·심박·위치)는 어떤 이벤트에도 포함되지 않으며, 설정 > 데이터 > "익명 사용 통계 보내기"를 끄면 아무것도 보내지 않습니다.

기본 백엔드 `OSLogAnalyticsBackend`는 Console.app(카테고리 `Analytics`)에만 기록합니다. TelemetryDeck을 붙이려면:

1. Xcode > File > Add Package Dependencies… 에서 `https://github.com/TelemetryDeck/SwiftSDK` 추가
2. `Analytics.swift` 상단 주석의 `TelemetryDeckBackend`를 추가하고, `RunStampApp.init`에서 `TelemetryDeck.initialize(config:)` 후 `Analytics.shared.backend = TelemetryDeckBackend()` 지정
