import SwiftUI

/// 유료(PRO) 기능: 포스터에서 강조할 콘텐츠(스탯 타일) 선택.
enum ContentHighlightTarget: String, CaseIterable, Identifiable {
    case duration
    case pace
    case heartRate
    case calories

    var id: String { rawValue }

    var displayText: String {
        switch self {
        case .duration:
            return "시간"
        case .pace:
            return "페이스"
        case .heartRate:
            return "심박"
        case .calories:
            return "칼로리"
        }
    }
}

/// PRO 기능 잠금 게이트.
/// TODO: StoreKit 구독/구매 연동 시 실제 구매 상태로 교체한다.
enum ProFeatureGate {
    static let isUnlocked = true
    static let lockedMessage = "콘텐츠 강조는 PRO 기능입니다. 업그레이드 후 이용할 수 있습니다."
}

/// 선택한 콘텐츠 주위에 불꽃(FireCorner 에셋) 장식과 열기 글로우를 두른다.
/// 불꽃의 엘보(밝은 코어)가 콘텐츠의 좌상단 코너에 오도록 배치된다.
struct FlameContentHighlight: ViewModifier {
    let isActive: Bool

    /// FireCorner 에셋 기준값 (1200×1025, 엘보 앵커 비율)
    private static let imageAspect: CGFloat = 1_025.0 / 1_200.0
    private static let anchorX: CGFloat = 0.281
    private static let anchorY: CGFloat = 0.389

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? RunStampColors.energyOrange.opacity(0.55) : .clear, radius: isActive ? 22 : 0)
            .overlay {
                if isActive {
                    GeometryReader { proxy in
                        let tile = proxy.size
                        // 넓은 타일에서 과대해지지 않도록 짧은 변 기준으로 크기를 잡는다
                        let flameWidth = min(tile.width, tile.height) * 2.1
                        let flameHeight = flameWidth * Self.imageAspect

                        Image("FireCorner")
                            .resizable()
                            .frame(width: flameWidth, height: flameHeight)
                            .offset(
                                x: -flameWidth * Self.anchorX + tile.width * 0.02,
                                y: -flameHeight * Self.anchorY + tile.height * 0.03
                            )
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func flameContentHighlight(_ isActive: Bool) -> some View {
        modifier(FlameContentHighlight(isActive: isActive))
    }
}
