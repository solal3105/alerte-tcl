import SwiftUI

struct MagnificentSplashView: View {
    @Binding var isActive: Bool
    @Binding var apiReady: Bool
    
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.95
    @State private var didScheduleFallback = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 120, height: 120)
                        .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                    
                    Image(systemName: "tram.fill")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                        scale = 1.0
                    }
                }
                
                Text("Alerte TCL")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Chargement…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(opacity)
        }
        .onChange(of: apiReady) { _, ready in
            if ready {
                dismissSplash()
            } else {
                scheduleFallbackDismiss()
            }
        }
        .onAppear {
            // If API is already ready, dismiss immediately
            if apiReady {
                dismissSplash()
            } else {
                scheduleFallbackDismiss()
            }
        }
    }
    
    private func scheduleFallbackDismiss() {
        guard !didScheduleFallback else { return }
        didScheduleFallback = true
        // Fallback auto-dismiss after 2 seconds to avoid blocking UI if API is slow
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !apiReady {
                dismissSplash()
            }
        }
    }
    
    private func dismissSplash() {
        withAnimation(.easeInOut(duration: 0.35)) {
            opacity = 0.0
        }
        // Slight delay to let the fade animation play before removing the view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isActive = false
        }
    }
}

#Preview {
    MagnificentSplashView(isActive: .constant(true), apiReady: .constant(false))
}
