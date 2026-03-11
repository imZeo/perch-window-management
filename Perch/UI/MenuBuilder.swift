import AppKit

@objc
protocol MenuActionHandling: AnyObject {
    @objc func handleMenuAction(_ sender: NSMenuItem)
}

enum MenuCommand {
    case openAssigned(bundleID: String)
    case assign(bundleID: String, displayName: String, assignmentTarget: AssignmentTarget)
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
    private let menuAppIconSize = NSSize(width: 24, height: 24)
    private let experimentalAllDesktopsTitle = "Assigned to All Desktops (Experimental)"
    private let assignAllDesktopsTitle = "Assign to All Desktops (Experimental)"

    func makeMenu(
        runningApps: [RunningAppInfo],
        rules: [AppRule],
        accessibilityTrusted: Bool,
        maxDesktopAssignments: Int,
        target: MenuActionHandling
    ) -> NSMenu {
        let menu = NSMenu()
        let rulesByBundleID = Dictionary(uniqueKeysWithValues: rules.map { ($0.bundleID, $0) })

        menu.addItem(sectionHeader("Unassigned Apps"))
        if runningApps.isEmpty {
            menu.addItem(disabledItem("No regular apps running"))
        } else {
            let sortedApps = runningApps.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            let unassignedApps = sortedApps.filter { rulesByBundleID[$0.bundleID] == nil }
            let assignedApps: [(app: RunningAppInfo, target: AssignmentTarget)] = sortedApps.compactMap { app in
                guard let rule = rulesByBundleID[app.bundleID] else { return nil }
                return (app: app, target: rule.assignmentTarget)
            }
            let allDesktopApps = assignedApps
                .filter { $0.target == .allDesktops }
                .map(\.app)
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            let assignedAppsByDesktop = Dictionary(grouping: assignedApps.compactMap { entry -> (app: RunningAppInfo, desktop: Int)? in
                guard let desktop = entry.target.desktopNumber else { return nil }
                return (entry.app, desktop)
            }) { $0.desktop }

            unassignedApps.forEach { app in
                menu.addItem(
                    runningAppItem(
                        app,
                        rules: rules,
                        maxDesktopAssignments: maxDesktopAssignments,
                        target: target
                    )
                )
            }

            let assignedDesktops = assignedAppsByDesktop.keys.sorted()
            if !unassignedApps.isEmpty && (!allDesktopApps.isEmpty || !assignedDesktops.isEmpty) {
                menu.addItem(.separator())
            }

            if !allDesktopApps.isEmpty {
                let item = NSMenuItem(title: experimentalAllDesktopsTitle, action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: experimentalAllDesktopsTitle)

                allDesktopApps.forEach { app in
                    submenu.addItem(
                        runningAppItem(
                            app,
                            rules: rules,
                            maxDesktopAssignments: maxDesktopAssignments,
                            target: target
                        )
                    )
                }

                item.submenu = submenu
                menu.addItem(item)
            }

            if !allDesktopApps.isEmpty && !assignedDesktops.isEmpty {
                menu.addItem(.separator())
            }

            assignedDesktops.forEach { desktop in
                let item = NSMenuItem(title: "Assigned to Desktop \(desktop)", action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: "Desktop \(desktop)")

                assignedAppsByDesktop[desktop]?
                    .map { $0.app }
                    .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                    .forEach { app in
                        submenu.addItem(
                            runningAppItem(
                                app,
                                rules: rules,
                                maxDesktopAssignments: maxDesktopAssignments,
                                target: target
                            )
                        )
                    }

                item.submenu = submenu
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(sectionHeader("Saved Rules"))
        if rules.isEmpty {
            menu.addItem(disabledItem("No saved assignments"))
        } else {
            let runningBundleIDs = Set(runningApps.map(\.bundleID))
            let allDesktopRules = rules
                .filter { $0.assignmentTarget == .allDesktops }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            let rulesByDesktop = Dictionary(grouping: rules.compactMap { rule -> AppRule? in
                guard rule.desktopNumber != nil else { return nil }
                return rule
            }) { $0.desktopNumber ?? 0 }

            if !allDesktopRules.isEmpty {
                let item = NSMenuItem(title: experimentalAllDesktopsTitle, action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: experimentalAllDesktopsTitle)

                allDesktopRules.forEach { rule in
                    submenu.addItem(
                        savedRuleItem(
                            rule,
                            isRunning: runningBundleIDs.contains(rule.bundleID),
                            target: target
                        )
                    )
                }

                item.submenu = submenu
                menu.addItem(item)
            }

            if !allDesktopRules.isEmpty && !rulesByDesktop.isEmpty {
                menu.addItem(.separator())
            }

            rulesByDesktop.keys.sorted().forEach { desktop in
                let item = NSMenuItem(title: "Desktop \(desktop)", action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: "Desktop \(desktop)")

                rulesByDesktop[desktop]?
                    .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                    .forEach { rule in
                        submenu.addItem(
                            savedRuleItem(
                                rule,
                                isRunning: runningBundleIDs.contains(rule.bundleID),
                                target: target
                            )
                        )
                    }

                item.submenu = submenu
                menu.addItem(item)
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
        item.image = resizedMenuIcon(from: app.icon)

        let submenu = NSMenu(title: app.displayName)
        let assignedTarget = rules.first(where: { $0.bundleID == app.bundleID })?.assignmentTarget

        if let assignedTarget {
            submenu.addItem(actionItem(
                openTitle(for: assignedTarget),
                command: .openAssigned(bundleID: app.bundleID),
                target: target
            ))
        } else {
            submenu.addItem(disabledItem("No assignment saved"))
        }

        submenu.addItem(.separator())

        let desktopLimit = max(maxDesktopAssignments, assignedTarget?.desktopNumber ?? 1)
        for desktop in 1...desktopLimit {
            let assignmentItem = actionItem(
                "Assign to Desktop \(desktop)",
                command: .assign(
                    bundleID: app.bundleID,
                    displayName: app.displayName,
                    assignmentTarget: .desktop(desktop)
                ),
                target: target
            )
            assignmentItem.state = assignedTarget == .desktop(desktop) ? NSControl.StateValue.on : NSControl.StateValue.off
            submenu.addItem(assignmentItem)
        }

        submenu.addItem(.separator())
        let allDesktopsItem = actionItem(
            assignAllDesktopsTitle,
            command: .assign(bundleID: app.bundleID, displayName: app.displayName, assignmentTarget: .allDesktops),
            target: target
        )
        allDesktopsItem.state = assignedTarget == .allDesktops ? .on : .off
        submenu.addItem(allDesktopsItem)

        submenu.addItem(.separator())
        submenu.addItem(actionItem("Clear Assignment", command: .clear(bundleID: app.bundleID), target: target))

        item.submenu = submenu
        return item
    }

    private func resizedMenuIcon(from icon: NSImage?) -> NSImage? {
        guard let icon else { return nil }

        let resizedIcon = icon.copy() as? NSImage
        resizedIcon?.size = menuAppIconSize
        return resizedIcon
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
        let item = NSMenuItem(title: "\(rule.displayName) -> \(rule.assignmentDisplayName)", action: nil, keyEquivalent: "")

        let submenu = NSMenu(title: rule.displayName)
        submenu.addItem(
            actionItem(
                isRunning ? openTitle(for: rule.assignmentTarget) : launchTitle(for: rule.assignmentTarget),
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

    private func openTitle(for assignmentTarget: AssignmentTarget) -> String {
        switch assignmentTarget {
        case .desktop(let desktopNumber):
            return "Open on Desktop \(desktopNumber)"
        case .allDesktops:
            return "Open with All Desktops Rule"
        }
    }

    private func launchTitle(for assignmentTarget: AssignmentTarget) -> String {
        switch assignmentTarget {
        case .desktop(let desktopNumber):
            return "Launch on Desktop \(desktopNumber)"
        case .allDesktops:
            return "Launch with All Desktops Rule"
        }
    }
}
