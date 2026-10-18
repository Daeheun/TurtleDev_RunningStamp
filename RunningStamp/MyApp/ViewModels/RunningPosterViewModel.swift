import Combine
import SwiftUI
import UIKit

@MainActor
final class RunningPosterViewModel: ObservableObject {
    let healthKitManager = HealthKitManager()
    /// 홈 리스트 행의 러닝 타입을 상세 화면과 같은 분석기로 계산하는 캐시.
    let signatureCache: RunSignatureCache

    @Published var permissionState: HealthKitManager.PermissionState = .notRequested
    @Published var workouts: [RunWorkoutSummary] = []
    @Published var isRequestingPermission = false
    @Published var isLoadingRuns = false
    @Published var message: String?

    init() {
        signatureCache = RunSignatureCache(
            healthKitManager: healthKitManager,
            maxHeartRate: UserProfileStore.shared.resolvedMaxHeartRate
        )
    }

    var isBusy: Bool {
        isRequestingPermission || isLoadingRuns
    }

    var canShowWorkoutPicker: Bool {
        permissionState == .authorized || !workouts.isEmpty
    }

    func requestAuthorizationAndLoadRuns() async {
        await requestAuthorization()
        if permissionState == .authorized {
            await loadRecentRuns()
        }
    }

    func requestAuthorization() async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        permissionState = await healthKitManager.requestAuthorization()
        switch permissionState {
        case .authorized:
            message = AppStrings.Health.authorized
            Analytics.shared.track(.healthAuthorization(result: "granted"))
            // 생년월일 → 나이 → 최대 심박(220 − 나이)로 존 기준을 개인화한다.
            await UserProfileStore.shared.refreshHealthAge(using: healthKitManager)
            signatureCache.updateMaxHeartRate(UserProfileStore.shared.resolvedMaxHeartRate)
        case .unavailable:
            message = AppStrings.Health.dataUnavailable
            Analytics.shared.track(.healthAuthorization(result: "unavailable"))
        case .denied(let reason):
            message = reason
            Analytics.shared.track(.healthAuthorization(result: "denied"))
        case .notRequested:
            message = nil
        }
    }

    func loadRecentRuns() async {
        isLoadingRuns = true
        message = nil
        defer { isLoadingRuns = false }

        do {
            let summaries = try await healthKitManager.fetchRecentRunningWorkouts(limit: 120)
            withAnimation(.easeOut(duration: 0.35)) {
                workouts = summaries
            }

            Analytics.shared.track(.runsLoaded(count: summaries.count))

            if summaries.isEmpty {
                message = AppStrings.Health.noRecentRuns
            } else {
                await hydrateRoutes(for: summaries)
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func hydrateRoutes(for summaries: [RunWorkoutSummary]) async {
        for summary in summaries {
            do {
                let summaryWithRoute = try await healthKitManager.summaryWithRoute(for: summary)
                guard let index = workouts.firstIndex(where: { $0.id == summary.id }) else { continue }
                withAnimation(.easeInOut(duration: 0.28)) {
                    workouts[index] = summaryWithRoute
                }
            } catch {
                continue
            }
        }
    }
}

@MainActor
final class RunDetailViewModel: ObservableObject {
    @Published var workout: RunWorkoutSummary
    @Published var report: RunningPosterReport?
    @Published var isLoading = false
    @Published var statusMessage: String?
    @Published var exportMessage: String?
    @Published var shareImage: UIImage?

    private let healthKitManager: HealthKitManager
    private let analyzer: HeartRateZoneAnalyzer

    init(workout: RunWorkoutSummary, healthKitManager: HealthKitManager) {
        self.workout = workout
        self.healthKitManager = healthKitManager
        // 리스트(RunSignatureCache)와 같은 최대 심박 기준을 써야 러닝 타입이 일치한다.
        let profile = UserProfileStore.shared
        self.analyzer = HeartRateZoneAnalyzer(
            maxHeartRate: profile.resolvedMaxHeartRate,
            distanceUnit: profile.distanceUnit
        )
    }

    func loadReport() async {
        guard report == nil else { return }
        isLoading = true
        defer { isLoading = false }

        var reportWorkout = workout
        var routeMessage: String?

        do {
            reportWorkout = try await healthKitManager.summaryWithRoute(for: workout)
            workout = reportWorkout
            if reportWorkout.isIndoorRunning {
                routeMessage = AppStrings.Report.indoorRoute
            } else if reportWorkout.routeLocations.isEmpty {
                routeMessage = AppStrings.Report.noRoute
            }
        } catch {
            routeMessage = AppStrings.Report.routeLoadFailed
        }

        do {
            let samples = try await healthKitManager.fetchHeartRateSamples(for: workout)

            if let realReport = analyzer.makeReport(for: reportWorkout, heartRateSamples: samples) {
                report = realReport
                let routeCount = reportWorkout.routeLocations.count
                let routeText = routeCount > 0 ? AppStrings.Report.routeCoordinates(routeCount) : (routeMessage ?? "")
                statusMessage = [AppStrings.Report.analyzedSamples(samples.count), routeText].filter { !$0.isEmpty }.joined(separator: " ")
            } else {
                // 심박 샘플이 없으면 가짜 샘플 대신 실제 거리·페이스만 담은 라이트 포스터를 만든다.
                report = analyzer.makeLightReport(for: reportWorkout)
                statusMessage = AppStrings.Report.lightPosterNoSamples
            }
        } catch {
            report = analyzer.makeLightReport(for: reportWorkout)
            statusMessage = AppStrings.Report.lightPosterAfterError(error.localizedDescription)
        }

        if let report {
            Analytics.shared.track(.runOpened(hasHeartRate: report.hasHeartRateData, isIndoor: reportWorkout.isIndoorRunning))
        }
    }

    /// PRO 잠금 안내를 띄우고 어떤 기능에서 막혔는지 기록한다(페이월 설계용 신호).
    func showProLocked(_ message: String, feature: String) {
        exportMessage = message
        Analytics.shared.track(.proFeatureLocked(feature: feature))
    }

    func exportPoster(format: PosterFormat = .feed, highlightStamp: HighlightStamp = .clean, contentHighlight: ContentHighlightTarget? = nil, layout: PosterLayout = .default) {
        guard let report else {
            exportMessage = AppStrings.Export.noPoster
            return
        }

        guard let image = PosterExportHelper.renderPoster(report: report, format: format, highlightStamp: highlightStamp, contentHighlight: contentHighlight, layout: layout) else {
            exportMessage = AppStrings.Export.renderFailed
            return
        }

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        exportMessage = AppStrings.Export.saved
        Analytics.shared.track(.posterSaved(format: format, hasHeartRate: report.hasHeartRateData))
    }

    func prepareShareImage(format: PosterFormat = .feed, highlightStamp: HighlightStamp = .clean, contentHighlight: ContentHighlightTarget? = nil, layout: PosterLayout = .default) {
        guard let report else {
            exportMessage = AppStrings.Export.noPoster
            return
        }

        shareImage = PosterExportHelper.renderPoster(report: report, format: format, highlightStamp: highlightStamp, contentHighlight: contentHighlight, layout: layout)
        if shareImage == nil {
            exportMessage = AppStrings.Export.shareRenderFailed
        } else {
            Analytics.shared.track(.posterShared(format: format, hasHeartRate: report.hasHeartRateData))
        }
    }

    /// 스토리(9:16) 포스터를 렌더링해 인스타그램 스토리로 바로 공유한다.
    /// 인스타그램이 없거나 열기에 실패하면 시스템 공유 시트로 대체한다.
    func shareToInstagramStories(highlightStamp: HighlightStamp = .clean, contentHighlight: ContentHighlightTarget? = nil, layout: PosterLayout = .default) {
        guard let report else {
            exportMessage = AppStrings.Export.noPoster
            return
        }

        guard let image = PosterExportHelper.renderPoster(report: report, format: .story, highlightStamp: highlightStamp, contentHighlight: contentHighlight, layout: layout) else {
            exportMessage = AppStrings.Export.shareRenderFailed
            return
        }

        InstagramStoryService.shareToStories(backgroundImage: image) { [weak self] success in
            Analytics.shared.track(.instagramStoryShare(opened: success))
            guard let self, !success else { return }
            self.shareImage = image
        }
    }
}
