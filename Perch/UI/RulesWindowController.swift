import AppKit

struct SettingsSnapshot {
    let rules: [AppRule]
    let accessibilityTrusted: Bool
    let maxDesktopsShown: Int
    let launchDelayMilliseconds: Int
    let watchLaunchesEnabled: Bool
    let shortcutModifier: DesktopShortcutModifier
}

final class RulesWindowController: NSWindowController {
    var onRequestAccessibility: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onOpenRule: ((String) -> Void)?
    var onRemoveRule: ((String) -> Void)?
    var onMaxDesktopsChanged: ((Int) -> Void)?
    var onLaunchDelayChanged: ((Int) -> Void)?
    var onWatchLaunchesChanged: ((Bool) -> Void)?
    var onShortcutModifierChanged: ((DesktopShortcutModifier) -> Void)?
    var onTestDesktopSwitch: ((Int) -> Void)?
    var onShowDiagnostics: (() -> Void)?

    private let setupStatusLabel = NSTextField(labelWithString: "")
    private let accessibilityStatusLabel = NSTextField(labelWithString: "")
    private let shortcutStatusLabel = NSTextField(labelWithString: "")
    private let launchDelayStatusLabel = NSTextField(labelWithString: "")
    private let maxDesktopsPopup = NSPopUpButton()
    private let shortcutModifierPopup = NSPopUpButton()
    private let testDesktopPopup = NSPopUpButton()
    private let testSwitchButton = NSButton(title: "Test Switch", target: nil, action: nil)
    private let launchDelayValueLabel = NSTextField(labelWithString: "")
    private let launchDelayStepper = NSStepper()
    private let watchLaunchesCheckbox = NSButton(checkboxWithTitle: "Watch launches and reopen assigned apps", target: nil, action: nil)
    private let tableView = NSTableView()
    private let emptyStateLabel = NSTextField(labelWithString: "No saved assignments yet. Assign a running app from the menu bar to create one.")
    private let openButton = NSButton(title: "Launch on Assigned Desktop", target: nil, action: nil)
    private let removeButton = NSButton(title: "Remove Rule", target: nil, action: nil)

    private var rules: [AppRule] = []
    private var pendingSnapshot: SettingsSnapshot?
    private var applyScheduled = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Perch Settings"
        super.init(window: window)
        configureWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(snapshot: SettingsSnapshot) {
        scheduleApply(snapshot)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(snapshot: SettingsSnapshot) {
        guard window?.isVisible == true else { return }
        scheduleApply(snapshot)
    }

    private func scheduleApply(_ snapshot: SettingsSnapshot) {
        pendingSnapshot = snapshot
        guard !applyScheduled else { return }

        applyScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyScheduled = false
            self.applyPendingSnapshotIfPossible()
        }
    }

