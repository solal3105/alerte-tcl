import Foundation
import UserNotifications
import UIKit

final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    private let notifiedAlertsKey = "notifiedAlertIds"
    private let lastCheckKey = "lastAlertCheckDate"
    
    @Published var isAuthorized = false
    @Published var pendingNotificationsCount = 0
    
    private override init() {
        super.init()
        center.delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - Permission Management
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
            await MainActor.run {
                self.isAuthorized = granted
            }
            print("✅ Notifications: Permission \(granted ? "accordée" : "refusée")")
            return granted
        } catch {
            print("❌ Notifications: Erreur permission - \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized ||
                                    settings.authorizationStatus == .provisional
            }
        }
    }
    
    // MARK: - Alert Notifications
    
    func scheduleAlertNotification(for alert: TCLAlert, preferences: Set<AlertSeverity>? = nil) {
        // Vérifier si on a déjà notifié cette alerte
        guard !hasNotified(alert) else {
            print("ℹ️ Notifications: Alerte \(alert.id) déjà notifiée")
            return
        }
        
        // Vérifier si le type de sévérité est dans les préférences
        if let prefs = preferences, !prefs.contains(alert.severity) {
            print("ℹ️ Notifications: Alerte \(alert.id) filtrée par préférences")
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
        content.sound = alert.severity == .major ? .defaultCritical : .default
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
                print("❌ Notifications: Erreur planification - \(error)")
            } else {
                self?.markAsNotified(alert)
                // Met à jour le badge après ajout
                self?.updateBadgeCount()
                print("✅ Notifications: Alerte \(alert.ligneCli) planifiée")
            }
        }
    }
    
    func processNewAlerts(_ alerts: [TCLAlert], subscriptionService: SubscriptionService) {
        let subscribedLines = subscriptionService.subscribedLineIds
        
        guard !subscribedLines.isEmpty else {
            print("ℹ️ Notifications: Aucune ligne abonnée")
            return
        }
        
        let relevantAlerts = alerts.filter { alert in
            subscribedLines.contains(alert.ligneCom) || subscribedLines.contains(alert.ligneCli)
        }
        
        print("📬 Notifications: \(relevantAlerts.count) alertes pour les lignes abonnées")
        
        for alert in relevantAlerts {
            // Récupérer les préférences de notification pour cette ligne
            let line = TransportLine(ligneCom: alert.ligneCom, ligneCli: alert.ligneCli, mode: alert.mode)
            let preferences = subscriptionService.getNotificationPreferences(for: line)
            
            scheduleAlertNotification(for: alert, preferences: preferences)
        }
        
        // Mettre à jour la date de dernière vérification
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
    }
    
    func scheduleNotifications(for alerts: [TCLAlert], subscribedLines: Set<String>) {
        let relevantAlerts = alerts.filter { alert in
            subscribedLines.contains(alert.ligneCom) || subscribedLines.contains(alert.ligneCli)
        }
        
        for alert in relevantAlerts {
            scheduleAlertNotification(for: alert)
        }
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
        center.getPendingNotificationRequests { [weak self] requests in
            let count = requests.filter { $0.content.userInfo["type"] as? String == "tcl_alert" }.count
            DispatchQueue.main.async {
                self?.pendingNotificationsCount = count
            }
            self?.center.setBadgeCount(count) { error in
                if let error = error {
                    print("❌ Notifications: Erreur mise à jour badge - \(error)")
                }
            }
        }
    }
    
    func clearBadge() {
        center.setBadgeCount(0) { error in
            if let error = error {
                print("❌ Notifications: Erreur réinitialisation badge - \(error)")
            }
        }
    }
    
    // MARK: - Cleanup
    
    func clearAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        clearBadge()
    }
    
    func resetNotificationHistory() {
        UserDefaults.standard.removeObject(forKey: notifiedAlertsKey)
        UserDefaults.standard.removeObject(forKey: lastCheckKey)
    }
    
    // MARK: - Background Refresh
    
    var lastCheckDate: Date? {
        UserDefaults.standard.object(forKey: lastCheckKey) as? Date
    }
    
    func shouldCheckForNewAlerts() -> Bool {
        guard let lastCheck = lastCheckDate else { return true }
        // Vérifier toutes les 5 minutes maximum
        return Date().timeIntervalSince(lastCheck) > 300
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
            print("📱 Notifications: Utilisateur a tapé sur l'alerte \(alertId)")
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
