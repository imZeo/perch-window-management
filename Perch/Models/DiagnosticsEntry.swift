import Foundation

struct DiagnosticsEntry: Identifiable {
    enum Level: String {
        case info = "INFO"
        case error = "ERROR"
    }

    let id = UUID()
    let timestamp: Date
    let category: String
    let level: Level
    let message: String
}
