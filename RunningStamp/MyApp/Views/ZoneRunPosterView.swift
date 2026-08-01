import CoreLocation
import SwiftUI

struct ZoneRunPosterView: View {
    static let canvasSize = CGSize(width: 1_080, height: 1_350)

    let report: RunningPosterReport
    var languageMode: PosterLanguageMode = .mixed
    var highlightStamp: HighlightStamp = .clean
    var contentHighlight: ContentHighlightTarget?

    private var signatureAccent: Color {
        effortColor(report.effortSignature.title)
    }

    private var resolvedHighlight: HighlightStamp {
        highlightStamp.resolved(for: report)
    }

    private var isFireMode: Bool {
        resolvedHighlight.style == .fire
    }

    private var posterAccent: Color {
        isFireMode ? RunStampColors.redlineRed : signatureAccent
    }

    var body: some View {
        ZStack {
            PosterBackground(accent: posterAccent)

            VStack(alignment: .leading, spacing: 16) {
                topBar

                HStack(alignment: .top, spacing: 20) {
                    heroSummary
                        .frame(width: 500, height: 480, alignment: .topLeading)

                    primaryVisual
                        .frame(width: 520, height: 480)
                }

                HStack(spacing: 12) {
                    PosterPanel(accent: posterAccent) {
                        HeartRateZonesCard(report: report, accent: posterAccent, highlightStamp: resolvedHighlight)
                    }
                    .frame(width: 514, height: 360)

                    PosterPanel(accent: posterAccent) {
                        HeartRateTimelineCard(report: report, accent: posterAccent, highlightStamp: resolvedHighlight)
                    }
                    .frame(width: 514, height: 360)
                }

                PosterPanel(accent: posterAccent, opacity: 0.15) {
                    EffortSignatureWideCard(signature: report.effortSignature, accent: posterAccent, highlightStamp: resolvedHighlight)
                }
                .frame(height: 310)

                footer
            }
            .padding(20)
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .foregroundStyle(RunStampColors.primaryText)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var topBar: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 10) {
                Text("RUNSTAMP")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .italic()
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 21, weight: .bold))
            }
            .foregroundStyle(posterAccent)

            Spacer()

            Text(report.dateText)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(RunStampColors.secondaryText.opacity(0.86))
        }
        .frame(height: 34)
    }

    private var heroSummary: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("오늘의 러닝 타입")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(posterAccent)

                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    Text(report.effortSignature.title)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .italic()
                        .lineLimit(2)
                        .minimumScaleFactor(0.58)
                    if isFireMode {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 42, weight: .black))
                            .foregroundStyle(RunStampColors.energyOrange)
                            .shadow(color: RunStampColors.energyOrange.opacity(0.85), radius: 14)
                    }
                }
                .shadow(color: isFireMode ? RunStampColors.redlineRed.opacity(0.72) : .white.opacity(0.16), radius: isFireMode ? 18 : 12)

                Text(PosterTextFormatter.signatureKoreanSubtitle(for: report.effortSignature.title))
                    .font(.system(size: 25, weight: .heavy))
                    .foregroundStyle(RunStampColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text(report.distanceText)
                    .font(.system(size: 104, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .shadow(color: isFireMode ? RunStampColors.redlineRed.opacity(0.34) : .clear, radius: 18)
                Text("km")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundStyle(RunStampColors.secondaryText.opacity(0.86))
                    .padding(.bottom, 18)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(112), spacing: 10), count: 4), spacing: 10) {
                PosterStatTile(icon: "clock.fill", label: "시간", value: report.durationText, tint: RunStampColors.electricBlue, isFlameHighlighted: contentHighlight == .duration)
                PosterStatTile(icon: "gauge.with.dots.needle.67percent", label: "평균 페이스", value: paceDisplayText, tint: RunStampColors.vibrantPurple, isFlameHighlighted: contentHighlight == .pace)
                PosterStatTile(icon: "heart.fill", label: "평균 심박", value: report.avgHRText, suffix: "bpm", tint: RunStampColors.redlineRed, isFlameHighlighted: contentHighlight == .heartRate)
                PosterStatTile(icon: "flame.fill", label: "칼로리", value: report.caloriesText, suffix: "kcal", tint: RunStampColors.energyOrange, isFlameHighlighted: contentHighlight == .calories)
            }

            Spacer(minLength: 0)
        }
    }

    private var paceDisplayText: String {
        guard !report.avgPaceText.contains("--") else { return "--'--\"" }
        return "\(report.avgPaceText)/km"
    }

    @ViewBuilder
    private var primaryVisual: some View {
        if report.isIndoorRunning {
            IndoorEffortVisualizerView(report: report, accent: posterAccent)
        } else if report.hasRouteData {
            NeonRouteMapView(locations: report.routeLocations, accent: posterAccent, highlightStamp: resolvedHighlight)
                .background(cardBackground(accent: posterAccent, opacity: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(posterAccent.opacity(0.24), lineWidth: 1.2))
        } else {
            EffortWaveFallbackView(report: report, accent: posterAccent)
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(report.isSampleData ? "샘플 데이터" : "RUNSTAMP")
                .font(.system(size: 25, weight: .black, design: .rounded))
                .italic()
                .foregroundStyle(report.isSampleData ? .orange : posterAccent)

            Spacer()

            Text("Apple 건강 데이터 기반 분석")
                .font(.system(size: 19, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.40))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(height: 36)
    }
}

private struct PosterBackground: View {
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [RunStampColors.appBackground, RunStampColors.surface.opacity(0.72), RunStampColors.appBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [accent.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 560
            )

            RadialGradient(
                colors: [accent.opacity(0.14), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 620
            )
        }
    }
}

private struct PosterPanel<Content: View>: View {
    let accent: Color
    var opacity: Double = 0.10
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(cardBackground(accent: accent, opacity: opacity))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(RunStampColors.cardStroke.opacity(0.55), lineWidth: 1.1))
    }
}

