import XCTest
@testable import FileViewerIpad

@MainActor
final class WorkspaceSceneCoordinatorTests: XCTestCase {
    func testSceneValueRoundTripsForWindowGroupIdentity() throws {
        let value = WorkspaceSceneValue(workspaceID: WorkspaceID())
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(WorkspaceSceneValue.self, from: data)

        XCTAssertEqual(decoded, value)
    }

    func testQueuesOpenRequestForOnlyItsTargetWorkspace() {
        let coordinator = WorkspaceSceneCoordinator()
        let first = WorkspaceID()
        let second = WorkspaceID()
        let recent = RecentDocument(
            identity: DocumentIdentity(
                persistentID: "recent",
                displayName: "Recent.md"
            ),
            kind: .markdown,
            lastOpenedAt: Date(timeIntervalSince1970: 1_000)
        )

        coordinator.enqueue(.recent(recent), for: first)

        XCTAssertEqual(coordinator.takeOpenRequests(for: second), [])
        XCTAssertEqual(coordinator.takeOpenRequests(for: first), [.recent(recent)])
        XCTAssertEqual(coordinator.takeOpenRequests(for: first), [])
    }

    func testQueuesActivationForItsTargetWorkspace() {
        let coordinator = WorkspaceSceneCoordinator()
        let workspaceID = WorkspaceID()
        let location = DocumentLocation(
            workspaceID: workspaceID,
            tabID: UUID()
        )

        coordinator.enqueueActivation(location)

        XCTAssertEqual(coordinator.takeActivations(for: workspaceID), [location])
        XCTAssertEqual(coordinator.takeActivations(for: workspaceID), [])
    }

    func testRegistrationTracksLiveWorkspaceScenes() {
        let coordinator = WorkspaceSceneCoordinator()
        let workspaceID = WorkspaceID()

        coordinator.register(workspaceID)
        XCTAssertTrue(coordinator.registeredWorkspaceIDs.contains(workspaceID))

        coordinator.unregister(workspaceID)
        XCTAssertFalse(coordinator.registeredWorkspaceIDs.contains(workspaceID))
    }
}
