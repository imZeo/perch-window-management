import AppKit

final class AppState {
    private let runningAppsService: RunningAppsService
    private let rulesStore: RulesStore
    private let settingsStore: SettingsStore
    private let spaceSwitcher: SpaceSwitcher
    private let appLauncher: AppLauncher
    private let launchObserver: LaunchObserver
    private let permissionsService: PermissionsService
    private let logger: AppLogger

    private(set) var runningApps: [RunningAppInfo] = []
    private(set) var rules: [AppRule] = []
    private(set) var maxDesktopsShown: Int
    private(set) var launchDelayMilliseconds: Int
    private(set) var watchLaunchesEnabled: Bool
    private(set) var shortcutModifier: DesktopShortcutModifier

    private var suppressedLaunchWatchBundleIDs: Set<String> = []

    var onChange: (() -> Void)?

    init(
        runningAppsService: RunningAppsService = RunningAppsService(),
        rulesStore: RulesStore = RulesStore(),
        settingsStore: SettingsStore = SettingsStore(),
        spaceSwitcher: SpaceSwitcher = SpaceSwitcher(),
        appLauncher: AppLauncher = AppLauncher(),
        launchObserver: LaunchObserver = LaunchObserver(),
        permissionsService: PermissionsService = PermissionsService(),
        logger: AppLogger = AppLogger(category: "AppState")
    ) {
        self.runningAppsService = runningAppsService
        self.rulesStore = rulesStore
        self.settingsStore = settingsStore
        self.spaceSwitcher = spaceSwitcher
        self.appLauncher = appLauncher
        self.launchObserver = launchObserver
        self.permissionsService = permissionsService
        self.logger = logger
        self.maxDesktopsShown = settingsStore.loadMaxDesktopsShown()
        self.launchDelayMilliseconds = settingsStore.loadLaunchDelayMilliseconds()
        self.watchLaunchesEnabled = settingsStore.loadWatchLaunchesEnabled()
        self.shortcutModifier = settingsStore.loadShortcutModifier()
    }

    func start() {
        reload()
        launchObserver.start { [weak self] event in
            self?.handleLaunchObserverEvent(event)
        }
    }

    func stop() {
        launchObserver.stop()
    }

    func reload() {
        rules = rulesStore.loadRules()
        reloadRunningApps()
    }

    func reloadRunningApps() {
        runningApps = runningAppsService.fetchRunningApps()
        onChange?()
    }

    func rule(for bundleID: String) -> AppRule? {
        rules.first(where: { $0.bundleID == bundleID })
    }

    func assignDesktop(_ desktopNumber: Int, to app: RunningAppInfo) {
        let rule = AppRule(
            bundleID: app.bundleID,
            displayName: app.displayName,
            desktopNumber: desktopNumber
        )

        rulesStore.upsert(rule)
        logger.info("Assigned \(app.bundleID) to desktop \(desktopNumber)")
        reload()
    }

    func clearAssignment(for bundleID: String) {
        rulesStore.removeRule(for: bundleID)
        logger.info("Cleared assignment for \(bundleID)")
        reload()
    }

    func openOnAssignedDesktop(bundleID: String) {
        guard let rule = rule(for: bundleID) else {
            logger.error("Missing rule for \(bundleID)")
            return
        }

        open(bundleID: bundleID, onDesktop: rule.desktopNumber, suppressLaunchWatch: true)
    }

    func open(bundleID: String, onDesktop desktopNumber: Int, suppressLaunchWatch: Bool = false) {
        guard permissionsService.isAccessibilityTrusted(prompt: false) else {
            logger.error("Accessibility permission is required to switch desktops")
            requestAccessibilityIfNeeded()
            return
        }

        if suppressLaunchWatch {
            registerSuppressedLaunchWatch(for: bundleID)
        }

        logger.info("Opening \(bundleID) on desktop \(desktopNumber) with \(shortcutModifier.title)")
        spaceSwitcher.switchToDesktop(desktopNumber, modifier: shortcutModifier)

        let delay = DispatchTime.now() + .milliseconds(launchDelayMilliseconds)
        DispatchQueue.main.asyncAfter(deadline: delay) { [weak self] in
            self?.appLauncher.launchOrActivate(bundleID: bundleID)
        }
    }

    func requestAccessibilityIfNeeded() {
        _ = permissionsService.isAccessibilityTrusted(prompt: true)
    }

    func isAccessibilityTrusted() -> Bool {
        permissionsService.isAccessibilityTrusted(prompt: false)
    }

    func setMaxDesktopsShown(_ count: Int) {
        maxDesktopsShown = min(max(count, 1), 9)
        settingsStore.saveMaxDesktopsShown(maxDesktopsShown)
        logger.info("Updated max desktops shown to \(maxDesktopsShown)")
        onChange?()
    }

    func setLaunchDelayMilliseconds(_ milliseconds: Int) {
        launchDelayMilliseconds = min(max(milliseconds, 50), 2000)
        settingsStore.saveLaunchDelayMilliseconds(launchDelayMilliseconds)
        logger.info("Updated launch delay to \(launchDelayMilliseconds) ms")
        onChange?()
    }

    func setWatchLaunchesEnabled(_ enabled: Bool) {
        watchLaunchesEnabled = enabled
        settingsStore.saveWatchLaunchesEnabled(enabled)
        logger.info(enabled ? "Enabled watch launches" : "Disabled watch launches")
        onChange?()
    }

    func setShortcutModifier(_ modifier: DesktopShortcutModifier) {
        shortcutModifier = modifier
        settingsStore.saveShortcutModifier(modifier)
        logger.info("Updated shortcut modifier to \(modifier.title)")
        onChange?()
    }

    private func handleLaunchObserverEvent(_ event: LaunchObserver.Event) {
        switch event {
        case .launched(let application):
            handleApplicationLaunch(application)
        case .terminated, .activated:
            break
        }

        reloadRunningApps()
    }

    private func handleApplicationLaunch(_ application: NSRunningApplication) {
        guard watchLaunchesEnabled else { return }
        guard let bundleID = application.bundleIdentifier else { return }
        guard let rule = rule(for: bundleID) else { return }

        if suppressedLaunchWatchBundleIDs.remove(bundleID) != nil {
            logger.info("Skipped launch watch for \(bundleID) because Perch initiated the launch")
            return
        }

        logger.info("Watch launches matched \(bundleID), reopening on desktop \(rule.desktopNumber)")
        open(bundleID: bundleID, onDesktop: rule.desktopNumber)
    }

    private func registerSuppressedLaunchWatch(for bundleID: String) {
        suppressedLaunchWatchBundleIDs.insert(bundleID)

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
            self?.suppressedLaunchWatchBundleIDs.remove(bundleID)
        }
    }
}