private struct PosterStatTile: View {
    let icon: String
    let label: String
    let value: String
    var suffix: String?
    let tint: Color
    var isFlameHighlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(tint.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.48)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.56))
                }
            }
        }
        .padding(14)
        .frame(width: 112, height: 126, alignment: .leading)
        .background(tint.opacity(isFlameHighlighted ? 0.18 : 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isFlameHighlighted ? RunStampColors.energyOrange.opacity(0.55) : tint.opacity(0.24), lineWidth: isFlameHighlighted ? 1.6 : 1))
        .flameContentHighlight(isFlameHighlighted)
        .zIndex(isFlameHighlighted ? 10 : 0)
    }
}

private struct HeartRateZonesCard: View {
    let report: RunningPosterReport
    let accent: Color
    let highlightStamp: HighlightStamp

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(RunStampColors.redlineRed)
                SectionTitle("심박 존 분석", accent: RunStampColors.primaryText.opacity(0.84))
            }

            HStack(spacing: 24) {
                DonutChart(results: report.zoneResults)
                    .frame(width: 230, height: 230)
                    .overlay {
                        VStack(spacing: 4) {
                            Text("\(Int((report.dominantZone?.percentage ?? report.zone2Percentage).rounded()))%")
                                .font(.system(size: 52, weight: .black, design: .rounded))
                                .monospacedDigit()
                            Text(PosterTextFormatter.dominantZoneKoreanText(zone: report.dominantZone?.zone ?? 2))
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(zoneColor(report.dominantZone?.zone ?? 2))
                                .lineLimit(1)
                                .minimumScaleFactor(0.70)
                        }
                    }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(report.zoneResults) { result in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(zoneColor(result.zone))
                                .frame(width: 14, height: 14)
                            Text(PosterTextFormatter.zoneShortLabel(zone: result.zone))
                                .foregroundStyle(result.zone == report.dominantZone?.zone ? zoneColor(result.zone) : RunStampColors.secondaryText.opacity(0.82))
                                .lineLimit(1)
                                .minimumScaleFactor(0.70)
                                .frame(width: 100, alignment: .leading)
                            Spacer(minLength: 4)
                            Text(RunFormatters.duration(result.duration))
                                .foregroundStyle(.white.opacity(0.86))
                                .monospacedDigit()
                                .frame(width: 70, alignment: .trailing)
                            Text("\(Int(result.percentage.rounded()))%")
                                .foregroundStyle(result.zone == report.dominantZone?.zone ? zoneColor(result.zone) : .white.opacity(0.48))
                                .monospacedDigit()
                                .frame(width: 42, alignment: .trailing)
                        }
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    }
                }
            }
        }
    }
}

