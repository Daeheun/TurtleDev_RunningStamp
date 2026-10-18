import Foundation
import OSLog

/// 퍼널 계측 이벤트. 건강 수치(거리·심박·위치)는 절대 담지 않고
/// 기능 사용 여부와 분기 결과만 기록한다.
enum AnalyticsEvent {
    case appLaunched
    case onboardingCompleted(connectsHealth: Bool)
    case healthAuthorization(result: String)
    case runsLoaded(count: Int)
    case runOpened(hasHeartRate: Bool, isIndoor: Bool)
    case posterSaved(format: PosterFormat, hasHeartRate: Bool)
    case posterShared(format: PosterFormat, hasHeartRate: Bool)
    case instagramStoryShare(opened: Bool)
    case posterNotification(action: String)
    case proFeatureLocked(feature: String)
    case settingChanged(key: String)

    var name: String {
        switch self {
        case .appLaunched: return "app_launched"
        case .onboardingCompleted: return "onboarding_completed"
        case .healthAuthorization: return "health_authorization"
        case .runsLoaded: return "runs_loaded"
        case .runOpened: return "run_opened"
        case .posterSaved: return "poster_saved"
        case .posterShared: return "poster_shared"
        case .instagramStoryShare: return "instagram_story_share"
        case .posterNotification: return "poster_notification"
        case .proFeatureLocked: return "pro_feature_locked"
        case .settingChanged: return "setting_changed"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .appLaunched:
            return [:]
        case .onboardingCompleted(let connectsHealth):
            return ["health_connect": connectsHealth ? "yes" : "later"]
        case .healthAuthorization(let result):
            return ["result": result]
        case .runsLoaded(let count):
            return ["count_bucket": Self.bucket(count)]
        case .runOpened(let hasHeartRate, let isIndoor):
            return ["heart_rate": hasHeartRate ? "yes" : "no", "indoor": isIndoor ? "yes" : "no"]
        case .posterSaved(let format, let hasHeartRate), .posterShared(let format, let hasHeartRate):
            return ["format": format.rawValue, "heart_rate": hasHeartRate ? "yes" : "no"]
        case .instagramStoryShare(let opened):
            return ["result": opened ? "opened" : "fallback_share_sheet"]
        case .posterNotification(let action):
            return ["action": action]
        case .proFeatureLocked(let feature):
            return ["feature": feature]
        case .settingChanged(let key):
            return ["key": key]
        }
    }

    /// 정확한 개수 대신 구간으로 보내 개인 식별 가능성을 낮춘다.
    private static func bucket(_ count: Int) -> String {
        switch count {
        case 0: return "0"
        case 1...5: return "1-5"
        case 6...20: return "6-20"
        case 21...60: return "21-60"
        default: return "60+"
        }
    }
}

/// 이벤트를 실제로 내보내는 백엔드. TelemetryDeck 등 SDK를 붙일 때 이 프로토콜만 구현하면 된다.
///
/// ```swift
/// import TelemetryDeck
/// struct TelemetryDeckBackend: AnalyticsBackend {
///     func send(_ name: String, parameters: [String: String]) {
///         TelemetryDeck.signal(name, parameters: parameters)
///     }
/// }
/// // RunStampApp.init 에서:
/// TelemetryDeck.initialize(config: .init(appID: "<TelemetryDeck App ID>"))
/// Analytics.shared.backend = TelemetryDeckBackend()
/// ```
protocol AnalyticsBackend {
    func send(_ name: String, parameters: [String: String])
}

/// 기본 백엔드: 외부 전송 없이 통합 로그(Console.app)에만 남긴다.
struct OSLogAnalyticsBackend: AnalyticsBackend {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RunStamp", category: "Analytics")

    func send(_ name: String, parameters: [String: String]) {
        let paramText = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        logger.info("event=\(name, privacy: .public) \(paramText, privacy: .public)")
    }
}

/// 앱 전역 계측 진입점. 사용자가 설정에서 통계를 끄면 아무것도 보내지 않는다.
@MainActor
final class Analytics {
    static let shared = Analytics()

    var backend: AnalyticsBackend = OSLogAnalyticsBackend()

    #if DEBUG
    /// DEBUG 확인용: 이번 실행에서 보낸 이벤트 수.
    private(set) var sentCount = 0
    #endif

    private init() {}

    func track(_ event: AnalyticsEvent) {
        guard AppPreferences.shared.isAnalyticsEnabled else { return }
        backend.send(event.name, parameters: event.parameters)
        #if DEBUG
        sentCount += 1
        #endif
    }
}
