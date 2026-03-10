import AppKit

final class DiagnosticsWindowController: NSWindowController {
    private let diagnosticsStore: DiagnosticsStore
    private let textView = NSTextView()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    private var updateScheduled = false

    init(diagnosticsStore: DiagnosticsStore = .shared) {
        self.diagnosticsStore = diagnosticsStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Perch Diagnostics"
        super.init(window: window)
        configureWindow()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scheduleUpdateContents),
            name: DiagnosticsStore.didChangeNotification,
            object: diagnosticsStore
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        scheduleUpdateContents()
    }

    private func configureWindow() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 420))
        window?.contentView = contentView

        let infoLabel = NSTextField(labelWithString: "Recent Perch activity")
        infoLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearLogs))
        clearButton.bezelStyle = .rounded

        let headerRow = NSStackView(views: [infoLabel, clearButton])
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 12
        headerRow.distribution = .equalSpacing

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView

        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.autoresizingMask = [.width, .height]
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        contentView.addSubview(headerRow)
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    @objc
    private func clearLogs() {
        diagnosticsStore.clear()
    }

    @objc
    private func updateContents() {
        let lines = diagnosticsStore.entries.map { entry in
            "\(dateFormatter.string(from: entry.timestamp)) [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)"
        }

        textView.string = lines.isEmpty ? "No diagnostics yet." : lines.joined(separator: "\n")
    }

    @objc
    private func scheduleUpdateContents() {
        guard !updateScheduled else { return }

        updateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateScheduled = false
            self.updateContents()
        }
    }
}
