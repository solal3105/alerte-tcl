import SwiftUI

struct OnboardingView: View {
    @Binding var isFinished: Bool
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "tram.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                
                Text("Bienvenue dans Alerte TCL")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Suivez les perturbations et les véhicules en temps réel, et abonnez-vous aux lignes qui vous intéressent.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isFinished = false
                    }
                } label: {
                    Text("Commencer")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    OnboardingView(isFinished: .constant(true))
}
