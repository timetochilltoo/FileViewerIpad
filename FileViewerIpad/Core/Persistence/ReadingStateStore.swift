import Foundation

actor UserDefaultsReadingStateStore: ReadingStateStoring {
    private let defaults: UserDefaults
    private let storageKey = "reading-state.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    init(suiteName: String) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func readingPosition(for identity: DocumentIdentity) -> ReadingPosition? {
        guard let data = defaults.data(forKey: storageKey),
              let records = try? JSONDecoder().decode(
                  [String: ReadingPosition].self,
                  from: data
              ) else {
            return nil
        }
        return records[identity.persistentID]
    }

    func saveReadingPosition(
        _ position: ReadingPosition,
        for identity: DocumentIdentity
    ) {
        var records = decodedRecords()
        records[identity.persistentID] = position
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func decodedRecords() -> [String: ReadingPosition] {
        guard let data = defaults.data(forKey: storageKey),
              let records = try? JSONDecoder().decode(
                  [String: ReadingPosition].self,
                  from: data
              ) else {
            return [:]
        }
        return records
    }
}
