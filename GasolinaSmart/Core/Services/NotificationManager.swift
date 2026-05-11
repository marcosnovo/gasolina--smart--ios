import Foundation
import UserNotifications

@Observable
final class NotificationManager {
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var enabledAlertTypes: Set<AlertType> {
        didSet { savePreferences() }
    }

    private let defaults = UserDefaults.standard
    private let enabledAlertsKey = "enabledAlertTypes"

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    var hasBeenDenied: Bool {
        authorizationStatus == .denied
    }

    init() {
        let saved = defaults.stringArray(forKey: enabledAlertsKey) ?? []
        enabledAlertTypes = Set(saved.compactMap { AlertType(rawValue: $0) })
        Task { await refreshAuthorizationStatus() }
    }

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                authorizationStatus = granted ? .authorized : .denied
            }
        } catch {
            await MainActor.run {
                authorizationStatus = .denied
            }
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            authorizationStatus = settings.authorizationStatus
        }
    }

    func toggleAlertType(_ type: AlertType) {
        if enabledAlertTypes.contains(type) {
            enabledAlertTypes.remove(type)
        } else {
            enabledAlertTypes.insert(type)
        }
    }

    func isAlertEnabled(_ type: AlertType) -> Bool {
        enabledAlertTypes.contains(type)
    }

    func scheduleNotification(title: String, body: String, identifier: String) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func removeAllPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func savePreferences() {
        let raw = enabledAlertTypes.map(\.rawValue)
        defaults.set(raw, forKey: enabledAlertsKey)
    }
}
