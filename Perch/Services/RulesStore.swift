import Foundation

final class RulesStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directoryURL = applicationSupportURL.appendingPathComponent("Perch", isDirectory: true)

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        fileURL = directoryURL.appendingPathComponent("rules.json")

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadRules() -> [AppRule] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([AppRule].self, from: data)) ?? []
    }

    func saveRules(_ rules: [AppRule]) {
        guard let data = try? encoder.encode(rules) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func upsert(_ rule: AppRule) {
        var rules = loadRules()

        if let index = rules.firstIndex(where: { $0.bundleID == rule.bundleID }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }

        saveRules(rules.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        })
    }

    func removeRule(for bundleID: String) {
        let filtered = loadRules().filter { $0.bundleID != bundleID }
        saveRules(filtered)
    }
}