private struct DonutChart: View {
    let results: [HeartRateZoneResult]

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 32)

            let total = max(results.map(\.percentage).reduce(0, +), 1)
            ForEach(Array(results.enumerated()), id: \.element.zone) { index, result in
                let start = results.prefix(index).map(\.percentage).reduce(0, +) / total
                let end = start + result.percentage / total
                Circle()
                    .trim(from: start, to: end)
                    .stroke(zoneColor(result.zone), style: StrokeStyle(lineWidth: 32, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: zoneColor(result.zone).opacity(0.20), radius: 10)
            }
        }
    }
}

private struct HeartRateTimelineCard: View {
    let report: RunningPosterReport
    let accent: Color
    let highlightStamp: HighlightStamp

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(RunStampColors.electricBlue)
                SectionTitle("심박 변화", accent: RunStampColors.primaryText.opacity(0.84))
                if isFireHighlighted {
                    highlightChip("HR PEAK", systemImage: "flame.fill", color: RunStampColors.energyOrange)
                }
            }

            GeometryReader { proxy in
                let rect = proxy.frame(in: .local)
                let chartRect = CGRect(x: rect.minX + 50, y: rect.minY + 8, width: rect.width - 94, height: rect.height - 38)
                let minBPM = 80.0
                let maxBPM = max(200.0, (report.heartRateTimeline.map(\.bpm).max() ?? 190) + 8)

                ZStack(alignment: .topLeading) {
                    if isFireHighlighted {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [RunStampColors.redlineRed.opacity(0.22), RunStampColors.energyOrange.opacity(0.14), .clear],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            )
                            .frame(width: chartRect.width, height: chartRect.height)
                            .position(x: chartRect.midX, y: chartRect.midY)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [RunStampColors.energyOrange.opacity(0.92), RunStampColors.redlineRed.opacity(0.80), RunStampColors.energyOrange.opacity(0.52)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2.4
                            )
                            .frame(width: chartRect.width + 18, height: chartRect.height + 18)
                            .position(x: chartRect.midX, y: chartRect.midY)
                            .shadow(color: RunStampColors.redlineRed.opacity(0.65), radius: 14)
                    }

                    ForEach(report.zoneResults) { result in
                        zoneBand(for: result, in: chartRect, minBPM: minBPM, maxBPM: maxBPM)
                    }

                    gridLines(in: chartRect)
                    heartRatePath(in: chartRect, minBPM: minBPM, maxBPM: maxBPM)
                        .stroke(isFireHighlighted ? RunStampColors.energyOrange.opacity(0.28) : accent.opacity(0.0), style: StrokeStyle(lineWidth: isFireHighlighted ? 12 : 0, lineCap: .round, lineJoin: .round))
                        .blur(radius: isFireHighlighted ? 6 : 0)

                    heartRatePath(in: chartRect, minBPM: minBPM, maxBPM: maxBPM)
                        .stroke(isFireHighlighted ? fireGradient : AnyShapeStyle(accent), style: StrokeStyle(lineWidth: isFireHighlighted ? 4.2 : 3.2, lineCap: .round, lineJoin: .round))
                        .shadow(color: (isFireHighlighted ? RunStampColors.energyOrange : accent).opacity(0.75), radius: isFireHighlighted ? 12 : 8)

                    axisLabels(in: chartRect, minBPM: minBPM, maxBPM: maxBPM)
                }
            }
        }
    }

    private var isFireHighlighted: Bool {
        highlightStamp.style == .fire
    }

    private var fireGradient: AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: [RunStampColors.warmYellow, RunStampColors.energyOrange, RunStampColors.redlineRed],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private func zoneBand(for result: HeartRateZoneResult, in rect: CGRect, minBPM: Double, maxBPM: Double) -> some View {
        let lower = max(result.minBPM, minBPM)
        let upper = min(result.maxBPM ?? maxBPM, maxBPM)
        let yTop = yPosition(for: upper, in: rect, minBPM: minBPM, maxBPM: maxBPM)
        let yBottom = yPosition(for: lower, in: rect, minBPM: minBPM, maxBPM: maxBPM)

        return Rectangle()
            .fill(zoneColor(result.zone).opacity(0.17))
            .frame(width: rect.width, height: max(yBottom - yTop, 1))
            .position(x: rect.midX, y: (yTop + yBottom) / 2)
    }

    private func gridLines(in rect: CGRect) -> some View {
        Path { path in
            for offset in stride(from: 0.0, through: 1.0, by: 0.25) {
                let y = rect.minY + rect.height * offset
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
        .stroke(.white.opacity(0.13), lineWidth: 1)
    }

    private func heartRatePath(in rect: CGRect, minBPM: Double, maxBPM: Double) -> Path {
        var path = Path()
        guard let firstDate = report.heartRateTimeline.first?.date,
              let lastDate = report.heartRateTimeline.last?.date,
              firstDate < lastDate else {
            return path
        }

        for point in report.heartRateTimeline {
            let xRatio = point.date.timeIntervalSince(firstDate) / lastDate.timeIntervalSince(firstDate)
            let x = rect.minX + rect.width * xRatio
            let y = yPosition(for: point.bpm, in: rect, minBPM: minBPM, maxBPM: maxBPM)
            let cgPoint = CGPoint(x: x, y: y)
            if path.isEmpty {
                path.move(to: cgPoint)
            } else {
                path.addLine(to: cgPoint)
            }
        }

        return path
    }

    private func axisLabels(in rect: CGRect, minBPM: Double, maxBPM: Double) -> some View {
        ZStack {
            ForEach([80, 110, 140, 170, 190], id: \.self) { value in
                Text("\(value)")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
                    .position(x: rect.minX - 24, y: yPosition(for: Double(value), in: rect, minBPM: minBPM, maxBPM: maxBPM))
            }

            ForEach(report.zoneResults) { result in
                let mid = (result.minBPM + (result.maxBPM ?? maxBPM)) / 2
                Text("Z\(result.zone)")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(zoneColor(result.zone))
                    .position(x: rect.maxX + 25, y: yPosition(for: mid, in: rect, minBPM: minBPM, maxBPM: maxBPM))
            }

            Text("0")
                .position(x: rect.minX, y: rect.maxY + 20)
            Text("종료")
                .position(x: rect.maxX, y: rect.maxY + 20)
        }
        .font(.system(size: 13, weight: .black, design: .monospaced))
        .foregroundStyle(.white.opacity(0.58))
    }

    private func yPosition(for bpm: Double, in rect: CGRect, minBPM: Double, maxBPM: Double) -> CGFloat {
        let ratio = (min(max(bpm, minBPM), maxBPM) - minBPM) / (maxBPM - minBPM)
        return rect.maxY - rect.height * ratio
    }
}

private struct EffortSignatureWideCard: View {
    let signature: EffortSignature
    let accent: Color
    let highlightStamp: HighlightStamp

    var body: some View {
        HStack(alignment: .center, spacing: 34) {
            ZStack {
                if isFireHighlighted {
                    Circle()
                        .stroke(RunStampColors.energyOrange.opacity(0.22), lineWidth: 12)
                        .frame(width: 224, height: 224)
                        .blur(radius: 2)
                    Circle()
                        .stroke(RunStampColors.redlineRed.opacity(0.34), lineWidth: 2)
                        .frame(width: 262, height: 262)
                }
                PulseBadge(accent: accent)
                    .frame(width: 250, height: 250)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("오늘의 러닝 시그니처")
                    .font(.system(size: 23, weight: .heavy))
                    .foregroundStyle(accent)

                HStack(alignment: .lastTextBaseline, spacing: 18) {
                    Text(signature.title)
                        .font(.system(size: 61, weight: .black, design: .rounded))
                        .italic()
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.50)
                    Text(PosterTextFormatter.signatureKoreanDescriptor(for: signature.title))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(RunStampColors.secondaryText.opacity(0.90))
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }

                HStack(spacing: 14) {
                    metricPill(PosterTextFormatter.localizedPrimaryMetric(signature.primaryMetricText, signatureTitle: signature.title), color: accent)
                    metricPill("회복 필요도 \(PosterTextFormatter.recoveryNeedKoreanText(signature.recoveryNeed))", color: RunStampColors.primaryText.opacity(0.72))
                }

                Text(PosterTextFormatter.signatureKoreanInsight(for: signature.title))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(RunStampColors.primaryText.opacity(0.76))
                    .lineSpacing(7)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
            }
        }
    }

    private var isFireHighlighted: Bool {
        highlightStamp.style == .fire
    }

    private func metricPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(color.opacity(0.30), lineWidth: 1))
    }
}

