import ServiceManagement

final class LaunchAtLoginService {
    enum Status {
        case enabled
        case disabled
        case requiresApproval
    }

    private let logger: AppLogger

    init(logger: AppLogger = AppLogger(category: "LaunchAtLogin")) {
        self.logger = logger
    }

    func status() -> Status {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered, .notFound:
            return .disabled
        @unknown default:
            logger.error("Encountered unknown launch-at-login status")
            return .disabled
        }
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Enabled launch at login")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Disabled launch at login")
            }
            return true
        } catch {
            logger.error("Failed to update launch at login: \(error.localizedDescription)")
            return false
        }
    }
}
