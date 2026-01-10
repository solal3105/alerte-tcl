import SwiftUI

struct AlertsView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.alerts.isEmpty {
                    noAlertsView
                } else {
                    alertsList
                }
            }
            .navigationTitle("Alertes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    refreshButton
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }
    
    private var alertsList: some View {
        List {
            headerSection
            
            severityFilterSection
            
            if let error = viewModel.error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
            }
            
            if viewModel.allAlertsSorted.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("Aucune alerte", systemImage: "checkmark.circle")
                    } description: {
                        Text("Aucune alerte pour ce filtre")
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.allAlertsSorted) { alert in
                    AlertCard(alert: alert)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadAlerts()
        }
    }
    
    private var severityFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                SeverityFilterChip(
                    title: "Toutes",
                    icon: nil,
                    count: viewModel.alerts.count,
                    isSelected: viewModel.selectedSeverityFilter == nil,
                    color: .gray
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectedSeverityFilter = nil
                    }
                }
                
                ForEach(AlertSeverity.allCases) { severity in
                    let count = viewModel.alerts.filter { $0.severity == severity }.count
                    SeverityFilterChip(
                        title: severity.rawValue,
                        icon: nil,
                        count: count,
                        isSelected: viewModel.selectedSeverityFilter == severity,
                        color: severityColor(severity)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if viewModel.selectedSeverityFilter == severity {
                                viewModel.selectedSeverityFilter = nil
                            } else {
                                viewModel.selectedSeverityFilter = severity
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "tram.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Réseau TCL")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    if let lastUpdate = viewModel.lastUpdate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(lastUpdate.formatted(.relative(presentation: .named)))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                StatCard(
                    value: "\(viewModel.alerts.count)",
                    label: "Alertes actives",
                    color: viewModel.alerts.isEmpty ? .green : .orange,
                    icon: "exclamationmark.triangle.fill"
                )
                
                StatCard(
                    value: "\(viewModel.subscribedLines.count)",
                    label: "Lignes suivies",
                    color: .blue,
                    icon: "star.fill"
                )
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }
    
    private func severityColor(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .major: return .red
        case .disruption: return .orange
        case .info: return .blue
        }
    }
    
    private var noAlertsView: some View {
        ContentUnavailableView {
            Label("Aucune alerte", systemImage: "checkmark.circle")
        } description: {
            Text("Aucune perturbation en cours sur le réseau")
        } actions: {
            Button {
                Task { await viewModel.loadAlerts() }
            } label: {
                Text("Actualiser")
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var refreshButton: some View {
        Button {
            Task { await viewModel.loadAlerts() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
    }
}

struct SeverityFilterChip: View {
    let title: String
    var icon: String? = nil
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? color : Color(.systemGray4))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.15) : Color(.systemGray6))
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AlertsView()
        .environmentObject(AlertViewModel())
}
