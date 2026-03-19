import AppKit

final class StatusBarController: NSObject {
    private let appState: AppState
    private let menuBuilder = MenuBuilder()
    private let rulesWindowController = RulesWindowController()
    private let diagnosticsWindowController = DiagnosticsWindowController()

    private var statusItem: NSStatusItem?
    private var rulesWindowRefreshScheduled = false

    init(appState: AppState) {
        self.appState = appState
        super.init()

        rulesWindowController.onRequestAccessibility = { [weak self] in
            self?.appState.requestAccessibilityIfNeeded()
            self?.rebuildMenu()
        }
        rulesWindowController.onRefresh = { [weak self] in
            self?.appState.reload()
        }
        rulesWindowController.onOpenRule = { [weak self] bundleID in
            self?.appState.openOnAssignedDesktop(bundleID: bundleID)
        }
        rulesWindowController.onRemoveRule = { [weak self] bundleID in
            self?.appState.clearAssignment(for: bundleID)
        }
        rulesWindowController.onMaxDesktopsChanged = { [weak self] count in
            self?.appState.setMaxDesktopsShown(count)
        }
        rulesWindowController.onLaunchDelayChanged = { [weak self] milliseconds in
            self?.appState.setLaunchDelayMilliseconds(milliseconds)
        }
        rulesWindowController.onWatchLaunchesChanged = { [weak self] enabled in
            self?.appState.setWatchLaunchesEnabled(enabled)
        }
        rulesWindowController.onLaunchAtLoginChanged = { [weak self] enabled in
            self?.appState.setLaunchAtLoginEnabled(enabled)
        }
        rulesWindowController.onShortcutModifierChanged = { [weak self] modifier in
            self?.appState.setShortcutModifier(modifier)
        }
        rulesWindowController.onTestDesktopSwitch = { [weak self] desktopNumber in
            self?.appState.testSwitchToDesktop(desktopNumber)
        }
        rulesWindowController.onShowDiagnostics = { [weak self] in
            self?.diagnosticsWindowController.show()
        }

        appState.onChange = { [weak self] in
            self?.rebuildMenu()
        }
    }

    func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = menuBarImage()
            button.imagePosition = .imageOnly
            button.toolTip = "Perch Window Management"
        }

        statusItem = item
        rebuildMenu()
    }

    private func menuBarImage() -> NSImage? {
        guard let image = NSImage(named: "MenuBarIcon") else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }

    private func rebuildMenu() {
        statusItem?.menu = menuBuilder.makeMenu(
            runningApps: appState.runningApps,
            rules: appState.rules,
            accessibilityTrusted: appState.isAccessibilityTrusted(),
            maxDesktopAssignments: appState.maxDesktopsShown,
            target: self
        )
        scheduleRulesWindowRefresh()
    }

    private func scheduleRulesWindowRefresh() {
        guard !rulesWindowRefreshScheduled else { return }

        rulesWindowRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.rulesWindowRefreshScheduled = false
            self.rulesWindowController.update(snapshot: self.settingsSnapshot())
        }
    }

    private func settingsSnapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            rules: appState.rules,
            accessibilityTrusted: appState.isAccessibilityTrusted(),
            maxDesktopsShown: appState.maxDesktopsShown,
            launchDelayMilliseconds: appState.launchDelayMilliseconds,
            watchLaunchesEnabled: appState.watchLaunchesEnabled,
            launchAtLoginEnabled: appState.launchAtLoginEnabled,
            launchAtLoginRequiresApproval: appState.launchAtLoginRequiresApproval,
            shortcutModifier: appState.shortcutModifier
        )
    }

    @objc
    func handleMenuAction(_ sender: NSMenuItem) {
        guard let commandBox = sender.representedObject as? MenuCommandBox else { return }

        switch commandBox.command {
        case .openAssigned(let bundleID):
            appState.openOnAssignedDesktop(bundleID: bundleID)
        case .assign(let bundleID, let displayName, let assignmentTarget):
            let app = RunningAppInfo(
                id: bundleID,
                bundleID: bundleID,
                displayName: displayName,
                processIdentifier: 0,
                isActive: false,
                icon: nil
            )
            appState.assign(assignmentTarget, to: app)
        case .clear(let bundleID):
            appState.clearAssignment(for: bundleID)
        case .testSwitch(let desktop):
            appState.testSwitchToDesktop(desktop)
        case .refresh:
            appState.reload()
        case .requestAccessibility:
            appState.requestAccessibilityIfNeeded()
            rebuildMenu()
        case .showRules:
            rulesWindowController.show(snapshot: settingsSnapshot())
        case .showDiagnostics:
            diagnosticsWindowController.show()
        case .quit:
            NSApplication.shared.terminate(nil)
        }
    }
}

extension StatusBarController: MenuActionHandling {}
