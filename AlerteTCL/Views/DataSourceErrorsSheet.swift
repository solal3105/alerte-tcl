import SwiftUI

struct DataSourceErrorsSheet: View {
    @ObservedObject var viewModel: LiveVehiclesViewModel
    @ObservedObject var alertViewModel: AlertViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isRetrying = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let error = alertViewModel.error {
                        ErrorRow(
                            title: "Alertes TCL",
                            icon: "exclamationmark.triangle.fill",
                            error: error,
                            isRetrying: isRetrying
                        ) {
                            retryAlerts()
                        }
                    }
                    
                    if let error = viewModel.error {
                        ErrorRow(
                            title: "Véhicules en temps réel",
                            icon: "bus.fill",
                            error: error,
                            isRetrying: isRetrying
                        ) {
                            retryVehicles()
                        }
                    }
                } header: {
                    Text("Sources de données en erreur")
                } footer: {
                    let h = Calendar.current.component(.hour, from: Date())
                    Text(h >= 22 || h < 6
                        ? "Il est probable que Grand Lyon coupe ses serveurs la nuit. Pas d'inquiétude, tout reviendra demain matin !"
                        : "Ces erreurs sont généralement temporaires. Réessayez dans quelques instants."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                
                Section {
                    Button {
                        retryAll()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Réessayer toutes les sources")
                            
                            if isRetrying {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isRetrying)
                }
            }
            .navigationTitle("Erreurs de chargement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func retryAlerts() {
        guard !isRetrying else { return }
        isRetrying = true
        
        Task(priority: .userInitiated) {
            await alertViewModel.loadAlerts()
            await MainActor.run {
                isRetrying = false
            }
        }
    }
    
    private func retryVehicles() {
        guard !isRetrying else { return }
        isRetrying = true
        
        Task(priority: .userInitiated) {
            await viewModel.loadVehicles()
            await MainActor.run {
                isRetrying = false
            }
        }
    }
    
    private func retryAll() {
        guard !isRetrying else { return }
        isRetrying = true
        
        Task(priority: .userInitiated) {
            async let alertsTask: () = alertViewModel.loadAlerts()
            async let vehiclesTask: () = viewModel.loadVehicles()
            _ = await (alertsTask, vehiclesTask)
            
            await MainActor.run {
                isRetrying = false
            }
        }
    }
}

struct ErrorRow: View {
    let title: String
    let icon: String
    let error: String
    let isRetrying: Bool
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.orange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                
                Text(simplifiedError)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button {
                onRetry()
            } label: {
                if isRetrying {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                }
            }
            .buttonStyle(.plain)
            .disabled(isRetrying)
        }
        .padding(.vertical, 4)
    }
    
    private var simplifiedError: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 6 {
            return "Les serveurs Grand Lyon se reposent la nuit — réessayez après 6h"
        }
        if error.contains("504") || error.contains("Timeout") || error.contains("timeout") || error.contains("timed out") {
            return "Le serveur prend son temps... réessayez dans quelques instants"
        } else if error.contains("500") || error.contains("502") || error.contains("503") {
            return "Serveur en maintenance, revenez bientôt"
        } else if error.contains("connection") || error.contains("network") || error.contains("Network") {
            return "Vérifiez votre connexion internet"
        } else if error.contains("401") || error.contains("403") {
            return "Erreur d'authentification avec l'API Grand Lyon"
        } else {
            return "Données temporairement indisponibles"
        }
    }
}

#Preview {
    DataSourceErrorsSheet(
        viewModel: LiveVehiclesViewModel(),
        alertViewModel: AlertViewModel()
    )
}
