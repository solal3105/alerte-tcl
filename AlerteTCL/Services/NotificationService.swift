import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    private let notifiedAlertsKey = "notifiedAlertIds"
    
    private init() {}
    
    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            print("Notifications permission granted: \(granted)")
        }
    }
    
    func scheduleAlertNotification(for alert: TCLAlert) {
        guard !hasNotified(alert) else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🚨 \(alert.mode.rawValue) \(alert.ligneCli)"
        content.subtitle = alert.titre
        content.body = alert.message
        content.sound = .default
        content.categoryIdentifier = "ALERT_CATEGORY"
        
        content.userInfo = [
            "alertId": alert.id,
            "lineId": alert.ligneCom,
            "severity": alert.severity.rawValue
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: alert.id,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { [weak self] error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            } else {
                self?.markAsNotified(alert)
            }
        }
    }
    
    func scheduleNotifications(for alerts: [TCLAlert], subscribedLines: Set<String>) {
        let relevantAlerts = alerts.filter { alert in
            subscribedLines.contains(alert.ligneCom) || subscribedLines.contains(alert.ligneCli)
        }
        
        for alert in relevantAlerts {
            scheduleAlertNotification(for: alert)
        }
    }
    
    private func hasNotified(_ alert: TCLAlert) -> Bool {
        let notifiedIds = UserDefaults.standard.stringArray(forKey: notifiedAlertsKey) ?? []
        return notifiedIds.contains(alert.id)
    }
    
    private func markAsNotified(_ alert: TCLAlert) {
        var notifiedIds = UserDefaults.standard.stringArray(forKey: notifiedAlertsKey) ?? []
        notifiedIds.append(alert.id)
        
        if notifiedIds.count > 100 {
            notifiedIds = Array(notifiedIds.suffix(50))
        }
        
        UserDefaults.standard.set(notifiedIds, forKey: notifiedAlertsKey)
    }
    
    func clearAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
    
    func resetNotificationHistory() {
        UserDefaults.standard.removeObject(forKey: notifiedAlertsKey)
    }
}
