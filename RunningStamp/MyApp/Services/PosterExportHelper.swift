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