private struct PulseBadge: View {
    let accent: Color

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(accent.opacity(Double(5 - index) * 0.06), lineWidth: 1.2)
                    .frame(width: CGFloat(110 + index * 28), height: CGFloat(110 + index * 28))
            }

            Circle()
                .fill(RadialGradient(colors: [accent.opacity(0.22), accent.opacity(0.05), .clear], center: .center, startRadius: 10, endRadius: 112))
                .frame(width: 220, height: 220)

            Circle()
                .stroke(accent, lineWidth: 8)
                .frame(width: 142, height: 142)
                .shadow(color: accent.opacity(0.80), radius: 18)

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 72, weight: .black))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.80), radius: 14)
        }
    }
}

struct IndoorEffortVisualizerView: View {
    let report: RunningPosterReport
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("실내 러닝 분석", accent: RunStampColors.primaryText.opacity(0.86))
                    Text("트레드밀 세션")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(accent)
                }

                Spacer()

                Image(systemName: "figure.run")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.65), radius: 10)
            }

            EffortWaveChart(report: report, accent: accent, showConsoleGrid: true)
                .frame(height: 270)

            HStack(spacing: 10) {
                IndoorMetricTile(label: "평균 속도", value: report.avgSpeedText, accent: RunStampColors.electricBlue)
                if let paceConsistencyText = report.paceConsistencyText {
                    IndoorMetricTile(label: "페이스 안정성", value: paceConsistencyText, accent: RunStampColors.vibrantPurple)
                }
                IndoorMetricTile(label: "심박 드리프트", value: report.hrDriftText, accent: accent)
                IndoorMetricTile(label: "주요 구간", value: report.dominantZoneText, accent: zoneColor(report.dominantZone?.zone ?? 2))
            }
        }
        .padding(22)
        .background(cardBackground(accent: accent, opacity: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(accent.opacity(0.28), lineWidth: 1.2))
        .overlay(alignment: .bottomTrailing) {
            Text("GPS 없이 기록된 러닝")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.28))
                .padding(18)
        }
    }
}

