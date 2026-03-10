import AppKit

final class AppLauncher {
    private let logger = AppLogger(category: "AppLauncher")

    func launchOrActivate(bundleID: String) {
        if let runningApplication = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            if #available(macOS 14.0, *) {
                _ = runningApplication.activate(options: [])
            } else {
                _ = runningApplication.activate(options: [.activateIgnoringOtherApps])
            }
            logger.info("Activated running app \(bundleID)")
            return
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            logger.error("Could not resolve application URL for \(bundleID)")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            guard let error else {
                self.logger.info("Launched app \(bundleID)")
                return
            }

            self.logger.error("Failed to launch \(bundleID): \(error.localizedDescription)")
        }
    }
}
