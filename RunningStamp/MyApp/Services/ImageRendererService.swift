import SwiftUI
import UIKit

@MainActor
enum ImageRendererService {
    static let storySize = CGSize(width: 1_080, height: 1_920)

    static func render<Content: View>(_ content: Content, size: CGSize = CGSize(width: 1_080, height: 1_920)) -> UIImage? {
        let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
        // 2배율 렌더링: 캔버스 좌표는 유지한 채 픽셀 해상도만 2160px 폭으로 올려
        // 저장·확대 시 선명도를 확보한다.
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }
}
