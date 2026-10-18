import SwiftUI

struct WorkoutPickerView: View {
    let workouts: [RunWorkoutSummary]
    let isLoading: Bool
    let message: String?
    let healthKitManager: HealthKitManager
    let selectedTransitionID: UUID?
    let reload: () -> Void
    let onSelect: (RunWorkoutSummary) -> Void

    @State private var selectedMonthID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if isLoading && workouts.isEmpty {
                LoadingSummaryCard()
                ForEach(0..<6, id: \.self) { _ in
                    LoadingWorkoutRow()
                }
            } else if workouts.isEmpty {
                emptyState
            } else if let selectedSection {
                MonthSelectorView(
                    sections: monthSections,
                    selectedID: selectedSection.id,
                    select: { id in
                        withAnimation(.easeInOut(duration: 0.22)) {
                            selectedMonthID = id
                        }
                    }
                )

                MonthlyRunningSummaryCard(workouts: selectedSection.workouts)
                    .opacity(selectedTransitionID == nil ? 1 : 0.28)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                MonthlyCalendarHeatmapView(monthDate: selectedSection.date, workouts: selectedSection.workouts)
                    .opacity(selectedTransitionID == nil ? 1 : 0.28)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                ForEach(Array(selectedSection.workouts.enumerated()), id: \.element.id) { index, workout in
                    let isSelected = selectedTransitionID == workout.id
                    let isDimmed = selectedTransitionID != nil && !isSelected

                    Button {
                        onSelect(workout)
                    } label: {
                        WorkoutRowView(
                            workout: workout,
                            index: index,
                            healthKitManager: healthKitManager,
                            isTransitioning: isSelected,
                            isDimmed: isDimmed
                        )
                    }
                    .buttonStyle(WorkoutRowPressButtonStyle())
                    .disabled(selectedTransitionID != nil)
                    .zIndex(isSelected ? 10 : 0)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onChange(of: workouts.map(\.id)) { _, _ in
            syncSelectedMonth()
        }
        .onAppear {
            syncSelectedMonth()
        }
        .animation(.easeInOut(duration: 0.3), value: workouts.map(\.id))
        .animation(.easeInOut(duration: 0.25), value: isLoading)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(monthTitle)
                    .font(.system(size: 22, weight: .black, design: .default))
                    .foregroundStyle(RunStampColors.primaryText)
                if !workouts.isEmpty {
                    Text("월별 러닝 기록")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(RunStampColors.tertiaryText)
                }
            }
            Spacer()
            Button(action: reload) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RunStampColors.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(RunStampColors.surface.opacity(0.92))
                    .clipShape(Circle())
            }
            .disabled(isLoading)
        }
        .padding(.top, 4)
    }

    private var monthTitle: String {
        selectedSection.map { RunFormatters.koreanMonth($0.date) } ?? RunFormatters.koreanMonth(workouts.first?.startDate ?? Date())
    }

    private var selectedSection: WorkoutMonthSection? {
        let sections = monthSections
        guard !sections.isEmpty else { return nil }
        if let selectedMonthID, let section = sections.first(where: { $0.id == selectedMonthID }) {
            return section
        }
        return sections.first
    }

    private var monthSections: [WorkoutMonthSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { workout in
            monthStart(for: workout.startDate, calendar: calendar)
        }

        return grouped
            .map { date, workouts in
                WorkoutMonthSection(
                    date: date,
                    workouts: workouts.sorted { $0.startDate > $1.startDate }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private func syncSelectedMonth() {
        let sections = monthSections
        guard !sections.isEmpty else {
            selectedMonthID = nil
            return
        }
        if let selectedMonthID, sections.contains(where: { $0.id == selectedMonthID }) {
            return
        }
        selectedMonthID = sections.first?.id
    }

    private func monthStart(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(RunStampColors.secondaryText)
            Text(message ?? "최근 러닝 기록이 없습니다.")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(RunStampColors.secondaryText)
            Button("다시 불러오기", action: reload)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .background(RunStampColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(RunStampColors.cardStroke.opacity(0.45), lineWidth: 1))
    }
}

private struct WorkoutMonthSection: Identifiable {
    let date: Date
    let workouts: [RunWorkoutSummary]

    var id: String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }
}

private struct MonthSelectorView: View {
    let sections: [WorkoutMonthSection]
    let selectedID: String
    let select: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sections) { section in
                    let isSelected = section.id == selectedID
                    Button {
                        select(section.id)
                    } label: {
                        VStack(spacing: 3) {
                            Text(monthLabel(section.date))
                                .font(.system(size: 15, weight: .black, design: .rounded))
                            Text("\(yearLabel(section.date)) · \(section.workouts.count)회")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        .foregroundStyle(isSelected ? RunStampColors.appBackground : RunStampColors.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(isSelected ? RunStampColors.limeGreen : RunStampColors.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(isSelected ? RunStampColors.limeGreen.opacity(0.35) : RunStampColors.cardStroke.opacity(0.45), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func monthLabel(_ date: Date) -> String {
        let month = Calendar.current.component(.month, from: date)
        return "\(month)월"
    }

    private func yearLabel(_ date: Date) -> String {
        let year = Calendar.current.component(.year, from: date)
        return "\(year)"
    }
}

private struct MonthlyRunningSummaryCard: View {
    let workouts: [RunWorkoutSummary]

    var body: some View {
        HStack(spacing: 0) {
            SummaryMetricView(icon: "shoeprints.fill", value: "\(workouts.count)", label: "총 세션", color: RunStampColors.electricBlue)
            divider
            SummaryMetricView(icon: "mappin.circle.fill", value: RunFormatters.summaryDistanceKm(totalDistance), label: "총 거리 (KM)", color: RunStampColors.vibrantPurple)
            divider
            SummaryMetricView(icon: "flame.fill", value: RunFormatters.number(totalCalories), label: "총 칼로리 (KCAL)", color: RunStampColors.energyOrange)
            divider
            SummaryMetricView(icon: "timer", value: RunFormatters.duration(totalDuration), label: "총 시간", color: RunStampColors.aquaTeal)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 10)
        .background(
            LinearGradient(
                colors: [RunStampColors.elevatedSurface, RunStampColors.surface.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(RunStampColors.cardStroke.opacity(0.45), lineWidth: 1))
    }

    private var divider: some View {
        Rectangle()
            .fill(RunStampColors.divider.opacity(0.65))
            .frame(width: 1, height: 58)
    }

    private var totalDistance: Double {
        workouts.map(\.distanceInMeters).reduce(0, +)
    }

    private var totalCalories: Double? {
        let values = workouts.compactMap(\.activeCalories)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private var totalDuration: TimeInterval {
        workouts.map(\.duration).reduce(0, +)
    }
}

private struct SummaryMetricView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(color.opacity(0.86))
                .frame(width: 34, height: 34)
                .background(color.opacity(0.10))
                .clipShape(Circle())
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(RunStampColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(RunStampColors.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LoadingSummaryCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(RunStampColors.elevatedSurface)
            .frame(height: 118)
            .shimmering()
    }
}

private struct LoadingWorkoutRow: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(RunStampColors.elevatedSurface)
            .frame(height: 142)
            .shimmering()
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.8

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.18), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(12))
                .offset(x: phase * 360)
                .blendMode(.plusLighter)
            }
            .clipped()
            .onAppear {
                phase = -0.8
                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

private extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
