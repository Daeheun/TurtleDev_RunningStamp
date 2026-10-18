import Combine
import HealthKit
import SwiftUI
import UserNotifications

/// 러닝 종료를 백그라운드에서 감지해 "포스터 준비" 로컬 알림을 보내고,
/// 알림 탭 시 해당 러닝의 상세 화면으로 딥링크하는 서비스.
///
/// 동작 흐름:
/// 1. HealthKit 권한 획득 후 `enableIfNeeded()` — 알림 권한 요청 + 백그라운드 전달 등록.
/// 2. Apple Watch 러닝이 iPhone 건강 앱에 동기화되면 HKObserverQuery가 앱을 깨운다.
/// 3. 기준 시각 이후 종료된 새 러닝이 있으면 로컬 알림 1건 발송(러닝당 1회).
/// 4. 알림 탭 → `pendingWorkoutID` 설정 → HomeView가 해당 러닝 상세로 이동.
@MainActor
final class AutoPosterService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = AutoPosterService()

    /// 알림을 탭해 열어야 할 러닝의 HealthKit UUID. HomeView가 관찰해 딥링크한다.
    @Published var pendingWorkoutID: UUID?

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?

    private static let enabledKey = "auto_poster_enabled"
    private static let lastEndDateKey = "auto_poster_last_notified_end_date"
    private static let workoutIDKey = "workoutID"

    private override init() {
        super.init()
    }

    /// 앱 시작 시 항상 호출한다. 알림 델리게이트를 연결하고,
    /// 이전에 활성화된 상태라면 감시를 재개한다. 백그라운드 전달로 앱이
    /// 깨어난 경우에도 이 경로로 옵저버가 복구되어 알림이 발송된다.
    func configureOnLaunch() {
        UNUserNotificationCenter.current().delegate = self
        if UserDefaults.standard.bool(forKey: Self.enabledKey) {
            startObserving()
        }
    }

    /// HealthKit 권한 획득 직후 호출한다. 최초 1회 알림 권한을 요청하고
    /// 백그라운드 전달 + 옵저버를 등록한다. 이미 활성화됐다면 감시만 재개한다.
    func enableIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.enabledKey) else {
            startObserving()
            return
        }

        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }

        // 과거 러닝에 대한 소급 알림을 막기 위해 기준 시각을 지금으로 잡는다.
        if defaults.object(forKey: Self.lastEndDateKey) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: Self.lastEndDateKey)
        }
        defaults.set(true, forKey: Self.enabledKey)

        do {
            try await healthStore.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate)
        } catch {
            // 백그라운드 전달 등록에 실패해도 앱 실행 중 감시는 계속 동작한다.
        }
        startObserving()
    }

    private func startObserving() {
        guard observerQuery == nil else { return }

        let query = HKObserverQuery(
            sampleType: .workoutType(),
            predicate: HKQuery.predicateForWorkouts(with: .running)
        ) { _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            Task { @MainActor in
                await AutoPosterService.shared.notifyLatestRunIfNeeded()
                // 처리 완료를 알려야 iOS가 백그라운드 전달 예산을 유지해 준다.
                completionHandler()
            }
        }
        observerQuery = query
        healthStore.execute(query)
    }

    /// 기준 시각 이후 종료된 최신 러닝을 찾아 알림을 1건 예약하고 기준 시각을 갱신한다.
    private func notifyLatestRunIfNeeded() async {
        let defaults = UserDefaults.standard
        let lastEnd = Date(timeIntervalSince1970: defaults.double(forKey: Self.lastEndDateKey))

        guard let workout = await fetchLatestRun(endingAfter: lastEnd) else { return }

        defaults.set(workout.endDate.timeIntervalSince1970, forKey: Self.lastEndDateKey)

        let kilometers = (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1_000
        let content = UNMutableNotificationContent()
        content.title = "오늘의 러닝 포스터가 준비됐어요 🔥"
        content.body = kilometers > 0
            ? String(format: "%.2fkm 완주! 탭해서 포스터를 확인하고 공유해 보세요.", kilometers)
            : "탭해서 포스터를 확인하고 공유해 보세요."
        content.sound = .default
        content.userInfo = [Self.workoutIDKey: workout.uuid.uuidString]

        let request = UNNotificationRequest(
            identifier: "auto-poster-\(workout.uuid.uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func fetchLatestRun(endingAfter date: Date) async -> HKWorkout? {
        await withCheckedContinuation { continuation in
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                HKQuery.predicateForWorkouts(with: .running),
                HKQuery.predicateForSamples(withStart: date, end: nil, options: .strictEndDate)
            ])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let workout = (samples as? [HKWorkout])?.first { $0.endDate > date }
                continuation.resume(returning: workout)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 앱이 포그라운드일 때도 배너로 표시한다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let idString = response.notification.request.content.userInfo[Self.workoutIDKey] as? String,
              let id = UUID(uuidString: idString) else {
            return
        }
        pendingWorkoutID = id
    }
}