private struct EffortWaveFallbackView: View {
    let report: RunningPosterReport
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("러닝 리듬", accent: RunStampColors.primaryText.opacity(0.86))
                    Text("경로 데이터 없음")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(accent)
                }

                Spacer()

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(accent)
            }

            EffortWaveChart(report: report, accent: accent, showConsoleGrid: false)
                .frame(height: 322)
        }
        .padding(22)
        .background(cardBackground(accent: accent, opacity: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(accent.opacity(0.28), lineWidth: 1.2))
    }
}

private struct IndoorMetricTile: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accent.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.90))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(accent.opacity(0.24), lineWidth: 1))
    }
}

struct EffortWaveChart: View {
    let report: RunningPosterReport
    let accent: Color
    let showConsoleGrid: Bool

    var body: some View {
        GeometryReader { proxy in
            let rect = proxy.frame(in: .local)
            let chartRect = rect.insetBy(dx: 20, dy: 18)
            let minBPM = 80.0
            let maxBPM = max(200.0, (report.heartRateTimeline.map(\.bpm).max() ?? 190) + 8)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.02, green: 0.025, blue: 0.08).opacity(0.72))

                ForEach(report.zoneResults) { result in
                    zoneBand(for: result, in: chartRect, minBPM: minBPM, maxBPM: maxBPM)
                }

