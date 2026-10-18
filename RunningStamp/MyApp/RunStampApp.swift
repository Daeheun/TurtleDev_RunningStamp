import SwiftUI

@main
struct RunStampApp: App {
    init() {
        // 알림 탭으로 콜드 스타트하는 경우를 놓치지 않도록 launch 시점에 델리게이트를 연결한다.
        AutoPosterService.shared.configureOnLaunch()
        Analytics.shared.track(.appLaunched)
    }

    var body: some Scene {
        WindowGroup {
            AppLaunchView()
        }
    }
}
