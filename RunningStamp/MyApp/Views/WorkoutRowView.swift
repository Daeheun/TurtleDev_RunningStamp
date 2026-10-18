import CoreLocation
import SwiftUI

struct WorkoutRowView: View {
    enum RouteState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
    }

    let workout: RunWorkoutSummary
    var index: Int = 0
    let healthKitManager: HealthKitManager?
    /// 러닝 타입 계산용 캐시. 값(`signature`)은 부모가 관찰해 넘겨주고, 이 행은 로드만 트리거한다.
    let signatureCache: RunSignatureCache?
    let signature: RunSignatureCache.QuickSignature?
    let isTransitioning: Bool
    let isDimmed: Bool

    @Environment(\.distanceUnit) private var distanceUnit
    @State private var displayedWorkout: RunWorkoutSummary
    @State private var routeState: RouteState

    init(
        workout: RunWorkoutSummary,
        index: Int = 0,
        healthKitManager: HealthKitManager? = nil,
        signatureCache: RunSignatureCache? = nil,
        signature: RunSignatureCache.QuickSignature? = nil,
        isTransitioning: Bool = false,
        isDimmed: Bool = false
    ) {
        self.workout = workout
        self.index = index
        self.healthKitManager = healthKitManager
        self.signatureCache = signatureCache
        self.signature = signature
        self.isTransitioning = isTransitioning
        self.isDimmed = isDimmed
        _displayedWorkout = State(initialValue: workout)
        _routeState = State(initialValue: workout.routeLocations.count >= 2 ? .loaded : .idle)
    }

    private var accent: Color {
        rowColors[index % rowColors.count]
    }

    var body: some View {
        HStack(spacing: 10) {
            StaticRunningIcon(accent: accent)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(accent)
                        .frame(width: 7, height: 7)
                    Text(RunFormatters.koreanWeekday(displayedWorkout.startDate))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(RunStampColors.secondaryText)
                }

                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    CountUpDistanceText(meters: displayedWorkout.distanceInMeters, unit: distanceUnit, isCounting: isTransitioning)
                        .font(.system(size: 35, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(RunStampColors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text(distanceUnit.symbol)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(RunStampColors.secondaryText)
                }

                Text(workoutKindText)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(accent)
            }
            .frame(width: 112, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                MetricLine(icon: "clock", text: RunFormatters.duration(displayedWorkout.duration))
                MetricLine(icon: "speedometer", text: RunFormatters.pace(displayedWorkout.averagePaceSecondsPerKm, unit: distanceUnit))
            }
            .frame(width: 84, alignment: .leading)

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 10) {
                Text(RunFormatters.clockTime(displayedWorkout.startDate))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(RunStampColors.secondaryText.opacity(0.80))
                rowMiniVisual
                    .frame(width: 96, height: 66)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(RunStampColors.secondaryText.opacity(0.55))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 118)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(isTransitioning ? accent.opacity(0.32) : RunStampColors.cardStroke.opacity(0.50), lineWidth: 1))
        .overlay {
            if isTransitioning {
                NeonSelectionBorder(accent: accent, cornerRadius: 30)
            }
        }
        .scaleEffect(isTransitioning ? 1.045 : 1.0)
        .opacity(isDimmed ? 0.30 : 1.0)
        .brightness(isTransitioning ? 0.06 : 0)
        .shadow(color: accent.opacity(isTransitioning ? 0.22 : 0.0), radius: isTransitioning ? 18 : 0, y: isTransitioning ? 8 : 0)
        .animation(.easeInOut(duration: 0.22), value: isTransitioning)
        .animation(.easeInOut(duration: 0.18), value: isDimmed)
        .task(id: workout.id) {
            // 경로와 러닝 타입을 동시에 불러온다. 둘 다 실패해도 행은 기본 상태로 표시된다.
            async let route: Void = loadRouteIfNeeded()
            async let signatureLoad: Void = signatureCache?.load(for: workout) ?? ()
            _ = await (route, signatureLoad)
        }
        .onChange(of: workout.routeLocations.count) { _, _ in
            displayedWorkout = workout
            routeState = workout.routeLocations.count >= 2 ? .loaded : .idle
        }
    }

    private var workoutKindText: String {
        if displayedWorkout.isIndoorRunning {
            return "실내 달리기"
        }
        return displayedWorkout.routeLocations.count >= 2 ? "실외 달리기" : "달리기"
    }

    @ViewBuilder
    private var rowMiniVisual: some View {
        if displayedWorkout.isIndoorRunning {
            IndoorEffortMiniView(
                title: estimatedEffortTitle,
                dominantZoneText: estimatedDominantZoneText,
                accent: accent
            )
        } else if displayedWorkout.routeLocations.count >= 2 || routeState == .loading {
            RouteThumbnailView(locations: displayedWorkout.routeLocations, routeState: routeState, accent: accent, isDrawingRoute: isTransitioning)
        } else {
            EffortMiniFallbackView(title: estimatedEffortTitle, accent: accent)
        }
    }

    /// 상세 포스터와 같은 분석기(RunSignatureCache)가 계산한 러닝 타입. 계산 전에는 자리표시자.
    private var estimatedEffortTitle: String {
        signature?.title ?? "···"
    }

    private var estimatedDominantZoneText: String? {
        signature?.dominantZoneText
    }

    private func loadRouteIfNeeded() async {
        guard !displayedWorkout.isIndoorRunning else {
            routeState = .unavailable
            return
        }
        guard displayedWorkout.routeLocations.count < 2 else {
            routeState = .loaded
            return
        }
        guard routeState == .idle, let healthKitManager else { return }

        routeState = .loading
        do {
            let updatedWorkout = try await healthKitManager.summaryWithRoute(for: workout)
            withAnimation(.easeInOut(duration: 0.25)) {
                displayedWorkout = updatedWorkout
                routeState = updatedWorkout.routeLocations.count >= 2 ? .loaded : .unavailable
            }
        } catch {
            routeState = .unavailable
        }
    }

    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [RunStampColors.elevatedSurface, RunStampColors.surface.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [accent.opacity(0.18), accent.opacity(0.06), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var rowColors: [Color] {
        [
            RunStampColors.energyOrange,
            RunStampColors.vibrantPurple,
            RunStampColors.electricBlue,
            RunStampColors.aquaTeal,
            RunStampColors.limeGreen,
            RunStampColors.warmYellow
        ]
    }
}

struct WorkoutRowPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.workoutRowIsPressed, configuration.isPressed)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct WorkoutRowPressedKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var workoutRowIsPressed: Bool {
        get { self[WorkoutRowPressedKey.self] }
        set { self[WorkoutRowPressedKey.self] = newValue }
    }
}

