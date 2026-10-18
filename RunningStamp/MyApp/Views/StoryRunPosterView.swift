import SwiftUI

enum PosterFormat: String, CaseIterable, Identifiable {
    case feed
    case story

    var id: String { rawValue }

    var displayText: String {
        switch self {
        case .feed:
            return "피드 4:5"
        case .story:
            return "스토리 9:16"
        }
    }

    var canvasSize: CGSize {
        switch self {
        case .feed:
            return ZoneRunPosterView.canvasSize
        case .story:
            return StoryRunPosterView.canvasSize
        }
    }
}

/// 인스타그램 스토리(1080×1920) 전용 세로형 포스터.
/// 상하단은 인스타그램 UI(카메라/보내기 버튼)가 겹치는 영역이라 비워둔다.
struct StoryRunPosterView: View {
    static let canvasSize = CGSize(width: 1_080, height: 1_920)

    let report: RunningPosterReport
    var highlightStamp: HighlightStamp = .clean
    var contentHighlight: ContentHighlightTarget?
    /// PRO: 섹션 커스텀 배치. 기본값이면 기존 렌더링과 동일하다.
    var layout: PosterLayout = .default

    private var resolvedHighlight: HighlightStamp {
        highlightStamp.resolved(for: report)
    }

    private var isFireMode: Bool {
        resolvedHighlight.style == .fire
    }

    private var posterAccent: Color {
        isFireMode ? RunStampColors.redlineRed : RunStampColors.effortColor(report.effortSignature.title)
    }

