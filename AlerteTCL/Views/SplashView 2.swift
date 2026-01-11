import SwiftUI

struct SplashView: View {
    // Matches ContentView’s usage
    @Binding var isActive: Bool
    @Binding var apiReady: Bool

    var body: some View {
        SplashScreenView(isFinished: $isActive)
            .onChange(of: apiReady) { _, ready in
                if ready {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isActive = false
                    }
                }
            }
    }
}

#Preview {
    SplashView(isActive: .constant(true), apiReady: .constant(false))
}
