import Foundation

struct EffortSignatureAnalyzer {
    private enum Threshold {
        static let controlledBaseZone2 = 55.0
        static let controlledBaseEasy = 75.0
        static let recoveryEasy = 80.0
        static let recoveryHardCap = 10.0
        static let steadyBuilderZ2Z3 = 65.0
        static let tempoZ3Z4 = 55.0
        static let tempoZone5Cap = 20.0
        static let redlineZone5 = 15.0
        static let redlineHard = 50.0
        static let progressiveBPMGain = 8.0
        static let earlyRedlineBPM = 158.0
    }

    func analyze(
        zoneResults: [HeartRateZoneResult],
        heartRateTimeline: [HeartRateSamplePoint],
        workoutDuration: TimeInterval
    ) -> EffortSignature {
        let z1 = percentage(for: 1, in: zoneResults)
        let z2 = percentage(for: 2, in: zoneResults)
        let z3 = percentage(for: 3, in: zoneResults)
        let z4 = percentage(for: 4, in: zoneResults)
        let z5 = percentage(for: 5, in: zoneResults)
        let easy = z1 + z2
        let aerobicWork = z2 + z3
        let tempoWork = z3 + z4
        let hard = z4 + z5
        let dominantZone = zoneResults.max { $0.percentage < $1.percentage }?.zone
        let progression = heartRateProgression(
            timeline: heartRateTimeline,
            workoutDuration: workoutDuration
        )

        // Strong high-intensity distribution is its own positive stimulus, not a failure.
        if z5 >= Threshold.redlineZone5 || hard >= Threshold.redlineHard {
            return redlinePush(hardPercentage: hard)
        }

        // Progressive runs should show a clear late lift, but not simply be hard from the start.
        if progression.isProgressive && !progression.startedVeryHard {
            return progressiveBurn(hardPercentage: hard)
        }

        // Very easy distribution with little high-zone time is recovery-oriented work.
        if easy >= Threshold.recoveryEasy && hard <= Threshold.recoveryHardCap {
            return recoveryFlow(easyPercentage: easy)
        }

        // Low-intensity control gets recognized without requiring a perfect Zone 2 session.
        if z2 >= Threshold.controlledBaseZone2 || easy >= Threshold.controlledBaseEasy {
            return controlledBase(easyPercentage: easy, zone2Percentage: z2)
        }

        // Sustained upper-aerobic work maps to a tempo-like signature.
        if tempoWork >= Threshold.tempoZ3Z4 && z5 < Threshold.tempoZone5Cap {
            return tempoEngine(tempoPercentage: tempoWork)
        }

        // Zone 3-dominant or Z2/Z3-heavy runs build steady endurance.
        if dominantZone == 3 || aerobicWork >= Threshold.steadyBuilderZ2Z3 {
            return steadyBuilder(aerobicPercentage: aerobicWork)
        }

        return mixedMiles(dominantZone: dominantZone, zoneResults: zoneResults)
    }

    private func heartRateProgression(
        timeline: [HeartRateSamplePoint],
        workoutDuration: TimeInterval
    ) -> (firstAverage: Double?, finalAverage: Double?, isProgressive: Bool, startedVeryHard: Bool) {
        guard let firstDate = timeline.first?.date, workoutDuration > 0 else {
            return (nil, nil, false, false)
        }

        let firstEnd = firstDate.addingTimeInterval(workoutDuration / 3)
        let finalStart = firstDate.addingTimeInterval(workoutDuration * 2 / 3)
        let middleStart = firstEnd
        let middleEnd = finalStart

        let firstAverage = averageBPM(in: timeline.filter { $0.date <= firstEnd })
        let middleAverage = averageBPM(in: timeline.filter { $0.date >= middleStart && $0.date <= middleEnd })
        let finalAverage = averageBPM(in: timeline.filter { $0.date >= finalStart })

        guard let firstAverage, let finalAverage else {
            return (firstAverage, finalAverage, false, false)
        }

        let middleIsNotDropping = middleAverage.map { $0 >= firstAverage - 2 } ?? true
        let finalLift = finalAverage - firstAverage >= Threshold.progressiveBPMGain
        let finalAboveMiddle = middleAverage.map { finalAverage >= $0 } ?? true
        let startedVeryHard = firstAverage >= Threshold.earlyRedlineBPM

        return (
            firstAverage,
            finalAverage,
            finalLift && middleIsNotDropping && finalAboveMiddle,
            startedVeryHard
        )
    }

    private func averageBPM(in points: [HeartRateSamplePoint]) -> Double? {
        guard !points.isEmpty else { return nil }
        return points.map(\.bpm).reduce(0, +) / Double(points.count)
    }

