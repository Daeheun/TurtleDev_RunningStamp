import SwiftUI
import UIKit

enum PosterTemplate: String, CaseIterable, Identifiable {
    case zone
    case receipt
    case route

    var id: String { rawValue }

    var displayText: String {
        switch self {
        case .zone:
            return "존 분석"
        case .receipt:
            return "영수증"
        case .route:
            return "경로"
        }
    }

    /// 존 분석 템플릿만 피드/스토리 형식 선택과 Fire 효과를 지원한다.
    /// 영수증·경로 템플릿은 9:16 고정 캔버스다.
    var supportsFormatAndEffect: Bool {
        self == .zone
    }

    func canvasSize(format: PosterFormat) -> CGSize {
        supportsFormatAndEffect ? format.canvasSize : ImageRendererService.storySize
    }
}

@MainActor
enum PosterExportHelper {
    static func renderPoster(
        template: PosterTemplate = .zone,
        report: RunningPosterReport,
        workout: RunWorkoutSummary,
        format: PosterFormat = .feed,
        highlightStamp: HighlightStamp = .clean,
        contentHighlight: ContentHighlightTarget? = nil
    ) -> UIImage? {
        switch template {
        case .zone:
            switch format {
            case .feed:
                return ImageRendererService.render(ZoneRunPosterView(report: report, highlightStamp: highlightStamp, contentHighlight: contentHighlight), size: ZoneRunPosterView.canvasSize)
            case .story:
                return ImageRendererService.render(StoryRunPosterView(report: report, highlightStamp: highlightStamp, contentHighlight: contentHighlight), size: StoryRunPosterView.canvasSize)
            }
        case .receipt:
            return ImageRendererService.render(RunningReceiptView(workout: workout), size: ImageRendererService.storySize)
        case .route:
            return ImageRendererService.render(RoutePosterView(workout: workout), size: ImageRendererService.storySize)
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