    var body: some View {
        ZStack(alignment: .top) {
            background

            // 섹션은 저장된 순서대로 플로우 레이아웃이 자동 배치한다.
            // 이동·숨김·크기 변경 시 나머지 섹션이 iOS 홈 화면처럼 재배치된다.
            PosterFlowLayout(spacing: 30) {
                ForEach(layout.visibleSections(for: .story)) { section in
                    storySection(section)
                        .posterSection(section, layout: layout, format: .story)
                }
            }
            .padding(.horizontal, 56)
            .padding(.top, 190)
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .foregroundStyle(RunStampColors.primaryText)
    }

    @ViewBuilder
    private func storySection(_ section: PosterSection) -> some View {
        switch section {
        case .topBar:
            topBar
        case .hero:
            heroBlock
        case .stats:
            statsRow
        case .visual:
            primaryVisual
        case .zoneBar:
            zoneBarCard
        case .footer:
            footer
        default:
            EmptyView()
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [RunStampColors.appBackground, RunStampColors.surface.opacity(0.72), RunStampColors.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [posterAccent.opacity(0.24), .clear],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 760
            )

            RadialGradient(
                colors: [posterAccent.opacity(0.14), .clear],
                center: .bottomLeading,
                startRadius: 60,
                endRadius: 820
            )
        }
    }

    private var topBar: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 10) {
                Text("RUNSTAMP")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .italic()
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 24, weight: .bold))
            }
            .foregroundStyle(posterAccent)

            Spacer()

            Text(report.dateText)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundStyle(RunStampColors.secondaryText.opacity(0.86))
        }
    }

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘의 러닝 타입")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(posterAccent)

            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text(report.effortSignature.title)
                    .font(.system(size: 78, weight: .black, design: .rounded))
                    .italic()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if isFireMode {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 50, weight: .black))
                        .foregroundStyle(RunStampColors.energyOrange)
                        .shadow(color: RunStampColors.energyOrange.opacity(0.85), radius: 16)
                }
            }
            .shadow(color: isFireMode ? RunStampColors.redlineRed.opacity(0.72) : .white.opacity(0.16), radius: isFireMode ? 20 : 12)

            Text(PosterTextFormatter.signatureKoreanSubtitle(for: report.effortSignature.title))
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(RunStampColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(alignment: .lastTextBaseline, spacing: 16) {
                Text(report.distanceText)
                    .font(.system(size: 158, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .shadow(color: isFireMode ? RunStampColors.redlineRed.opacity(0.34) : .clear, radius: 20)
                Text("km")
                    .font(.system(size: 40, weight: .black, design: .monospaced))
                    .foregroundStyle(RunStampColors.secondaryText.opacity(0.86))
                    .padding(.bottom, 26)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            storyStatTile(icon: "clock.fill", label: "시간", value: report.durationText, tint: RunStampColors.electricBlue, isFlameHighlighted: contentHighlight == .duration)
            storyStatTile(icon: "gauge.with.dots.needle.67percent", label: "평균 페이스", value: paceDisplayText, tint: RunStampColors.vibrantPurple, isFlameHighlighted: contentHighlight == .pace)
            storyStatTile(icon: "heart.fill", label: "평균 심박", value: report.avgHRText, suffix: "bpm", tint: RunStampColors.redlineRed, isFlameHighlighted: contentHighlight == .heartRate)
            storyStatTile(icon: "flame.fill", label: "칼로리", value: report.caloriesText, suffix: "kcal", tint: RunStampColors.energyOrange, isFlameHighlighted: contentHighlight == .calories)
        }
    }

    private var paceDisplayText: String {
        guard !report.avgPaceText.contains("--") else { return "--'--\"" }
        return "\(report.avgPaceText)/km"
    }

    private func storyStatTile(icon: String, label: String, value: String, suffix: String? = nil, tint: Color, isFlameHighlighted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(tint.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.56))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(tint.opacity(isFlameHighlighted ? 0.18 : 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isFlameHighlighted ? RunStampColors.energyOrange.opacity(0.55) : tint.opacity(0.24), lineWidth: isFlameHighlighted ? 1.6 : 1))
        .flameContentHighlight(isFlameHighlighted)
        .zIndex(isFlameHighlighted ? 10 : 0)
    }

    @ViewBuilder
    private var primaryVisual: some View {
        if report.isIndoorRunning {
            IndoorEffortVisualizerView(report: report, accent: posterAccent)
        } else if report.hasRouteData {
            NeonRouteMapView(locations: report.routeLocations, accent: posterAccent, highlightStamp: resolvedHighlight)
                .background(storyCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(posterAccent.opacity(0.24), lineWidth: 1.4))
        } else {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("러닝 리듬")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(RunStampColors.primaryText.opacity(0.86))
                        Text("경로 데이터 없음")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(posterAccent)
                    }

                    Spacer()

                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(posterAccent)
                }

                EffortWaveChart(report: report, accent: posterAccent, showConsoleGrid: false)
            }
            .padding(24)
            .background(storyCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(posterAccent.opacity(0.28), lineWidth: 1.4))
        }
    }

    private var storyCardBackground: LinearGradient {
        LinearGradient(
            colors: [posterAccent.opacity(0.10), RunStampColors.elevatedSurface, RunStampColors.surface.opacity(0.96)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var zoneBarCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(RunStampColors.redlineRed)
                Text("심박 존 분석")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(RunStampColors.primaryText.opacity(0.84))

                Spacer()

                Text(PosterTextFormatter.dominantZoneKoreanText(zone: report.dominantZone?.zone ?? 2))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(storyZoneColor(report.dominantZone?.zone ?? 2))
                Text("\(Int((report.dominantZone?.percentage ?? report.zone2Percentage).rounded()))%")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(storyZoneColor(report.dominantZone?.zone ?? 2))
            }

            zoneBar

            HStack(spacing: 0) {
                ForEach(report.zoneResults) { result in
                    HStack(spacing: 7) {
                        Circle()
                            .fill(storyZoneColor(result.zone))
                            .frame(width: 12, height: 12)
                        Text("Z\(result.zone)")
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                            .foregroundStyle(result.zone == report.dominantZone?.zone ? storyZoneColor(result.zone) : RunStampColors.secondaryText.opacity(0.82))
                        Text("\(Int(result.percentage.rounded()))%")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.60))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(24)
        .background(storyCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(RunStampColors.cardStroke.opacity(0.55), lineWidth: 1.1))
    }

    private var zoneBar: some View {
        GeometryReader { proxy in
            let total = max(report.zoneResults.map(\.percentage).reduce(0, +), 1)
            HStack(spacing: 3) {
                ForEach(report.zoneResults) { result in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(storyZoneColor(result.zone))
                        .frame(width: max(proxy.size.width * result.percentage / total - 3, 6))
                        .shadow(color: storyZoneColor(result.zone).opacity(result.zone == report.dominantZone?.zone ? 0.55 : 0.0), radius: 8)
                }
            }
        }
        .frame(height: 40)
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(report.isSampleData ? "샘플 데이터" : "RUNSTAMP")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .italic()
                .foregroundStyle(report.isSampleData ? .orange : posterAccent)

            Spacer()

            Text("Apple 건강 데이터 기반 분석")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.40))
        }
    }
}

#Preview("Story · Clean", traits: .fixedLayout(width: 1_080, height: 1_920)) {
    StoryRunPosterView(report: HeartRateZoneAnalyzer().sampleReport(), highlightStamp: .clean)
}

#Preview("Story · Fire", traits: .fixedLayout(width: 1_080, height: 1_920)) {
    StoryRunPosterView(report: HeartRateZoneAnalyzer().sampleReport(), highlightStamp: HighlightStamp(target: .firePoster, style: .fire))
}

private func storyZoneColor(_ zone: Int) -> Color {
    switch zone {
    case 1:
        return RunStampColors.electricBlue
    case 2:
        return RunStampColors.limeGreen
    case 3:
        return RunStampColors.warmYellow
    case 4:
        return RunStampColors.energyOrange
    default:
        return RunStampColors.redlineRed
    }
}
