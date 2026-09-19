import Foundation

/// Alertes trafic depuis le relais `/alerts`, ramenées aux lignes en perturbation (même règle que
/// `TrafficBanner.linesInError` du module partagé : en cours, hors simples informations, une entrée
/// par ligne avec sa sévérité la plus forte).
enum AlertsService {
    private struct Response: Decodable {
        let values: [Alert]
    }

    private struct Alert: Decodable {
        let type: String?
        let debut: String?
        let fin: String?
        let ligneCom: String?
        let ligneCli: String?
        let titre: String?

        enum CodingKeys: String, CodingKey {
            case type, debut, fin, titre
            case ligneCom = "ligne_com"
            case ligneCli = "ligne_cli"
        }

        var severity: WidgetSeverity {
            let t = (type ?? "").lowercased()
            if t.contains("majeure") { return .major }
            if t.contains("perturbation") { return .disruption }
            return .info
        }

        var lineId: String {
            let cli = ligneCli ?? ""
            return cli.isEmpty ? (ligneCom ?? "") : cli
        }

        func isOngoing(at now: Date) -> Bool {
            if let end = fin.flatMap(AlertsService.parseDate), end < now { return false }
            if let start = debut.flatMap(AlertsService.parseDate), start > now { return false }
            return true
        }
    }

    /// Toutes les lignes en perturbation du réseau, gardées pour filtrer sans réseau si les abonnements changent.
    private struct NetworkState: Codable {
        let lines: [WidgetTrafficLine]
        let networkMajor: Int
    }

    struct Result {
        let disrupted: [WidgetTrafficLine]
        let networkMajor: Int
        let fetchedAt: Date
        let stale: Bool
    }

    private static let cacheKey = "alerts.network"
    private static let staleMaxAge: TimeInterval = 60 * 60

    private static let formatters: [DateFormatter] = ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"].map { format in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Paris")
        f.dateFormat = format
        return f
    }

    private static func parseDate(_ string: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }

    /// L'état des lignes suivies : les perturbées parmi `subscribed`, et le nombre d'alertes majeures du réseau.
    static func traffic(subscribed: [String], now: Date = Date()) async -> Result? {
        let state: NetworkState
        let fetchedAt: Date
        let stale: Bool
        do {
            let response = try await WidgetNetwork.json(Response.self, from: "\(ProxyEndpoint.baseURL)/alerts")
            let ongoing = response.values.filter { $0.isOngoing(at: now) }
            let byLine = Dictionary(grouping: ongoing.filter { $0.severity != .info && !$0.lineId.isEmpty }, by: \.lineId)
            let lines = byLine.compactMap { lineId, alerts -> WidgetTrafficLine? in
                guard let worst = alerts.min(by: { $0.severity < $1.severity }) else { return nil }
                return WidgetTrafficLine(line: lineId, severity: worst.severity, title: worst.titre ?? "")
            }
            state = NetworkState(lines: lines, networkMajor: ongoing.filter { $0.severity == .major }.count)
            WidgetStore.cache(state, key: cacheKey)
            fetchedAt = now
            stale = false
        } catch {
            AppLogger.debug("Alertes injoignables : \(error.localizedDescription)", category: .widget)
            guard let cached = WidgetStore.cached(NetworkState.self, key: cacheKey, maxAge: staleMaxAge) else { return nil }
            state = cached.value
            fetchedAt = cached.savedAt
            stale = true
        }
        let subscribedSet = Set(subscribed)
        let disrupted = state.lines
            .filter { subscribedSet.contains($0.line) }
            .sorted { ($0.severity, $0.line) < ($1.severity, $1.line) }
        return Result(disrupted: disrupted, networkMajor: state.networkMajor, fetchedAt: fetchedAt, stale: stale)
    }
}
