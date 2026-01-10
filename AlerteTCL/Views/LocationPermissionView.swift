import SwiftUI

struct LocationPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRequesting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 120, height: 120)
                    
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
                        isRequesting = true
                        Task {
                            LocationService.shared.requestPermission()
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Activer la localisation")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isRequesting)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Plus tard")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    LocationPermissionView()
}
