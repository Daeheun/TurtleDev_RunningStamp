import SwiftUI

/// 유료(PRO) 기능: 포스터 섹션 배치 편집 화면.
/// - 드래그: 섹션을 다른 섹션 위로 끌면 순서가 바뀌고 나머지가 자동 재배치된다(iOS 홈 화면식).
/// - 핀치: 두 손가락으로 섹션 크기를 조절한다.
/// - 숨김: ⊖ 배지로 섹션을 제거하고, 하단 트레이에서 탭으로 복원한다.
struct PosterLayoutEditorView: View {
    let format: PosterFormat
    let report: RunningPosterReport
    var highlightStamp: HighlightStamp = .clean
    var contentHighlight: ContentHighlightTarget?
    let initialLayout: PosterLayout
    let onSave: (PosterLayout) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: PosterLayout
    @State private var draggingSection: PosterSection?
    @State private var pinchingSection: PosterSection?
    @State private var pinchBaseScale: CGFloat?

    private static let canvasSpaceName = "posterLayoutEditorCanvas"

    init(
        format: PosterFormat,
        report: RunningPosterReport,
        highlightStamp: HighlightStamp = .clean,
        contentHighlight: ContentHighlightTarget? = nil,
        initialLayout: PosterLayout,
        onSave: @escaping (PosterLayout) -> Void
    ) {
        self.format = format
        self.report = report
        self.highlightStamp = highlightStamp
        self.contentHighlight = contentHighlight
        self.initialLayout = initialLayout
        self.onSave = onSave

        var normalized = initialLayout
        normalized.normalizeOrder(for: format)
        _draft = State(initialValue: normalized)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RunStampColors.appBackground.ignoresSafeArea()

                VStack(spacing: 12) {
                    Text("드래그로 순서 변경 · 두 손가락으로 크기 조절 · ⊖로 숨기기")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(RunStampColors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    GeometryReader { proxy in
                        let canvas = format.canvasSize
                        let scale = min(proxy.size.width / canvas.width, proxy.size.height / canvas.height)

                        editorCanvas
                            .frame(width: canvas.width, height: canvas.height)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(width: canvas.width * scale, height: canvas.height * scale, alignment: .topLeading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    hiddenSectionTray
                }
                .padding(16)
            }
            .navigationTitle("레이아웃 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("초기화") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            var reset = PosterLayout.default
                            reset.normalizeOrder(for: format)
                            draft = reset
                        }
                    }
                    .disabled(draft.isDefault)

                    Button("완료") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.black)
                }
            }
        }
    }

    private var editorCanvas: some View {
        posterContent
            .allowsHitTesting(false)
            .overlayPreferenceValue(PosterSectionFramePreferenceKey.self) { anchors in
                GeometryReader { proxy in
                    let rects = anchors.mapValues { proxy[$0] }
                    ZStack(alignment: .topLeading) {
                        ForEach(draft.visibleSections(for: format)) { section in
                            if let rect = rects[section] {
                                sectionHandle(section, rect: rect, rects: rects)
                            }
                        }
                    }
                }
            }
            .coordinateSpace(name: Self.canvasSpaceName)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.22), lineWidth: 2))
    }

    @ViewBuilder
    private var posterContent: some View {
        switch format {
        case .feed:
            ZoneRunPosterView(report: report, highlightStamp: highlightStamp, contentHighlight: contentHighlight, layout: draft)
        case .story:
            StoryRunPosterView(report: report, highlightStamp: highlightStamp, contentHighlight: contentHighlight, layout: draft)
        }
    }

    // MARK: - 섹션 핸들

    private func sectionHandle(_ section: PosterSection, rect: CGRect, rects: [PosterSection: CGRect]) -> some View {
        let isDragging = draggingSection == section
        let isPinching = pinchingSection == section
        let isActive = isDragging || isPinching
        let scalePercent = Int((draft.clampedScale(for: section, format: format) * 100).rounded())
        let strokeColor: Color = isActive ? RunStampColors.energyOrange : .white.opacity(0.45)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RunStampColors.energyOrange.opacity(isActive ? 0.08 : 0.0))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(strokeColor, style: StrokeStyle(lineWidth: isActive ? 7 : 4, dash: [14, 11]))

            Text(scalePercent == 100 ? section.displayName : "\(section.displayName) · \(scalePercent)%")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(isActive ? RunStampColors.appBackground : .white.opacity(0.92))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(isActive ? RunStampColors.energyOrange : Color.black.opacity(0.55))
                .clipShape(Capsule())
                .offset(x: 14, y: -24)
        }
        .frame(width: rect.width, height: rect.height)
        .contentShape(Rectangle())
        .gesture(reorderDrag(for: section, rects: rects))
        .simultaneousGesture(pinch(for: section))
        .overlay(alignment: .topTrailing) {
            hideButton(for: section)
                .offset(x: 26, y: -26)
        }
        .position(x: rect.midX, y: rect.midY)
        .zIndex(isActive ? 20 : 0)
    }

    /// iOS 홈 화면식 삭제(숨김) 배지.
    private func hideButton(for section: PosterSection) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                draft.setHidden(true, for: section)
            }
        } label: {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 64, weight: .black))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, RunStampColors.redlineRed)
                .background(Circle().fill(.white).padding(10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 제스처

    /// 드래그한 섹션이 다른 섹션 위를 지나면 순서를 교환한다. 나머지는 플로우가 재배치.
    private func reorderDrag(for section: PosterSection, rects: [PosterSection: CGRect]) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.canvasSpaceName))
            .onChanged { value in
                guard pinchingSection == nil else { return }
                draggingSection = section

                guard let target = rects.first(where: { $0.key != section && $0.value.contains(value.location) })?.key,
                      !draft.state(for: target).isHidden else {
                    return
                }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    draft.move(section, toPositionOf: target, format: format)
                }
            }
            .onEnded { _ in
                draggingSection = nil
            }
    }

    /// 두 손가락 핀치로 섹션 크기 조절(0.5배 ~ 캔버스 폭 한계까지).
    private func pinch(for section: PosterSection) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.02)
            .onChanged { value in
                if pinchingSection != section {
                    pinchingSection = section
                    pinchBaseScale = draft.state(for: section).scale
                }
                guard let base = pinchBaseScale else { return }
                withAnimation(.interactiveSpring) {
                    draft.setScale(base * value.magnification, for: section, format: format)
                }
            }
            .onEnded { _ in
                pinchingSection = nil
                pinchBaseScale = nil
            }
    }

    // MARK: - 숨긴 섹션 트레이

    @ViewBuilder
    private var hiddenSectionTray: some View {
        let hidden = draft.hiddenSections(for: format)
        if !hidden.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("숨긴 섹션 — 탭하면 복원됩니다")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RunStampColors.secondaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(hidden) { section in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    draft.setHidden(false, for: section)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundStyle(RunStampColors.limeGreen)
                                    Text(section.displayName)
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                        .foregroundStyle(RunStampColors.primaryText)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(RunStampColors.surface)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(RunStampColors.cardStroke.opacity(0.65), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
