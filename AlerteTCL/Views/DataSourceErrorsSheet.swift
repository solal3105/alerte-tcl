import SwiftUI

struct DataSourceErrorsSheet: View {
    @ObservedObject var viewModel: LiveVehiclesViewModel
    @ObservedObject var alertViewModel: AlertViewModel
    @Binding var isPresented: Bool
    
    @State private var retryingSources: Set<DataSource> = []
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.failedDataSources, id: \.source) { item in
                        DataSourceErrorRow(
                            source: item.source,
                            error: item.error,
                            isRetrying: retryingSources.contains(item.source)
                        ) {
                            retrySource(item.source)
                        }
                    }
                    
                    if let alertError = alertViewModel.alertsError {
                        DataSourceErrorRow(
                            source: .alerts,
                            error: alertError,
                            isRetrying: retryingSources.contains(.alerts)
                        ) {
                            retrySource(.alerts)
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
                            
                            if !retryingSources.isEmpty {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(!retryingSources.isEmpty)
                }
            }
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
    
    private func retrySource(_ source: DataSource) {
        guard !retryingSources.contains(source) else {
            print("🔄 Source \(source.displayName) déjà en cours de retry")
            return
        }
        
        retryingSources.insert(source)
        print("🔄 Début retry: \(source.displayName)")
        
        Task.detached(priority: .userInitiated) {
            let startTime = Date()
            
            if source == .alerts {
                await alertViewModel.loadAlerts()
            } else {
                await viewModel.retryDataSource(source)
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                retryingSources.remove(source)
                
                // Vérifier si le retry a réussi
                let hasError = source == .alerts 
                    ? alertViewModel.alertsError != nil 
                    : viewModel.dataSourceErrors[source] != nil
                
                if hasError {
                    print("❌ Retry échoué: \(source.displayName) (durée: \(String(format: "%.1f", duration))s)")
                } else {
                    print("✅ Retry réussi: \(source.displayName) (durée: \(String(format: "%.1f", duration))s)")
                }
            }
        }
    }
    
    private func retryAll() {
        print("🔄 Début retry de toutes les sources en erreur")
        
        for item in viewModel.failedDataSources {
            retrySource(item.source)
        }
        
        if alertViewModel.alertsError != nil {
            retrySource(.alerts)
        }
    }
}

struct DataSourceErrorRow: View {
    let source: DataSource
    let error: String
    let isRetrying: Bool
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.icon)
                .font(.system(size: 20))
                .foregroundStyle(.orange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source.displayName)
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
        if error.contains("timeout") || error.contains("timed out") {
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
