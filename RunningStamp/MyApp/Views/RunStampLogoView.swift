import SwiftUI

struct RunStampLogoView: View {
    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.10)
                .ignoresSafeArea()

            Image("RunStampSplash")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}
