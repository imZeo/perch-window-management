import AppKit

@objc
protocol MenuActionHandling: AnyObject {
    @objc func handleMenuAction(_ sender: NSMenuItem)
}

enum MenuCommand {
    case openAssigned(bundleID: String)
    case assign(bundleID: String, displayName: String, desktopNumber: Int)
    case clear(bundleID: String)
    case refresh
    case requestAccessibility
    case showRules
    case quit
}

final class MenuCommandBox: NSObject {
    let command: MenuCommand

    init(command: MenuCommand) {
        self.command = command
    }
}

final class MenuBuilder {
    private let maxDesktopAssignments = 9

    func makeMenu(
        runningApps: [RunningAppInfo],
        rules: [AppRule],
        accessibilityTrusted: Bool,
        target: MenuActionHandling
    ) -> NSMenu {
        let menu = NSMenu()

        menu.addItem(sectionHeader("Running Apps"))
        if runningApps.isEmpty {
            menu.addItem(disabledItem("No regular apps running"))
        } else {
            runningApps.forEach { app in
                menu.addItem(runningAppItem(app, rules: rules, target: target))
            }
        }

        menu.addItem(.separator())
        menu.addItem(sectionHeader("Saved Rules"))
        if rules.isEmpty {
            menu.addItem(disabledItem("No saved assignments"))
        } else {
            rules.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }.forEach { rule in
                let title = "\(rule.displayName) -> Desktop \(rule.desktopNumber)"
                menu.addItem(disabledItem(title))
            }
        }

        menu.addItem(.separator())
        menu.addItem(sectionHeader("Permissions"))
        let permissionTitle = accessibilityTrusted ? "Accessibility Granted" : "Request Accessibility Access"
        let permissionItem = actionItem(
            permissionTitle,
            command: .requestAccessibility,
            target: target
        )
        permissionItem.state = accessibilityTrusted ? .on : .off
        menu.addItem(permissionItem)

        menu.addItem(.separator())
        menu.addItem(actionItem("Settings", command: .showRules, target: target))
        menu.addItem(actionItem("Refresh", command: .refresh, target: target))
        menu.addItem(actionItem("Quit", command: .quit, target: target))

        return menu
    }

    private func runningAppItem(
        _ app: RunningAppInfo,
        rules: [AppRule],
        target: MenuActionHandling
    ) -> NSMenuItem {
        let item = NSMenuItem(title: app.displayName, action: nil, keyEquivalent: "")
        item.image = app.icon

        let submenu = NSMenu(title: app.displayName)
        if let rule = rules.first(where: { $0.bundleID == app.bundleID }) {
            submenu.addItem(actionItem(
                "Open on Desktop \(rule.desktopNumber)",
                command: .openAssigned(bundleID: app.bundleID),
                target: target
            ))
        } else {
            submenu.addItem(disabledItem("No desktop assigned"))
        }

        submenu.addItem(.separator())

        for desktop in 1...maxDesktopAssignments {
            let assignmentItem = actionItem(
                "Assign to Desktop \(desktop)",
                command: .assign(bundleID: app.bundleID, displayName: app.displayName, desktopNumber: desktop),
                target: target
            )
            assignmentItem.state = rules.first(where: { $0.bundleID == app.bundleID })?.desktopNumber == desktop ? .on : .off
            submenu.addItem(assignmentItem)
        }

        submenu.addItem(.separator())
        submenu.addItem(actionItem("Clear Assignment", command: .clear(bundleID: app.bundleID), target: target))

        item.submenu = submenu
        return item
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(
        _ title: String,
        command: MenuCommand,
        target: MenuActionHandling
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(MenuActionHandling.handleMenuAction(_:)), keyEquivalent: "")
        item.target = target
        item.representedObject = MenuCommandBox(command: command)
        return item
    }
}
