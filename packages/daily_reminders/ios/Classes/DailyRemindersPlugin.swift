import Flutter
import UIKit
import UserNotifications

public class DailyRemindersPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private static let queue = DispatchQueue(label: "chimin.remindme.reminders")
    private static let prefix = "daily_task_reminder_"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = DailyRemindersPlugin()
        let channel = FlutterMethodChannel(name: "chimin.remindme/reminders", binaryMessenger: registrar.messenger())
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard notification.request.content.userInfo["dailyReminder"] as? Bool == true else { return }
        if #available(iOS 14.0, *) { completionHandler([.banner, .list, .sound]) }
        else { completionHandler([.alert, .sound]) }
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        guard response.notification.request.content.userInfo["dailyReminder"] as? Bool == true else { return }
        channel?.invokeMethod("openHome", arguments: nil)
        completionHandler()
    }

    private static func summary(_ tasks: [[String: Any]], on date: Date, calendar: Calendar) -> UNMutableNotificationContent? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let today = (components.year ?? 0) * 10000 + (components.month ?? 0) * 100 + (components.day ?? 0)
        var overdue = 0
        var dueToday = 0
        var titles: [String] = []
        for task in tasks {
            guard task["completed"] as? Bool != true, task["deleted"] as? Bool != true,
                  let year = task["year"] as? Int, let month = task["month"] as? Int,
                  let day = task["day"] as? Int else { continue }
            let due = year * 10000 + month * 100 + day
            if due > today { continue }
            if due == today { dueToday += 1 } else { overdue += 1 }
            titles.append(task["title"] as? String ?? "(Untitled)")
        }
        if titles.isEmpty { return nil }
        let content = UNMutableNotificationContent()
        content.title = "\(overdue) overdue · \(dueToday) today"
        content.body = String(titles.joined(separator: "\n").prefix(20000))
        content.sound = .default
        content.userInfo = ["dailyReminder": true]
        return content
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let center = UNUserNotificationCenter.current()
        if call.method == "requestPermission" {
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError(code: "permission", message: error.localizedDescription, details: nil))
                    } else { result(nil) }
                }
            }
        } else if call.method == "replace", let state = call.arguments as? [String: Any] {
            Self.queue.async {
                // Serialize the entire replacement, including asynchronous center operations.
                let ids = (0..<60).map { Self.prefix + String($0) }
                center.removePendingNotificationRequests(withIdentifiers: ids)
                center.removeDeliveredNotifications(withIdentifiers: ids)
                let immediateID = Self.prefix + "now"
                let enabled = state["active"] as? Bool == true && state["enabled"] as? Bool == true
                let notifyNow = state["notifyNow"] as? Bool == true
                if !enabled || notifyNow {
                    center.removePendingNotificationRequests(withIdentifiers: [immediateID])
                    center.removeDeliveredNotifications(withIdentifiers: [immediateID])
                }
                var failure: Error?
                if enabled {
                    let calendar = Calendar.current
                    let now = Date()
                    let start = calendar.startOfDay(for: now)
                    let tasks = state["tasks"] as? [[String: Any]] ?? []
                    if notifyNow, let content = Self.summary(tasks, on: now, calendar: calendar) {
                        let request = UNNotificationRequest(identifier: immediateID, content: content,
                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
                        let done = DispatchSemaphore(value: 0)
                        center.add(request) { error in failure = failure ?? error; done.signal() }
                        done.wait()
                    } else if Self.summary(tasks, on: now, calendar: calendar) == nil {
                        center.removePendingNotificationRequests(withIdentifiers: [immediateID])
                        center.removeDeliveredNotifications(withIdentifiers: [immediateID])
                    }
                    for offset in 0..<60 {
                        guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                              let date = calendar.date(bySettingHour: state["hour"] as? Int ?? 8,
                                  minute: state["minute"] as? Int ?? 0, second: 0, of: day), date > now else { continue }
                        guard let content = Self.summary(tasks, on: day, calendar: calendar) else { continue }
                        var triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                        triggerDate.timeZone = calendar.timeZone
                        let request = UNNotificationRequest(identifier: ids[offset], content: content,
                            trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false))
                        let done = DispatchSemaphore(value: 0)
                        center.add(request) { error in failure = failure ?? error; done.signal() }
                        done.wait()
                    }
                }
                DispatchQueue.main.async {
                    if let error = failure {
                        result(FlutterError(code: "schedule", message: error.localizedDescription, details: nil))
                    } else { result(nil) }
                }
            }
        } else { result(FlutterMethodNotImplemented) }
    }
}
