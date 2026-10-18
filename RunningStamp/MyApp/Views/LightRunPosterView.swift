import SwiftUI

/// 심박 데이터가 없는 러닝용 "라이트 포스터".
/// 존 분석·시그니처 대신 거리·시간·페이스·칼로리와 경로(있으면)만 담는 미니멀 구성이며,
/// 피드(4:5)와 스토리(9:16) 두 형식을 같은 뷰로 렌더링한다.
/// 샘플 데이터 폴백을 대체하므로 포스터에 찍히는 숫자는 항상 실제 기록이다.
struct LightRunPosterView: View {
    let report: RunningPosterReport
    var format: PosterFormat = .feed

    private var canvasSize: CGSize { format.canvasSize }
    private var isStory: Bool { format == .story }
    private var accent: Color { RunStampColors.electricBlue }

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: isStory ? 36 : 28) {
                topBar
                hero
                statsRow
                primaryVisual
                    .frame(maxHeight: .infinity)
                footer
            }
            .padding(.horizontal, 56)
            .padding(.top, isStory ? 190 : 56)
            .padding(.bottom, isStory ? 190 : 56)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .foregroundStyle(RunStampColors.primaryText)
        .clipShape(RoundedRectangle(cornerRadius: isStory ? 0 : 8, style: .continuous))
    }

    // MARK: - 섹션

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [RunStampColors.appBackground, RunStampColors.surface.opacity(0.72), RunStampColors.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [accent.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 30,
                endRadius: isStory ? 760 : 560
            )
            RadialGradient(
                colors: [RunStampColors.aquaTeal.opacity(0.12), .clear],
                center: .bottomLeading,
                startRadius: 60,
                endRadius: isStory ? 820 : 620
            )
        }
    }

    private var topBar: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 10) {
                Text("RUNSTAMP")
                    .font(.system(size: isStory ? 30 : 27, weight: .black, design: .rounded))
                    .italic()
                Image(systemName: "figure.run")
                    .font(.system(size: isStory ? 24 : 21, weight: .bold))
            }
            .foregroundStyle(accent)

            Spacer()

            Text(report.dateText)
                .font(.system(size: isStory ? 24 : 22, weight: .black, design: .monospaced))
                .foregroundStyle(RunStampColors.secondaryText.opacity(0.86))
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(report.isIndoorRunning ? "오늘의 실내 러닝" : "오늘의 러닝")
                .font(.system(size: isStory ? 26 : 22, weight: .bold))
                .foregroundStyle(accent)

            HStack(alignment: .lastTextBaseline, spacing: 16) {
                Text(report.distanceText)
                    .font(.system(size: isStory ? 190 : 150, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .shadow(color: accent.opacity(0.28), radius: 20)
                Text(report.distanceUnitText)
                    .font(.system(size: isStory ? 44 : 36, weight: .black, design: .monospaced))
                    .foregroundStyle(RunStampColors.secondaryText.opacity(0.86))
                    .padding(.bottom, isStory ? 30 : 22)
            }

            Text("\(report.durationText)  ·  \(paceDisplayText)")
                .font(.system(size: isStory ? 32 : 28, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(RunStampColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 14) {
            statTile(icon: "clock.fill", label: "시간", value: report.durationText, tint: RunStampColors.electricBlue)
            statTile(icon: "gauge.with.dots.needle.67percent", label: "평균 페이스", value: paceDisplayText, tint: RunStampColors.vibrantPurple)
            statTile(icon: "flame.fill", label: "칼로리", value: report.caloriesText, suffix: "kcal", tint: RunStampColors.energyOrange)
        }
    }

    private func statTile(icon: String, label: String, value: String, suffix: String? = nil, tint: Color) -> some View {
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
                    .font(.system(size: 36, weight: .black, design: .rounded))
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
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(0.24), lineWidth: 1))
    }

    @ViewBuilder
    private var primaryVisual: some View {
        if report.hasRouteData {
            NeonRouteMapView(locations: report.routeLocations, accent: accent, highlightStamp: .clean)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(accent.opacity(0.24), lineWidth: 1.4))
        } else {
            paceCard
        }
    }

    /// 경로가 없을 때(실내·GPS 미기록) 평균 속도를 큰 숫자로 보여주는 카드.
    private var paceCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("평균 속도")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(RunStampColors.primaryText.opacity(0.86))
                    Text(report.isIndoorRunning ? "트레드밀 세션" : "경로 데이터 없음")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(accent)
                }

                Spacer()

                Image(systemName: report.isIndoorRunning ? "figure.run.treadmill" : "figure.run")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.65), radius: 10)
            }

            Spacer(minLength: 0)

            Text(report.avgSpeedText)
                .font(.system(size: isStory ? 120 : 96, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: accent.opacity(0.55), radius: 16)

            speedBars

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(accent.opacity(0.28), lineWidth: 1.4))
    }

    /// 장식용 막대. 데이터를 흉내 내지 않도록 균일한 그라디언트 띠로만 그린다.
    private var speedBars: some View {
        HStack(spacing: 6) {
            ForEach(0..<24, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accent.opacity(0.12 + Double(index) / 24 * 0.5))
                    .frame(height: 14)
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(report.isIndoorRunning ? "INDOOR RUN" : "FREE RUN")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(accent.opacity(0.9))

            Spacer()

            Text("Apple 건강 데이터 기반 기록")
                .font(.system(size: isStory ? 20 : 19, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.40))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }

    // MARK: - 헬퍼

    private var paceDisplayText: String {
        guard !report.avgPaceText.contains("--") else { return "--'--\"" }
        return "\(report.avgPaceText)\(report.paceUnitText)"
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.10), RunStampColors.elevatedSurface, RunStampColors.surface.opacity(0.96)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview("Light · Feed", traits: .fixedLayout(width: 1_080, height: 1_350)) {
    LightRunPosterView(report: HeartRateZoneAnalyzer().makeLightReport(for: .previewWorkout), format: .feed)
}

#Preview("Light · Story", traits: .fixedLayout(width: 1_080, height: 1_920)) {
    LightRunPosterView(report: HeartRateZoneAnalyzer().makeLightReport(for: .previewWorkout), format: .story)
}

private extension RunWorkoutSummary {
    static var previewWorkout: RunWorkoutSummary {
        let start = Date().addingTimeInterval(-3_000)
        return RunWorkoutSummary(
            id: UUID(),
            startDate: start,
            endDate: start.addingTimeInterval(2_820),
            duration: 2_820,
            distanceInMeters: 8_210,
            activeCalories: 540,
            averagePaceSecondsPerKm: 2_820 / 8.21,
            averageHeartRate: nil,
            averageRunningPower: nil,
            averageCadence: nil,
            isIndoorRunning: true
        )
    }
}
