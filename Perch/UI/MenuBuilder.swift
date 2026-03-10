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
    case showDiagnostics
    case quit
}

final class MenuCommandBox: NSObject {
    let command: MenuCommand

    init(command: MenuCommand) {
        self.command = command
    }
}

final class MenuBuilder {
    func makeMenu(
        runningApps: [RunningAppInfo],
        rules: [AppRule],
        accessibilityTrusted: Bool,
        maxDesktopAssignments: Int,
        target: MenuActionHandling
    ) -> NSMenu {
        let menu = NSMenu()

        menu.addItem(sectionHeader("Running Apps"))
        if runningApps.isEmpty {
            menu.addItem(disabledItem("No regular apps running"))
        } else {
            runningApps.forEach { app in
                menu.addItem(
                    runningAppItem(
                        app,
                        rules: rules,
                        maxDesktopAssignments: maxDesktopAssignments,
                        target: target
                    )
                )
            }
        }

        menu.addItem(.separator())
        menu.addItem(sectionHeader("Saved Rules"))
        if rules.isEmpty {
            menu.addItem(disabledItem("No saved assignments"))
        } else {
            let runningBundleIDs = Set(runningApps.map(\.bundleID))
            rules.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }.forEach { rule in
                menu.addItem(savedRuleItem(rule, isRunning: runningBundleIDs.contains(rule.bundleID), target: target))
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
        permissionItem.state = accessibilityTrusted ? NSControl.StateValue.on : NSControl.StateValue.off
        menu.addItem(permissionItem)

        menu.addItem(.separator())
        menu.addItem(actionItem("Settings", command: .showRules, target: target))
        menu.addItem(actionItem("Diagnostics", command: .showDiagnostics, target: target))
        menu.addItem(actionItem("Refresh", command: .refresh, target: target))
        menu.addItem(actionItem("Quit", command: .quit, target: target))

        return menu
    }

    private func runningAppItem(
        _ app: RunningAppInfo,
        rules: [AppRule],
        maxDesktopAssignments: Int,
        target: MenuActionHandling
    ) -> NSMenuItem {
        let item = NSMenuItem(title: app.displayName, action: nil, keyEquivalent: "")
        item.image = app.icon

        let submenu = NSMenu(title: app.displayName)
        let assignedDesktop = rules.first(where: { $0.bundleID == app.bundleID })?.desktopNumber

        if let assignedDesktop {
            submenu.addItem(actionItem(
                "Open on Desktop \(assignedDesktop)",
                command: .openAssigned(bundleID: app.bundleID),
                target: target
            ))
        } else {
            submenu.addItem(disabledItem("No desktop assigned"))
        }

        submenu.addItem(.separator())

        let desktopLimit = max(maxDesktopAssignments, assignedDesktop ?? 1)
        for desktop in 1...desktopLimit {
            let assignmentItem = actionItem(
                "Assign to Desktop \(desktop)",
                command: .assign(bundleID: app.bundleID, displayName: app.displayName, desktopNumber: desktop),
                target: target
            )
            assignmentItem.state = assignedDesktop == desktop ? NSControl.StateValue.on : NSControl.StateValue.off
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

    private func savedRuleItem(
        _ rule: AppRule,
        isRunning: Bool,
        target: MenuActionHandling
    ) -> NSMenuItem {
        let item = NSMenuItem(title: "\(rule.displayName) -> Desktop \(rule.desktopNumber)", action: nil, keyEquivalent: "")

        let submenu = NSMenu(title: rule.displayName)
        submenu.addItem(
            actionItem(
                isRunning ? "Open on Assigned Desktop" : "Launch on Assigned Desktop",
                command: .openAssigned(bundleID: rule.bundleID),
                target: target
            )
        )
        submenu.addItem(.separator())
        submenu.addItem(actionItem("Clear Assignment", command: .clear(bundleID: rule.bundleID), target: target))

        item.submenu = submenu
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
