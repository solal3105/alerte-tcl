import SwiftUI

struct AmazingSplashView: View {
    @Binding var isActive: Bool
    @Binding var uiReady: Bool
    @State private var logoScale: CGFloat = 0.95
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var minimumAnimationDone = false
    
    var body: some View {
        ZStack {
            // Fond blanc pur (ou adaptatif selon le mode)
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Logo simple et épuré
                ZStack {
                    // Cercle de fond avec couleur de la ligne (bleu TCL)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 80, height: 80)
                    
                    // Icône tram simple
                    Image(systemName: "tram.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                // Nom de l'app simple
                Text("AlerteTCL")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .opacity(textOpacity)
                
                Spacer()
                
                // Indicateur de chargement minimaliste
                ProgressView()
                    .tint(.blue)
                    .opacity(textOpacity)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: uiReady) { _, ready in
            if ready && minimumAnimationDone {
                dismissSplash()
            }
        }
        .onChange(of: minimumAnimationDone) { _, done in
            if done && uiReady {
                dismissSplash()
            }
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Animation ultra rapide du logo
        withAnimation(.easeOut(duration: 0.25)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Texte apparaît presque immédiatement
        withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
            textOpacity = 1.0
        }
        
        // Minimum animation time réduit à 0.6 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            minimumAnimationDone = true
        }
    }
    
    private func dismissSplash() {
        withAnimation(.easeOut(duration: 0.2)) {
            logoOpacity = 0
            textOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isActive = false
        }
    }
}

// MARK: - Preview

struct AmazingSplashView_Previews: PreviewProvider {
    static var previews: some View {
        AmazingSplashView(isActive: .constant(true), uiReady: .constant(false))
    }
}
