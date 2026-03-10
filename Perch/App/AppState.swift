import AppKit

final class AppState {
    private let runningAppsService: RunningAppsService
    private let rulesStore: RulesStore
    private let spaceSwitcher: SpaceSwitcher
    private let appLauncher: AppLauncher
    private let launchObserver: LaunchObserver
    private let permissionsService: PermissionsService
    private let logger: AppLogger

    private(set) var runningApps: [RunningAppInfo] = []
    private(set) var rules: [AppRule] = []

    var onChange: (() -> Void)?

    init(
        runningAppsService: RunningAppsService = RunningAppsService(),
        rulesStore: RulesStore = RulesStore(),
        spaceSwitcher: SpaceSwitcher = SpaceSwitcher(),
        appLauncher: AppLauncher = AppLauncher(),
        launchObserver: LaunchObserver = LaunchObserver(),
        permissionsService: PermissionsService = PermissionsService(),
        logger: AppLogger = AppLogger(category: "AppState")
    ) {
        self.runningAppsService = runningAppsService
        self.rulesStore = rulesStore
        self.spaceSwitcher = spaceSwitcher
        self.appLauncher = appLauncher
        self.launchObserver = launchObserver
        self.permissionsService = permissionsService
        self.logger = logger
    }

    func start() {
        reload()
        launchObserver.start { [weak self] in
            self?.reloadRunningApps()
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

        open(bundleID: bundleID, onDesktop: rule.desktopNumber)
    }

    func open(bundleID: String, onDesktop desktopNumber: Int) {
        guard permissionsService.isAccessibilityTrusted(prompt: false) else {
            logger.error("Accessibility permission is required to switch desktops")
            requestAccessibilityIfNeeded()
            return
        }

        logger.info("Opening \(bundleID) on desktop \(desktopNumber)")
        spaceSwitcher.switchToDesktop(desktopNumber)

        let delay = DispatchTime.now() + .milliseconds(250)
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
}
