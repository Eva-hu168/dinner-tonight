import Foundation
import UserNotifications

enum Reminders {
    private static let identifier = "dinner-feedback"
    private static let hour = 10

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// One reminder at a time: a new choice replaces the previous request, which shares its identifier.
    static func scheduleFeedback(dishName: String) {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else { return }
        var when = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        when.hour = hour
        let content = UNMutableNotificationContent()
        content.title = "How was dinner?"
        content.body = "Did you make \(dishName)? Tell me and I'll pick better."
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
