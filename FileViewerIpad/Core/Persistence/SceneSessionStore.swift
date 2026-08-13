import Foundation

struct WorkspaceSessionDocument: Codable, Hashable, Sendable {
    let identity: DocumentIdentity
    let kind: DocumentKind

    init(identity: DocumentIdentity, kind: DocumentKind) {
        self.identity = identity
        self.kind = kind
    }

    init(descriptor: DocumentDescriptor) {
        self.init(identity: descriptor.identity, kind: descriptor.kind)
    }

    func recentDocument(restoredAt date: Date) -> RecentDocument {
        RecentDocument(identity: identity, kind: kind, lastOpenedAt: date)
    }
}

struct WorkspaceSession: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let documents: [WorkspaceSessionDocument]
    let selectedDocumentPersistentID: String?
    let updatedAt: Date

    init(
        schemaVersion: Int = WorkspaceSession.currentSchemaVersion,
        documents: [WorkspaceSessionDocument],
        selectedDocumentPersistentID: String?,
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.documents = documents
        self.selectedDocumentPersistentID = selectedDocumentPersistentID
        self.updatedAt = updatedAt
    }
}

protocol SceneSessionStoring: Sendable {
    func session(for workspaceID: WorkspaceID) async -> WorkspaceSession?
    func saveSession(_ session: WorkspaceSession, for workspaceID: WorkspaceID) async
    func removeSession(for workspaceID: WorkspaceID) async
}

actor UserDefaultsSceneSessionStore: SceneSessionStoring {
    static let storageKey = "scene-sessions.v1"

    private let defaults: UserDefaults
    private let maximumWorkspaceCount: Int
    private let maximumDocumentsPerWorkspace: Int

    init(
        defaults: UserDefaults = .standard,
        maximumWorkspaceCount: Int = 12,
        maximumDocumentsPerWorkspace: Int = 20
    ) {
        self.defaults = defaults
        self.maximumWorkspaceCount = max(1, maximumWorkspaceCount)
        self.maximumDocumentsPerWorkspace = max(1, maximumDocumentsPerWorkspace)
    }

    init(
        suiteName: String,
        maximumWorkspaceCount: Int = 12,
        maximumDocumentsPerWorkspace: Int = 20
    ) {
        self.init(
            defaults: UserDefaults(suiteName: suiteName) ?? .standard,
            maximumWorkspaceCount: maximumWorkspaceCount,
            maximumDocumentsPerWorkspace: maximumDocumentsPerWorkspace
        )
    }

    func session(for workspaceID: WorkspaceID) -> WorkspaceSession? {
        guard let session = decodedSessions()[workspaceID.storageKey],
              session.schemaVersion == WorkspaceSession.currentSchemaVersion else {
            return nil
        }
        return normalized(session)
    }

    func saveSession(
        _ session: WorkspaceSession,
        for workspaceID: WorkspaceID
    ) {
        var sessions = decodedSessions()
        let normalizedSession = normalized(session)

        guard !normalizedSession.documents.isEmpty else {
            sessions.removeValue(forKey: workspaceID.storageKey)
            save(sessions)
            return
        }

        sessions[workspaceID.storageKey] = normalizedSession
        let retainedSessions = sessions
            .sorted { $0.value.updatedAt > $1.value.updatedAt }
            .prefix(maximumWorkspaceCount)
        save(
            Dictionary(
                uniqueKeysWithValues: retainedSessions.map {
                    ($0.key, $0.value)
                }
            )
        )
    }

    func removeSession(for workspaceID: WorkspaceID) {
        var sessions = decodedSessions()
        sessions.removeValue(forKey: workspaceID.storageKey)
        save(sessions)
    }

    private func decodedSessions() -> [String: WorkspaceSession] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let sessions = try? JSONDecoder().decode(
                  [String: WorkspaceSession].self,
                  from: data
              ) else {
            return [:]
        }
        return sessions
    }

    private func normalized(_ session: WorkspaceSession) -> WorkspaceSession {
        var seenPersistentIDs: Set<String> = []
        let documents = session.documents.filter { document in
            seenPersistentIDs.insert(document.identity.persistentID).inserted
        }
        .prefix(maximumDocumentsPerWorkspace)

        let retainedDocuments = Array(documents)
        let retainedIDs = Set(retainedDocuments.map(\.identity.persistentID))
        let selectedID = session.selectedDocumentPersistentID.flatMap { id in
            retainedIDs.contains(id) ? id : nil
        }

        return WorkspaceSession(
            documents: retainedDocuments,
            selectedDocumentPersistentID: selectedID,
            updatedAt: session.updatedAt
        )
    }

    private func save(_ sessions: [String: WorkspaceSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

private extension WorkspaceID {
    var storageKey: String {
        rawValue.uuidString.lowercased()
    }
}
