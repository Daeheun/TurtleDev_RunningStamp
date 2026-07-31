import Foundation

struct HeartRateZoneAnalyzer {
    var age: Int = 35
    var zoneBoundaries: [HeartRateZoneBoundary] = HeartRateZoneAnalyzer.defaultZoneBoundaries
    var maxSampleGap: TimeInterval = 120
    var fallbackLastSampleInterval: TimeInterval = 30
    private let effortSignatureAnalyzer = EffortSignatureAnalyzer()

    static let defaultZoneBoundaries: [HeartRateZoneBoundary] = [
        HeartRateZoneBoundary(id: 1, name: "Zone 1", minRatio: 0.50, maxRatio: 0.60),
        HeartRateZoneBoundary(id: 2, name: "Zone 2", minRatio: 0.60, maxRatio: 0.70),
        HeartRateZoneBoundary(id: 3, name: "Zone 3", minRatio: 0.70, maxRatio: 0.80),
        HeartRateZoneBoundary(id: 4, name: "Zone 4", minRatio: 0.80, maxRatio: 0.90),
        HeartRateZoneBoundary(id: 5, name: "Zone 5", minRatio: 0.90, maxRatio: nil)
    ]

    var estimatedMaxHeartRate: Double {
        Double(220 - age)
    }

    func makeReport(for workout: RunWorkoutSummary, heartRateSamples: [HeartRateSamplePoint]) -> RunningPosterReport? {
        let cleanedSamples = heartRateSamples
            .filter { $0.bpm.isFinite && $0.bpm > 30 && $0.bpm < 240 }
            .sorted { $0.date < $1.date }

        guard !cleanedSamples.isEmpty else { return nil }

        let zoneResults = calculateZoneResults(
            samples: cleanedSamples,
            workoutStart: workout.startDate,
            workoutEnd: workout.endDate
        )
        let zone2Percentage = zoneResults.first(where: { $0.zone == 2 })?.percentage ?? 0
        let effortSignature = effortSignatureAnalyzer.analyze(
            zoneResults: zoneResults,
            heartRateTimeline: cleanedSamples,
            workoutDuration: workout.duration
        )
        let title = posterTitle(for: effortSignature, zone2Percentage: zone2Percentage)
        let avgHeartRate = workout.averageHeartRate ?? averageHeartRate(from: cleanedSamples)
        let maxHeartRate = cleanedSamples.map(\.bpm).max()

        let dominantZone = zoneResults.max { $0.percentage < $1.percentage }
        return RunningPosterReport(
            title: title,
            subtitle: posterSubtitle(for: effortSignature, title: title),
            dateText: RunFormatters.posterDate(workout.startDate),
            distanceText: RunFormatters.distanceNumberKm(workout.distanceInMeters),
            durationText: RunFormatters.duration(workout.duration),
            avgPaceText: RunFormatters.paceCompact(workout.averagePaceSecondsPerKm),
            avgHRText: RunFormatters.number(avgHeartRate),
            maxHRText: RunFormatters.number(maxHeartRate),
            caloriesText: RunFormatters.number(workout.activeCalories),
            zoneResults: zoneResults,
            dominantZone: dominantZone,
            zone2Percentage: zone2Percentage,
            runType: effortSignature.title,
            insightText: effortSignature.koreanInsight,
            heartRateTimeline: cleanedSamples,
            effortSignature: effortSignature,
            routeLocations: workout.routeLocations,
            isIndoorRunning: workout.isIndoorRunning,
            avgSpeedText: averageSpeedText(distanceMeters: workout.distanceInMeters, duration: workout.duration),
            paceConsistencyText: nil,
            hrDriftText: heartRateDriftText(samples: cleanedSamples, startDate: workout.startDate, endDate: workout.endDate),
            dominantZoneText: dominantZone.map { "Z\($0.zone) \(Int($0.percentage.rounded()))%" } ?? "--"
        )
    }

    func calculateZoneResults(
        samples: [HeartRateSamplePoint],
        workoutStart: Date,
        workoutEnd: Date
    ) -> [HeartRateZoneResult] {
        let sortedSamples = samples.sorted { $0.date < $1.date }
        var durationsByZone = Dictionary(uniqueKeysWithValues: zoneBoundaries.map { ($0.id, TimeInterval.zero) })

        for index in sortedSamples.indices {
            let sample = sortedSamples[index]
            let intervalEnd: Date
            if index < sortedSamples.index(before: sortedSamples.endIndex) {
                intervalEnd = min(sortedSamples[sortedSamples.index(after: index)].date, workoutEnd)
            } else {
                intervalEnd = min(sample.date.addingTimeInterval(fallbackLastSampleInterval), workoutEnd)
            }

            let intervalStart = max(sample.date, workoutStart)
            let rawInterval = intervalEnd.timeIntervalSince(intervalStart)
            guard rawInterval > 0 else { continue }

            let interval = min(rawInterval, maxSampleGap)
            let zone = zoneID(for: sample.bpm)
            durationsByZone[zone, default: 0] += interval
        }

        let assignedDuration = max(durationsByZone.values.reduce(0, +), 1)
        return zoneBoundaries.map { boundary in
            let duration = durationsByZone[boundary.id, default: 0]
            return HeartRateZoneResult(
                zone: boundary.id,
                name: boundary.name,
                minBPM: boundary.minRatio * estimatedMaxHeartRate,
                maxBPM: boundary.maxRatio.map { $0 * estimatedMaxHeartRate },
                duration: duration,
                percentage: duration / assignedDuration * 100
            )
        }
    }

