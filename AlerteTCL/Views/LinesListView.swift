import SwiftUI

struct LinesListView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    @State private var selectedLineForSubscription: TransportLine?
    @State private var selectedAlertTypes: Set<AlertSeverity> = Set(AlertSeverity.allCases)
    
    private var sortedModes: [TransportMode] {
        viewModel.groupedLines.keys.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ModeFilterPill(
                            title: "Tous",
                            icon: "list.bullet",
                            isSelected: viewModel.selectedMode == nil
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.selectedMode = nil
                            }
                        }
                        
                        ForEach(TransportMode.allCases) { mode in
                            ModeFilterPill(
                                title: mode.rawValue,
                                icon: mode.icon,
                                isSelected: viewModel.selectedMode == mode
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.selectedMode = mode
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                    
                    LazyVStack(spacing: 24) {
                        ForEach(sortedModes, id: \.self) { mode in
                        if let lines = viewModel.groupedLines[mode], !lines.isEmpty {
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
                                        GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)
                                    ],
                                    spacing: 12
                                ) {
                                    ForEach(lines) { line in
                                        LineCard(
                                            line: line,
                                            alertCount: viewModel.alertCount(for: line),
                                            isSubscribed: viewModel.isSubscribed(to: line)
                                        ) {
                                            selectedLineForSubscription = line
                                            selectedAlertTypes = viewModel.subscriptionService.getNotificationPreferences(for: line)
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
        }
        .searchable(text: $viewModel.searchText, prompt: "Rechercher une ligne")
        .confirmationDialog(
            subscriptionDialogTitle,
            isPresented: Binding(
                get: { selectedLineForSubscription != nil },
                set: { if !$0 { selectedLineForSubscription = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let line = selectedLineForSubscription {
                if viewModel.isSubscribed(to: line) {
                    Button("Se désabonner", role: .destructive) {
                        viewModel.subscriptionService.unsubscribe(from: line)
                        selectedLineForSubscription = nil
                    }
                } else {
                    Button("Toutes les alertes") {
                        subscribeWithTypes(line: line, types: Set(AlertSeverity.allCases))
                    }
                    
                    Button("Perturbations majeures uniquement") {
                        subscribeWithTypes(line: line, types: [.major])
                    }
                    
                    Button("Perturbations (sans infos)") {
                        subscribeWithTypes(line: line, types: [.major, .disruption])
                    }
                }
                
                Button("Annuler", role: .cancel) {
                    selectedLineForSubscription = nil
                }
            }
        } message: {
            if let line = selectedLineForSubscription {
                if viewModel.isSubscribed(to: line) {
                    Text("Vous êtes abonné aux alertes de cette ligne")
                } else {
                    Text("Choisissez les types d'alertes à recevoir")
                }
            }
        }
    }
    
    private var subscriptionDialogTitle: String {
        guard let line = selectedLineForSubscription else { return "" }
        let modePrefix: String
        switch line.mode {
        case .metro: modePrefix = "Métro"
        case .tramway: modePrefix = "Tram"
        case .busC: modePrefix = "Bus C"
        case .bus: modePrefix = "Bus"
        case .funiculaire: modePrefix = "Funi"
        case .navette: modePrefix = "Navette"
        }
        return "\(modePrefix) \(line.displayName)"
    }
    
    private func subscribeWithTypes(line: TransportLine, types: Set<AlertSeverity>) {
        Task {
            _ = await NotificationService.shared.requestPermission()
            viewModel.subscriptionService.subscribe(to: line, notificationTypes: types)
            await MainActor.run {
                selectedLineForSubscription = nil
            }
        }
    }
}

struct LineCard: View {
    let line: TransportLine
    let alertCount: Int
    let isSubscribed: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(line.displayName)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: isSubscribed ? "bell.fill" : "bell")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                HStack {
                    if alertCount > 0 {
                        Text("\(alertCount) alerte\(alertCount > 1 ? "s" : "")")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.primary)
                    } else {
                        Text("RAS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(14)
            .frame(height: 100)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let count: Int?
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        count: Int?,
        isSelected: Bool,
        color: Color,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.count = count
        self.isSelected = isSelected
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let count = count, count > 0 {
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
            .background(
                Group {
                    if isSelected {
                        color.opacity(0.2)
                    } else {
                        Color(.systemGray6)
                    }
                }
            )
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ModeFilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        Color.primary
                    } else {
                        Color(.systemGray6)
                    }
                }
            )
            .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LinesListView()
        .environmentObject(AlertViewModel())
}
