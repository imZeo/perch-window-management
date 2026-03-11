import Cocoa

final class SpaceSwitcher {
    private let logger = AppLogger(category: "SpaceSwitcher")

    func switchToDesktop(_ number: Int, modifier: DesktopShortcutModifier) {
        guard (1...9).contains(number) else { return }
        guard let keyCode = keyCode(for: number) else { return }

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = modifier.eventFlags
        keyUp?.flags = modifier.eventFlags

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        logger.info("Posted \(modifier.title) shortcut for desktop \(number)")
    }

    private func keyCode(for number: Int) -> CGKeyCode? {
        switch number {
        case 1: return 18
        case 2: return 19
        case 3: return 20
        case 4: return 21
        case 5: return 23
        case 6: return 22
        case 7: return 26
        case 8: return 28
        case 9: return 25
        default: return nil
        }
    }
}

final class DockAssignmentService {
    enum NativeAssignment {
        case allDesktops
        case none

        var labels: [String] {
            switch self {
            case .allDesktops:
                return ["All Desktops", "All Spaces"]
            case .none:
                return ["None"]
            }
        }

        var title: String {
            switch self {
            case .allDesktops:
                return "All Desktops"
            case .none:
                return "None"
            }
        }
    }

    private let logger = AppLogger(category: "DockAssignmentService")

    func apply(_ assignment: NativeAssignment, bundleID: String, displayName: String) -> Bool {
        var lastErrorDescription = "Unknown error"

        for label in assignment.labels {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: scriptSource(displayName: displayName, assignmentLabel: label)) else {
                lastErrorDescription = "Could not create AppleScript"
                continue
            }

            script.executeAndReturnError(&error)

            if error == nil {
                logger.info("Applied native \(assignment.title) assignment to \(bundleID)")
                return true
            }

            lastErrorDescription = error?.description ?? lastErrorDescription
        }

        logger.error("Failed to apply native \(assignment.title) assignment to \(bundleID): \(lastErrorDescription)")
        return false
    }

    private func scriptSource(displayName: String, assignmentLabel: String) -> String {
        let escapedDisplayName = escapeAppleScript(displayName)
        let escapedAssignmentLabel = escapeAppleScript(assignmentLabel)

        return """
        tell application "System Events"
            tell process "Dock"
                set appTile to first UI element of list 1 whose name is "\(escapedDisplayName)"
                perform action "AXShowMenu" of appTile
                delay 0.2
                click menu item "\(escapedAssignmentLabel)" of menu 1 of menu item "Assign To" of menu 1 of menu item "Options" of menu 1 of appTile
            end tell
        end tell
        """
    }

    private func escapeAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
