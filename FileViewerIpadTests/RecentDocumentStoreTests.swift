import Foundation
import XCTest
@testable import FileViewerIpad

final class RecentDocumentStoreTests: XCTestCase {
    func testOrdersDeduplicatesAndCapsRecentDocuments() async {
        let suiteName = "RecentDocumentStoreTests.\(UUID().uuidString)"
        let store = UserDefaultsRecentDocumentStore(
            suiteName: suiteName,
            maximumCount: 2
        )

        await store.record(makeRecent(id: "a", date: 1))
        await store.record(makeRecent(id: "b", date: 2))
        await store.record(makeRecent(id: "c", date: 3))
        await store.record(makeRecent(id: "b", date: 4))

        let documents = await store.recentDocuments()
        XCTAssertEqual(
            documents.map(\.identity.persistentID),
            ["b", "c"]
        )
        UserDefaults(suiteName: suiteName)?
            .removePersistentDomain(forName: suiteName)
    }

    func testRemovesRecentDocument() async {
        let suiteName = "RecentDocumentStoreTests.\(UUID().uuidString)"
        let store = UserDefaultsRecentDocumentStore(suiteName: suiteName)
        let document = makeRecent(id: "remove-me", date: 1)

        await store.record(document)
        await store.remove(identity: document.identity)

        let documents = await store.recentDocuments()
        XCTAssertTrue(documents.isEmpty)
        UserDefaults(suiteName: suiteName)?
            .removePersistentDomain(forName: suiteName)
    }

    private func makeRecent(id: String, date: TimeInterval) -> RecentDocument {
        RecentDocument(
            identity: DocumentIdentity(
                persistentID: id,
                displayName: "\(id).md"
            ),
            kind: .markdown,
            lastOpenedAt: Date(timeIntervalSince1970: date)
        )
    }
}
