import SwiftUI
import UIKit

struct RunDetailView: View {
    @StateObject private var viewModel: RunDetailViewModel
    @State private var highlightStyle: HighlightStampStyle = .fire

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
                        highlightControls
                        posterPreview(report)
                        actionButtons
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
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
            highlightSectionTitle("포스터 효과")
            HStack(spacing: 8) {
                highlightStyleChip(.fire)
                highlightStyleChip(.clean)
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

            ScaledZoneRunPosterPreview(report: report, highlightStamp: selectedHighlightStamp(for: report))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.36), radius: 24, y: 10)
        }
        .padding(12)
        .background(RunStampColors.elevatedSurface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(RunStampColors.cardStroke.opacity(0.45), lineWidth: 1))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            reportActionButton(title: "이미지로 저장", systemImage: "square.and.arrow.down", isPrimary: true) {
                viewModel.exportPoster(highlightStamp: currentHighlightStamp)
            }

            reportActionButton(title: "인스타 공유", systemImage: "square.and.arrow.up", isPrimary: false) {
                viewModel.prepareShareImage(highlightStamp: currentHighlightStamp)
            }
        }
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

private struct ScaledZoneRunPosterPreview: View {
    let report: RunningPosterReport
    let highlightStamp: HighlightStamp

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let scale = width / ZoneRunPosterView.canvasSize.width

            ZoneRunPosterView(report: report, highlightStamp: highlightStamp)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(
                    width: ZoneRunPosterView.canvasSize.width * scale,
                    height: ZoneRunPosterView.canvasSize.height * scale,
                    alignment: .topLeading
                )
        }
        .frame(height: previewHeight)
    }

    private var previewHeight: CGFloat {
        let availableWidth = max(UIScreen.main.bounds.width - 60, 300)
        return availableWidth * ZoneRunPosterView.canvasSize.height / ZoneRunPosterView.canvasSize.width
    }
}

private struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
