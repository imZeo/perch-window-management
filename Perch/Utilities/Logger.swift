import Foundation
import OSLog

struct AppLogger {
    private let logger: Logger

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "SpaceLauncher", category: String) {
        logger = Logger(subsystem: subsystem, category: category)
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
