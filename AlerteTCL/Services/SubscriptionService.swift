import Foundation
import Combine

struct LineSubscription: Codable {
    let lineId: String
    var notificationTypes: Set<String>
}

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    private let subscriptionsKey = "lineSubscriptions"
    
    @Published private(set) var subscriptions: [String: LineSubscription] = [:]
    
    var subscribedLineIds: Set<String> {
        Set(subscriptions.keys)
    }
    
    private init() {
        loadSubscriptions()
    }
    
    private func loadSubscriptions() {
        if let data = UserDefaults.standard.data(forKey: subscriptionsKey),
           let saved = try? JSONDecoder().decode([String: LineSubscription].self, from: data) {
            subscriptions = saved
        }
    }
    
    private func saveSubscriptions() {
        if let data = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(data, forKey: subscriptionsKey)
        }
    }
    
    func isSubscribed(to lineId: String) -> Bool {
        subscriptions[lineId] != nil
    }
    
    func subscribe(to line: TransportLine, notificationTypes: Set<AlertSeverity> = Set(AlertSeverity.allCases)) {
        let types = Set(notificationTypes.map { $0.rawValue })
        subscriptions[line.ligneCom] = LineSubscription(lineId: line.ligneCom, notificationTypes: types)
        if !line.ligneCli.isEmpty && line.ligneCli != line.ligneCom {
            subscriptions[line.ligneCli] = LineSubscription(lineId: line.ligneCli, notificationTypes: types)
        }
        saveSubscriptions()
    }
    
    func unsubscribe(from line: TransportLine) {
        subscriptions.removeValue(forKey: line.ligneCom)
        if !line.ligneCli.isEmpty && line.ligneCli != line.ligneCom {
            subscriptions.removeValue(forKey: line.ligneCli)
        }
        saveSubscriptions()
    }
    
    func toggle(line: TransportLine) {
        if isSubscribed(to: line.ligneCom) || isSubscribed(to: line.ligneCli) {
            unsubscribe(from: line)
        } else {
            subscribe(to: line)
        }
    }
    
    func updateNotificationPreferences(for line: TransportLine, types: Set<AlertSeverity>) {
        let typeStrings = Set(types.map { $0.rawValue })
        if var sub = subscriptions[line.ligneCom] {
            sub.notificationTypes = typeStrings
            subscriptions[line.ligneCom] = sub
        }
        if !line.ligneCli.isEmpty && line.ligneCli != line.ligneCom {
            if var sub = subscriptions[line.ligneCli] {
                sub.notificationTypes = typeStrings
                subscriptions[line.ligneCli] = sub
            }
        }
        saveSubscriptions()
    }
    
    func getNotificationPreferences(for line: TransportLine) -> Set<AlertSeverity> {
        if let sub = subscriptions[line.ligneCom] {
            return Set(sub.notificationTypes.compactMap { AlertSeverity(rawValue: $0) })
        }
        return Set(AlertSeverity.allCases)
    }
    
}
