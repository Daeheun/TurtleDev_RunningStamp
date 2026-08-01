import Combine
import SwiftUI
import UIKit

@MainActor
final class RunningPosterViewModel: ObservableObject {
    let healthKitManager = HealthKitManager()

    @Published var permissionState: HealthKitManager.PermissionState = .notRequested
    @Published var workouts: [RunWorkoutSummary] = []
    @Published var isRequestingPermission = false
    @Published var isLoadingRuns = false
    @Published var message: String?

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
            message = "Apple Health에서 최근 러닝 운동을 불러올 수 있습니다."
        case .unavailable:
            message = "이 기기에서는 HealthKit을 사용할 수 없습니다."
        case .denied(let reason):
            message = reason
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

            if summaries.isEmpty {
                message = "최근 Apple Watch 러닝 기록을 찾지 못했습니다."
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
    private let analyzer = HeartRateZoneAnalyzer()

    init(workout: RunWorkoutSummary, healthKitManager: HealthKitManager) {
        self.workout = workout
        self.healthKitManager = healthKitManager
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
                routeMessage = "실내 러닝이라 GPS 경로 대신 실내 Effort Wave를 표시합니다."
            } else if reportWorkout.routeLocations.isEmpty {
                routeMessage = "경로 데이터가 없어 포스터에는 Effort Wave를 표시합니다."
            }
        } catch {
            routeMessage = "경로 데이터는 불러오지 못했지만 심박 분석은 계속합니다."
        }

        do {
            let samples = try await healthKitManager.fetchHeartRateSamples(for: workout)

            if let realReport = analyzer.makeReport(for: reportWorkout, heartRateSamples: samples) {
                report = realReport
                let routeCount = reportWorkout.routeLocations.count
                let routeText = routeCount > 0 ? " 경로 좌표 \(routeCount)개를 반영했습니다." : " \(routeMessage ?? "")"
                statusMessage = "실제 HealthKit 심박 샘플 \(samples.count)개를 분석했습니다." + routeText
            } else {
                report = analyzer.sampleReport()
                statusMessage = "선택한 운동 시간 범위에서 사용 가능한 심박 샘플이 0개입니다. Apple Health 권한에서 심박수 접근이 허용되어 있는지 확인해 주세요."
            }
        } catch {
            report = analyzer.sampleReport()
            statusMessage = "심박 데이터를 불러오지 못해 Sample Data Mode로 표시합니다. \(error.localizedDescription)"
        }
    }

    func exportPoster(template: PosterTemplate = .zone, format: PosterFormat = .feed, highlightStamp: HighlightStamp = .clean, contentHighlight: ContentHighlightTarget? = nil) {
        guard let report else {
            exportMessage = "아직 생성된 포스터가 없습니다."
            return
        }

        guard let image = PosterExportHelper.renderPoster(template: template, report: report, workout: workout, format: format, highlightStamp: highlightStamp, contentHighlight: contentHighlight) else {
            exportMessage = "포스터 이미지를 생성하지 못했습니다."
            return
        }

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        exportMessage = "포스터 이미지를 사진 보관함에 저장했습니다."
    }

    func prepareShareImage(template: PosterTemplate = .zone, format: PosterFormat = .feed, highlightStamp: HighlightStamp = .clean, contentHighlight: ContentHighlightTarget? = nil) {
        guard let report else {
            exportMessage = "아직 생성된 포스터가 없습니다."
            return
        }

        shareImage = PosterExportHelper.renderPoster(template: template, report: report, workout: workout, format: format, highlightStamp: highlightStamp, contentHighlight: contentHighlight)
        if shareImage == nil {
            exportMessage = "공유할 포스터 이미지를 생성하지 못했습니다."
        }
    }

    /// 스토리(9:16) 포스터를 렌더링해 인스타그램 스토리로 바로 공유한다.
    /// 인스타그램이 없거나 열기에 실패하면 시스템 공유 시트로 대체한다.
    func shareToInstagramStories(template: PosterTemplate = .zone, highlightStamp: HighlightStamp = .clean, contentHighlight: ContentHighlightTarget? = nil) {
        guard let report else {
            exportMessage = "아직 생성된 포스터가 없습니다."
            return
        }

        guard let image = PosterExportHelper.renderPoster(template: template, report: report, workout: workout, format: .story, highlightStamp: highlightStamp, contentHighlight: contentHighlight) else {
            exportMessage = "공유할 포스터 이미지를 생성하지 못했습니다."
            return
        }

        InstagramStoryService.shareToStories(backgroundImage: image) { [weak self] success in
            guard let self, !success else { return }
            self.shareImage = image
        }
    }
}
