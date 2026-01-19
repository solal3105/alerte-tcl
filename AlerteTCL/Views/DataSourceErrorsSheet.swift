import SwiftUI

struct DataSourceErrorsSheet: View {
    @ObservedObject var viewModel: LiveVehiclesViewModel
    @ObservedObject var alertViewModel: AlertViewModel
    @Binding var isPresented: Bool
    
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
                    Text("Ces erreurs peuvent être causées par une maintenance des serveurs Grand Lyon ou un problème de connexion.")
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
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .navigationTitle("Erreurs de chargement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        isPresented = false
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
        if error.contains("Timeout") || error.contains("timeout") || error.contains("timed out") {
            return "Timeout - serveur lent ou indisponible"
        } else if error.contains("connection") || error.contains("network") {
            return "Problème de connexion réseau"
        } else if error.contains("401") || error.contains("403") {
            return "Erreur d'authentification"
        } else if error.contains("500") || error.contains("502") || error.contains("503") {
            return "Serveur indisponible"
        } else {
            return error
        }
    }
}

#Preview {
    DataSourceErrorsSheet(
        viewModel: LiveVehiclesViewModel(),
        alertViewModel: AlertViewModel(),
        isPresented: .constant(true)
    )
}