                if showConsoleGrid {
                    consoleGrid(in: chartRect)
                        .stroke(.white.opacity(0.09), lineWidth: 1)
                }

                wavePath(in: chartRect, minBPM: minBPM, maxBPM: maxBPM)
                    .stroke(accent.opacity(0.26), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                    .blur(radius: 8)

                wavePath(in: chartRect, minBPM: minBPM, maxBPM: maxBPM)
                    .stroke(waveGradient, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                    .shadow(color: accent.opacity(0.75), radius: 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text(PosterTextFormatter.signatureKoreanSubtitle(for: report.effortSignature.title))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(RunStampColors.secondaryText.opacity(0.70))
                    Text(report.hrDriftText)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                    Text("심박 드리프트")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(RunStampColors.secondaryText.opacity(0.62))
                }
                .padding(18)
            }
        }
    }

    private var waveGradient: LinearGradient {
        LinearGradient(
            colors: signatureWaveColors(title: report.effortSignature.title, accent: accent),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func zoneBand(for result: HeartRateZoneResult, in rect: CGRect, minBPM: Double, maxBPM: Double) -> some View {
        let lower = max(result.minBPM, minBPM)
        let upper = min(result.maxBPM ?? maxBPM, maxBPM)
        let yTop = yPosition(for: upper, in: rect, minBPM: minBPM, maxBPM: maxBPM)
        let yBottom = yPosition(for: lower, in: rect, minBPM: minBPM, maxBPM: maxBPM)

        return Rectangle()
            .fill(zoneColor(result.zone).opacity(0.12))
            .frame(width: rect.width, height: max(yBottom - yTop, 1))
            .position(x: rect.midX, y: (yTop + yBottom) / 2)
    }

    private func wavePath(in rect: CGRect, minBPM: Double, maxBPM: Double) -> Path {
        var path = Path()
        guard let firstDate = report.heartRateTimeline.first?.date,
              let lastDate = report.heartRateTimeline.last?.date,
              firstDate < lastDate else {
            return path
        }

        for point in report.heartRateTimeline {
            let xRatio = point.date.timeIntervalSince(firstDate) / lastDate.timeIntervalSince(firstDate)
            let x = rect.minX + rect.width * xRatio
            let y = yPosition(for: point.bpm, in: rect, minBPM: minBPM, maxBPM: maxBPM)
            let nextPoint = CGPoint(x: x, y: y)
            if path.isEmpty {
                path.move(to: nextPoint)
            } else {
                path.addLine(to: nextPoint)
            }
        }

        return path
    }

    private func consoleGrid(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0...5 {
            let y = rect.minY + rect.height * CGFloat(index) / 5
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        for index in 0...6 {
            let x = rect.minX + rect.width * CGFloat(index) / 6
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        return path
    }

    private func yPosition(for bpm: Double, in rect: CGRect, minBPM: Double, maxBPM: Double) -> CGFloat {
        let ratio = (min(max(bpm, minBPM), maxBPM) - minBPM) / (maxBPM - minBPM)
        return rect.maxY - rect.height * ratio
    }
}

struct NeonRouteMapView: View {
    let locations: [CLLocation]
    let accent: Color
    let highlightStamp: HighlightStamp

    var body: some View {
        GeometryReader { proxy in
            let rect = proxy.frame(in: .local)
            let route = routePoints(in: rect)

            ZStack {
                mapGrid(in: rect)
                    .stroke(Color(red: 0.12, green: 0.28, blue: 0.70).opacity(0.22), lineWidth: 1.4)

                routePath(points: route)
                    .stroke(accent.opacity(isNeonHighlighted ? 0.42 : 0.28), style: StrokeStyle(lineWidth: isNeonHighlighted ? 24 : 18, lineCap: .round, lineJoin: .round))
                    .blur(radius: isNeonHighlighted ? 12 : 9)
                routePath(points: route)
                    .stroke(routeGradient, style: StrokeStyle(lineWidth: isNeonHighlighted ? 7.5 : 6, lineCap: .round, lineJoin: .round))
                    .shadow(color: accent.opacity(isNeonHighlighted ? 1.0 : 0.85), radius: isNeonHighlighted ? 18 : 10)

                if let start = route.first {
                    if isNeonHighlighted { pulseMarker(at: start, color: RunStampColors.energyOrange) }
                    marker(at: start, fill: Color(red: 1.0, green: 0.42, blue: 0.12), stroke: accent)
                }
                if let end = route.last {
                    if isNeonHighlighted { pulseMarker(at: end, color: RunStampColors.redlineRed) }
                    marker(at: end, fill: Color(red: 0.08, green: 0.02, blue: 0.08), stroke: .white)
                }

                if locations.count < 2 {
                    Text("경로 미리보기")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.40))
                        .position(x: rect.midX, y: rect.maxY - 24)
                }
            }
            .padding(2)
        }
    }

    private var isNeonHighlighted: Bool {
        highlightStamp.style == .fire
    }

    private var routeGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.82, blue: 0.22), accent, Color(red: 1.0, green: 0.20, blue: 0.28)],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    private func pulseMarker(at point: CGPoint, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.24), lineWidth: 3)
                .frame(width: 58, height: 58)
            Circle()
                .stroke(color.opacity(0.40), lineWidth: 2)
                .frame(width: 42, height: 42)
        }
        .shadow(color: color.opacity(0.65), radius: 14)
        .position(point)
    }

    private func marker(at point: CGPoint, fill: Color, stroke: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: 26, height: 26)
            .overlay(Circle().stroke(stroke, lineWidth: 5))
            .shadow(color: stroke.opacity(0.75), radius: 9)
            .position(point)
    }

    private func routePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        return path
    }

    private func routePoints(in rect: CGRect) -> [CGPoint] {
        guard locations.count >= 2 else {
            return placeholderRoute(in: rect)
        }

        let coordinates = locations.map(\.coordinate)
        guard let minLatitude = coordinates.map(\.latitude).min(),
              let maxLatitude = coordinates.map(\.latitude).max(),
              let minLongitude = coordinates.map(\.longitude).min(),
              let maxLongitude = coordinates.map(\.longitude).max() else {
            return placeholderRoute(in: rect)
        }

        let latitudeSpan = max(maxLatitude - minLatitude, 0.000_001)
        let longitudeSpan = max(maxLongitude - minLongitude, 0.000_001)
        let drawingRect = rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08)
        let routeAspect = CGFloat(longitudeSpan / latitudeSpan)
        let rectAspect = drawingRect.width / drawingRect.height
        let fittedWidth = routeAspect > rectAspect ? drawingRect.width : drawingRect.height * routeAspect
        let fittedHeight = routeAspect > rectAspect ? drawingRect.width / routeAspect : drawingRect.height
        let fittedRect = CGRect(
            x: drawingRect.midX - fittedWidth / 2,
            y: drawingRect.midY - fittedHeight / 2,
            width: fittedWidth,
            height: fittedHeight
        )

        return coordinates.map { coordinate in
            let xRatio = (coordinate.longitude - minLongitude) / longitudeSpan
            let yRatio = (coordinate.latitude - minLatitude) / latitudeSpan
            return CGPoint(x: fittedRect.minX + fittedRect.width * xRatio, y: fittedRect.maxY - fittedRect.height * yRatio)
        }
    }

    private func mapGrid(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<10 {
            let y = rect.height * CGFloat(index) / 9
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y + CGFloat(index % 2) * 18))
        }
        for index in 0..<9 {
            let x = rect.width * CGFloat(index) / 8
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x - 80 + CGFloat(index % 2) * 120, y: rect.height))
        }
        return path
    }

    private func placeholderRoute(in rect: CGRect) -> [CGPoint] {
        let r = rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.10)
        return [
            CGPoint(x: r.minX + r.width * 0.30, y: r.minY + r.height * 0.20),
            CGPoint(x: r.minX + r.width * 0.42, y: r.minY + r.height * 0.30),
            CGPoint(x: r.minX + r.width * 0.36, y: r.minY + r.height * 0.72),
            CGPoint(x: r.minX + r.width * 0.66, y: r.minY + r.height * 0.92),
            CGPoint(x: r.minX + r.width * 0.86, y: r.minY + r.height * 0.76),
            CGPoint(x: r.minX + r.width * 0.78, y: r.minY + r.height * 0.42),
            CGPoint(x: r.minX + r.width * 0.56, y: r.minY + r.height * 0.10)
        ]
    }
}

