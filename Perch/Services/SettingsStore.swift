import Foundation

final class SettingsStore {
    private enum Key {
        static let maxDesktopsShown = "maxDesktopsShown"
        static let launchDelayMilliseconds = "launchDelayMilliseconds"
        static let watchLaunchesEnabled = "watchLaunchesEnabled"
        static let shortcutModifier = "shortcutModifier"
    }

    private let userDefaults: UserDefaults
    private let defaultMaxDesktopsShown = 5
    private let defaultLaunchDelayMilliseconds = 250

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadMaxDesktopsShown() -> Int {
        let storedValue = userDefaults.integer(forKey: Key.maxDesktopsShown)
        guard storedValue != 0 else { return defaultMaxDesktopsShown }
        return clamp(storedValue)
    }

    func saveMaxDesktopsShown(_ count: Int) {
        userDefaults.set(clamp(count), forKey: Key.maxDesktopsShown)
    }

    func loadLaunchDelayMilliseconds() -> Int {
        let storedValue = userDefaults.integer(forKey: Key.launchDelayMilliseconds)
        guard storedValue != 0 else { return defaultLaunchDelayMilliseconds }
        return clampDelay(storedValue)
    }

    func saveLaunchDelayMilliseconds(_ milliseconds: Int) {
        userDefaults.set(clampDelay(milliseconds), forKey: Key.launchDelayMilliseconds)
    }

    func loadWatchLaunchesEnabled() -> Bool {
        userDefaults.bool(forKey: Key.watchLaunchesEnabled)
    }

    func saveWatchLaunchesEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Key.watchLaunchesEnabled)
    }

    func loadShortcutModifier() -> DesktopShortcutModifier {
        guard
            let storedValue = userDefaults.string(forKey: Key.shortcutModifier),
            let modifier = DesktopShortcutModifier(rawValue: storedValue)
        else {
            return .control
        }

        return modifier
    }

    func saveShortcutModifier(_ modifier: DesktopShortcutModifier) {
        userDefaults.set(modifier.rawValue, forKey: Key.shortcutModifier)
    }

    private func clamp(_ count: Int) -> Int {
        min(max(count, 1), 9)
    }

    private func clampDelay(_ milliseconds: Int) -> Int {
        min(max(milliseconds, 50), 2000)
    }
}