private struct CountUpDistanceText: View {
    let meters: Double
    let unit: DistanceUnit
    let isCounting: Bool
    @State private var countStartDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let value = isCounting ? animatedMeters(at: timeline.date) : meters
            Text(RunFormatters.distanceNumber(value, unit: unit))
        }
        .onChange(of: isCounting) { _, counting in
            if counting {
                countStartDate = Date()
            }
        }
    }

    private func animatedMeters(at date: Date) -> Double {
        let duration = 0.62
        let elapsed = min(max(date.timeIntervalSince(countStartDate), 0), duration)
        let progress = elapsed / duration
        let eased = 1 - pow(1 - progress, 3)
        return meters * eased
    }
}

private struct NeonSelectionBorder: View {
    let accent: Color
    let cornerRadius: CGFloat
    @State private var rotation = Angle.zero

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                AngularGradient(
                    colors: [.clear, accent.opacity(0.25), accent, .white, accent, .clear],
                    center: .center,
                    angle: rotation
                ),
                lineWidth: 3
            )
            .shadow(color: accent.opacity(0.85), radius: 10)
            .onAppear {
                rotation = .zero
                withAnimation(.linear(duration: 0.52).repeatForever(autoreverses: false)) {
                    rotation = .degrees(360)
                }
            }
    }
}

private struct StaticRunningIcon: View {
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.20))
                .frame(width: 54, height: 54)

            Image(systemName: "figure.run")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(accent)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 58, height: 58)
    }
}

