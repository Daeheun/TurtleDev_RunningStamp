import SwiftUI
import UIKit

@MainActor
enum PosterExportHelper {
    static func renderPoster(report: RunningPosterReport, highlightStamp: HighlightStamp = .clean) -> UIImage? {
        ImageRendererService.render(ZoneRunPosterView(report: report, highlightStamp: highlightStamp), size: ZoneRunPosterView.canvasSize)
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
