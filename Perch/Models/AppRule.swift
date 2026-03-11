import Foundation

enum AssignmentTarget: Codable, Hashable {
    case desktop(Int)
    case allDesktops

    var desktopNumber: Int? {
        guard case .desktop(let number) = self else { return nil }
        return number
    }

    var displayName: String {
        switch self {
        case .desktop(let number):
            return "Desktop \(number)"
        case .allDesktops:
            return "All Desktops"
        }
    }
}

struct AppRule: Codable, Identifiable, Hashable {
    var id: String { bundleID }

    let bundleID: String
    var displayName: String
    var assignmentTarget: AssignmentTarget

    var desktopNumber: Int? {
        assignmentTarget.desktopNumber
    }

    var assignmentDisplayName: String {
        assignmentTarget.displayName
    }

    init(bundleID: String, displayName: String, assignmentTarget: AssignmentTarget) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.assignmentTarget = assignmentTarget
    }

    private enum CodingKeys: String, CodingKey {
        case bundleID
        case displayName
        case desktopNumber
        case assignmentTarget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        displayName = try container.decode(String.self, forKey: .displayName)

        if let assignmentTarget = try container.decodeIfPresent(AssignmentTarget.self, forKey: .assignmentTarget) {
            self.assignmentTarget = assignmentTarget
            return
        }

        let desktopNumber = try container.decode(Int.self, forKey: .desktopNumber)
        assignmentTarget = .desktop(desktopNumber)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleID, forKey: .bundleID)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(assignmentTarget, forKey: .assignmentTarget)
    }
}
