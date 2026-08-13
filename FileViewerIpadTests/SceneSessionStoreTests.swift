import Foundation
import XCTest
@testable import FileViewerIpad

final class SceneSessionStoreTests: XCTestCase {
    func testSavesSessionsIndependentlyByWorkspace() async throws {
        let suiteName = "SceneSessionStoreTests.\(UUID().uuidString)"
        let store = UserDefaultsSceneSessionStore(suiteName: suiteName)
        let firstWorkspace = WorkspaceID()
        let secondWorkspace = WorkspaceID()
        let firstSession = makeSession(ids: ["a", "b"], selectedID: "b", date: 1)
        let secondSession = makeSession(ids: ["c"], selectedID: "c", date: 2)
        defer { clearDefaults(suiteName) }

        await store.saveSession(firstSession, for: firstWorkspace)
        await store.saveSession(secondSession, for: secondWorkspace)

        let firstValue = await store.session(for: firstWorkspace)
        let secondValue = await store.session(for: secondWorkspace)
        let restoredFirst = try XCTUnwrap(firstValue)
        let restoredSecond = try XCTUnwrap(secondValue)
        XCTAssertEqual(restoredFirst, firstSession)
        XCTAssertEqual(restoredSecond, secondSession)
    }

    func testDeduplicatesAndCapsDocumentsAndWorkspaces() async throws {
        let suiteName = "SceneSessionStoreTests.\(UUID().uuidString)"
        let store = UserDefaultsSceneSessionStore(
            suiteName: suiteName,
            maximumWorkspaceCount: 2,
            maximumDocumentsPerWorkspace: 2
        )
        let oldestWorkspace = WorkspaceID()
        let middleWorkspace = WorkspaceID()
        let newestWorkspace = WorkspaceID()
        defer { clearDefaults(suiteName) }

        await store.saveSession(
            makeSession(ids: ["a"], selectedID: "a", date: 1),
            for: oldestWorkspace
        )
        await store.saveSession(
            makeSession(ids: ["b"], selectedID: "b", date: 2),
            for: middleWorkspace
        )
        await store.saveSession(
            makeSession(
                ids: ["c", "c", "d", "e"],
                selectedID: "e",
                date: 3
            ),
            for: newestWorkspace
        )

        let oldest = await store.session(for: oldestWorkspace)
        let newestValue = await store.session(for: newestWorkspace)
        let newest = try XCTUnwrap(newestValue)
        XCTAssertNil(oldest)
        XCTAssertEqual(
            newest.documents.map(\.identity.persistentID),
            ["c", "d"]
        )
        XCTAssertNil(newest.selectedDocumentPersistentID)
    }

    func testIgnoresUnsupportedSchemaAndCorruptData() async throws {
        let suiteName = "SceneSessionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UserDefaultsSceneSessionStore(suiteName: suiteName)
        let workspaceID = WorkspaceID()
        let unsupported = WorkspaceSession(
            schemaVersion: 99,
            documents: makeSession(ids: ["a"], selectedID: "a", date: 1).documents,
            selectedDocumentPersistentID: "a",
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        defer { clearDefaults(suiteName) }

        let encoded = try JSONEncoder().encode([
            workspaceID.rawValue.uuidString.lowercased(): unsupported
        ])
        defaults.set(encoded, forKey: UserDefaultsSceneSessionStore.storageKey)
        let unsupportedResult = await store.session(for: workspaceID)
        XCTAssertNil(unsupportedResult)

        defaults.set(
            Data("not-json".utf8),
            forKey: UserDefaultsSceneSessionStore.storageKey
        )
        let corruptResult = await store.session(for: workspaceID)
        XCTAssertNil(corruptResult)
    }

    @MainActor
    func testWorkspaceSnapshotPersistsNoDocumentContent() async throws {
        let suiteName = "SceneSessionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UserDefaultsSceneSessionStore(suiteName: suiteName)
        let workspace = WorkspaceModel()
        let secretBody = "PRIVATE-DOCUMENT-CONTENT-77B3"
        let descriptor = DocumentDescriptor(
            identity: DocumentIdentity(
                persistentID: "private-document",
                displayName: "Private.md"
            ),
            kind: .markdown
        )
        workspace.open(
            ResolvedDocument(
                descriptor: descriptor,
                content: .markdown(secretBody)
            )
        )
        defer { clearDefaults(suiteName) }

        let snapshot = try XCTUnwrap(workspace.sessionSnapshot())
        await store.saveSession(snapshot, for: workspace.id)

        let data = try XCTUnwrap(
            defaults.data(forKey: UserDefaultsSceneSessionStore.storageKey)
        )
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(secretBody))
    }

    private func makeSession(
        ids: [String],
        selectedID: String?,
        date: TimeInterval
    ) -> WorkspaceSession {
        WorkspaceSession(
            documents: ids.map { id in
                WorkspaceSessionDocument(
                    identity: DocumentIdentity(
                        persistentID: id,
                        displayName: "\(id).md"
                    ),
                    kind: .markdown
                )
            },
            selectedDocumentPersistentID: selectedID,
            updatedAt: Date(timeIntervalSince1970: date)
        )
    }

    private func clearDefaults(_ suiteName: String) {
        UserDefaults(suiteName: suiteName)?
            .removePersistentDomain(forName: suiteName)
    }
}
