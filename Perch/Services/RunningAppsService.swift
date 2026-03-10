import AppKit

final class RunningAppsService {
    func fetchRunningApps() -> [RunningAppInfo] {
        NSWorkspace.shared.runningApplications
            .filter { application in
                application.activationPolicy == .regular &&
                application.bundleIdentifier != nil &&
                !application.isTerminated
            }
            .compactMap { application in
                guard let bundleID = application.bundleIdentifier else { return nil }

                return RunningAppInfo(
                    id: bundleID,
                    bundleID: bundleID,
                    displayName: application.localizedName ?? bundleID,
                    processIdentifier: application.processIdentifier,
                    isActive: application.isActive,
                    icon: application.icon
                )
            }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }
}