private struct MetricLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.56))
                .frame(width: 18)
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
    }
}

private struct RouteThumbnailView: View {
    let locations: [CLLocation]
    let routeState: WorkoutRowView.RouteState
    let accent: Color
    let isDrawingRoute: Bool
    @State private var drawProgress: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let rect = proxy.frame(in: .local)
            let points = routePoints(in: rect)

            ZStack {
                mapGrid(in: rect)
                    .stroke(RunStampColors.cardStroke.opacity(0.25), lineWidth: 0.8)

                if locations.count >= 2 {
                    routePath(points: points)
                        .trimmedPath(from: 0, to: drawProgress)
                        .stroke(accent.opacity(0.18), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        .blur(radius: 2)

                    routePath(points: points)
                        .trimmedPath(from: 0, to: drawProgress)
                        .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .shadow(color: accent.opacity(isDrawingRoute ? 0.52 : 0.0), radius: isDrawingRoute ? 6 : 0)

                    if let start = points.first {
                        Circle()
                            .fill(accent)
                            .frame(width: 6, height: 6)
                            .position(start)
                    }

                    if let end = points.last {
                        Circle()
                            .stroke(accent, lineWidth: 2)
                            .frame(width: 9, height: 9)
                            .position(end)
                    }
                } else {
                    routeStatusView
                }
            }
        }
        .onAppear {
            drawProgress = 1
        }
        .onChange(of: isDrawingRoute) { _, drawing in
            guard locations.count >= 2 else { return }
            if drawing {
                drawProgress = 0
                withAnimation(.easeOut(duration: 0.58)) {
                    drawProgress = 1
                }
            } else {
                drawProgress = 1
            }
        }
    }

    private var routeStatusView: some View {
        Group {
            switch routeState {
            case .loading:
                ProgressView()
                    .tint(accent)
                    .scaleEffect(0.7)
            case .unavailable:
                Text("NO ROUTE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(RunStampColors.tertiaryText)
            case .idle:
                Text("ROUTE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(RunStampColors.tertiaryText.opacity(0.80))
            case .loaded:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            return []
        }

        let coordinates = locations.map(\.coordinate)
        guard let minLatitude = coordinates.map(\.latitude).min(),
              let maxLatitude = coordinates.map(\.latitude).max(),
              let minLongitude = coordinates.map(\.longitude).min(),
              let maxLongitude = coordinates.map(\.longitude).max() else {
            return []
        }

        let latitudeSpan = max(maxLatitude - minLatitude, 0.000_001)
        let longitudeSpan = max(maxLongitude - minLongitude, 0.000_001)
        let drawingRect = rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.12)

        return coordinates.map { coordinate in
            let x = drawingRect.minX + ((coordinate.longitude - minLongitude) / longitudeSpan) * drawingRect.width
            let y = drawingRect.maxY - ((coordinate.latitude - minLatitude) / latitudeSpan) * drawingRect.height
            return CGPoint(x: x, y: y)
        }
    }

    private func mapGrid(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<5 {
            let y = rect.height * CGFloat(index) / 4
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y + CGFloat(index % 2) * 7))
        }
        for index in 0..<5 {
            let x = rect.width * CGFloat(index) / 4
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x - 18, y: rect.height))
        }
        return path
    }

    private func placeholderPoints(in rect: CGRect) -> [CGPoint] {
        let r = rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.16)
        return [
            CGPoint(x: r.minX + r.width * 0.08, y: r.maxY - r.height * 0.28),
            CGPoint(x: r.minX + r.width * 0.28, y: r.maxY - r.height * 0.38),
            CGPoint(x: r.minX + r.width * 0.38, y: r.maxY - r.height * 0.78),
            CGPoint(x: r.minX + r.width * 0.60, y: r.maxY - r.height * 0.86),
            CGPoint(x: r.minX + r.width * 0.82, y: r.maxY - r.height * 0.50),
            CGPoint(x: r.minX + r.width * 0.58, y: r.maxY - r.height * 0.32)
        ]
    }
}