    func zoneID(for bpm: Double) -> Int {
        for boundary in zoneBoundaries {
            let minBPM = boundary.minRatio * estimatedMaxHeartRate
            let maxBPM = boundary.maxRatio.map { $0 * estimatedMaxHeartRate } ?? Double.infinity
            if bpm >= minBPM && bpm < maxBPM {
                return boundary.id
            }
        }

        return bpm < zoneBoundaries[0].minRatio * estimatedMaxHeartRate ? 1 : 5
    }

    func averageHeartRate(from samples: [HeartRateSamplePoint]) -> Double? {
        guard !samples.isEmpty else { return nil }
        return samples.map(\.bpm).reduce(0, +) / Double(samples.count)
    }

    private func averageSpeedText(distanceMeters: Double, duration: TimeInterval) -> String {
        let hours = duration / 3_600
        guard distanceMeters > 0, hours > 0 else { return "-- KM/H" }
        return String(format: "%.1f KM/H", distanceMeters / 1_000 / hours)
    }

    private func heartRateDriftText(samples: [HeartRateSamplePoint], startDate: Date, endDate: Date) -> String {
        let duration = endDate.timeIntervalSince(startDate)
        guard duration > 0 else { return "-- BPM" }

        let firstEnd = startDate.addingTimeInterval(duration / 3)
        let finalStart = startDate.addingTimeInterval(duration * 2 / 3)
        let firstSamples = samples.filter { $0.date >= startDate && $0.date <= firstEnd }
        let finalSamples = samples.filter { $0.date >= finalStart && $0.date <= endDate }
        guard let firstAverage = averageHeartRate(from: firstSamples),
              let finalAverage = averageHeartRate(from: finalSamples) else {
            return "-- BPM"
        }

        let drift = finalAverage - firstAverage
        return String(format: "%+.0f BPM", drift)
    }

    func sampleReport() -> RunningPosterReport {
        sampleReports()[0]
    }

    func sampleReports() -> [RunningPosterReport] {
        [
            makeSampleReport(kind: .controlledBase),
            makeSampleReport(kind: .tempoEngine),
            makeSampleReport(kind: .redlinePush)
        ].compactMap { $0 }
    }

    private func posterTitle(for signature: EffortSignature, zone2Percentage: Double) -> String {
        switch signature.title {
        case "CONTROLLED BASE":
            return zone2Percentage >= 55 ? "ZONE 2 CLUB" : "CONTROLLED BASE"
        case "RECOVERY FLOW":
            return "EASY MILES"
        default:
            return signature.title
        }
    }

    private func posterSubtitle(for signature: EffortSignature, title: String) -> String {
        if title == "ZONE 2 CLUB" {
            return "SLOW IS SMOOTH. SMOOTH IS FAST."
        }

        return signature.subtitle.uppercased()
    }

    private enum SampleKind {
        case controlledBase
        case tempoEngine
        case redlinePush
    }

    private func makeSampleReport(kind: SampleKind) -> RunningPosterReport? {
        let start = Date().addingTimeInterval(-3_200)
        let duration: TimeInterval = 3_204
        let distance = 10_010.0
        let points = sampleHeartRatePoints(kind: kind, start: start, duration: duration)
        let workout = RunWorkoutSummary(
            id: UUID(),
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            duration: duration,
            distanceInMeters: distance,
            activeCalories: sampleCalories(for: kind),
            averagePaceSecondsPerKm: duration / (distance / 1_000),
            averageHeartRate: averageHeartRate(from: points),
            averageRunningPower: nil,
            averageCadence: nil
        )

        guard let report = makeReport(for: workout, heartRateSamples: points) else { return nil }
        return RunningPosterReport(
            id: report.id,
            isSampleData: true,
            title: report.title,
            subtitle: report.subtitle,
            dateText: report.dateText,
            distanceText: report.distanceText,
            durationText: report.durationText,
            avgPaceText: report.avgPaceText,
            avgHRText: report.avgHRText,
            maxHRText: report.maxHRText,
            caloriesText: report.caloriesText,
            zoneResults: report.zoneResults,
            dominantZone: report.dominantZone,
            zone2Percentage: report.zone2Percentage,
            runType: report.runType,
            insightText: report.insightText,
            heartRateTimeline: report.heartRateTimeline,
            effortSignature: report.effortSignature,
            routeLocations: report.routeLocations,
            isIndoorRunning: report.isIndoorRunning,
            avgSpeedText: report.avgSpeedText,
            paceConsistencyText: report.paceConsistencyText,
            hrDriftText: report.hrDriftText,
            dominantZoneText: report.dominantZoneText
        )
    }

    private func sampleHeartRatePoints(kind: SampleKind, start: Date, duration: TimeInterval) -> [HeartRateSamplePoint] {
        stride(from: 0, through: Int(duration), by: 40).map { second in
            let progress = Double(second) / duration
            let wave = sin(progress * .pi * 6) * 4
            let bpm: Double

            switch kind {
            case .controlledBase:
                bpm = 120 + wave + min(progress * 8, 8)
            case .tempoEngine:
                bpm = 138 + wave + min(progress * 12, 12)
            case .redlinePush:
                bpm = 158 + wave + min(progress * 18, 18)
            }

            return HeartRateSamplePoint(
                date: start.addingTimeInterval(TimeInterval(second)),
                bpm: bpm
            )
        }
    }

    private func sampleCalories(for kind: SampleKind) -> Double {
        switch kind {
        case .controlledBase: return 620
        case .tempoEngine: return 710
        case .redlinePush: return 790
        }
    }
}
