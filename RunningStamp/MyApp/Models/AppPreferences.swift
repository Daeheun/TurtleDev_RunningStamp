import Combine
import Foundation

/// 프로필(UserProfileStore)과 무관한 앱 단위 환경설정.
/// 온보딩 완료 여부와 익명 사용 통계 동의를 UserDefaults에 보관한다.
@MainActor
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    private static let onboardingCompletedKey = "onboarding_completed_v1"
    private static let analyticsEnabledKey = "analytics_enabled"

    /// 온보딩 3장을 끝까지 봤거나 건너뛴 적이 있는지.
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.onboardingCompletedKey) }
    }

    /// 익명 사용 통계 전송 동의. 기본값은 켜짐이며 설정에서 끌 수 있다.
    @Published var isAnalyticsEnabled: Bool {
        didSet { UserDefaults.standard.set(isAnalyticsEnabled, forKey: Self.analyticsEnabledKey) }
    }

    private init() {
        let defaults = UserDefaults.standard
        hasCompletedOnboarding = defaults.bool(forKey: Self.onboardingCompletedKey)
        if defaults.object(forKey: Self.analyticsEnabledKey) == nil {
            isAnalyticsEnabled = true
        } else {
            isAnalyticsEnabled = defaults.bool(forKey: Self.analyticsEnabledKey)
        }
    }
}
