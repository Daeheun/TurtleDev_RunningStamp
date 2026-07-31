import Foundation

enum PosterLanguageMode {
    case korean
    case english
    case mixed
}

struct PosterTextFormatter {
    static func signatureKoreanSubtitle(for title: String) -> String {
        switch title {
        case "REDLINE PUSH":
            return "고강도 세션"
        case "TEMPO ENGINE":
            return "템포 러닝"
        case "CONTROLLED BASE":
            return "베이스 러닝"
        case "RECOVERY FLOW":
            return "회복 러닝"
        case "STEADY BUILDER":
            return "지구력 빌드업"
        case "PROGRESSIVE BURN":
            return "후반 가속 러닝"
        default:
            return "자유 러닝"
        }
    }

    static func signatureKoreanDescriptor(for title: String) -> String {
        switch title {
        case "REDLINE PUSH":
            return "고강도 자극 중심 러닝"
        case "TEMPO ENGINE":
            return "리듬감 있는 템포 러닝"
        case "CONTROLLED BASE":
            return "안정적인 베이스 러닝"
        case "RECOVERY FLOW":
            return "회복 중심 저강도 러닝"
        case "STEADY BUILDER":
            return "지구력과 페이스 빌드업"
        case "PROGRESSIVE BURN":
            return "후반으로 갈수록 강해진 러닝"
        default:
            return "자유롭게 변화한 러닝"
        }
    }

    static func signatureKoreanInsight(for title: String) -> String {
        switch title {
        case "REDLINE PUSH":
            return "강하게 밀어붙인 고강도 러닝입니다.\n회복까지 챙기면 더 좋은 훈련이 됩니다."
        case "TEMPO ENGINE":
            return "꾸준히 밀어붙인 템포성 러닝입니다.\n리듬감 있게 잘 끌고 간 세션이에요."
        case "CONTROLLED BASE":
            return "안정적인 강도로 유지한 베이스 러닝입니다.\n기초 체력을 쌓기 좋은 세션이에요."
        case "RECOVERY FLOW":
            return "몸을 부드럽게 풀어낸 저강도 러닝입니다.\n무리하지 않고 좋은 리듬을 만들었어요."
        case "STEADY BUILDER":
            return "중강도 영역에서 꾸준히 이어간 러닝입니다.\n지구력과 페이스 감각을 함께 쌓은 세션이에요."
        case "PROGRESSIVE BURN":
            return "후반으로 갈수록 강도를 끌어올린 러닝입니다.\n마지막까지 힘을 잘 살린 세션이에요."
        default:
            return "여러 강도가 섞인 자유 러닝입니다.\n컨디션과 코스 변화가 함께 반영된 세션이에요."
        }
    }

    static func dominantZoneKoreanText(zone: Int) -> String {
        switch zone {
        case 1:
            return "회복 구간"
        case 2:
            return "베이스 구간"
        case 3:
            return "중강도 구간"
        case 4:
            return "템포 구간"
        default:
            return "최대강도 구간"
        }
    }

    static func zoneShortLabel(zone: Int) -> String {
        switch zone {
        case 1:
            return "Z1 회복"
        case 2:
            return "Z2 베이스"
        case 3:
            return "Z3 중강도"
        case 4:
            return "Z4 템포"
        default:
            return "Z5 최대강도"
        }
    }

    static func recoveryNeedKoreanText(_ recoveryNeed: RecoveryNeed) -> String {
        switch recoveryNeed {
        case .low:
            return "낮음"
        case .medium:
            return "보통"
        case .high:
            return "높음"
        }
    }

    static func localizedPrimaryMetric(_ text: String, signatureTitle: String) -> String {
        let percent = text.split(separator: " ").last(where: { $0.contains("%") }).map(String.init) ?? ""
        switch signatureTitle {
        case "REDLINE PUSH":
            return "고강도 구간 \(percent)".trimmingCharacters(in: .whitespaces)
        case "TEMPO ENGINE":
            return "템포 구간 \(percent)".trimmingCharacters(in: .whitespaces)
        case "CONTROLLED BASE", "RECOVERY FLOW":
            return "저강도 구간 \(percent)".trimmingCharacters(in: .whitespaces)
        case "STEADY BUILDER":
            return "중강도 구간 \(percent)".trimmingCharacters(in: .whitespaces)
        case "PROGRESSIVE BURN":
            return "후반 상승 \(percent)".trimmingCharacters(in: .whitespaces)
        default:
            return text
        }
    }
}
