import SwiftUI

struct SplashScreenView: View {
    @Binding var isFinished: Bool
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 16) {
                Spacer()
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                
                Text("Alerte TCL")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(.bottom, 40)
            }
        }
        .task {
            // Optional auto-dismiss if ContentView doesn't dismiss it earlier
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            // Do not force-finish if ContentView will handle it after API load; keep as a fallback.
            if isFinished {
                withAnimation(.easeOut(duration: 0.3)) {
                    isFinished = false
                }
            }
        }
        .onTapGesture {
            // Allow user to skip splash if needed
            withAnimation(.easeOut(duration: 0.3)) {
                isFinished = false
            }
        }
    }
}

#Preview {
    SplashScreenView(isFinished: .constant(true))
}
