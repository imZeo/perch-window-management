import AppKit

final class AppLauncher {
    func launchOrActivate(bundleID: String) {
        if let runningApplication = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            runningApplication.activate(options: [.activateIgnoringOtherApps])
            return
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            guard let error else { return }
            NSLog("Failed to launch %@: %@", bundleID, error.localizedDescription)
        }
    }
}
