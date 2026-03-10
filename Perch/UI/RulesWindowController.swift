import AppKit

struct SettingsSnapshot {
    let rules: [AppRule]
    let accessibilityTrusted: Bool
    let maxDesktopsShown: Int
}

final class RulesWindowController: NSWindowController {
    var onRequestAccessibility: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onOpenRule: ((String) -> Void)?
    var onRemoveRule: ((String) -> Void)?
    var onMaxDesktopsChanged: ((Int) -> Void)?

    private let accessibilityStatusLabel = NSTextField(labelWithString: "")
    private let maxDesktopsPopup = NSPopUpButton()
    private let tableView = NSTableView()
    private let emptyStateLabel = NSTextField(labelWithString: "No saved assignments yet.")
    private let openButton = NSButton(title: "Open on Assigned Desktop", target: nil, action: nil)
    private let removeButton = NSButton(title: "Remove Rule", target: nil, action: nil)

    private var rules: [AppRule] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 420),
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
        apply(snapshot: snapshot)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(snapshot: SettingsSnapshot) {
        guard window?.isVisible == true else { return }
        apply(snapshot: snapshot)
    }

    private func configureWindow() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 420))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window?.contentView = contentView

        let permissionsTitle = sectionLabel("Accessibility")
        accessibilityStatusLabel.font = .systemFont(ofSize: 13)
        accessibilityStatusLabel.textColor = .secondaryLabelColor

        let permissionsButton = NSButton(title: "Request Access", target: self, action: #selector(requestAccessibility))
        permissionsButton.bezelStyle = .rounded

        let maxDesktopsLabel = NSTextField(labelWithString: "Max desktops shown")
        maxDesktopsLabel.font = .systemFont(ofSize: 13)

        maxDesktopsPopup.addItems(withTitles: (1...9).map(String.init))
        maxDesktopsPopup.target = self
        maxDesktopsPopup.action = #selector(changeMaxDesktops)

        let desktopCountRow = NSStackView(views: [maxDesktopsLabel, maxDesktopsPopup])
        desktopCountRow.orientation = .horizontal
        desktopCountRow.alignment = .centerY
        desktopCountRow.spacing = 12

        let permissionsStack = NSStackView(views: [permissionsTitle, accessibilityStatusLabel, permissionsButton])
        permissionsStack.orientation = .vertical
        permissionsStack.alignment = .leading
        permissionsStack.spacing = 8

        let savedAppsTitle = sectionLabel("Saved Apps")

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
        addColumn(title: "Bundle ID", identifier: "bundleID", width: 300)
        addColumn(title: "Desktop", identifier: "desktop", width: 100)

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

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refresh))
        refreshButton.bezelStyle = .rounded

        let actionsStack = NSStackView(views: [openButton, removeButton, refreshButton])
        actionsStack.orientation = .horizontal
        actionsStack.alignment = .centerY
        actionsStack.spacing = 8

        let layoutStack = NSStackView(views: [permissionsStack, desktopCountRow, savedAppsTitle, scrollView, emptyStateLabel, actionsStack])
        layoutStack.translatesAutoresizingMaskIntoConstraints = false
        layoutStack.orientation = .vertical
        layoutStack.alignment = .leading
        layoutStack.spacing = 14

        contentView.addSubview(layoutStack)

        NSLayoutConstraint.activate([
            layoutStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            layoutStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            layoutStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            layoutStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            scrollView.widthAnchor.constraint(equalTo: layoutStack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            emptyStateLabel.widthAnchor.constraint(equalTo: layoutStack.widthAnchor)
        ])

        updateButtons()
    }

    private func apply(snapshot: SettingsSnapshot) {
        rules = snapshot.rules.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        accessibilityStatusLabel.stringValue = snapshot.accessibilityTrusted
            ? "Granted. Desktop switching is available."
            : "Not granted. Perch cannot switch desktops until access is approved."

        maxDesktopsPopup.selectItem(withTitle: String(snapshot.maxDesktopsShown))
        emptyStateLabel.isHidden = !rules.isEmpty
        tableView.reloadData()
        updateButtons()
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
            value = "Desktop \(item.desktopNumber)"
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
