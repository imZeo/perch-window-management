import AppKit

struct RunningAppInfo: Identifiable, Hashable {
    let id: String
    let bundleID: String
    let displayName: String
    let processIdentifier: pid_t
    let isActive: Bool
    let icon: NSImage?

    init(
        id: String,
        bundleID: String,
        displayName: String,
        processIdentifier: pid_t,
        isActive: Bool,
        icon: NSImage?
    ) {
        self.id = id
        self.bundleID = bundleID
        self.displayName = displayName
        self.processIdentifier = processIdentifier
        self.isActive = isActive
        self.icon = icon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(bundleID)
        hasher.combine(processIdentifier)
    }

    static func == (lhs: RunningAppInfo, rhs: RunningAppInfo) -> Bool {
        lhs.id == rhs.id &&
        lhs.bundleID == rhs.bundleID &&
        lhs.processIdentifier == rhs.processIdentifier &&
        lhs.displayName == rhs.displayName &&
        lhs.isActive == rhs.isActive
    }
}
