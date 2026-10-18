import SwiftUI
import UIKit

struct RunDetailView: View {
    @StateObject private var viewModel: RunDetailViewModel
    @StateObject private var layoutStore = PosterLayoutStore()
    @State private var highlightStyle: HighlightStampStyle = .fire
    @State private var posterFormat: PosterFormat = .feed
    @State private var contentHighlight: ContentHighlightTarget?
    @State private var isLayoutEditorPresented = false
    @State private var isPresetSavePromptPresented = false
    @State private var presetNameDraft = ""
    #if DEBUG
    /// DEBUG 전용: PRO 잠금 상태를 실기기에서 재빌드 없이 전환하기 위한 토글.
    @AppStorage(ProFeatureGate.unlockedDefaultsKey) private var proUnlockedDebug = ProFeatureGate.defaultUnlocked
    #endif

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
                        highlightControls
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
        .alert("레이아웃 프리셋 저장", isPresented: $isPresetSavePromptPresented) {
            TextField("프리셋 이름", text: $presetNameDraft)
            Button("저장") {
                if !layoutStore.savePreset(named: presetNameDraft, for: posterFormat) {
                    viewModel.exportMessage = "프리셋은 형식별로 최대 \(PosterLayoutStore.maxPresetCount)개까지 저장할 수 있습니다."
                }
                presetNameDraft = ""
            }
            Button("취소", role: .cancel) { presetNameDraft = "" }
        } message: {
            Text("현재 \(posterFormat.displayText) 배치를 프리셋으로 저장합니다.")
        }
        .sheet(item: shareImageBinding) { image in
            ActivityView(activityItems: [image.image])
        }
        .sheet(isPresented: $isLayoutEditorPresented) {
            if let report = viewModel.report {
                PosterLayoutEditorView(
                    format: posterFormat,
                    report: report,
                    highlightStamp: selectedHighlightStamp(for: report),
                    contentHighlight: contentHighlight,
                    initialLayout: layoutStore.layout(for: posterFormat),
                    onSave: { layoutStore.setLayout($0, for: posterFormat) }
                )
            }
        }
    }

    /// PRO 잠금 상태에서는 저장된 커스텀 배치를 무시하고 기본 배치로 렌더링한다.
    /// (저장값은 보존되므로 다시 언락하면 커스텀이 복원된다.)
    private func activeLayout(for format: PosterFormat) -> PosterLayout {
        ProFeatureGate.isUnlocked ? layoutStore.layout(for: format) : .default
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

            HStack(spacing: 6) {
                highlightSectionTitle("포스터 레이아웃")
                proBadge
                if ProFeatureGate.isUnlocked && !layoutStore.layout(for: posterFormat).isDefault {
                    Text("커스텀 적용중")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(RunStampColors.energyOrange)
                }
            }
            layoutEditButton

            HStack(spacing: 6) {
                highlightSectionTitle("레이아웃 프리셋")
                proBadge
            }
            presetRow

            #if DEBUG
            proDebugToggle
            #endif
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

    /// PRO: 포스터 섹션 자유 배치 편집 진입 버튼. 잠금 상태에서는 업그레이드 안내를 띄운다.
    private var layoutEditButton: some View {
        Button {
            guard ProFeatureGate.isUnlocked else {
                viewModel.exportMessage = ProFeatureGate.layoutLockedMessage
                return
            }
            isLayoutEditorPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: ProFeatureGate.isUnlocked ? "square.grid.3x1.below.line.grid.1x2" : "lock.fill")
                    .font(.system(size: 12, weight: .black))
                Text("배치·크기·숨김 편집")
                    .font(.system(size: 13, weight: .black, design: .rounded))
            }
            .foregroundStyle(RunStampColors.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(RunStampColors.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(RunStampColors.cardStroke.opacity(0.65), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// PRO: 저장된 배치 프리셋 목록. 탭하면 적용, 길게 눌러 삭제한다.
    private var presetRow: some View {
        let presets = layoutStore.presets(for: posterFormat)
        let currentLayout = layoutStore.layout(for: posterFormat)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                savePresetChip(currentLayout: currentLayout)
                defaultLayoutChip(isActive: currentLayout.isDefault)

                ForEach(presets) { preset in
                    presetChip(preset, isActive: !currentLayout.isDefault && preset.layout == currentLayout)
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// 현재 배치를 이름 붙여 저장하는 진입 칩.
    private func savePresetChip(currentLayout: PosterLayout) -> some View {
        Button {
            guard ProFeatureGate.isUnlocked else {
                viewModel.exportMessage = ProFeatureGate.layoutLockedMessage
                return
            }
            guard !currentLayout.isDefault else {
                viewModel.exportMessage = "기본 배치 상태입니다. 먼저 레이아웃을 편집한 뒤 프리셋으로 저장해 주세요."
                return
            }
            presetNameDraft = ""
            isPresetSavePromptPresented = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: ProFeatureGate.isUnlocked ? "plus.circle.fill" : "lock.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(RunStampColors.limeGreen)
                Text("현재 배치 저장")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(RunStampColors.primaryText)
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RunStampColors.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(RunStampColors.cardStroke.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .buttonStyle(.plain)
    }

    /// 기본 배치로 되돌리는 칩. 프리셋을 쓰다가 원래 디자인으로 즉시 복귀할 수 있다.
    private func defaultLayoutChip(isActive: Bool) -> some View {
        Button {
            guard ProFeatureGate.isUnlocked else {
                viewModel.exportMessage = ProFeatureGate.layoutLockedMessage
                return
            }
            withAnimation(.easeInOut(duration: 0.18)) {
                layoutStore.setLayout(.default, for: posterFormat)
            }
        } label: {
            presetChipLabel(name: "기본 배치", isActive: isActive)
        }
        .buttonStyle(.plain)
    }

    private func presetChip(_ preset: PosterLayoutPreset, isActive: Bool) -> some View {
        Button {
            guard ProFeatureGate.isUnlocked else {
                viewModel.exportMessage = ProFeatureGate.layoutLockedMessage
                return
            }
            withAnimation(.easeInOut(duration: 0.18)) {
                layoutStore.applyPreset(preset, for: posterFormat)
            }
        } label: {
            presetChipLabel(name: preset.name, isActive: isActive)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    layoutStore.deletePreset(preset, for: posterFormat)
                }
            } label: {
                Label("프리셋 삭제", systemImage: "trash")
            }
        }
    }

    private func presetChipLabel(name: String, isActive: Bool) -> some View {
        Text(name)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(isActive ? RunStampColors.appBackground : RunStampColors.primaryText)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? RunStampColors.energyOrange : RunStampColors.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isActive ? .clear : RunStampColors.cardStroke.opacity(0.65), lineWidth: 1))
    }

    #if DEBUG
    /// DEBUG 전용 잠금 토글. 실기기에서 락/언락 UI를 즉시 확인하기 위한 스위치이며,
    /// RELEASE 빌드에는 컴파일되지 않는다. (실제 결제 흐름은 StoreKit 연동 시 대체)
    private var proDebugToggle: some View {
        Toggle(isOn: $proUnlockedDebug) {
            HStack(spacing: 5) {
                Image(systemName: proUnlockedDebug ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 11, weight: .black))
                Text("PRO 잠금 해제 · DEBUG 전용")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(RunStampColors.secondaryText)
        }
        .tint(RunStampColors.energyOrange)
        .onChange(of: proUnlockedDebug) { _, isUnlocked in
            // 잠금으로 되돌리면 이미 선택된 강조를 해제해 게이트와 상태를 일치시킨다.
            if !isUnlocked {
                withAnimation(.easeInOut(duration: 0.18)) {
                    contentHighlight = nil
                }
            }
        }
    }
    #endif

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

            ScaledCanvasPreview(canvasSize: posterFormat.canvasSize) {
                switch posterFormat {
                case .feed:
                    ZoneRunPosterView(report: report, highlightStamp: selectedHighlightStamp(for: report), contentHighlight: contentHighlight, layout: activeLayout(for: .feed))
                case .story:
                    StoryRunPosterView(report: report, highlightStamp: selectedHighlightStamp(for: report), contentHighlight: contentHighlight, layout: activeLayout(for: .story))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.36), radius: 24, y: 10)
            .frame(height: previewHeight)
            .animation(.easeInOut(duration: 0.22), value: posterFormat)
        }
        .padding(12)
        .background(RunStampColors.elevatedSurface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(RunStampColors.cardStroke.opacity(0.45), lineWidth: 1))
    }

    private var previewHeight: CGFloat {
        let availableWidth = max(UIScreen.main.bounds.width - 60, 300)
        let canvas = posterFormat.canvasSize
        return availableWidth * canvas.height / canvas.width
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            instagramStoryButton

            HStack(spacing: 12) {
                reportActionButton(title: "이미지로 저장", systemImage: "square.and.arrow.down", isPrimary: true) {
                    viewModel.exportPoster(format: posterFormat, highlightStamp: currentHighlightStamp, contentHighlight: contentHighlight, layout: activeLayout(for: posterFormat))
                }

                reportActionButton(title: "공유하기", systemImage: "square.and.arrow.up", isPrimary: false) {
                    viewModel.prepareShareImage(format: posterFormat, highlightStamp: currentHighlightStamp, contentHighlight: contentHighlight, layout: activeLayout(for: posterFormat))
                }
            }
        }
    }

    private var instagramStoryButton: some View {
        Button {
            viewModel.shareToInstagramStories(highlightStamp: currentHighlightStamp, contentHighlight: contentHighlight, layout: activeLayout(for: .story))
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
