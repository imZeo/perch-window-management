import Foundation

final class SettingsStore {
    private enum Key {
        static let maxDesktopsShown = "maxDesktopsShown"
    }

    private let userDefaults: UserDefaults
    private let defaultMaxDesktopsShown = 5

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

    private func clamp(_ count: Int) -> Int {
        min(max(count, 1), 9)
    }
}
