import SwiftUI

struct NotificationPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRequesting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                }
                
                // Title & Description
                VStack(spacing: 12) {
                    Text("Restez informé")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Recevez des notifications en temps réel pour les perturbations sur vos lignes préférées")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "exclamationmark.triangle.fill", color: .orange, title: "Alertes en temps réel", description: "Soyez prévenu dès qu'une perturbation affecte vos lignes")
                    
                    FeatureRow(icon: "slider.horizontal.3", color: .blue, title: "Personnalisable", description: "Choisissez les types d'alertes qui vous intéressent")
                    
                    FeatureRow(icon: "lock.fill", color: .green, title: "Confidentialité", description: "Vos données restent sur votre appareil")
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        isRequesting = true
                        Task {
                            NotificationService.shared.requestPermission()
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Activer les notifications")
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

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    NotificationPermissionView()
}
