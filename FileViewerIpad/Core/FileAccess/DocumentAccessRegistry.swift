import Foundation

struct WorkspaceID: Hashable, Codable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct DocumentLocation: Hashable, Sendable {
    let workspaceID: WorkspaceID
    let tabID: DocumentTab.ID
}

enum DocumentClaimResult: Equatable, Sendable {
    case claimed
    case activateExisting(DocumentLocation)
}

actor DocumentAccessRegistry {
    private var locations: [DocumentIdentity: DocumentLocation] = [:]

    func claim(
        _ identity: DocumentIdentity,
        at location: DocumentLocation
    ) -> DocumentClaimResult {
        if let existing = locations[identity] {
            return .activateExisting(existing)
        }

        locations[identity] = location
        return .claimed
    }

    func release(
        _ identity: DocumentIdentity,
        from location: DocumentLocation
    ) {
        guard locations[identity] == location else { return }
        locations.removeValue(forKey: identity)
    }

    func location(for identity: DocumentIdentity) -> DocumentLocation? {
        locations[identity]
    }
}

