import SwiftUI

// MARK: - NewAlertsView (Main View)
struct NewAlertsView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    @State private var selectedLine: TransportLine?
    @State private var showSubscribeSheet = false
    @State private var searchText = ""
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Section Mes Lignes
                    myLinesSection
                    
                    // Section Toutes les lignes
                    allLinesSection
                }
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                await viewModel.loadAlerts()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .sheet(item: $selectedLine) { line in
                LineDetailSheet(line: line, viewModel: viewModel)
            }
            .sheet(isPresented: $showSubscribeSheet) {
                SubscribeLineSheet(viewModel: viewModel)
            }
            
            // Bouton refresh flottant
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        Task { await viewModel.loadAlerts() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.large)
                    .disabled(viewModel.isLoading)
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }
    
    // MARK: - My Lines Section
    private var myLinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mes lignes")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button {
                    showSubscribeSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("S'abonner")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            
            if viewModel.subscribedLines.isEmpty {
                emptySubscriptionsView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(sortedSubscribedLines) { line in
                        SubscribedLineCard(
                            line: line,
                            alerts: viewModel.alerts(for: line),
                            highestSeverity: highestSeverity(for: line)
                        )
                        .onTapGesture {
                            selectedLine = line
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var sortedSubscribedLines: [TransportLine] {
        viewModel.subscribedLines.sorted { line1, line2 in
            let severity1 = highestSeverity(for: line1)?.sortOrder ?? 999
            let severity2 = highestSeverity(for: line2)?.sortOrder ?? 999
            
            if severity1 != severity2 {
                return severity1 < severity2
            }
            
            if line1.mode.sortOrder != line2.mode.sortOrder {
                return line1.mode.sortOrder < line2.mode.sortOrder
            }
            
            return line1.displayName.localizedStandardCompare(line2.displayName) == .orderedAscending
        }
    }
    
    private func highestSeverity(for line: TransportLine) -> AlertSeverity? {
        let lineAlerts = viewModel.alerts(for: line)
        return lineAlerts.map { $0.severity }.min { $0.sortOrder < $1.sortOrder }
    }
    
    private var emptySubscriptionsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 4) {
                Text("Aucune ligne suivie")
                    .font(.headline)
                Text("Abonnez-vous à des lignes pour recevoir leurs alertes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement()
            .accessibilityLabel("Aucune ligne suivie. Abonnez-vous à des lignes pour recevoir leurs alertes.")
            .accessibilityHint("Double-cliquer pour s'abonner à des lignes")
            
            Button {
                showSubscribeSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("M'abonner à une ligne")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.blue)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
    
    // MARK: - All Lines Section
    private var allLinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Toutes les lignes")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 16)
                .padding(.top, 24)
            
            ForEach(sortedModes, id: \.self) { mode in
                let modeLines = viewModel.allLines.filter { $0.mode == mode }
                    .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
                
                if !modeLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(mode.color)
                            
                            Text(mode.rawValue)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(modeLines) { line in
                                    CompactLineChip(
                                        line: line,
                                        alertCount: viewModel.alertCount(for: line),
                                        isSubscribed: viewModel.isSubscribed(to: line)
                                    )
                                    .onTapGesture {
                                        selectedLine = line
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var sortedModes: [TransportMode] {
        TransportMode.allCases.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - Subscribed Line Card
private struct SubscribedLineCard: View {
    let line: TransportLine
    let alerts: [TCLAlert]
    let highestSeverity: AlertSeverity?
    
    var body: some View {
        HStack(spacing: 14) {
            // Badge ligne
            AlertLineBadgeView(line: line, size: 52)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(line.mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text("Ligne \(line.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let severity = highestSeverity {
                    HStack(spacing: 4) {
                        Image(systemName: severity.icon)
                            .font(.caption)
                        Text("\(alerts.count) alerte\(alerts.count > 1 ? "s" : "")")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(severityColor(severity))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Aucune perturbation")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.green)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(statusBackground)
        .contentShape(Rectangle())
    }
    
    private var statusBackground: some View {
        Group {
            if let severity = highestSeverity {
                severityColor(severity).opacity(0.08)
            } else {
                Color.green.opacity(0.05)
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

// MARK: - Compact Line Chip
private struct CompactLineChip: View {
    let line: TransportLine
    let alertCount: Int
    let isSubscribed: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                AlertLineBadgeView(line: line, size: 56)
                
                if alertCount > 0 {
                    Circle()
                        .fill(.orange)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Text("\(alertCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 22, y: -22)
                }
                
                if isSubscribed {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.blue)
                        .clipShape(Circle())
                        .offset(x: 22, y: 22)
                }
            }
        }
    }
}

// MARK: - Line Detail Sheet
struct LineDetailSheet: View {
    let line: TransportLine
    @ObservedObject var viewModel: AlertViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSubscriptionOptions = false
    
    private var lineAlerts: [TCLAlert] {
        viewModel.alerts(for: line).sorted { $0.severity.sortOrder < $1.severity.sortOrder }
    }
    
    private var isSubscribed: Bool {
        viewModel.isSubscribed(to: line)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    lineHeader
                    
                    // Subscribe button
                    subscribeSection
                    
                    // Alerts
                    if lineAlerts.isEmpty {
                        noAlertsView
                    } else {
                        alertsSection
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ligne \(line.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showSubscriptionOptions) {
                SubscriptionOptionsSheet(line: line, viewModel: viewModel)
            }
        }
        .interactiveDismissDisabled(false)
    }
    
    private var lineHeader: some View {
        HStack(spacing: 16) {
            AlertLineBadgeView(line: line, size: 72)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(line.mode.rawValue)
                    .font(.headline)
                
                if lineAlerts.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Aucune perturbation")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(lineAlerts.count) alerte\(lineAlerts.count > 1 ? "s" : "")")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
    }
    
    private var subscribeSection: some View {
        VStack(spacing: 12) {
            if isSubscribed {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.blue)
                    Text("Vous suivez cette ligne")
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(16)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                HStack(spacing: 12) {
                    Button {
                        showSubscriptionOptions = true
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Options")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Button {
                        withAnimation {
                            viewModel.toggleSubscription(for: line)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bell.slash")
                            Text("Se désabonner")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                Button {
                    showSubscriptionOptions = true
                } label: {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                        Text("S'abonner à cette ligne")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var noAlertsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            
            Text("Aucune perturbation")
                .font(.headline)
            
            Text("Cette ligne fonctionne normalement")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
    
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alertes en cours")
                .font(.headline)
                .padding(.horizontal, 16)
            
            LazyVStack(spacing: 12) {
                ForEach(lineAlerts) { alert in
                    AlertDetailCard(alert: alert)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Alert Detail Card
private struct AlertDetailCard: View {
    let alert: TCLAlert
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: alert.severity.icon)
                    .foregroundStyle(severityColor)
                
                Text(alert.severity.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(severityColor)
                
                Spacer()
                
                if let debut = alert.debut {
                    Text(debut.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(alert.titre)
                .font(.body)
                .fontWeight(.medium)
            
            if !alert.message.isEmpty {
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(severityColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(severityColor.opacity(0.3), lineWidth: 1)
        }
    }
    
    private var severityColor: Color {
        switch alert.severity {
        case .major: return .red
        case .disruption: return .orange
        case .info: return .blue
        }
    }
}

// MARK: - Subscription Options Sheet
struct SubscriptionOptionsSheet: View {
    let line: TransportLine
    @ObservedObject var viewModel: AlertViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTypes: Set<AlertSeverity>
    
    init(line: TransportLine, viewModel: AlertViewModel) {
        self.line = line
        self.viewModel = viewModel
        let currentPrefs = viewModel.subscriptionService.getNotificationPreferences(for: line)
        _selectedTypes = State(initialValue: currentPrefs)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    AlertLineBadgeView(line: line, size: 72)
                    
                    Text("Notifications pour la ligne \(line.displayName)")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Choisissez les types d'alertes que vous souhaitez recevoir")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Options
                VStack(spacing: 12) {
                    ForEach(AlertSeverity.allCases) { severity in
                        NotificationTypeRow(
                            severity: severity,
                            isSelected: selectedTypes.contains(severity)
                        ) {
                            if selectedTypes.contains(severity) {
                                selectedTypes.remove(severity)
                            } else {
                                selectedTypes.insert(severity)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Save button
                Button {
                    if selectedTypes.isEmpty {
                        viewModel.subscriptionService.unsubscribe(from: line)
                    } else if viewModel.isSubscribed(to: line) {
                        viewModel.subscriptionService.updateNotificationPreferences(for: line, types: selectedTypes)
                    } else {
                        viewModel.subscriptionService.subscribe(to: line, notificationTypes: selectedTypes)
                    }
                    dismiss()
                } label: {
                    Text(selectedTypes.isEmpty ? "Se désabonner" : "Enregistrer")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedTypes.isEmpty ? Color.red : Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Options de notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Notification Type Row
private struct NotificationTypeRow: View {
    let severity: AlertSeverity
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(severityColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: severity.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(severityColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(severity.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(severityDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? severityColor : .secondary)
            }
            .padding(14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    private var severityColor: Color {
        switch severity {
        case .major: return .red
        case .disruption: return .orange
        case .info: return .blue
        }
    }
    
    private var severityDescription: String {
        switch severity {
        case .major: return "Interruptions totales de service"
        case .disruption: return "Retards et déviations importantes"
        case .info: return "Informations et travaux prévus"
        }
    }
}

// MARK: - Subscribe Line Sheet
struct SubscribeLineSheet: View {
    @ObservedObject var viewModel: AlertViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedLine: TransportLine?
    
    private var filteredLines: [TransportLine] {
        let lines = viewModel.allLines.filter { !viewModel.isSubscribed(to: $0) }
        
        if searchText.isEmpty {
            return lines.sorted { $0.mode.sortOrder < $1.mode.sortOrder }
        }
        
        return lines.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.ligneCom.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.mode.sortOrder < $1.mode.sortOrder }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(TransportMode.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { mode in
                    let modeLines = filteredLines.filter { $0.mode == mode }
                    
                    if !modeLines.isEmpty {
                        Section {
                            ForEach(modeLines) { line in
                                Button {
                                    selectedLine = line
                                } label: {
                                    HStack(spacing: 12) {
                                        AlertLineBadgeView(line: line, size: 40)
                                        
                                        Text("Ligne \(line.displayName)")
                                            .foregroundStyle(.primary)
                                        
                                        Spacer()
                                        
                                        let count = viewModel.alertCount(for: line)
                                        if count > 0 {
                                            Text("\(count) alerte\(count > 1 ? "s" : "")")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                    .foregroundStyle(mode.color)
                                Text(mode.rawValue)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher une ligne")
            .navigationTitle("S'abonner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedLine) { line in
                SubscriptionOptionsSheet(line: line, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Alert Line Badge View (with proper colors per line type)

struct AlertLineBadgeView: View {
    let line: TransportLine
    let size: CGFloat
    
    private var lineName: String {
        line.ligneCli.isEmpty ? line.ligneCom : line.ligneCli
    }
    
    private var bgColor: Color {
        LineColorHelper.backgroundColor(for: lineName)
    }
    
    private var textColor: Color {
        LineColorHelper.textColor(for: lineName)
    }
    
    private var needsBorder: Bool {
        LineColorHelper.needsBorder(for: lineName)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(bgColor)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .stroke(Color(.systemGray3), lineWidth: needsBorder ? 1 : 0)
                )
            
            Text(lineName)
                .font(.system(size: size * 0.28, weight: .black))
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}

// MARK: - Legacy AlertsView (kept for compatibility)
struct AlertsView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    
    var body: some View {
        NewAlertsView()
    }
}

#Preview {
    NewAlertsView()
        .environmentObject(AlertViewModel())
}
