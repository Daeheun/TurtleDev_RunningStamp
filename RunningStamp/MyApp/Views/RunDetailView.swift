import SwiftUI
import UIKit

struct RunDetailView: View {
    @StateObject private var viewModel: RunDetailViewModel
    @State private var highlightStyle: HighlightStampStyle = .fire
    @State private var posterFormat: PosterFormat = .feed
    @State private var posterTemplate: PosterTemplate = .zone
    @State private var contentHighlight: ContentHighlightTarget?

    init(workout: RunWorkoutSummary, healthKitManager: HealthKitManager) {
        _viewModel = StateObject(wrappedValue: RunDetailViewModel(workout: workout, healthKitManager: healthKitManager))
    }

    var body: some View {
        ZStack {
            ZStack {
                RunStampColors.appBackground
                RadialGradient(
                    colors: [RunStampColors.aquaTeal.opacity(0.08), .clear],
                    center: .topTrailing,
                    startRadius: 30,
                    endRadius: 360
                )
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard

                    if viewModel.isLoading {
                        loadingCard
                    }

                    if let report = viewModel.report {
                        posterPreview(report)
                        if posterTemplate.supportsFormatAndEffect {
                            highlightControls
                        }
                        actionButtons
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .animation(.easeInOut(duration: 0.22), value: posterTemplate)
            }
        }
        .navigationTitle("Run Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadReport()
        }
        .alert("Export", isPresented: exportAlertBinding) {
            Button("OK", role: .cancel) { viewModel.exportMessage = nil }
        } message: {
            Text(viewModel.exportMessage ?? "")
        }
        .sheet(item: shareImageBinding) { image in
            ActivityView(activityItems: [image.image])
        }
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(RunStampColors.aquaTeal.opacity(0.14))
                    .frame(width: 66, height: 66)
                Image(systemName: "figure.run")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(RunStampColors.aquaTeal)
            }
            .layoutPriority(1)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(RunStampColors.aquaTeal)
                        .frame(width: 7, height: 7)
                    Text(RunFormatters.koreanWeekday(viewModel.workout.startDate))
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(RunStampColors.secondaryText)
                    Text(RunFormatters.clockTime(viewModel.workout.startDate))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(RunStampColors.tertiaryText)
                }
                .lineLimit(1)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(RunFormatters.listDistanceNumberKm(viewModel.workout.distanceInMeters))
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.46)
                    Text("KM")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(RunStampColors.secondaryText)
                        .padding(.bottom, 8)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(RunFormatters.duration(viewModel.workout.duration)) · \(RunFormatters.pace(viewModel.workout.averagePaceSecondsPerKm))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .layoutPriority(3)

            VStack(alignment: .trailing, spacing: 6) {
                Text(RunFormatters.koreanMonth(viewModel.workout.startDate))
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(viewModel.workout.routeLocations.count >= 2 ? "ROUTE READY" : "ROUTE CHECK")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.70, green: 0.96, blue: 0.08).opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 86, alignment: .trailing)
            .layoutPriority(1)
        }
        .padding(18)
        .background(
            ZStack {
                RunStampColors.elevatedSurface
                LinearGradient(
                    colors: [RunStampColors.aquaTeal.opacity(0.14), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(RunStampColors.cardStroke.opacity(0.45), lineWidth: 1))
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(RunStampColors.limeGreen)
            Text("러닝 데이터를 분석하고 있습니다")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RunStampColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var highlightControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            highlightSectionTitle("포스터 형식")
            HStack(spacing: 8) {
                formatChip(.feed)
                formatChip(.story)
            }

            highlightSectionTitle("포스터 효과")
            HStack(spacing: 8) {
                highlightStyleChip(.fire)
                highlightStyleChip(.clean)
            }

            HStack(spacing: 6) {
                highlightSectionTitle("콘텐츠 강조")
                proBadge
            }
            HStack(spacing: 8) {
                contentHighlightChip(nil)
                ForEach(ContentHighlightTarget.allCases) { target in
                    contentHighlightChip(target)
                }
            }
        }
        .padding(14)
        .background(RunStampColors.elevatedSurface.opacity(0.90))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(RunStampColors.cardStroke.opacity(0.45), lineWidth: 1))
    }

    private func highlightSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(RunStampColors.primaryText.opacity(0.88))
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(RunStampColors.appBackground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                LinearGradient(
                    colors: [RunStampColors.warmYellow, RunStampColors.energyOrange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
    }

    private func contentHighlightChip(_ target: ContentHighlightTarget?) -> some View {
        let isSelected = contentHighlight == target
        return Button {
            guard ProFeatureGate.isUnlocked || target == nil else {
                viewModel.exportMessage = ProFeatureGate.lockedMessage
                return
            }
            withAnimation(.easeInOut(duration: 0.18)) {
                contentHighlight = target
            }
        } label: {
            HStack(spacing: 4) {
                if target != nil {
                    Image(systemName: ProFeatureGate.isUnlocked ? "flame.fill" : "lock.fill")
                        .font(.system(size: 10, weight: .black))
                }
                Text(target?.displayText ?? "없음")
                    .font(.system(size: 13, weight: .black, design: .rounded))
            }
            .foregroundStyle(isSelected ? RunStampColors.appBackground : RunStampColors.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isSelected ? RunStampColors.energyOrange : RunStampColors.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? .clear : RunStampColors.cardStroke.opacity(0.65), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func formatChip(_ format: PosterFormat) -> some View {
        let isSelected = posterFormat == format
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                posterFormat = format
            }
        } label: {
            Text(format.displayText)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? RunStampColors.appBackground : RunStampColors.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? RunStampColors.limeGreen : RunStampColors.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? .clear : RunStampColors.cardStroke.opacity(0.65), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func highlightStyleChip(_ style: HighlightStampStyle) -> some View {
        let isSelected = highlightStyle == style
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                highlightStyle = style
            }
        } label: {
            Text(style == .fire ? "Fire" : "Clean")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? RunStampColors.appBackground : RunStampColors.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? RunStampColors.limeGreen : RunStampColors.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? .clear : RunStampColors.cardStroke.opacity(0.65), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var currentHighlightStamp: HighlightStamp {
        highlightStyle == .fire ? HighlightStamp(target: .firePoster, style: .fire) : .clean
    }

    private func selectedHighlightStamp(for report: RunningPosterReport) -> HighlightStamp {
        currentHighlightStamp.resolved(for: report)
    }

    private func posterPreview(_ report: RunningPosterReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("REPORT PREVIEW")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(RunStampColors.secondaryText.opacity(0.78))
                Spacer()
                Text(report.effortSignature.title)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(RunStampColors.effortColor(report.effortSignature.title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            TabView(selection: $posterTemplate) {
                ForEach(PosterTemplate.allCases) { template in
                    templatePage(template, report: report)
                        .tag(template)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: previewHeight)
            .animation(.easeInOut(duration: 0.22), value: posterFormat)

            HStack(spacing: 8) {
                ForEach(PosterTemplate.allCases) { template in
                    templateChip(template)
                }
            }
        }
        .padding(12)
        .background(RunStampColors.elevatedSurface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(RunStampColors.cardStroke.opacity(0.45), lineWidth: 1))
    }

    @ViewBuilder
    private func templatePage(_ template: PosterTemplate, report: RunningPosterReport) -> some View {
        Group {
            switch template {
            case .zone:
                ScaledCanvasPreview(canvasSize: posterFormat.canvasSize) {
                    switch posterFormat {
                    case .feed:
                        ZoneRunPosterView(report: report, highlightStamp: selectedHighlightStamp(for: report), contentHighlight: contentHighlight)
                    case .story:
                        StoryRunPosterView(report: report, highlightStamp: selectedHighlightStamp(for: report), contentHighlight: contentHighlight)
                    }
                }
            case .receipt:
                ScaledCanvasPreview(canvasSize: ImageRendererService.storySize) {
                    RunningReceiptView(workout: viewModel.workout)
                }
            case .route:
                ScaledCanvasPreview(canvasSize: ImageRendererService.storySize) {
                    RoutePosterView(workout: viewModel.workout)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.36), radius: 24, y: 10)
    }

    private var previewHeight: CGFloat {
        let availableWidth = max(UIScreen.main.bounds.width - 60, 300)
        let canvas = posterTemplate.canvasSize(format: posterFormat)
        return availableWidth * canvas.height / canvas.width
    }

    private func templateChip(_ template: PosterTemplate) -> some View {
        let isSelected = posterTemplate == template
        return Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                posterTemplate = template
            }
        } label: {
            Text(template.displayText)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? RunStampColors.appBackground : RunStampColors.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? RunStampColors.limeGreen : RunStampColors.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? .clear : RunStampColors.cardStroke.opacity(0.65), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            instagramStoryButton

            HStack(spacing: 12) {
                reportActionButton(title: "이미지로 저장", systemImage: "square.and.arrow.down", isPrimary: true) {
                    viewModel.exportPoster(template: posterTemplate, format: posterFormat, highlightStamp: currentHighlightStamp, contentHighlight: contentHighlight)
                }

                reportActionButton(title: "공유하기", systemImage: "square.and.arrow.up", isPrimary: false) {
                    viewModel.prepareShareImage(template: posterTemplate, format: posterFormat, highlightStamp: currentHighlightStamp, contentHighlight: contentHighlight)
                }
            }
        }
    }

    private var instagramStoryButton: some View {
        Button {
            viewModel.shareToInstagramStories(template: posterTemplate, highlightStamp: currentHighlightStamp, contentHighlight: contentHighlight)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 19, weight: .black))
                Text("인스타 스토리로 공유")
                    .font(.system(size: 15, weight: .black))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.51, green: 0.23, blue: 0.86),
                        Color(red: 0.91, green: 0.18, blue: 0.44),
                        Color(red: 0.99, green: 0.55, blue: 0.24)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func reportActionButton(title: String, systemImage: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(isPrimary ? RunStampColors.appBackground : RunStampColors.primaryText)
                .background(isPrimary ? RunStampColors.limeGreen : RunStampColors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(isPrimary ? .clear : RunStampColors.cardStroke.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var exportAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.exportMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.exportMessage = nil }
            }
        )
    }

    private var shareImageBinding: Binding<ShareableImage?> {
        Binding(
            get: { viewModel.shareImage.map(ShareableImage.init(image:)) },
            set: { value in
                if value == nil { viewModel.shareImage = nil }
            }
        )
    }
}

private struct ScaledCanvasPreview<Content: View>: View {
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

private struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
