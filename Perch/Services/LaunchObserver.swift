import AppKit

final class LaunchObserver {
    enum Event {
        case launched(NSRunningApplication)
        case terminated
        case activated
    }

    private var observers: [NSObjectProtocol] = []

    func start(onEvent: @escaping (Event) -> Void) {
        stop()

        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { notification in
                guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                    return
                }
                onEvent(.launched(application))
            },
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { _ in
                onEvent(.terminated)
            },
            center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { _ in
                onEvent(.activated)
            }
        ]
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
