import Foundation
import UserNotifications
import UIKit
import Shared

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    private let seenKeysKey = "notificationSeenKeys"
    private let baselineDoneKey = "notifBaselineDone"
    
    @Published var isAuthorized = false
    
    private override init() {
        super.init()
        center.delegate = self
        registerNotificationCategories()
        checkAuthorizationStatus()
    }

    private func registerNotificationCategories() {
        let alertCategory = UNNotificationCategory(
            identifier: "TCL_ALERT",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([alertCategory])
    }
    
    // MARK: - Permission Management
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
            isAuthorized = granted
            AppLogger.debug("✅ Notifications: Permission \(granted ? "accordée" : "refusée")")
            return granted
        } catch {
            AppLogger.error("Notifications: Erreur permission - \(error)", category: .notifications)
            return false
        }
    }

    func checkAuthorizationStatus() {
        Task {
            let settings = await center.notificationSettings()
            let authorized = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            isAuthorized = authorized
        }
    }
    
    // MARK: - Alert Notifications

    /// Applique la règle commune (`AlertNotifications`) : premier passage silencieux, puis une
    /// notification par alerte et par phase (annoncée, en cours) pour les lignes abonnées.
    func processNewAlerts(_ alerts: [TCLAlert], subscriptionService: SubscriptionService) {
        let subscriptions = subscriptionService.subscriptions
        guard !subscriptions.isEmpty else { return }
        let rules = AlertNotifications.shared
        let sharedAlerts = alerts.map(\.shared)
        let defaults = UserDefaults.standard

        if !defaults.bool(forKey: baselineDoneKey) {
            let baseline = rules.baselineKeys(alerts: sharedAlerts, subscriptions: subscriptions)
            saveSeen(rules.remember(seenKeys: seenKeys, newKeys: Array(baseline)))
            defaults.set(true, forKey: baselineDoneKey)
            AppLogger.debug("ℹ️ Notifications: baseline (\(baseline.count / 2) alertes silencieuses)")
            return
        }

        let pending = rules.pending(
            alerts: sharedAlerts,
            subscriptions: subscriptions,
            seenKeys: Set(seenKeys),
            nowEpoch: Int64(Date().timeIntervalSince1970)
        )
        AppLogger.debug("📬 Notifications: \(pending.count) notification(s) à émettre")
        pending.forEach(schedule)
    }

    private func schedule(_ pending: AlertNotifications.Pending) {
        let alert = pending.alert
        let rules = AlertNotifications.shared
        let content = UNMutableNotificationContent()
        content.title = rules.title(alert: alert, phase: pending.phase)
        content.subtitle = rules.subtitle(alert: alert, phase: pending.phase)
        content.body = alert.message
        content.sound = .default
        content.categoryIdentifier = "TCL_ALERT"
        content.threadIdentifier = "tcl-alerts-\(alert.ligneCom)"
        content.userInfo = [
            "alertId": alert.id,
            "lineId": alert.ligneCom,
            "lineCli": alert.ligneCli,
            "severity": alert.severity.displayName,
            "type": "tcl_alert"
        ]

        let request = UNNotificationRequest(
            identifier: "alert-\(alert.id)-\(pending.phase.name)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        let key = pending.key
        let title = content.title
        center.add(request) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    AppLogger.debug("❌ Notifications: Erreur planification - \(error)")
                } else {
                    self.saveSeen(AlertNotifications.shared.remember(seenKeys: self.seenKeys, newKeys: [key]))
                    self.updateBadgeCount()
                    AppLogger.debug("✅ Notifications: \(title) planifiée")
                }
            }
        }
    }

    // MARK: - Deduplication

    private var seenKeys: [String] {
        UserDefaults.standard.stringArray(forKey: seenKeysKey) ?? []
    }

    private func saveSeen(_ keys: [String]) {
        UserDefaults.standard.set(keys, forKey: seenKeysKey)
    }

    // MARK: - Badge Management
    
    func updateBadgeCount() {
        Task {
            let pending = await center.pendingNotificationRequests()
            let delivered = await center.deliveredNotifications()
            let count = pending.filter { $0.content.userInfo["type"] as? String == "tcl_alert" }.count
                + delivered.filter { $0.request.content.userInfo["type"] as? String == "tcl_alert" }.count
            do {
                try await center.setBadgeCount(count)
            } catch {
                AppLogger.error("Notifications: Erreur mise à jour badge - \(error)", category: .notifications)
            }
        }
    }

    func clearBadge() {
        Task {
            do {
                try await center.setBadgeCount(0)
            } catch {
                AppLogger.error("Notifications: Erreur réinitialisation badge - \(error)", category: .notifications)
            }
        }
    }
    
    // MARK: - Cleanup
    
    func clearAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        clearBadge()
    }
    
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: @preconcurrency UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Afficher la notification même si l'app est au premier plan
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let alertId = userInfo["alertId"] as? String {
            AppLogger.debug("📱 Notifications: Tap sur alerte \(alertId)")
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenAlertDetail"),
                object: nil,
                userInfo: userInfo
            )
        }
        
        completionHandler()
    }
}
