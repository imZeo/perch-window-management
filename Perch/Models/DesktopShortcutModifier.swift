import CoreGraphics
import Foundation

enum DesktopShortcutModifier: String, CaseIterable {
    case control
    case option
    case command

    var title: String {
        switch self {
        case .control:
            return "Control + Number"
        case .option:
            return "Option + Number"
        case .command:
            return "Command + Number"
        }
    }

    var eventFlags: CGEventFlags {
        switch self {
        case .control:
            return .maskControl
        case .option:
            return .maskAlternate
        case .command:
            return .maskCommand
        }
    }
}
