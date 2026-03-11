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
    private var hasPositionedWindow = false
    private let leftColumnWidth: CGFloat = 460

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
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
        if !hasPositionedWindow {
            window?.center()
            hasPositionedWindow = true
        }
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
        guard let window else { return }

        window.delegate = self
        window.backgroundColor = NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.15, alpha: 1.0)
        window.isOpaque = false
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified

        let contentView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 1180, height: 760))
        contentView.material = .underWindowBackground
        contentView.blendingMode = .behindWindow
        contentView.state = .active
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.19, alpha: 0.84).cgColor
        window.contentView = contentView

        let titleLabel = NSTextField(labelWithString: "Perch Settings")
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.alignment = .left

        let subtitleLabel = helperLabel("Desktop switching, behaviour, and saved apps.")
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.alignment = .left

        let headerStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 6

        let permissionsSection = makePermissionsSection()
        let behaviorSection = makeBehaviorSection()
        let savedAppsSection = makeSavedAppsSection()

        let leftColumn = NSStackView(views: [headerStack, permissionsSection, behaviorSection])
        leftColumn.orientation = .vertical
        leftColumn.alignment = .width
        leftColumn.spacing = 18
        leftColumn.translatesAutoresizingMaskIntoConstraints = false

        permissionsSection.translatesAutoresizingMaskIntoConstraints = false
        behaviorSection.translatesAutoresizingMaskIntoConstraints = false
        permissionsSection.widthAnchor.constraint(equalTo: behaviorSection.widthAnchor).isActive = true

        let contentRow = NSStackView(views: [leftColumn, savedAppsSection])
        contentRow.orientation = .horizontal
        contentRow.alignment = .top
        contentRow.spacing = 18
        contentRow.distribution = .fill
        contentRow.translatesAutoresizingMaskIntoConstraints = false

        let rightSpacer = NSView()
        rightSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)

        let rightColumn = NSStackView(views: [rightSpacer, savedAppsSection])
        rightColumn.orientation = .vertical
        rightColumn.alignment = .width
        rightColumn.spacing = 18
        rightColumn.translatesAutoresizingMaskIntoConstraints = false

        let mainSplit = NSStackView(views: [leftColumn, rightColumn])
        mainSplit.translatesAutoresizingMaskIntoConstraints = false
        mainSplit.orientation = .horizontal
        mainSplit.alignment = .top
        mainSplit.spacing = 18
        mainSplit.distribution = .fill

        contentView.addSubview(mainSplit)

        NSLayoutConstraint.activate([
            mainSplit.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            mainSplit.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            mainSplit.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            mainSplit.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28),
            leftColumn.widthAnchor.constraint(equalToConstant: leftColumnWidth),
            headerStack.leadingAnchor.constraint(equalTo: leftColumn.leadingAnchor),
            permissionsSection.leadingAnchor.constraint(equalTo: leftColumn.leadingAnchor),
            behaviorSection.leadingAnchor.constraint(equalTo: leftColumn.leadingAnchor),
            savedAppsSection.topAnchor.constraint(equalTo: permissionsSection.topAnchor),
            savedAppsSection.bottomAnchor.constraint(equalTo: behaviorSection.bottomAnchor),
            savedAppsSection.widthAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])

        updateButtons()
        sizeWindowToFitContent()
    }

    private func sizeWindowToFitContent() {
        guard let window, let contentView = window.contentView else { return }

        contentView.layoutSubtreeIfNeeded()
        let fittingSize = contentView.fittingSize
        guard fittingSize.width > 0, fittingSize.height > 0 else { return }

        let minimumSize = NSSize(width: max(fittingSize.width, 1080), height: max(fittingSize.height, 720))
        window.contentMinSize = minimumSize
        window.setContentSize(minimumSize)
    }

    private func makePermissionsSection() -> NSView {
        let title = sectionHeader("Setup", detail: "Access and test switching.")
        let descriptionLabel = helperLabel("Access and test switching.")
        descriptionLabel.isHidden = true
        setupStatusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        setupStatusLabel.maximumNumberOfLines = 0
        configureWrappingLabel(setupStatusLabel)

        accessibilityStatusLabel.font = .systemFont(ofSize: 13)
        accessibilityStatusLabel.textColor = .secondaryLabelColor
        accessibilityStatusLabel.maximumNumberOfLines = 0
        configureWrappingLabel(accessibilityStatusLabel)
        shortcutStatusLabel.font = .systemFont(ofSize: 13)
        shortcutStatusLabel.textColor = .secondaryLabelColor
        configureWrappingLabel(shortcutStatusLabel)
        launchDelayStatusLabel.font = .systemFont(ofSize: 13)
        launchDelayStatusLabel.textColor = .secondaryLabelColor
        configureWrappingLabel(launchDelayStatusLabel)

        let requestButton = NSButton(title: "Request Access", target: self, action: #selector(requestAccessibility))
        styleButton(requestButton)

        testSwitchButton.target = self
        testSwitchButton.action = #selector(testDesktopSwitch)
        styleButton(testSwitchButton)

        let testLabel = NSTextField(labelWithString: "Test desktop switch")
        testLabel.alignment = .left
        testLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let testRow = row(label: testLabel, controls: [testDesktopPopup, testSwitchButton])
        let helper = helperLabel("Only switches desktop.")

        let buttonRow = NSStackView(views: [requestButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .leading

        let statusStack = NSStackView(views: [setupStatusLabel, accessibilityStatusLabel, shortcutStatusLabel, launchDelayStatusLabel])
        statusStack.orientation = .vertical
        statusStack.alignment = .leading
        statusStack.spacing = 8

        let stack = NSStackView(views: [title, descriptionLabel, statusStack, spacer(height: 10), testRow, helper, spacer(height: 10), buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return makeCard(containing: stack)
    }

    private func makeBehaviorSection() -> NSView {
        let title = sectionHeader("Behaviour", detail: "Switching and launch handling.")
        let descriptionLabel = helperLabel("Switching and launch handling.")
        descriptionLabel.isHidden = true

        let maxDesktopsLabel = NSTextField(labelWithString: "Max desktops shown")
        maxDesktopsLabel.font = .systemFont(ofSize: 13)
        maxDesktopsLabel.alignment = .left
        maxDesktopsPopup.addItems(withTitles: (1...9).map(String.init))
        maxDesktopsPopup.target = self
        maxDesktopsPopup.action = #selector(changeMaxDesktops)

        let shortcutLabel = NSTextField(labelWithString: "Shortcut assumptions")
        shortcutLabel.font = .systemFont(ofSize: 13)
        shortcutLabel.alignment = .left
        shortcutModifierPopup.addItems(withTitles: DesktopShortcutModifier.allCases.map(\.title))
        shortcutModifierPopup.target = self
        shortcutModifierPopup.action = #selector(changeShortcutModifier)

        let shortcutHintLabel = helperLabel("Match Mission Control shortcuts.")

        let launchDelayLabel = NSTextField(labelWithString: "Launch delay")
        launchDelayLabel.font = .systemFont(ofSize: 13)
        launchDelayLabel.alignment = .left
        launchDelayStepper.minValue = 50
        launchDelayStepper.maxValue = 2000
        launchDelayStepper.increment = 50
        launchDelayStepper.target = self
        launchDelayStepper.action = #selector(changeLaunchDelay)
        launchDelayValueLabel.font = .systemFont(ofSize: 13)

        watchLaunchesCheckbox.target = self
        watchLaunchesCheckbox.action = #selector(toggleWatchLaunches)

        let diagnosticsButton = NSButton(title: "Open Diagnostics", target: self, action: #selector(showDiagnostics))
        styleButton(diagnosticsButton)

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refresh))
        styleButton(refreshButton)

        let maxDesktopsRow = row(label: maxDesktopsLabel, control: maxDesktopsPopup)
        let shortcutRow = row(label: shortcutLabel, control: shortcutModifierPopup)
        let launchDelayRow = row(label: launchDelayLabel, controls: [launchDelayValueLabel, launchDelayStepper])
        let actionsRow = NSStackView(views: [diagnosticsButton, refreshButton])
        actionsRow.orientation = .horizontal
        actionsRow.alignment = .centerY
        actionsRow.spacing = 8

        let stack = NSStackView(views: [title, descriptionLabel, spacer(height: 4), maxDesktopsRow, shortcutRow, shortcutHintLabel, launchDelayRow, watchLaunchesCheckbox, spacer(height: 4), actionsRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        return makeCard(containing: stack)
    }

    private func makeSavedAppsSection() -> NSView {
        let title = sectionLabel("Saved Apps")
        let descriptionLabel = helperLabel("Double-click to launch on its saved desktop.")

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView
        scrollView.drawsBackground = false

        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsEmptySelection = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(openSelectedRule)
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.19, alpha: 0.85)
        tableView.gridStyleMask = []
        tableView.selectionHighlightStyle = .regular

        addColumn(title: "App", identifier: "app", width: 180)
        addColumn(title: "Bundle ID", identifier: "bundleID", width: 360)
        addColumn(title: "Desktop", identifier: "desktop", width: 110)

        emptyStateLabel.alignment = .center
        emptyStateLabel.textColor = .secondaryLabelColor
        emptyStateLabel.font = .systemFont(ofSize: 13)
        emptyStateLabel.isHidden = true

        openButton.target = self
        openButton.action = #selector(openSelectedRule)
        styleButton(openButton)

        removeButton.target = self
        removeButton.action = #selector(removeSelectedRule)
        styleButton(removeButton)

        let actionsStack = NSStackView(views: [openButton, removeButton])
        actionsStack.orientation = .horizontal
        actionsStack.alignment = .centerY
        actionsStack.spacing = 8

        let titleStack = NSStackView(views: [title, descriptionLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 8

        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let headerRow = NSStackView(views: [titleStack, headerSpacer, actionsStack])
        headerRow.orientation = .horizontal
        headerRow.alignment = .top
        headerRow.spacing = 16

        let tableContainer = NSVisualEffectView()
        tableContainer.material = .contentBackground
        tableContainer.blendingMode = .withinWindow
        tableContainer.state = .active
        tableContainer.wantsLayer = true
        tableContainer.layer?.cornerRadius = 20
        tableContainer.layer?.borderWidth = 1
        tableContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        tableContainer.layer?.shadowColor = NSColor.white.withAlphaComponent(0.14).cgColor
        tableContainer.layer?.shadowOpacity = 0.18
        tableContainer.layer?.shadowRadius = 16
        tableContainer.layer?.shadowOffset = NSSize(width: 0, height: -1)
        tableContainer.translatesAutoresizingMaskIntoConstraints = false
        tableContainer.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: tableContainer.topAnchor, constant: 0),
            scrollView.leadingAnchor.constraint(equalTo: tableContainer.leadingAnchor, constant: 0),
            scrollView.trailingAnchor.constraint(equalTo: tableContainer.trailingAnchor, constant: 0),
            scrollView.bottomAnchor.constraint(equalTo: tableContainer.bottomAnchor, constant: 0)
        ])

        tableContainer.setContentHuggingPriority(.defaultLow, for: .vertical)
        tableContainer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        let stack = NSStackView(views: [headerRow, tableContainer, emptyStateLabel])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12

        tableContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true

        return makeCard(containing: stack, contentInsets: NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
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
        row.setHuggingPriority(.defaultLow, for: .horizontal)
        return row
    }

    private func makeCard(containing content: NSView, contentInsets: NSEdgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)) -> NSView {
        let card = NSVisualEffectView()
        card.material = .sidebar
        card.blendingMode = .withinWindow
        card.state = .active
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 24
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        card.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        card.layer?.shadowColor = NSColor.white.withAlphaComponent(0.10).cgColor
        card.layer?.shadowOpacity = 0.20
        card.layer?.shadowRadius = 18
        card.layer?.shadowOffset = NSSize(width: 0, height: -2)

        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: contentInsets.top),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: contentInsets.left),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -contentInsets.right),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -contentInsets.bottom)
        ])

        return card
    }

    private func addColumn(title: String, identifier: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        column.minWidth = width * 0.7
        tableView.addTableColumn(column)
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.alignment = .left
        return label
    }

    private func sectionHeader(_ title: String, detail: String) -> NSView {
        let titleLabel = sectionLabel(title)
        let detailLabel = helperLabel(detail)

        let stack = NSStackView(views: [titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    private func helperLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        label.alignment = .left
        configureWrappingLabel(label)
        return label
    }

    private func configureWrappingLabel(_ label: NSTextField) {
        label.lineBreakMode = .byWordWrapping
        label.cell?.wraps = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func spacer(height: CGFloat) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    private func styleButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.controlSize = .regular
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
        label.font = .systemFont(ofSize: 13)
        label.alignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSTableCellView()
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        rowView.wantsLayer = true
        rowView.layer?.cornerRadius = 8
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtons()
    }
}
