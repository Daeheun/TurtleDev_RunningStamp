import SwiftUI

/// 1080pt 기준 포스터 캔버스를 주어진 폭에 맞춰 축소해 보여준다.
/// 상세 화면 미리보기와 온보딩 예시 포스터가 공유한다.
struct ScaledCanvasPreview<Content: View>: View {
    let canvasSize: CGSize
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / canvasSize.width

            content()
                .frame(width: canvasSize.width, height: canvasSize.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(
                    width: canvasSize.width * scale,
                    height: canvasSize.height * scale,
                    alignment: .topLeading
                )
        }
    }
}
