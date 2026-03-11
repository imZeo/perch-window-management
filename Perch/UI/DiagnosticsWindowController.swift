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
    private var hasPositionedWindow = false

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
        if !hasPositionedWindow {
            window?.center()
            hasPositionedWindow = true
        }

        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        scheduleUpdateContents()
    }

    private func configureWindow() {
        window?.delegate = self

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 420))
        window?.contentView = contentView

        let infoLabel = NSTextField(labelWithString: "Recent Perch activity")
        infoLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let copyButton = NSButton(title: "Copy All", target: self, action: #selector(copyLogs))
        copyButton.bezelStyle = .rounded

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearLogs))
        clearButton.bezelStyle = .rounded

        let buttonsRow = NSStackView(views: [copyButton, clearButton])
        buttonsRow.orientation = .horizontal
        buttonsRow.alignment = .centerY
        buttonsRow.spacing = 8

        let headerRow = NSStackView(views: [infoLabel, buttonsRow])
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
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
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

        window?.center()
    }

    @objc
    private func clearLogs() {
        diagnosticsStore.clear()
    }

    @objc
    private func copyLogs() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(renderedLogs(), forType: .string)
    }

    @objc
    private func updateContents() {
        guard window?.inLiveResize != true else {
            scheduleUpdateContents()
            return
        }

        textView.string = renderedLogs()
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

    private func renderedLogs() -> String {
        let lines = diagnosticsStore.entries.map { entry in
            "\(dateFormatter.string(from: entry.timestamp)) [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)"
        }

        return lines.isEmpty
            ? "No diagnostics yet.\n\nUse Perch to assign an app, open an assigned app, or test desktop switching. Recent activity and errors will appear here."
            : lines.joined(separator: "\n")
    }
}

extension DiagnosticsWindowController: NSWindowDelegate {
    func windowDidEndLiveResize(_ notification: Notification) {
        scheduleUpdateContents()
    }
}
