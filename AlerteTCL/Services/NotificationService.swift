import Foundation
import UserNotifications
import UIKit

final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    private let notifiedAlertsKey = "notifiedAlertIds"
    private let lastCheckKey = "lastAlertCheckDate"
    
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
            await MainActor.run { self.isAuthorized = granted }
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
            await MainActor.run { self.isAuthorized = authorized }
        }
    }
    
    // MARK: - Alert Notifications
    
    func scheduleAlertNotification(for alert: TCLAlert, preferences: Set<AlertSeverity>? = nil) {
        // Vérifier si on a déjà notifié cette alerte
        guard !hasNotified(alert) else {
            AppLogger.debug("ℹ️ Notifications: Alerte \(alert.id) déjà notifiée")
            return
        }
        
        // Vérifier si le type de sévérité est dans les préférences
        if let prefs = preferences, !prefs.contains(alert.severity) {
            AppLogger.debug("ℹ️ Notifications: Alerte \(alert.id) filtrée par préférences")
            return
        }
        
        let content = UNMutableNotificationContent()
        
        // Emoji basé sur la sévérité
        let emoji: String
        switch alert.severity {
        case .major: emoji = "🔴"
        case .disruption: emoji = "🟠"
        case .info: emoji = "🔵"
        }
        
        content.title = "\(emoji) \(alert.mode.rawValue) \(alert.ligneCli.isEmpty ? alert.ligneCom : alert.ligneCli)"
        content.subtitle = alert.titre
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
        
        // Notification immédiate
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "alert-\(alert.id)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { [weak self] error in
            if let error = error {
                AppLogger.debug("❌ Notifications: Erreur planification - \(error)")
            } else {
                self?.markAsNotified(alert)
                // Met à jour le badge après ajout
                self?.updateBadgeCount()
                AppLogger.debug("✅ Notifications: Alerte \(alert.ligneCli) planifiée")
            }
        }
    }
    
    @MainActor
    func processNewAlerts(_ alerts: [TCLAlert], subscriptionService: SubscriptionService) {
        let subscribedLines = subscriptionService.subscribedLineIds
        
        guard !subscribedLines.isEmpty else {
            AppLogger.debug("ℹ️ Notifications: Aucune ligne abonnée")
            return
        }
        
        let relevantAlerts = alerts.filter { alert in
            subscribedLines.contains(alert.ligneCom) || subscribedLines.contains(alert.ligneCli)
        }
        
        AppLogger.debug("📬 Notifications: \(relevantAlerts.count) alertes pour les lignes abonnées")
        
        for alert in relevantAlerts {
            // Récupérer les préférences de notification pour cette ligne
            let line = TransportLine(ligneCom: alert.ligneCom, ligneCli: alert.ligneCli, mode: alert.mode)
            let preferences = subscriptionService.getNotificationPreferences(for: line)
            
            scheduleAlertNotification(for: alert, preferences: preferences)
        }
        
        // Mettre à jour la date de dernière vérification
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
    }
    
    // MARK: - Notification History
    
    private func hasNotified(_ alert: TCLAlert) -> Bool {
        let notifiedIds = UserDefaults.standard.stringArray(forKey: notifiedAlertsKey) ?? []
        return notifiedIds.contains(alert.id)
    }
    
    private func markAsNotified(_ alert: TCLAlert) {
        var notifiedIds = UserDefaults.standard.stringArray(forKey: notifiedAlertsKey) ?? []
        notifiedIds.append(alert.id)
        
        // Garder seulement les 200 dernières pour éviter de grossir indéfiniment
        if notifiedIds.count > 200 {
            notifiedIds = Array(notifiedIds.suffix(100))
        }
        
        UserDefaults.standard.set(notifiedIds, forKey: notifiedAlertsKey)
    }
    
    // MARK: - Badge Management
    
    func updateBadgeCount() {
        Task { [weak self] in
            guard let self else { return }
            let pending = await self.center.pendingNotificationRequests()
            let delivered = await self.center.deliveredNotifications()
            let pendingCount = pending.filter { $0.content.userInfo["type"] as? String == "tcl_alert" }.count
            let deliveredCount = delivered.filter { $0.request.content.userInfo["type"] as? String == "tcl_alert" }.count
            let count = pendingCount + deliveredCount
            do {
                try await self.center.setBadgeCount(count)
            } catch {
                AppLogger.error("Notifications: Erreur mise à jour badge - \(error)", category: .notifications)
            }
        }
    }

    func clearBadge() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.center.setBadgeCount(0)
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
            AppLogger.debug("📱 Notifications: Utilisateur a tapé sur l'alerte \(alertId)")
            // On pourrait poster une notification pour ouvrir les détails de l'alerte
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenAlertDetail"),
                object: nil,
                userInfo: userInfo
            )
        }
        
        completionHandler()
    }
}
