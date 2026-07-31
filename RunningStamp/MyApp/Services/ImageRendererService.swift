import SwiftUI
import UIKit

@MainActor
enum ImageRendererService {
    static let storySize = CGSize(width: 1_080, height: 1_920)

    static func render<Content: View>(_ content: Content, size: CGSize = CGSize(width: 1_080, height: 1_920)) -> UIImage? {
        let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }
}
