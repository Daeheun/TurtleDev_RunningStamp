import Foundation

enum HighlightStampTarget: String, CaseIterable, Identifiable {
    case firePoster

    var id: String { rawValue }

    var displayText: String {
        "Fire"
    }
}

enum HighlightStampStyle: String, CaseIterable, Identifiable {
    case fire
    case clean

    var id: String { rawValue }

    var displayText: String {
        switch self {
        case .fire:
            return "Fire"
        case .clean:
            return "Clean"
        }
    }
}

struct HighlightStamp: Equatable {
    var target: HighlightStampTarget
    var style: HighlightStampStyle

    static let clean = HighlightStamp(target: .firePoster, style: .clean)

    var isEnabled: Bool {
        style != .clean
    }

    func resolved(for _: RunningPosterReport) -> HighlightStamp {
        guard style == .fire else { return .clean }
        return HighlightStamp(target: .firePoster, style: .fire)
    }

    func matches(_ target: HighlightStampTarget, _ style: HighlightStampStyle? = nil) -> Bool {
        guard isEnabled, self.target == target else { return false }
        if let style {
            return self.style == style
        }
        return true
    }
}
