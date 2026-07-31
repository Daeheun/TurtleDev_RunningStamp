import SwiftUI

struct AppLaunchView: View {
    @State private var isShowingHome = false

    var body: some View {
        ZStack {
            if isShowingHome {
                HomeView()
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                RunStampLogoView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .statusBarHidden(!isShowingHome)
        .persistentSystemOverlays(isShowingHome ? .automatic : .hidden)
        .task {
            try? await Task.sleep(nanoseconds: 1_850_000_000)
            withAnimation(.easeInOut(duration: 0.42)) {
                isShowingHome = true
            }
        }
    }
}
