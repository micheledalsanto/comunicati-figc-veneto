import UserNotifications

enum NotificationManager {
    static func requestAuthorization() async {
        try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func sendNotification(for items: [Comunicato]) async {
        let content = UNMutableNotificationContent()
        content.sound = .default

        if items.count == 1 {
            content.title = "Nuovo Comunicato"
            content.body = items[0].title
        } else {
            content.title = "Nuovi Comunicati"
            content.body = "\(items.count) nuovi comunicati disponibili"
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