    private func percentage(for zone: Int, in results: [HeartRateZoneResult]) -> Double {
        results.first(where: { $0.zone == zone })?.percentage ?? 0
    }

    private func controlledBase(easyPercentage: Double, zone2Percentage: Double) -> EffortSignature {
        EffortSignature(
            title: "CONTROLLED BASE",
            subtitle: "Aerobic foundation",
            emoji: "🟢",
            primaryMetricText: "Z1-Z2 \(Int(easyPercentage.rounded()))%",
            secondaryMetricText: "Recovery Need: Low",
            recoveryNeed: .low,
            koreanInsight: "낮은 강도를 안정적으로 유지한 베이스 러닝입니다. 오래 달릴 수 있는 기반을 쌓은 좋은 세션이에요."
        )
    }

    private func recoveryFlow(easyPercentage: Double) -> EffortSignature {
        EffortSignature(
            title: "RECOVERY FLOW",
            subtitle: "Easy miles",
            emoji: "🌿",
            primaryMetricText: "Z1-Z2 \(Int(easyPercentage.rounded()))%",
            secondaryMetricText: "Recovery Need: Low",
            recoveryNeed: .low,
            koreanInsight: "회복과 컨디션 유지에 좋은 저강도 러닝입니다. 무리하지 않고 몸을 잘 풀어낸 세션이에요."
        )
    }

    private func steadyBuilder(aerobicPercentage: Double) -> EffortSignature {
        EffortSignature(
            title: "STEADY BUILDER",
            subtitle: "Solid aerobic work",
            emoji: "🔵",
            primaryMetricText: "Z2-Z3 \(Int(aerobicPercentage.rounded()))%",
            secondaryMetricText: "Recovery Need: Medium",
            recoveryNeed: .medium,
            koreanInsight: "중강도 영역에서 꾸준히 밀어붙인 러닝입니다. 지구력과 페이스 유지력을 함께 쌓은 세션이에요."
        )
    }

    private func tempoEngine(tempoPercentage: Double) -> EffortSignature {
        EffortSignature(
            title: "TEMPO ENGINE",
            subtitle: "Strong sustained effort",
            emoji: "🟠",
            primaryMetricText: "Z3-Z4 \(Int(tempoPercentage.rounded()))%",
            secondaryMetricText: "Recovery Need: Medium",
            recoveryNeed: .medium,
            koreanInsight: "강한 페이스를 일정하게 유지한 템포성 러닝입니다. 심폐 지구력과 페이스 감각을 자극한 세션이에요."
        )
    }

    private func redlinePush(hardPercentage: Double) -> EffortSignature {
        EffortSignature(
            title: "REDLINE PUSH",
            subtitle: "High intensity stimulus",
            emoji: "🔴",
            primaryMetricText: "Z4-Z5 \(Int(hardPercentage.rounded()))%",
            secondaryMetricText: "Recovery Need: High",
            recoveryNeed: .high,
            koreanInsight: "최대 심박에 가까운 고강도 자극이 포함된 러닝입니다. 강한 세션이었으니 충분한 회복을 가져가세요."
        )
    }

    private func progressiveBurn(hardPercentage: Double) -> EffortSignature {
        let recoveryNeed: RecoveryNeed = hardPercentage >= 35 ? .high : .medium
        return EffortSignature(
            title: "PROGRESSIVE BURN",
            subtitle: "Strong finish",
            emoji: "⚡️",
            primaryMetricText: "Late HR +8 BPM",
            secondaryMetricText: "Recovery Need: \(recoveryNeed.displayText)",
            recoveryNeed: recoveryNeed,
            koreanInsight: "후반으로 갈수록 강도가 올라간 프로그레시브 러닝입니다. 마지막까지 힘을 끌어올린 좋은 마무리였어요."
        )
    }

    private func mixedMiles(dominantZone: Int?, zoneResults: [HeartRateZoneResult]) -> EffortSignature {
        let dominant = dominantZone.map { "Z\($0)" } ?? "Mixed"
        let percentage = dominantZone.flatMap { zone in
            zoneResults.first(where: { $0.zone == zone })?.percentage
        } ?? 0

        return EffortSignature(
            title: "MIXED MILES",
            subtitle: "Varied effort",
            emoji: "⚪️",
            primaryMetricText: "\(dominant) \(Int(percentage.rounded()))%",
            secondaryMetricText: "Recovery Need: Medium",
            recoveryNeed: .medium,
            koreanInsight: "여러 강도가 섞인 자유 러닝에 가까웠습니다. 컨디션, 코스, 페이스 변화가 함께 반영된 세션이에요."
        )
    }
}
