import AppKit

final class AppState {
    private let runningAppsService: RunningAppsService
    private let rulesStore: RulesStore
    private let settingsStore: SettingsStore
    private let spaceSwitcher: SpaceSwitcher
    private let dockAssignmentService: DockAssignmentService
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
        dockAssignmentService: DockAssignmentService = DockAssignmentService(),
        appLauncher: AppLauncher = AppLauncher(),
        launchObserver: LaunchObserver = LaunchObserver(),
        permissionsService: PermissionsService = PermissionsService(),
        logger: AppLogger = AppLogger(category: "AppState")
    ) {
        self.runningAppsService = runningAppsService
        self.rulesStore = rulesStore
        self.settingsStore = settingsStore
        self.spaceSwitcher = spaceSwitcher
        self.dockAssignmentService = dockAssignmentService
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

    func assign(_ assignmentTarget: AssignmentTarget, to app: RunningAppInfo) {
        let existingTarget = rule(for: app.bundleID)?.assignmentTarget
        let needsNativeAssignmentClear = existingTarget == .allDesktops && assignmentTarget != .allDesktops
        let needsNativeAssignmentApply = assignmentTarget == .allDesktops
        let accessibilityTrusted = permissionsService.isAccessibilityTrusted(prompt: false)

        if needsNativeAssignmentClear && !accessibilityTrusted {
            logger.error("Accessibility permission is required to manage native app assignments")
            requestAccessibilityIfNeeded()
            return
        }

        if needsNativeAssignmentClear,
           !dockAssignmentService.apply(.none, bundleID: app.bundleID, displayName: app.displayName) {
            logger.error("Could not clear native All Desktops assignment for \(app.bundleID); saving the new rule anyway")
        }

        let rule = AppRule(bundleID: app.bundleID, displayName: app.displayName, assignmentTarget: assignmentTarget)
        rulesStore.upsert(rule)
        logger.info("Assigned \(app.bundleID) to \(rule.assignmentDisplayName)")

        if needsNativeAssignmentApply {
            if !accessibilityTrusted {
                logger.error("Saved All Desktops rule for \(app.bundleID), but Accessibility permission is still required to apply it natively")
                requestAccessibilityIfNeeded()
            } else if !dockAssignmentService.apply(.allDesktops, bundleID: app.bundleID, displayName: app.displayName) {
                logger.error("Saved All Desktops rule for \(app.bundleID), but native Dock assignment did not apply")
            }
        }

        reload()
    }

    func clearAssignment(for bundleID: String) {
        guard let existingRule = rule(for: bundleID) else { return }

        if existingRule.assignmentTarget == .allDesktops {
            guard permissionsService.isAccessibilityTrusted(prompt: false) else {
                logger.error("Accessibility permission is required to clear native app assignments")
                requestAccessibilityIfNeeded()
                return
            }

            if !dockAssignmentService.apply(.none, bundleID: bundleID, displayName: existingRule.displayName) {
                logger.error("Could not clear native All Desktops assignment for \(bundleID); removing the saved rule anyway")
            }
        }

        rulesStore.removeRule(for: bundleID)
        logger.info("Cleared assignment for \(bundleID)")
        reload()
    }

    func openOnAssignedDesktop(bundleID: String) {
        guard let rule = rule(for: bundleID) else {
            logger.error("Missing rule for \(bundleID)")
            return
        }

        open(bundleID: bundleID, using: rule.assignmentTarget, suppressLaunchWatch: true)
    }

    func open(bundleID: String, using assignmentTarget: AssignmentTarget, suppressLaunchWatch: Bool = false) {
        if case .desktop = assignmentTarget,
           !permissionsService.isAccessibilityTrusted(prompt: false) {
            logger.error("Accessibility permission is required to switch desktops")
            requestAccessibilityIfNeeded()
            return
        }

        if suppressLaunchWatch {
            registerSuppressedLaunchWatch(for: bundleID)
        }

        switch assignmentTarget {
        case .desktop(let desktopNumber):
            logger.info("Opening \(bundleID) on desktop \(desktopNumber) with \(shortcutModifier.title)")
            spaceSwitcher.switchToDesktop(desktopNumber, modifier: shortcutModifier)
        case .allDesktops:
            logger.info("Opening \(bundleID) with native All Desktops assignment")
        }

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

        switch rule.assignmentTarget {
        case .desktop:
            logger.info("Watch launches matched \(bundleID), reopening on \(rule.assignmentDisplayName)")
            open(bundleID: bundleID, using: rule.assignmentTarget)
        case .allDesktops:
            logger.info("Watch launches matched \(bundleID), native All Desktops assignment will handle placement")
        }
    }

    private func registerSuppressedLaunchWatch(for bundleID: String) {
        suppressedLaunchWatchBundleIDs.insert(bundleID)

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
            self?.suppressedLaunchWatchBundleIDs.remove(bundleID)
        }
    }
}
