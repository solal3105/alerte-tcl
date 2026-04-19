import Foundation
import Combine

@MainActor
final class AlertViewModel: ObservableObject {
    @Published var alerts: [TCLAlert] = []
    @Published var allLines: [TransportLine] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdate: Date?
    @Published var selectedMode: TransportMode?
    @Published var searchText = ""
    @Published var selectedSeverityFilter: AlertSeverity?

    struct LineAlertSummary: Identifiable, Hashable {
        let id: String
        let displayName: String
        let mode: TransportMode
        let highestSeverity: AlertSeverity
        let alerts: [TCLAlert]

        var alertCount: Int { alerts.count }
    }
    
    let subscriptionService = SubscriptionService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        allLines = TransportLine.allPredefinedLines
        
        subscriptionService.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    var subscribedLines: [TransportLine] {
        allLines.filter { line in
            subscriptionService.isSubscribed(to: line.ligneCom) ||
            subscriptionService.isSubscribed(to: line.ligneCli)
        }
    }
    
    var filteredLines: [TransportLine] {
        var lines = allLines
        
        if let mode = selectedMode {
            lines = lines.filter { $0.mode == mode }
        }
        
        if !searchText.isEmpty {
            lines = lines.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.ligneCom.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return lines.sorted { $0.mode.sortOrder < $1.mode.sortOrder }
    }
    
    var subscribedAlerts: [TCLAlert] {
        alerts.filter { alert in
            subscriptionService.isSubscribed(to: alert.ligneCom) ||
            subscriptionService.isSubscribed(to: alert.ligneCli)
        }
        .sorted { $0.severity.sortOrder < $1.severity.sortOrder }
    }
    
    var allAlertsSorted: [TCLAlert] {
        var result = alerts
        
        if let filter = selectedSeverityFilter {
            result = result.filter { $0.severity == filter }
        }
        
        return result.sorted { $0.severity.sortOrder < $1.severity.sortOrder }
    }

    var linesInError: [LineAlertSummary] {
        // Ne prendre que les alertes actives avec une vraie perturbation (pas juste info)
        let activeAlerts = alerts.filter { $0.isActive && $0.severity != .info }
        let grouped = Dictionary(grouping: activeAlerts) { alert in
            alert.ligneCli.isEmpty ? alert.ligneCom : alert.ligneCli
        }

        let summaries: [LineAlertSummary] = grouped.compactMap { key, groupedAlerts in
            guard let first = groupedAlerts.first else { return nil }
            let highestSeverity = groupedAlerts
                .map { $0.severity }
                .min { $0.sortOrder < $1.sortOrder } ?? first.severity

            return LineAlertSummary(
                id: key,
                displayName: key,
                mode: first.mode,
                highestSeverity: highestSeverity,
                alerts: groupedAlerts.sorted { $0.severity.sortOrder < $1.severity.sortOrder }
            )
        }

        return summaries.sorted {
            let severityPriority0 = severityDisplayPriority($0.highestSeverity)
            let severityPriority1 = severityDisplayPriority($1.highestSeverity)
            
            if severityPriority0 != severityPriority1 {
                return severityPriority0 < severityPriority1
            }
            if $0.mode.sortOrder != $1.mode.sortOrder {
                return $0.mode.sortOrder < $1.mode.sortOrder
            }
            return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }
    
    private func severityDisplayPriority(_ severity: AlertSeverity) -> Int {
        switch severity {
        case .disruption: return 0
        case .major: return 1
        case .info: return 2
        }
    }
    
    var groupedLines: [TransportMode: [TransportLine]] {
        Dictionary(grouping: filteredLines) { $0.mode }
    }
    
    var alertCountByLine: [String: Int] {
        var counts: [String: Int] = [:]
        for alert in alerts where alert.severity != .info {
            counts[alert.ligneCom, default: 0] += 1
            if !alert.ligneCli.isEmpty && alert.ligneCli != alert.ligneCom {
                counts[alert.ligneCli, default: 0] += 1
            }
        }
        return counts
    }
    
    func alertCount(for line: TransportLine) -> Int {
        max(alertCountByLine[line.ligneCom] ?? 0, alertCountByLine[line.ligneCli] ?? 0)
    }
    
    func alerts(for line: TransportLine) -> [TCLAlert] {
        alerts.filter { $0.ligneCom == line.ligneCom || $0.ligneCli == line.ligneCli }
    }
    
    /// Nombre max de retries automatiques pour le chargement initial
    private static let maxRetries = 1
    private static let retryDelay: UInt64 = 2_000_000_000 // 2s
    
    func loadAlerts() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        let isFirstLoad = lastUpdate == nil
        let attempts = isFirstLoad ? (Self.maxRetries + 1) : 1
        var lastError: Error?
        
        for attempt in 1...attempts {
            do {
                let fetchedAlerts = try await TCLAPIService.shared.fetchAlerts()
                alerts = fetchedAlerts
                lastUpdate = Date()
                error = nil
                
                extractLinesFromAlerts(fetchedAlerts)
                
                // Traiter les nouvelles alertes pour les notifications
                NotificationService.shared.processNewAlerts(fetchedAlerts, subscriptionService: subscriptionService)
                
                print("✅ AlertViewModel: \(fetchedAlerts.count) alertes chargées depuis l'API")
                return
            } catch {
                lastError = error
                print("⚠️ Erreur alertes tentative \(attempt)/\(attempts): \(error.localizedDescription)")
            }
            
            // Retry avec délai seulement si ce n'est pas la dernière tentative
            if attempt < attempts {
                print("🔄 Retry alertes dans 2s...")
                try? await Task.sleep(nanoseconds: Self.retryDelay)
            }
        }
        
        // Toutes les tentatives ont échoué
        self.error = lastError?.localizedDescription
    }
    
    private func extractLinesFromAlerts(_ alerts: [TCLAlert]) {
        var existingIds = Set(allLines.map { $0.id })
        var existingCliKeys = Set(allLines.compactMap { line -> String? in
            guard !line.ligneCli.isEmpty else { return nil }
            return "\(line.mode.rawValue)-\(line.ligneCli)"
        })
        
        for alert in alerts {
            let line = TransportLine(
                ligneCom: alert.ligneCom,
                ligneCli: alert.ligneCli,
                mode: alert.mode
            )
            
            let cliKey = line.ligneCli.isEmpty ? nil : "\(line.mode.rawValue)-\(line.ligneCli)"
            let alreadyExists = existingIds.contains(line.id) || (cliKey != nil && existingCliKeys.contains(cliKey!))
            
            if !alreadyExists {
                allLines.append(line)
                existingIds.insert(line.id)
                if let cliKey = cliKey {
                    existingCliKeys.insert(cliKey)
                }
            }
        }
        
        allLines.sort { $0.mode.sortOrder < $1.mode.sortOrder }
    }
    
    func filteredAlerts(for line: TransportLine) -> [TCLAlert] {
        let lineAlerts = alerts(for: line)
        let preferences = subscriptionService.getNotificationPreferences(for: line)
        
        return lineAlerts.filter { alert in
            preferences.contains(alert.severity)
        }
    }
    
    func toggleSubscription(for line: TransportLine) {
        subscriptionService.toggle(line: line)
    }
    
    func isSubscribed(to line: TransportLine) -> Bool {
        subscriptionService.isSubscribed(to: line.ligneCom) ||
        subscriptionService.isSubscribed(to: line.ligneCli)
    }
}
