import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Accueil", systemImage: "house")
                }
                .tag(0)
                .badge(viewModel.linesInError.count)
            
            LinesListView()
                .tabItem {
                    Label("Lignes", systemImage: "tram.fill")
                }
                .tag(1)
            
            SubscriptionsView()
                .tabItem {
                    Label("Abonnements", systemImage: "star.fill")
                }
                .tag(2)
                .badge(viewModel.subscribedLines.count)
        }
        .tint(.primary)
        .task {
            await viewModel.loadAlerts()
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    @State private var selectedLine: AlertViewModel.LineAlertSummary?
    
    private var sortedModes: [TransportMode] {
        TransportMode.allCases.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ZStack {
            Group {
                if viewModel.linesInError.isEmpty {
                    ContentUnavailableView {
                        Label("Aucune perturbation", systemImage: "checkmark.circle")
                    } description: {
                        Text("Aucune ligne en erreur pour le moment")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(sortedModes, id: \.self) { mode in
                                let modeLines = viewModel.linesInError.filter { $0.mode == mode }
                                
                                if !modeLines.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(spacing: 6) {
                                            Image(systemName: mode.icon)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.primary)
                                            
                                            Text(mode.rawValue.uppercased())
                                                .font(.system(size: 13, weight: .black))
                                                .foregroundStyle(.primary)
                                                .tracking(0.5)
                                        }
                                        .padding(.horizontal, 16)
                                        
                                        LazyVGrid(
                                            columns: [
                                                GridItem(.flexible(), spacing: 16),
                                                GridItem(.flexible(), spacing: 16)
                                            ],
                                            spacing: 16
                                        ) {
                                            ForEach(modeLines) { item in
                                                LineErrorCard(item: item)
                                                    .onTapGesture {
                                                        selectedLine = item
                                                    }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        Task { await viewModel.loadAlerts() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }
                
                Spacer()
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .sheet(item: $selectedLine) { item in
            NavigationStack {
                List {
                    ForEach(item.alerts) { alert in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(alert.severity.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(severityColor(alert.severity))
                                Spacer()
                                Text(alert.mode.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(alert.titre)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            if !alert.message.isEmpty {
                                Text(alert.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .navigationTitle(item.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fermer") { selectedLine = nil }
                    }
                }
            }
        }
    }

    private func severityColor(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .major: return .red
        case .disruption: return .orange
        case .info: return .blue
        }
    }
}

private struct LineErrorCard: View {
    let item: AlertViewModel.LineAlertSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: modeIcon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.75))
                        
                        Text(modePrefix.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white.opacity(0.75))
                            .tracking(0.5)
                    }
                    
                    Text(item.displayName)
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if item.highestSeverity == .major {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                } else if item.highestSeverity == .disruption {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                } else if item.highestSeverity == .info {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.highestSeverity.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(0.3)
                
                Text("\(item.alertCount) alerte\(item.alertCount > 1 ? "s" : "")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(18)
        .frame(height: 160)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
    }

    private var modePrefix: String {
        switch item.mode {
        case .metro:
            return "Métro"
        case .tramway:
            return "Tram"
        case .bus:
            return "Bus"
        case .funiculaire:
            return "Funi"
        case .navette:
            return "Navette"
        }
    }
    
    private var modeIcon: String {
        switch item.mode {
        case .metro:
            return "tram.fill"
        case .tramway:
            return "tram"
        case .bus:
            return "bus.fill"
        case .funiculaire:
            return "cablecar.fill"
        case .navette:
            return "ferry.fill"
        }
    }

    private var backgroundColor: Color {
        switch item.highestSeverity {
        case .major:
            return Color(red: 0.95, green: 0.26, blue: 0.21)
        case .disruption:
            return Color(red: 1.0, green: 0.45, blue: 0.0)
        case .info:
            return Color(red: 0.0, green: 0.48, blue: 1.0)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AlertViewModel())
}
