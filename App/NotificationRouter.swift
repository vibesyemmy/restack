// App/NotificationRouter.swift
import UserNotifications
import RestackKit

/// Routes the "Undo" action on an auto-restore notification back to `AppModel`.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    private let onUndo: () -> Void
    init(onUndo: @escaping () -> Void) { self.onUndo = onUndo; super.init() }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNUserNotificationNotifier.undoActionID {
            Task { @MainActor in onUndo() }
        }
        completionHandler()
    }
}
