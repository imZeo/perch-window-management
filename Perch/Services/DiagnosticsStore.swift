import Foundation

final class DiagnosticsStore {
    static let shared = DiagnosticsStore()
    static let didChangeNotification = Notification.Name("PerchDiagnosticsDidChange")

    private let lock = NSLock()
    private let capacity = 250
    private var entriesStorage: [DiagnosticsEntry] = []

    var entries: [DiagnosticsEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entriesStorage
    }

    func add(level: DiagnosticsEntry.Level, category: String, message: String) {
        lock.lock()
        entriesStorage.append(
            DiagnosticsEntry(
                timestamp: Date(),
                category: category,
                level: level,
                message: message
            )
        )

        if entriesStorage.count > capacity {
            entriesStorage.removeFirst(entriesStorage.count - capacity)
        }
        lock.unlock()

        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    func clear() {
        lock.lock()
        entriesStorage.removeAll()
        lock.unlock()

        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
