import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    private let seenKeysKey = "notificationSeenKeys"
    
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
    
    func scheduleAlertNotification(for alert: TCLAlert, phase: AlertNotificationPhase, preferences: Set<AlertSeverity>? = nil) {
        let key = alert.notificationKey(phase: phase)
        guard !hasSeen(key) else {
            AppLogger.debug("ℹ️ Notifications: Alerte \(alert.id) [\(phase.rawValue)] déjà notifiée")
            return
        }
        if let prefs = preferences, !prefs.contains(alert.severity) {
            AppLogger.debug("ℹ️ Notifications: Alerte \(alert.id) filtrée par préférences")
            return
        }

        let content = UNMutableNotificationContent()
        let emoji: String
        switch alert.severity {
        case .major:      emoji = "🔴"
        case .disruption: emoji = "🟠"
        case .info:       emoji = "🔵"
        }
        let lineLabel = alert.ligneCli.isEmpty ? alert.ligneCom : alert.ligneCli
        content.title = phase == .announced
            ? "📅 \(emoji) \(alert.mode.rawValue) \(lineLabel)"
            : "\(emoji) \(alert.mode.rawValue) \(lineLabel)"
        content.subtitle = phase == .announced
            ? "À venir · \(alert.titre)"
            : alert.titre
        content.body = alert.message
        content.sound = .default
        content.categoryIdentifier = "TCL_ALERT"
        content.threadIdentifier = "tcl-alerts-\(alert.ligneCom)"
        content.userInfo = [
            "alertId": alert.id,
            "lineId": alert.ligneCom,
            "lineCli": alert.ligneCli,
            "severity": alert.severity.rawValue,
            "type": "tcl_alert"
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "alert-\(alert.id)-\(phase.rawValue)",
            content: content,
            trigger: trigger
        )

        center.add(request) { [weak self] error in
            Task { @MainActor [weak self] in
                if let error {
                    AppLogger.debug("❌ Notifications: Erreur planification - \(error)")
                } else {
                    self?.markSeen(key)
                    self?.updateBadgeCount()
                    AppLogger.debug("✅ Notifications: Alerte \(lineLabel) [\(phase.rawValue)] planifiée")
                }
            }
        }
    }
    
    func processNewAlerts(_ alerts: [TCLAlert], subscriptionService: SubscriptionService) {
        let subscribedLines = subscriptionService.subscribedLineIds
        
        guard !subscribedLines.isEmpty else {
            AppLogger.debug("ℹ️ Notifications: Aucune ligne abonnée")
            return
        }
        
        let relevant = alerts.filter {
            subscribedLines.contains($0.ligneCom) || subscribedLines.contains($0.ligneCli)
        }
        AppLogger.debug("📬 Notifications: \(relevant.count) alertes pour les lignes abonnées")
        
        for alert in relevant {
            let line = TransportLine(ligneCom: alert.ligneCom, ligneCli: alert.ligneCli, mode: alert.mode)
            let preferences = subscriptionService.getNotificationPreferences(for: line)
            if alert.isUpcoming {
                scheduleAlertNotification(for: alert, phase: .announced, preferences: preferences)
            }
            if alert.isOngoing {
                scheduleAlertNotification(for: alert, phase: .active, preferences: preferences)
            }
        }
    }
    
    // MARK: - Deduplication

    private func hasSeen(_ key: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: seenKeysKey) ?? []).contains(key)
    }

    private func markSeen(_ key: String) {
        var keys = UserDefaults.standard.stringArray(forKey: seenKeysKey) ?? []
        keys.append(key)
        if keys.count > 500 { keys = Array(keys.suffix(250)) }
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

extension NotificationService: UNUserNotificationCenterDelegate {
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
