// Sources/RestackKit/Notifying.swift
import Foundation

/// Posts user-facing notifications for auto-restore events.
public protocol Notifying {
    /// Notify the user that Restack auto-restored a layout (offer Undo in the UI layer).
    func postAutoRestored()
    /// Called when a periodic autosave captured a layout that meaningfully differs from the
    /// last saved one for this config (or is the first capture for it). Layout only —
    /// title churn never triggers this. Quiet feedback; no system notification expected.
    func postLayoutAutosaved()
}

public extension Notifying {
    /// Default no-op so simple notifiers and test fakes need not care about autosave events.
    func postLayoutAutosaved() {}
}

#if canImport(UserNotifications)
import UserNotifications

/// Real notifier backed by UNUserNotificationCenter. The Undo action button is registered
/// via the notification category; the app delegate routes taps to the coordinator.
public final class UNUserNotificationNotifier: Notifying {
    public static let categoryID = "RESTACK_AUTO_RESTORE"
    public static let undoActionID = "RESTACK_UNDO"

    public init() {}

    /// Registers the notification category with an Undo action. Call once at startup.
    public func registerCategory() {
        let undo = UNNotificationAction(identifier: Self.undoActionID, title: "Undo", options: [])
        let category = UNNotificationCategory(identifier: Self.categoryID, actions: [undo],
                                              intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    public func postAutoRestored() {
        let content = UNMutableNotificationContent()
        content.title = "Restack"
        content.body = "Restored your layout for this display setup."
        content.categoryIdentifier = Self.categoryID
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
#endif