    private func configureWindow() {
        window?.delegate = self

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 560))
        window?.contentView = contentView

        let permissionsSection = makePermissionsSection()
        let behaviorSection = makeBehaviorSection()
        let savedAppsSection = makeSavedAppsSection()

        let layoutStack = NSStackView(views: [permissionsSection, behaviorSection, savedAppsSection])
        layoutStack.translatesAutoresizingMaskIntoConstraints = false
        layoutStack.orientation = .vertical
        layoutStack.alignment = .width
        layoutStack.spacing = 18

        contentView.addSubview(layoutStack)

        NSLayoutConstraint.activate([
            layoutStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            layoutStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            layoutStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            layoutStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        updateButtons()
        sizeWindowToFitContent()
    }

    private func sizeWindowToFitContent() {
        guard let window, let contentView = window.contentView else { return }

        contentView.layoutSubtreeIfNeeded()
        let fittingSize = contentView.fittingSize
        guard fittingSize.width > 0, fittingSize.height > 0 else { return }

        window.contentMinSize = fittingSize
        window.setContentSize(fittingSize)
        window.center()
    }

    private func makePermissionsSection() -> NSView {
        let title = sectionLabel("Setup")
        setupStatusLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        accessibilityStatusLabel.font = .systemFont(ofSize: 13)
        accessibilityStatusLabel.textColor = .secondaryLabelColor
        shortcutStatusLabel.font = .systemFont(ofSize: 13)
        shortcutStatusLabel.textColor = .secondaryLabelColor
        launchDelayStatusLabel.font = .systemFont(ofSize: 13)
        launchDelayStatusLabel.textColor = .secondaryLabelColor

        let requestButton = NSButton(title: "Request Access", target: self, action: #selector(requestAccessibility))
        requestButton.bezelStyle = .rounded

        testSwitchButton.target = self
        testSwitchButton.action = #selector(testDesktopSwitch)
        testSwitchButton.bezelStyle = .rounded

        let testRow = row(label: NSTextField(labelWithString: "Test desktop switch"), controls: [testDesktopPopup, testSwitchButton])
        let helper = helperLabel("Test Switch only changes desktop so you can verify the shortcut and timing.")

        let stack = NSStackView(views: [title, setupStatusLabel, accessibilityStatusLabel, shortcutStatusLabel, launchDelayStatusLabel, testRow, helper, requestButton])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        return stack
    }

    private func makeBehaviorSection() -> NSView {
        let title = sectionLabel("Behavior")

        let maxDesktopsLabel = NSTextField(labelWithString: "Max desktops shown")
        maxDesktopsLabel.font = .systemFont(ofSize: 13)
        maxDesktopsPopup.addItems(withTitles: (1...9).map(String.init))
        maxDesktopsPopup.target = self
        maxDesktopsPopup.action = #selector(changeMaxDesktops)

        let shortcutLabel = NSTextField(labelWithString: "Shortcut assumptions")
        shortcutLabel.font = .systemFont(ofSize: 13)
        shortcutModifierPopup.addItems(withTitles: DesktopShortcutModifier.allCases.map(\.title))
        shortcutModifierPopup.target = self
        shortcutModifierPopup.action = #selector(changeShortcutModifier)

        let shortcutHintLabel = helperLabel("Must match your Mission Control desktop shortcuts.")

        let launchDelayLabel = NSTextField(labelWithString: "Launch delay")
        launchDelayLabel.font = .systemFont(ofSize: 13)
        launchDelayStepper.minValue = 50
        launchDelayStepper.maxValue = 2000
        launchDelayStepper.increment = 50
        launchDelayStepper.target = self
        launchDelayStepper.action = #selector(changeLaunchDelay)
        launchDelayValueLabel.font = .systemFont(ofSize: 13)

        watchLaunchesCheckbox.target = self
        watchLaunchesCheckbox.action = #selector(toggleWatchLaunches)

        let diagnosticsButton = NSButton(title: "Open Diagnostics", target: self, action: #selector(showDiagnostics))
        diagnosticsButton.bezelStyle = .rounded

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refresh))
        refreshButton.bezelStyle = .rounded

        let maxDesktopsRow = row(label: maxDesktopsLabel, control: maxDesktopsPopup)
        let shortcutRow = row(label: shortcutLabel, control: shortcutModifierPopup)
        let launchDelayRow = row(label: launchDelayLabel, controls: [launchDelayValueLabel, launchDelayStepper])
        let actionsRow = NSStackView(views: [diagnosticsButton, refreshButton])
        actionsRow.orientation = .horizontal
        actionsRow.alignment = .centerY
        actionsRow.spacing = 8

        let stack = NSStackView(views: [title, maxDesktopsRow, shortcutRow, shortcutHintLabel, launchDelayRow, watchLaunchesCheckbox, actionsRow])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10
        return stack
    }

    private func makeSavedAppsSection() -> NSView {
        let title = sectionLabel("Saved Apps")

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView

        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsEmptySelection = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(openSelectedRule)

        addColumn(title: "App", identifier: "app", width: 170)
        addColumn(title: "Bundle ID", identifier: "bundleID", width: 320)
        addColumn(title: "Assignment", identifier: "desktop", width: 140)

        emptyStateLabel.alignment = .center
        emptyStateLabel.textColor = .secondaryLabelColor
        emptyStateLabel.font = .systemFont(ofSize: 13)
        emptyStateLabel.isHidden = true

        openButton.target = self
        openButton.action = #selector(openSelectedRule)
        openButton.bezelStyle = .rounded

        removeButton.target = self
        removeButton.action = #selector(removeSelectedRule)
        removeButton.bezelStyle = .rounded

        let actionsStack = NSStackView(views: [openButton, removeButton])
        actionsStack.orientation = .horizontal
        actionsStack.alignment = .centerY
        actionsStack.spacing = 8

        let stack = NSStackView(views: [title, scrollView, emptyStateLabel, actionsStack])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10

        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true

        return stack
    }

    private func apply(snapshot: SettingsSnapshot) {
        rules = snapshot.rules.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        accessibilityStatusLabel.stringValue = snapshot.accessibilityTrusted
            ? "Granted. Desktop switching is available."
            : "Not granted. Perch cannot switch desktops until access is approved."
        setupStatusLabel.stringValue = snapshot.accessibilityTrusted
            ? "Setup ready. Perch can switch desktops."
            : "Setup incomplete. Perch cannot switch desktops yet."
        setupStatusLabel.textColor = snapshot.accessibilityTrusted ? .labelColor : .systemRed
        shortcutStatusLabel.stringValue = "Shortcut: \(snapshot.shortcutModifier.title)"
        launchDelayStatusLabel.stringValue = "Launch delay: \(snapshot.launchDelayMilliseconds) ms"

        maxDesktopsPopup.selectItem(withTitle: String(snapshot.maxDesktopsShown))
        launchDelayStepper.integerValue = snapshot.launchDelayMilliseconds
        launchDelayValueLabel.stringValue = "\(snapshot.launchDelayMilliseconds) ms"
        watchLaunchesCheckbox.state = snapshot.watchLaunchesEnabled ? .on : .off
        shortcutModifierPopup.selectItem(at: DesktopShortcutModifier.allCases.firstIndex(of: snapshot.shortcutModifier) ?? 0)
        updateTestDesktopPopup(maxDesktopsShown: snapshot.maxDesktopsShown)
        testDesktopPopup.isEnabled = snapshot.accessibilityTrusted
        testSwitchButton.isEnabled = snapshot.accessibilityTrusted

        emptyStateLabel.isHidden = !rules.isEmpty
        tableView.reloadData()
        updateButtons()
    }

    private func shouldDeferWindowUpdates() -> Bool {
        window?.inLiveResize == true
    }

    private func applyPendingSnapshotIfPossible() {
        guard let snapshot = pendingSnapshot else { return }
        guard !shouldDeferWindowUpdates() else {
            scheduleApply(snapshot)
            return
        }

        pendingSnapshot = nil
        apply(snapshot: snapshot)
    }

    private func row(label: NSTextField, control: NSView) -> NSStackView {
        row(label: label, controls: [control])
    }

    private func row(label: NSTextField, controls: [NSView]) -> NSStackView {
        let trailingControls = NSStackView(views: controls)
        trailingControls.orientation = .horizontal
        trailingControls.alignment = .centerY
        trailingControls.spacing = 8

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [label, spacer, trailingControls])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.detachesHiddenViews = true
        return row
    }

    private func addColumn(title: String, identifier: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        tableView.addTableColumn(column)
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        return label
    }

    private func helperLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func updateTestDesktopPopup(maxDesktopsShown: Int) {
        let previousSelection = Int(testDesktopPopup.selectedItem?.title ?? "") ?? 1
        let titles = (1...maxDesktopsShown).map { "Desktop \($0)" }
        testDesktopPopup.removeAllItems()
        testDesktopPopup.addItems(withTitles: titles)
        let selectedDesktop = min(max(previousSelection, 1), maxDesktopsShown)
        testDesktopPopup.selectItem(withTitle: "Desktop \(selectedDesktop)")
    }

    private func selectedRule() -> AppRule? {
        let row = tableView.selectedRow
        guard row >= 0 && row < rules.count else { return nil }
        return rules[row]
    }

    private func updateButtons() {
        let hasSelection = selectedRule() != nil
        openButton.isEnabled = hasSelection
        removeButton.isEnabled = hasSelection
    }

    @objc
    private func requestAccessibility() {
        onRequestAccessibility?()
    }

    @objc
    private func refresh() {
        onRefresh?()
    }

    @objc
    private func openSelectedRule() {
        guard let rule = selectedRule() else { return }
        onOpenRule?(rule.bundleID)
    }

    @objc
    private func removeSelectedRule() {
        guard let rule = selectedRule() else { return }
        onRemoveRule?(rule.bundleID)
    }

    @objc
    private func changeMaxDesktops() {
        guard let value = Int(maxDesktopsPopup.selectedItem?.title ?? "") else { return }
        onMaxDesktopsChanged?(value)
    }

    @objc
    private func changeLaunchDelay() {
        let value = launchDelayStepper.integerValue
        launchDelayValueLabel.stringValue = "\(value) ms"
        onLaunchDelayChanged?(value)
    }

    @objc
    private func toggleWatchLaunches() {
        onWatchLaunchesChanged?(watchLaunchesCheckbox.state == .on)
    }

    @objc
    private func changeShortcutModifier() {
        let selectedIndex = shortcutModifierPopup.indexOfSelectedItem
        guard DesktopShortcutModifier.allCases.indices.contains(selectedIndex) else { return }
        onShortcutModifierChanged?(DesktopShortcutModifier.allCases[selectedIndex])
    }

    @objc
    private func showDiagnostics() {
        onShowDiagnostics?()
    }

    @objc
    private func testDesktopSwitch() {
        guard let title = testDesktopPopup.selectedItem?.title,
              let desktopNumber = Int(title.replacingOccurrences(of: "Desktop ", with: "")) else { return }
        onTestDesktopSwitch?(desktopNumber)
    }
}

extension RulesWindowController: NSWindowDelegate {
    func windowDidEndLiveResize(_ notification: Notification) {
        applyPendingSnapshotIfPossible()
    }
}

extension RulesWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        rules.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")
        let item = rules[row]
        let value: String

        switch identifier.rawValue {
        case "app":
            value = item.displayName
        case "bundleID":
            value = item.bundleID
        case "desktop":
            value = item.assignmentDisplayName
        default:
            value = ""
        }

        let label = NSTextField(labelWithString: value)
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtons()
    }
}
