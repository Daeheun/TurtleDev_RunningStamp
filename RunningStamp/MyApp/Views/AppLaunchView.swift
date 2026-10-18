import SwiftUI

struct AppLaunchView: View {
    private enum Stage {
        case splash
        case onboarding
        case home
    }

    @ObservedObject private var preferences = AppPreferences.shared
    @State private var stage: Stage = .splash
    /// 온보딩에서 "나중에"를 고르면 홈이 자동으로 HealthKit 권한을 요청하지 않는다.
    @State private var autoRequestsHealthAccess = true

    var body: some View {
        ZStack {
            switch stage {
            case .splash:
                RunStampLogoView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            case .onboarding:
                OnboardingView(onFinish: finishOnboarding)
                    .transition(.opacity)
            case .home:
                HomeView(autoRequestsHealthAccess: autoRequestsHealthAccess)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .statusBarHidden(stage == .splash)
        .persistentSystemOverlays(stage == .splash ? .hidden : .automatic)
        .task {
            try? await Task.sleep(nanoseconds: 1_850_000_000)
            withAnimation(.easeInOut(duration: 0.42)) {
                stage = preferences.hasCompletedOnboarding ? .home : .onboarding
            }
        }
    }

    private func finishOnboarding(connectsHealth: Bool) {
        preferences.hasCompletedOnboarding = true
        autoRequestsHealthAccess = connectsHealth
        Analytics.shared.track(.onboardingCompleted(connectsHealth: connectsHealth))
        withAnimation(.easeInOut(duration: 0.35)) {
            stage = .home
        }
    }
}
