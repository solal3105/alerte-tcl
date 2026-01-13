import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    
    private var sortedSubscribedLines: [TransportLine] {
        viewModel.subscribedLines.sorted { line1, line2 in
            let alerts1 = viewModel.alerts(for: line1)
            let alerts2 = viewModel.alerts(for: line2)
            
            let hasAlerts1 = !alerts1.isEmpty
            let hasAlerts2 = !alerts2.isEmpty
            
            // Prioritize lines with alerts first
            if hasAlerts1 != hasAlerts2 {
                return hasAlerts1
            }
            
            // If both have alerts, sort by severity (major first, then disruption, then info)
            if hasAlerts1 && hasAlerts2 {
                let highestSeverity1 = alerts1.map { $0.severity.sortOrder }.min() ?? 999
                let highestSeverity2 = alerts2.map { $0.severity.sortOrder }.min() ?? 999
                
                if highestSeverity1 != highestSeverity2 {
                    return highestSeverity1 < highestSeverity2
                }
            }
            
            // Then sort by transport mode
            if line1.mode.sortOrder != line2.mode.sortOrder {
                return line1.mode.sortOrder < line2.mode.sortOrder
            }
            
            // Finally sort by display name
            return line1.displayName < line2.displayName
        }
    }
    
    var body: some View {
        ZStack {
            Group {
                if viewModel.subscribedLines.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(sortedSubscribedLines) { line in
                                SubscriptionCard(
                                    line: line,
                                    alerts: viewModel.alerts(for: line),
                                    subscriptionService: viewModel.subscriptionService,
                                    onUnsubscribe: {
                                        withAnimation {
                                            viewModel.toggleSubscription(for: line)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(16)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
        }
    }
    
    private var emptyView: some View {
        ContentUnavailableView {
            Label("Aucun abonnement", systemImage: "star.slash")
        } description: {
            Text("Ajoutez des lignes depuis l'onglet Lignes pour recevoir des notifications")
        }
    }
}

struct SubscriptionCard: View {
    let line: TransportLine
    let alerts: [TCLAlert]
    @ObservedObject var subscriptionService: SubscriptionService
    let onUnsubscribe: () -> Void
    
    @State private var showPreferences = false
    
    private var sortedAlerts: [TCLAlert] {
        let prefs = subscriptionService.getNotificationPreferences(for: line)
        return alerts
            .filter { prefs.contains($0.severity) }
            .sorted { $0.severity.sortOrder < $1.severity.sortOrder }
    }
    
    private var highestSeverity: AlertSeverity? {
        sortedAlerts.first?.severity
    }
    
    private var cardColor: Color {
        guard let severity = highestSeverity else {
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        }
        switch severity {
        case .major: return Color(red: 0.95, green: 0.26, blue: 0.21)
        case .disruption: return Color(red: 1.0, green: 0.45, blue: 0.0)
        case .info: return Color(red: 0.0, green: 0.48, blue: 1.0)
        }
    }
    
    private var modeIcon: String {
        switch line.mode {
        case .metro: return "tram.fill"
        case .tramway: return "tram"
        case .busC: return "bus.fill"
        case .bus: return "bus.fill"
        case .funiculaire: return "cablecar.fill"
        case .navette: return "ferry.fill"
        }
    }
    
    private var modePrefix: String {
        switch line.mode {
        case .metro: return "Métro"
        case .tramway: return "Tram"
        case .busC: return "Bus C"
        case .bus: return "Bus"
        case .funiculaire: return "Funi"
        case .navette: return "Navette"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: modeIcon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.75))
                        
                        Text(modePrefix.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white.opacity(0.75))
                            .tracking(0.5)
                    }
                    
                    Text(line.displayName)
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        showPreferences = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Button(action: onUnsubscribe) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(18)
            .background(cardColor)
            
            if sortedAlerts.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Aucune perturbation")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sortedAlerts) { alert in
                        AlertDetailRow(alert: alert)
                        
                        if alert.id != sortedAlerts.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showPreferences) {
            NotificationPreferencesSheet(
                line: line,
                subscriptionService: subscriptionService
            )
            .presentationDetents([.medium])
        }
    }
}

struct AlertDetailRow: View {
    let alert: TCLAlert
    
    private var severityColor: Color {
        switch alert.severity {
        case .major: return .red
        case .disruption: return .orange
        case .info: return .blue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: alert.severity.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(severityColor)
                
                Text(alert.severity.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(severityColor)
                    .tracking(0.3)
                
                Spacer()
                
                if let debut = alert.debut {
                    Text(formatDate(debut))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            
            Text(alert.titre)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            if !alert.message.isEmpty {
                Text(alert.message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if !alert.cause.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text(alert.cause)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SubscriptionLineSection: View {
    let line: TransportLine
    let alerts: [TCLAlert]
    let onUnsubscribe: () -> Void
    @ObservedObject var subscriptionService: SubscriptionService
    
    @State private var isExpanded = true
    @State private var showPreferences = false
    
    private var sortedAlerts: [TCLAlert] {
        let prefs = subscriptionService.getNotificationPreferences(for: line)
        return alerts
            .filter { prefs.contains($0.severity) }
            .sorted { $0.severity.sortOrder < $1.severity.sortOrder }
    }
    
    private var activePreferences: Set<AlertSeverity> {
        subscriptionService.getNotificationPreferences(for: line)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                LineBadge(line: line.displayName)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.displayName)
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    if sortedAlerts.isEmpty {
                        Text("Aucune perturbation")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("\(sortedAlerts.count) alerte\(sortedAlerts.count > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                Spacer()
                
                Button {
                    showPreferences = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                if !sortedAlerts.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .contentShape(Rectangle())
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: onUnsubscribe) {
                    Label("Supprimer", systemImage: "trash")
                }
            }
            
            if isExpanded && !sortedAlerts.isEmpty {
                VStack(spacing: 8) {
                    ForEach(sortedAlerts) { alert in
                        CompactAlertCard(alert: alert)
                    }
                }
                .padding(.top, 12)
                .padding(.leading, 56)
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showPreferences) {
            NotificationPreferencesSheet(
                line: line,
                subscriptionService: subscriptionService
            )
            .presentationDetents([.medium])
        }
    }
}

struct NotificationPreferencesSheet: View {
    let line: TransportLine
    @ObservedObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTypes: Set<AlertSeverity> = []
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        LineBadge(line: line.displayName)
                        VStack(alignment: .leading) {
                            Text(line.displayName)
                                .font(.headline)
                            Text("Choisissez les notifications")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section("Types d'alertes") {
                    ForEach(AlertSeverity.allCases) { severity in
                        Button {
                            if selectedTypes.contains(severity) {
                                if selectedTypes.count > 1 {
                                    selectedTypes.remove(severity)
                                }
                            } else {
                                selectedTypes.insert(severity)
                            }
                        } label: {
                            HStack {
                                Image(systemName: severity.icon)
                                    .foregroundStyle(severityColor(severity))
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(severity.rawValue)
                                        .foregroundStyle(.primary)
                                    Text(severityDescription(severity))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedTypes.contains(severity) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Section {
                    Text("Vous recevrez uniquement les notifications correspondant aux types sélectionnés.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Préférences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        subscriptionService.updateNotificationPreferences(for: line, types: selectedTypes)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            selectedTypes = subscriptionService.getNotificationPreferences(for: line)
        }
    }
    
    private func severityColor(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .major: return .red
        case .disruption: return .orange
        case .info: return .blue
        }
    }
    
    private func severityDescription(_ severity: AlertSeverity) -> String {
        switch severity {
        case .major: return "Interruptions de service, incidents graves"
        case .disruption: return "Travaux, modifications de parcours"
        case .info: return "Informations générales, événements"
        }
    }
}

struct CompactAlertCard: View {
    let alert: TCLAlert
    @State private var isExpanded = false
    
    private var severityColor: Color {
        switch alert.severity {
        case .info: return .blue
        case .disruption: return .orange
        case .major: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: alert.severity.icon)
                    .font(.caption)
                    .foregroundStyle(severityColor)
                
                Text(alert.titre)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(isExpanded ? nil : 2)
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text(alert.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        if !alert.cause.isEmpty {
                            Label(alert.cause, systemImage: "info.circle")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        if let debut = alert.debut {
                            Label(formatDate(debut), systemImage: "calendar")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(severityColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(severityColor.opacity(0.2), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SubscriptionsView()
        .environmentObject(AlertViewModel())
}
