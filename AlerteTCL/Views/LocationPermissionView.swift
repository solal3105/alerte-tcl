import SwiftUI

struct LocationPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
                
                ZStack {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 120, height: 120)
                        .shadow(color: .blue.opacity(0.3), radius: 16, x: 0, y: 8)
                    
                    Image(systemName: "location.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                }
                
                VStack(spacing: 12) {
                    Text("Trouvez-vous facilement")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Centrez automatiquement la carte sur votre position pour voir les transports autour de vous")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "location.circle.fill", color: .blue, title: "Centrage automatique", description: "La carte se centre sur votre position actuelle")
                    
                    FeatureRow(icon: "map.fill", color: .green, title: "Transports à proximité", description: "Visualisez les véhicules autour de vous en temps réel")
                    
                    FeatureRow(icon: "lock.fill", color: .orange, title: "Confidentialité", description: "Votre position n'est jamais partagée ni stockée")
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        LocationService.shared.requestPermission()
                        dismiss()
                    } label: {
                        Text("Activer la localisation")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.large)
                    
                    Button("Plus tard", role: .cancel) {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    LocationPermissionView()
}
