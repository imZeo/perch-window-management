import Foundation

final class RulesStore {
    private enum StoreError: LocalizedError {
        case createDirectoryFailed(underlying: Error)
        case readFailed(underlying: Error)
        case decodeFailed(underlying: Error)
        case encodeFailed(underlying: Error)
        case writeFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .createDirectoryFailed(let underlying):
                return "Failed to create rules directory: \(underlying.localizedDescription)"
            case .readFailed(let underlying):
                return "Failed to read saved rules: \(underlying.localizedDescription)"
            case .decodeFailed(let underlying):
                return "Failed to decode saved rules: \(underlying.localizedDescription)"
            case .encodeFailed(let underlying):
                return "Failed to encode saved rules: \(underlying.localizedDescription)"
            case .writeFailed(let underlying):
                return "Failed to write saved rules: \(underlying.localizedDescription)"
            }
        }
    }

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager
    private let logger: AppLogger

    init(
        fileManager: FileManager = .default,
        applicationSupportDirectoryURL: URL? = nil,
        logger: AppLogger = AppLogger(category: "RulesStore")
    ) {
        self.fileManager = fileManager
        self.logger = logger

        let applicationSupportURL = applicationSupportDirectoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let directoryURL = applicationSupportURL.appendingPathComponent("Perch", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            logger.error(StoreError.createDirectoryFailed(underlying: error).localizedDescription)
        }
        fileURL = directoryURL.appendingPathComponent("rules.json")

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadRules() -> [AppRule] {
        do {
            let rules = try loadRulesFromDisk()
            let supportedRules = rules.filter { $0.assignmentTarget != .allDesktops }
            if supportedRules.count != rules.count {
                do {
                    try saveRulesToDisk(supportedRules)
                } catch {
                    logger.error(error.localizedDescription)
                }
            }
            return supportedRules
        } catch CocoaError.fileReadNoSuchFile {
            return []
        } catch {
            logger.error(error.localizedDescription)
            return []
        }
    }

    func saveRules(_ rules: [AppRule]) {
        do {
            try saveRulesToDisk(rules)
        } catch {
            logger.error(error.localizedDescription)
        }
    }

    func upsert(_ rule: AppRule) {
        guard var rules = loadRulesForMutation() else { return }

        if let index = rules.firstIndex(where: { $0.bundleID == rule.bundleID }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }

        saveRules(
            rules.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        )
    }

    func removeRule(for bundleID: String) {
        guard let rules = loadRulesForMutation() else { return }
        let filtered = rules.filter { $0.bundleID != bundleID }
        saveRules(filtered)
    }

    private func loadRulesForMutation() -> [AppRule]? {
        do {
            return try loadRulesFromDisk().filter { $0.assignmentTarget != .allDesktops }
        } catch CocoaError.fileReadNoSuchFile {
            return []
        } catch {
            logger.error("Skipping rules update because the existing rules file could not be loaded. \(error.localizedDescription)")
            return nil
        }
    }

    private func loadRulesFromDisk() throws -> [AppRule] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw StoreError.readFailed(underlying: error)
        }

        do {
            return try decoder.decode([AppRule].self, from: data)
        } catch {
            throw StoreError.decodeFailed(underlying: error)
        }
    }

    private func saveRulesToDisk(_ rules: [AppRule]) throws {
        let data: Data
        do {
            data = try encoder.encode(rules)
        } catch {
            throw StoreError.encodeFailed(underlying: error)
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw StoreError.writeFailed(underlying: error)
        }
    }
}
