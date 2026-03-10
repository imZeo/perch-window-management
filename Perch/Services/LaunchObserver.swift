import AppKit

final class LaunchObserver {
    private var observers: [NSObjectProtocol] = []

    func start(onChange: @escaping () -> Void) {
        stop()

        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification
        ]

        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                onChange()
            }
        }
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    deinit {
        stop()
    }
}
