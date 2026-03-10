import Foundation
import OSLog

struct AppLogger {
    private let logger: Logger
    private let category: String
    private let diagnosticsStore: DiagnosticsStore

    init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "Perch",
        category: String,
        diagnosticsStore: DiagnosticsStore = .shared
    ) {
        logger = Logger(subsystem: subsystem, category: category)
        self.category = category
        self.diagnosticsStore = diagnosticsStore
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        diagnosticsStore.add(level: .info, category: category, message: message)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        diagnosticsStore.add(level: .error, category: category, message: message)
    }
}
