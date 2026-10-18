import SwiftUI
import UIKit

@MainActor
enum PosterExportHelper {
    static func renderPoster(
        report: RunningPosterReport,
        format: PosterFormat = .feed,
        highlightStamp: HighlightStamp = .clean,
        contentHighlight: ContentHighlightTarget? = nil,
        layout: PosterLayout = .default
    ) -> UIImage? {
        // 심박 데이터가 없는 러닝은 강조·레이아웃과 무관하게 라이트 포스터로 렌더링한다.
        guard report.hasHeartRateData else {
            return ImageRendererService.render(LightRunPosterView(report: report, format: format), size: format.canvasSize)
        }

        switch format {
        case .feed:
            return ImageRendererService.render(ZoneRunPosterView(report: report, highlightStamp: highlightStamp, contentHighlight: contentHighlight, layout: layout), size: ZoneRunPosterView.canvasSize)
        case .story:
            return ImageRendererService.render(StoryRunPosterView(report: report, highlightStamp: highlightStamp, contentHighlight: contentHighlight, layout: layout), size: StoryRunPosterView.canvasSize)
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
