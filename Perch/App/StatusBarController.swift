import AppKit

final class StatusBarController: NSObject {
    private let appState: AppState
    private let menuBuilder = MenuBuilder()
    private let rulesWindowController = RulesWindowController()

    private var statusItem: NSStatusItem?

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

        appState.onChange = { [weak self] in
            self?.rebuildMenu()
        }
    }

    func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Perch"
        item.button?.toolTip = "Perch Window Management"

        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        statusItem?.menu = menuBuilder.makeMenu(
            runningApps: appState.runningApps,
            rules: appState.rules,
            accessibilityTrusted: appState.isAccessibilityTrusted(),
            target: self
        )
        rulesWindowController.update(snapshot: settingsSnapshot())
    }

    private func settingsSnapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            rules: appState.rules,
            accessibilityTrusted: appState.isAccessibilityTrusted()
        )
    }

    @objc
    func handleMenuAction(_ sender: NSMenuItem) {
        guard let commandBox = sender.representedObject as? MenuCommandBox else { return }

        switch commandBox.command {
        case .openAssigned(let bundleID):
            appState.openOnAssignedDesktop(bundleID: bundleID)
        case .assign(let bundleID, let displayName, let desktopNumber):
            let app = RunningAppInfo(
                id: bundleID,
                bundleID: bundleID,
                displayName: displayName,
                processIdentifier: 0,
                isActive: false,
                icon: nil
            )
            appState.assignDesktop(desktopNumber, to: app)
        case .clear(let bundleID):
            appState.clearAssignment(for: bundleID)
        case .refresh:
            appState.reload()
        case .requestAccessibility:
            appState.requestAccessibilityIfNeeded()
            rebuildMenu()
        case .showRules:
            rulesWindowController.show(snapshot: settingsSnapshot())
        case .quit:
            NSApplication.shared.terminate(nil)
        }
    }
}

extension StatusBarController: MenuActionHandling {}
