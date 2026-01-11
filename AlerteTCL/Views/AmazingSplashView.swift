// AmazingSplashView.swift
import SwiftUI

struct AmazingSplashView: View {
    @Binding var isActive: Bool
    @Binding var apiReady: Bool
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                
                Text("Alerte TCL")
                    .font(.title)
                    .fontWeight(.bold)
                
                ProgressView("Chargement…")
                    .progressViewStyle(.circular)
                    .tint(.blue)
                    .padding(.top, 8)
            }
        }
        .onChange(of: apiReady) { _, ready in
            if ready {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isActive = false
                }
            }
        }
        .task {
            // Sécurité: si l’API a déjà répondu avant l’affichage
            if apiReady {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isActive = false
                    }
                }
            }
        }
    }
}

#Preview {
    AmazingSplashView(isActive: .constant(true), apiReady: .constant(false))
}
