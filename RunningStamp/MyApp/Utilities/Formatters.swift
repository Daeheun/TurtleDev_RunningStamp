import Foundation

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

    static func distanceKm(_ meters: Double) -> String {
        String(format: "%.2f KM", meters / 1_000)
    }

    static func distanceNumberKm(_ meters: Double) -> String {
        String(format: "%.2f", meters / 1_000)
    }

    static func listDistanceNumberKm(_ meters: Double) -> String {
        let km = meters / 1_000
        return km >= 10 ? String(format: "%.2f", km) : String(format: "%.2f", km)
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

    static func pace(_ secondsPerKm: Double?) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite, secondsPerKm > 0 else {
            return "--'--\"/KM"
        }

        let totalSeconds = Int(secondsPerKm.rounded())
        return String(format: "%d'%02d\"/KM", totalSeconds / 60, totalSeconds % 60)
    }

    static func paceCompact(_ secondsPerKm: Double?) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite, secondsPerKm > 0 else {
            return "--'--\""
        }

        let totalSeconds = Int(secondsPerKm.rounded())
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

    static func summaryDistanceKm(_ meters: Double) -> String {
        String(format: "%.1f", meters / 1_000)
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
