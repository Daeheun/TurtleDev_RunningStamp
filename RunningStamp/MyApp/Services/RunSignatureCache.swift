import Combine
import Foundation

/// 홈 리스트 행에 표시할 러닝 시그니처를 상세 화면과 **같은 분석기**로 계산해 캐시한다.
/// 이전에는 리스트가 평균 심박 ÷ 185라는 별도 추정식을 써서 상세 포스터의 러닝 타입과
/// 다르게 나올 수 있었다. 이제 리스트·포스터 모두 사용자 최대 심박 기준의 존 분포로 판정한다.
@MainActor
final class RunSignatureCache: ObservableObject {
    struct QuickSignature: Equatable {
        let title: String
        let dominantZoneText: String?
        let hasHeartRateData: Bool

        static let light = QuickSignature(
            title: HeartRateZoneAnalyzer.lightRunTitle,
            dominantZoneText: nil,
            hasHeartRateData: false
        )
    }

    @Published private(set) var signatures: [UUID: QuickSignature] = [:]

    private let healthKitManager: HealthKitManager
    private var analyzer: HeartRateZoneAnalyzer
    private var inFlight: Set<UUID> = []

    init(healthKitManager: HealthKitManager, maxHeartRate: Double) {
        self.healthKitManager = healthKitManager
        self.analyzer = HeartRateZoneAnalyzer(maxHeartRate: maxHeartRate)
    }

    func signature(for workout: RunWorkoutSummary) -> QuickSignature? {
        signatures[workout.id]
    }

    /// 최대 심박 기준이 바뀌면 존 경계가 달라지므로 캐시를 비워 다시 계산하게 한다.
    func updateMaxHeartRate(_ maxHeartRate: Double) {
        guard analyzer.maxHeartRate != maxHeartRate else { return }
        analyzer.maxHeartRate = maxHeartRate
        signatures = [:]
    }

    /// 행이 화면에 나타날 때 호출한다. 이미 계산됐거나 진행 중이면 아무것도 하지 않는다.
    func load(for workout: RunWorkoutSummary) async {
        let id = workout.id
        guard signatures[id] == nil, !inFlight.contains(id) else { return }
        inFlight.insert(id)
        defer { inFlight.remove(id) }

        let samples = (try? await healthKitManager.fetchHeartRateSamples(for: workout)) ?? []
        guard let report = analyzer.makeReport(for: workout, heartRateSamples: samples) else {
            signatures[id] = .light
            return
        }

        signatures[id] = QuickSignature(
            title: report.effortSignature.title,
            dominantZoneText: report.dominantZoneText,
            hasHeartRateData: true
        )
    }
}
