import Combine
import SwiftUI

/// 사용자 프로필·환경 설정 저장소.
/// 심박 존 계산의 기준이 되는 최대 심박수와 거리 단위를 관리한다.
///
/// 최대 심박수 우선순위:
/// 1. 설정에서 직접 입력한 값
/// 2. Apple Health 생년월일로 계산한 나이 기준(220 − 나이)
/// 3. 둘 다 없으면 기본값(`fallbackMaxHeartRate`)
@MainActor
final class UserProfileStore: ObservableObject {
    static let shared = UserProfileStore()

    enum MaxHeartRateSource: Equatable {
        case manual
        case healthAge(Int)
        case fallback
    }

    static let fallbackMaxHeartRate = 185
    static let manualMaxHeartRateRange = 120...230

    private static let manualMaxHeartRateKey = "profile_manual_max_heart_rate"
    private static let healthAgeKey = "profile_health_age"

    /// 설정에서 직접 입력한 최대 심박수. nil이면 자동 계산.
    @Published var manualMaxHeartRate: Int? {
        didSet {
            if let manualMaxHeartRate {
                UserDefaults.standard.set(manualMaxHeartRate, forKey: Self.manualMaxHeartRateKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.manualMaxHeartRateKey)
            }
        }
    }

    /// Apple Health 생년월일로 계산한 만 나이. 읽기에 실패하면 nil.
    @Published private(set) var healthAge: Int? {
        didSet {
            if let healthAge {
                UserDefaults.standard.set(healthAge, forKey: Self.healthAgeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.healthAgeKey)
            }
        }
    }

    @Published var distanceUnit: DistanceUnit {
        didSet {
            UserDefaults.standard.set(distanceUnit.rawValue, forKey: DistanceUnit.defaultsKey)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let storedManual = defaults.object(forKey: Self.manualMaxHeartRateKey) as? Int
        manualMaxHeartRate = storedManual.flatMap { Self.manualMaxHeartRateRange.contains($0) ? $0 : nil }
        healthAge = defaults.object(forKey: Self.healthAgeKey) as? Int
        distanceUnit = .current
    }

    /// 나이 기준 추정 최대 심박(220 − 나이). 나이를 모르면 nil.
    var ageEstimatedMaxHeartRate: Int? {
        healthAge.map { 220 - $0 }
    }

    var maxHeartRateSource: MaxHeartRateSource {
        if manualMaxHeartRate != nil {
            return .manual
        }
        if let healthAge {
            return .healthAge(healthAge)
        }
        return .fallback
    }

    /// 존 분석에 실제로 사용하는 최대 심박수.
    var resolvedMaxHeartRate: Double {
        Double(manualMaxHeartRate ?? ageEstimatedMaxHeartRate ?? Self.fallbackMaxHeartRate)
    }

    /// Apple Health에서 생년월일을 읽어 나이를 갱신한다. 권한이 없거나 미입력이면 기존 값을 유지한다.
    func refreshHealthAge(using healthKitManager: HealthKitManager) async {
        if let age = await healthKitManager.fetchAge() {
            healthAge = age
        }
    }
}

// MARK: - 환경값

private struct DistanceUnitEnvironmentKey: EnvironmentKey {
    static let defaultValue: DistanceUnit = .kilometers
}

extension EnvironmentValues {
    /// 현재 거리 단위. 홈 루트에서 주입하며, 바뀌면 이를 읽는 뷰가 다시 그려진다.
    var distanceUnit: DistanceUnit {
        get { self[DistanceUnitEnvironmentKey.self] }
        set { self[DistanceUnitEnvironmentKey.self] = newValue }
    }
}