private func highlightChip(_ text: String, systemImage: String, color: Color) -> some View {
    HStack(spacing: 5) {
        Image(systemName: systemImage)
        Text(text)
    }
    .font(.system(size: 12, weight: .black, design: .monospaced))
    .foregroundStyle(color)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(color.opacity(0.14))
    .clipShape(Capsule())
    .overlay(Capsule().stroke(color.opacity(0.32), lineWidth: 1))
}

private struct SectionTitle: View {
    let text: String
    let accent: Color

    init(_ text: String, accent: Color) {
        self.text = text
        self.accent = accent
    }

    var body: some View {
        Text(text)
            .font(.system(size: 24, weight: .black, design: .rounded))
            .foregroundStyle(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }
}

private func cardBackground(accent: Color, opacity: Double) -> LinearGradient {
    LinearGradient(
        colors: [accent.opacity(min(opacity, 0.10)), RunStampColors.elevatedSurface, RunStampColors.surface.opacity(0.96)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private func signatureWaveColors(title: String, accent: Color) -> [Color] {
    switch title {
    case "REDLINE PUSH":
        return [RunStampColors.energyOrange, RunStampColors.redlineRed, accent]
    case "TEMPO ENGINE":
        return [RunStampColors.vibrantPurple, RunStampColors.energyOrange, accent]
    case "CONTROLLED BASE", "RECOVERY FLOW":
        return [RunStampColors.aquaTeal, RunStampColors.limeGreen, accent]
    case "PROGRESSIVE BURN":
        return [RunStampColors.warmYellow, RunStampColors.energyOrange, accent]
    default:
        return [RunStampColors.electricBlue, accent, RunStampColors.vibrantPurple]
    }
}

private func effortColor(_ title: String) -> Color {
    RunStampColors.effortColor(title)
}

private func zoneColor(_ zone: Int) -> Color {
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
