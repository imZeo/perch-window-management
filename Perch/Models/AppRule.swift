import Foundation

struct AppRule: Codable, Identifiable, Hashable {
    var id: String { bundleID }

    let bundleID: String
    var displayName: String
    var desktopNumber: Int
}
