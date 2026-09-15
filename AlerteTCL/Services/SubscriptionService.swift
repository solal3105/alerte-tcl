import Foundation
import Combine
import Shared

/// Abonnements aux notifications, indépendants des lignes favorites.
///
/// Les règles (double code de ligne, types d'alertes par défaut) et le format enregistré viennent
/// du module partagé (`LineSubscriptions`), identiques sur Android ; ce service ne fait que
/// publier l'état et le conserver dans les réglages de l'application.
@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    private let subscriptionsKey = "lineSubscriptions"
    private let rules = LineSubscriptions.shared

    @Published private(set) var subscriptions: [String: LineSubscription] = [:]

    var subscribedLineIds: Set<String> {
        Set(subscriptions.keys)
    }

    private init() {
        #if DEBUG
        if DemoShowcase.isAlertsCase {
            subscriptions = DemoShowcase.subscriptions()
            return
        }
        #endif
        subscriptions = rules.decode(encoded: storedEncoded())
    }

    /// Les versions précédentes enregistraient le JSON en données binaires ; on lit les deux formes.
    private func storedEncoded() -> String? {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: subscriptionsKey) {
            return String(data: data, encoding: .utf8)
        }
        return defaults.string(forKey: subscriptionsKey)
    }

    private func apply(_ updated: [String: LineSubscription]) {
        subscriptions = updated
        #if DEBUG
        if DemoShowcase.isAlertsCase { return }  // jamais enregistré en démo
        #endif
        UserDefaults.standard.set(rules.encode(subscriptions: updated), forKey: subscriptionsKey)
    }

    func isSubscribed(to lineId: String) -> Bool {
        subscriptions[lineId] != nil
    }

    func isSubscribed(to line: TransportLine) -> Bool {
        rules.isSubscribed(subscriptions: subscriptions, line: line.shared)
    }

    func subscribe(to line: TransportLine, notificationTypes: Set<AlertSeverity> = Set(AlertSeverity.allCases)) {
        apply(rules.subscribe(subscriptions: subscriptions, line: line.shared, severities: Set(notificationTypes.map(\.shared))))
    }

    func unsubscribe(from line: TransportLine) {
        apply(rules.unsubscribe(subscriptions: subscriptions, line: line.shared))
    }

    func toggle(line: TransportLine) {
        apply(rules.toggle(subscriptions: subscriptions, line: line.shared))
    }

    func updateNotificationPreferences(for line: TransportLine, types: Set<AlertSeverity>) {
        subscribe(to: line, notificationTypes: types)
    }

    func getNotificationPreferences(for line: TransportLine) -> Set<AlertSeverity> {
        Set(rules.preferences(subscriptions: subscriptions, line: line.shared).compactMap { AlertSeverity(shared: $0) })
    }
}
