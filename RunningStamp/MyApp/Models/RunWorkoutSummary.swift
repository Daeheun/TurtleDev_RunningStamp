import CoreLocation
import Foundation

struct HeartRateSamplePoint: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let bpm: Double

    init(id: UUID = UUID(), date: Date, bpm: Double) {
        self.id = id
        self.date = date
        self.bpm = bpm
    }
}

struct HeartRateZoneBoundary: Identifiable, Hashable {
    let id: Int
    let name: String
    let minRatio: Double
    let maxRatio: Double?
}

struct HeartRateZoneResult: Identifiable, Hashable {
    var id: Int { zone }
    let zone: Int
    let name: String
    let minBPM: Double
    let maxBPM: Double?
    let duration: TimeInterval
    let percentage: Double
}

enum RecoveryNeed {
    case low
    case medium
    case high

    var displayText: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var koreanText: String {
        switch self {
        case .low: return "낮음"
        case .medium: return "보통"
        case .high: return "높음"
        }
    }
}

struct EffortSignature {
    let title: String
    let subtitle: String
    let emoji: String
    let primaryMetricText: String
    let secondaryMetricText: String
    let recoveryNeed: RecoveryNeed
    let koreanInsight: String
}

struct RunningPosterReport: Identifiable {
    let id: UUID
    let isSampleData: Bool
    /// false면 심박 샘플이 없는 러닝이라 존 분석 없이 거리·페이스 중심의 라이트 포스터로 렌더링한다.
    let hasHeartRateData: Bool
    /// 포스터에 표시할 거리 단위 기호("km"/"mi")와 페이스 접미사("/km"/"/mi").
    let distanceUnitText: String
    let paceUnitText: String
    let title: String
    let subtitle: String
    let dateText: String
    let distanceText: String
    let durationText: String
    let avgPaceText: String
    let avgHRText: String
    let maxHRText: String
    let caloriesText: String
    let zoneResults: [HeartRateZoneResult]
    let dominantZone: HeartRateZoneResult?
    let zone2Percentage: Double
    let runType: String
    let insightText: String
    let heartRateTimeline: [HeartRateSamplePoint]
    let effortSignature: EffortSignature
    let routeLocations: [CLLocation]
    let isIndoorRunning: Bool
    let avgSpeedText: String
    let paceConsistencyText: String?
    let hrDriftText: String
    let dominantZoneText: String

    var hasRouteData: Bool {
        routeLocations.count >= 2
    }

    init(
        id: UUID = UUID(),
        isSampleData: Bool = false,
        hasHeartRateData: Bool = true,
        distanceUnitText: String = "km",
        paceUnitText: String = "/km",
        title: String,
        subtitle: String,
        dateText: String,
        distanceText: String,
        durationText: String,
        avgPaceText: String,
        avgHRText: String,
        maxHRText: String,
        caloriesText: String,
        zoneResults: [HeartRateZoneResult],
        dominantZone: HeartRateZoneResult? = nil,
        zone2Percentage: Double,
        runType: String,
        insightText: String,
        heartRateTimeline: [HeartRateSamplePoint],
        effortSignature: EffortSignature,
        routeLocations: [CLLocation] = [],
        isIndoorRunning: Bool = false,
        avgSpeedText: String = "-- KM/H",
        paceConsistencyText: String? = nil,
        hrDriftText: String = "-- BPM",
        dominantZoneText: String = "--"
    ) {
        self.id = id
        self.isSampleData = isSampleData
        self.hasHeartRateData = hasHeartRateData
        self.distanceUnitText = distanceUnitText
        self.paceUnitText = paceUnitText
        self.title = title
        self.subtitle = subtitle
        self.dateText = dateText
        self.distanceText = distanceText
        self.durationText = durationText
        self.avgPaceText = avgPaceText
        self.avgHRText = avgHRText
        self.maxHRText = maxHRText
        self.caloriesText = caloriesText
        self.zoneResults = zoneResults
        self.dominantZone = dominantZone ?? zoneResults.max { $0.percentage < $1.percentage }
        self.zone2Percentage = zone2Percentage
        self.runType = runType
        self.insightText = insightText
        self.heartRateTimeline = heartRateTimeline
        self.effortSignature = effortSignature
        self.routeLocations = routeLocations
        self.isIndoorRunning = isIndoorRunning
        self.avgSpeedText = avgSpeedText
        self.paceConsistencyText = paceConsistencyText
        self.hrDriftText = hrDriftText
        self.dominantZoneText = dominantZoneText
    }
}
