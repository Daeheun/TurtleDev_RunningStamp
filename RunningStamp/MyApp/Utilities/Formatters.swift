import Foundation

/// 거리·페이스 표시 단위. 설정 화면에서 바꾸며 UserDefaults에 저장된다.
enum DistanceUnit: String, CaseIterable, Identifiable, Codable {
    case kilometers
    case miles

    static let defaultsKey = "distance_unit"

    /// 저장된 단위. 뷰 밖(포스터 렌더·알림 문구)에서 현재 단위가 필요할 때 사용한다.
    static var current: DistanceUnit {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(DistanceUnit.init(rawValue:)) ?? .kilometers
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kilometers: return "킬로미터"
        case .miles: return "마일"
        }
    }

    /// 대문자 단위 기호(리스트·헤더용).
    var symbol: String {
        switch self {
        case .kilometers: return "KM"
        case .miles: return "MI"
        }
    }

    /// 소문자 단위 기호(포스터용).
    var lowercaseSymbol: String {
        switch self {
        case .kilometers: return "km"
        case .miles: return "mi"
        }
    }

    var paceSuffix: String { "/\(symbol)" }
    var lowercasePaceSuffix: String { "/\(lowercaseSymbol)" }

    var speedSymbol: String {
        switch self {
        case .kilometers: return "KM/H"
        case .miles: return "MPH"
        }
    }

    var metersPerUnit: Double {
        switch self {
        case .kilometers: return 1_000
        case .miles: return 1_609.344
        }
    }

    func value(fromMeters meters: Double) -> Double {
        meters / metersPerUnit
    }

    /// km당 초 → 현재 단위당 초.
    func paceSeconds(fromSecondsPerKm secondsPerKm: Double) -> Double {
        secondsPerKm * metersPerUnit / 1_000
    }
}

// HealthKit setup note: the RunStamp target needs the HealthKit capability enabled
// in Signing & Capabilities and NSHealthShareUsageDescription in Info.plist.
enum RunFormatters {
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let receiptDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private static let posterDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    private static let koreanMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter
    }()

    private static let koreanWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "hh.mm a"
        return formatter
    }()

    /// 거리 숫자만("8.21"). 단위 기호는 호출부가 `unit.symbol`로 붙인다.
    static func distanceNumber(_ meters: Double, unit: DistanceUnit = .current) -> String {
        String(format: "%.2f", unit.value(fromMeters: meters))
    }

    /// 거리 + 단위("8.21 KM").
    static func distance(_ meters: Double, unit: DistanceUnit = .current) -> String {
        "\(distanceNumber(meters, unit: unit)) \(unit.symbol)"
    }

    /// 월 요약 카드용 소수 1자리 거리 숫자.
    static func summaryDistanceNumber(_ meters: Double, unit: DistanceUnit = .current) -> String {
        String(format: "%.1f", unit.value(fromMeters: meters))
    }

    /// 평균 속도("10.4 KM/H").
    static func speed(distanceMeters: Double, duration: TimeInterval, unit: DistanceUnit = .current) -> String {
        let hours = duration / 3_600
        guard distanceMeters > 0, hours > 0 else { return "-- \(unit.speedSymbol)" }
        return String(format: "%.1f %@", unit.value(fromMeters: distanceMeters) / hours, unit.speedSymbol)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(Int(seconds.rounded()), 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 페이스 + 단위("5'32\"/KM"). 입력은 항상 km당 초.
    static func pace(_ secondsPerKm: Double?, unit: DistanceUnit = .current) -> String {
        "\(paceCompact(secondsPerKm, unit: unit))\(unit.paceSuffix)"
    }

    /// 페이스 숫자만("5'32\""). 입력은 항상 km당 초.
    static func paceCompact(_ secondsPerKm: Double?, unit: DistanceUnit = .current) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite, secondsPerKm > 0 else {
            return "--'--\""
        }

        let totalSeconds = Int(unit.paceSeconds(fromSecondsPerKm: secondsPerKm).rounded())
        return String(format: "%d'%02d\"", totalSeconds / 60, totalSeconds % 60)
    }

    static func calories(_ value: Double?) -> String {
        guard let value else { return "-- KCAL" }
        return String(format: "%.0f KCAL", value)
    }

    static func number(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return String(format: "%.0f", value)
    }

    static func listDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    static func cardDate(_ date: Date) -> String {
        receiptDateFormatter.string(from: date).uppercased()
    }

    static func posterDate(_ date: Date) -> String {
        posterDateFormatter.string(from: date)
    }

    static func koreanMonth(_ date: Date) -> String {
        koreanMonthFormatter.string(from: date)
    }

    static func koreanWeekday(_ date: Date) -> String {
        koreanWeekdayFormatter.string(from: date)
    }

    static func clockTime(_ date: Date) -> String {
        clockFormatter.string(from: date)
    }

    static func heartRate(_ value: Double?) -> String {
        guard let value else { return "-- BPM" }
        return String(format: "%.0f BPM", value)
    }

    static func power(_ value: Double?) -> String {
        guard let value else { return "-- W" }
        return String(format: "%.0f W", value)
    }

    static func cadence(_ value: Double?) -> String {
        guard let value else { return "-- SPM" }
        return String(format: "%.0f SPM", value)
    }
}
