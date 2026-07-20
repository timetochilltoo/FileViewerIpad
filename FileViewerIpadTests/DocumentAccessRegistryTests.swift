import XCTest
@testable import FileViewerIpad

final class DocumentAccessRegistryTests: XCTestCase {
    func testSecondClaimActivatesExistingLocation() async {
        let registry = DocumentAccessRegistry()
        let identity = DocumentIdentity(persistentID: "document-a", displayName: "A.pdf")
        let firstLocation = DocumentLocation(
            workspaceID: WorkspaceID(),
            tabID: UUID()
        )
        let secondLocation = DocumentLocation(
            workspaceID: WorkspaceID(),
            tabID: UUID()
        )

        let firstResult = await registry.claim(identity, at: firstLocation)
        let secondResult = await registry.claim(identity, at: secondLocation)

        XCTAssertEqual(firstResult, .claimed)
        XCTAssertEqual(secondResult, .activateExisting(firstLocation))
    }

    func testReleaseOnlyRemovesMatchingLocation() async {
        let registry = DocumentAccessRegistry()
        let identity = DocumentIdentity(persistentID: "document-a", displayName: "A.pdf")
        let owner = DocumentLocation(workspaceID: WorkspaceID(), tabID: UUID())
        let other = DocumentLocation(workspaceID: WorkspaceID(), tabID: UUID())

        _ = await registry.claim(identity, at: owner)
        await registry.release(identity, from: other)
        let stillOwned = await registry.location(for: identity)
        await registry.release(identity, from: owner)
        let released = await registry.location(for: identity)

        XCTAssertEqual(stillOwned, owner)
        XCTAssertNil(released)
    }
}

