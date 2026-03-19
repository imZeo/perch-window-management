import AppKit

final class RunningAppsService {
    func fetchRunningApps() -> [RunningAppInfo] {
        let apps: [RunningAppInfo] = NSWorkspace.shared.runningApplications
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

        return deduplicatedApps(from: apps)
    }

    func deduplicatedApps(from apps: [RunningAppInfo]) -> [RunningAppInfo] {
        let groupedApps = Dictionary(grouping: apps) { $0.bundleID }
        return groupedApps.values
            .compactMap { preferredApp(from: $0) }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    private func preferredApp(from apps: [RunningAppInfo]) -> RunningAppInfo? {
        apps.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            if lhs.displayName != rhs.displayName {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.processIdentifier < rhs.processIdentifier
        }.first
    }
}
