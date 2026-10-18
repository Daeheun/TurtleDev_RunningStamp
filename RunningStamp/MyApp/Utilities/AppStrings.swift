import Foundation

/// 뷰 밖(서비스·뷰모델·알림)에서 쓰는 사용자 노출 문자열 모음.
/// SwiftUI `Text` 리터럴과 함께 `Localizable.xcstrings`로 추출되므로
/// 영어권 확장 시 이 파일과 카탈로그만 손보면 된다.
enum AppStrings {
    enum Health {
        static let notConnected = String(localized: "연결 안 됨", comment: "HealthKit 권한 상태")
        static let unavailable = String(localized: "HealthKit 사용 불가", comment: "HealthKit 권한 상태")
        static let connected = String(localized: "연결됨", comment: "HealthKit 권한 상태")
        static let permissionNeeded = String(localized: "권한 필요", comment: "HealthKit 권한 상태")

        static let usageDescriptionMissing = String(localized: "앱 Info.plist에 NSHealthShareUsageDescription이 없습니다. RunStamp 타깃에 추가한 뒤 다시 시도해 주세요.")
        static let dataUnavailable = String(localized: "이 기기에서는 HealthKit을 사용할 수 없습니다.")
        static let workoutUnavailable = String(localized: "선택한 러닝 기록을 더 이상 찾을 수 없습니다. 최근 러닝을 다시 불러온 뒤 시도해 주세요.")

        static let authorized = String(localized: "Apple Health에서 최근 러닝 운동을 불러올 수 있습니다.")
        static let noRecentRuns = String(localized: "최근 Apple Watch 러닝 기록을 찾지 못했습니다.")
    }

    enum Report {
        static let indoorRoute = String(localized: "실내 러닝이라 GPS 경로 대신 실내 Effort Wave를 표시합니다.")
        static let noRoute = String(localized: "경로 데이터가 없어 포스터에는 Effort Wave를 표시합니다.")
        static let routeLoadFailed = String(localized: "경로 데이터는 불러오지 못했지만 심박 분석은 계속합니다.")
        static let lightPosterNoSamples = String(localized: "심박 샘플이 없어 거리·페이스 중심의 라이트 포스터를 생성했습니다.")

        static func routeCoordinates(_ count: Int) -> String {
            String(localized: "경로 좌표 \(count)개를 반영했습니다.")
        }

        static func analyzedSamples(_ count: Int) -> String {
            String(localized: "실제 HealthKit 심박 샘플 \(count)개를 분석했습니다.")
        }

        static func lightPosterAfterError(_ reason: String) -> String {
            String(localized: "심박 데이터를 불러오지 못해 라이트 포스터를 생성했습니다. \(reason)")
        }
    }

    enum Export {
        static let noPoster = String(localized: "아직 생성된 포스터가 없습니다.")
        static let renderFailed = String(localized: "포스터 이미지를 생성하지 못했습니다.")
        static let shareRenderFailed = String(localized: "공유할 포스터 이미지를 생성하지 못했습니다.")
        static let saved = String(localized: "포스터 이미지를 사진 보관함에 저장했습니다.")
        static let defaultLayoutFirst = String(localized: "기본 배치 상태입니다. 먼저 레이아웃을 편집한 뒤 프리셋으로 저장해 주세요.")

        static func presetLimit(_ count: Int) -> String {
            String(localized: "프리셋은 형식별로 최대 \(count)개까지 저장할 수 있습니다.")
        }
    }

    enum Pro {
        static let contentHighlightLocked = String(localized: "콘텐츠 강조는 PRO 기능입니다. 업그레이드 후 이용할 수 있습니다.")
        static let layoutLocked = String(localized: "포스터 레이아웃 커스텀은 PRO 기능입니다. 업그레이드 후 이용할 수 있습니다.")
    }

    enum Notification {
        static let posterReadyTitle = String(localized: "오늘의 러닝 포스터가 준비됐어요 🔥")
        static let posterReadyBodyFallback = String(localized: "탭해서 포스터를 확인하고 공유해 보세요.")

        static func posterReadyBody(distanceText: String) -> String {
            String(localized: "\(distanceText) 완주! 탭해서 포스터를 확인하고 공유해 보세요.")
        }
    }
}
