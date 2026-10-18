import SwiftUI

/// 월간 러닝 캘린더 히트맵. 날짜별 총 러닝 거리를 GitHub 잔디 스타일의
/// 5단계 색 농도로 표시해 한 달 러닝 습관을 한눈에 보여준다.
struct MonthlyCalendarHeatmapView: View {
    /// 표시할 달(해당 월의 아무 날짜나 가능, 보통 월 시작일).
    let monthDate: Date
    /// 해당 월의 러닝 기록.
    let workouts: [RunWorkoutSummary]

    private static let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            weekdayHeader
            dayGrid
            legend
        }
        .padding(16)
        .background(RunStampColors.elevatedSurface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(RunStampColors.cardStroke.opacity(0.45), lineWidth: 1))
    }

    // MARK: - 서브뷰

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 7) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(RunStampColors.limeGreen)
                Text("러닝 캘린더")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(RunStampColors.primaryText)
            }

            Spacer()

            Text("\(runDayCount)일 러닝")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(RunStampColors.limeGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RunStampColors.limeGreen.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: Self.columns, spacing: 6) {
            ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(weekdayColor(index))
            }
        }
    }

    private var dayGrid: some View {
        // 빈 칸과 날짜를 하나의 인덱스 시퀀스로 다뤄 ForEach ID 충돌을 막는다.
        LazyVGrid(columns: Self.columns, spacing: 6) {
            ForEach(0..<(leadingBlankCount + dayCount), id: \.self) { index in
                let day = index - leadingBlankCount + 1
                if day >= 1 {
                    dayCell(day)
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let meters = dailyDistance[day] ?? 0
        let level = intensityLevel(for: meters)

        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Self.levelColors[level])
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Text("\(day)")
                    .font(.system(size: 11, weight: level == 0 ? .bold : .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dayTextColor(level: level))
                    .minimumScaleFactor(0.6)
            }
            .overlay {
                if isToday(day) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(RunStampColors.warmYellow, lineWidth: 1.5)
                }
            }
    }

    private var legend: some View {
        HStack(spacing: 5) {
            Spacer()
            Text("적음")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(RunStampColors.tertiaryText)
            ForEach(1..<Self.levelColors.count, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Self.levelColors[level])
                    .frame(width: 12, height: 12)
            }
            Text("많음")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(RunStampColors.tertiaryText)
        }
    }

    // MARK: - 데이터

    /// 일(day) → 그날 총 러닝 거리(미터).
    private var dailyDistance: [Int: Double] {
        var result: [Int: Double] = [:]
        for workout in workouts where calendar.isDate(workout.startDate, equalTo: monthDate, toGranularity: .month) {
            let day = calendar.component(.day, from: workout.startDate)
            result[day, default: 0] += workout.distanceInMeters
        }
        return result
    }

    private var runDayCount: Int {
        dailyDistance.count
    }

    private var dayCount: Int {
        calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
    }

    /// 1일 앞에 채울 빈 칸 수(일요일 시작 기준).
    private var leadingBlankCount: Int {
        let components = calendar.dateComponents([.year, .month], from: monthDate)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        return calendar.component(.weekday, from: firstDay) - 1
    }

    private func isToday(_ day: Int) -> Bool {
        let today = Date()
        return calendar.isDate(today, equalTo: monthDate, toGranularity: .month)
            && calendar.component(.day, from: today) == day
    }

    // MARK: - 색 농도

    /// 러닝 없음(0) → 10km 이상(4)까지 5단계.
    private static let levelColors: [Color] = [
        RunStampColors.surface.opacity(0.85),
        RunStampColors.limeGreen.opacity(0.26),
        RunStampColors.limeGreen.opacity(0.48),
        RunStampColors.limeGreen.opacity(0.72),
        RunStampColors.limeGreen
    ]

    private func intensityLevel(for meters: Double) -> Int {
        switch meters {
        case ..<1:
            return 0
        case ..<3_000:
            return 1
        case ..<6_000:
            return 2
        case ..<10_000:
            return 3
        default:
            return 4
        }
    }

    private func dayTextColor(level: Int) -> Color {
        switch level {
        case 0:
            return RunStampColors.tertiaryText
        case 1:
            return RunStampColors.primaryText
        default:
            return RunStampColors.appBackground
        }
    }

    private func weekdayColor(_ index: Int) -> Color {
        switch index {
        case 0:
            return RunStampColors.redlineRed.opacity(0.75)
        case 6:
            return RunStampColors.electricBlue.opacity(0.85)
        default:
            return RunStampColors.secondaryText
        }
    }
}
