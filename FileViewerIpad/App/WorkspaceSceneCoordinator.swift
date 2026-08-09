import Foundation
import Observation

struct WorkspaceSceneValue: Codable, Hashable, Sendable {
    let workspaceID: WorkspaceID

    init(workspaceID: WorkspaceID = WorkspaceID()) {
        self.workspaceID = workspaceID
    }
}

enum WorkspaceSceneOpenRequest: Hashable, Sendable {
    case url(URL)
    case recent(RecentDocument)
}

/// Coordinates one-shot work between independent SwiftUI workspace scenes.
///
/// SwiftUI's `openWindow(value:)` can bring a scene identified by its payload to
/// the foreground, but it does not deliver a document operation to that scene.
/// This coordinator supplies that missing, app-local handoff without using a
/// broadcast notification that every window would consume.
@MainActor
@Observable
final class WorkspaceSceneCoordinator {
    private var pendingOpenRequests: [WorkspaceID: [WorkspaceSceneOpenRequest]] = [:]
    private var pendingActivations: [WorkspaceID: [DocumentLocation]] = [:]

    private(set) var revision = 0
    private(set) var registeredWorkspaceIDs: Set<WorkspaceID> = []

    func register(_ workspaceID: WorkspaceID) {
        registeredWorkspaceIDs.insert(workspaceID)
        bumpRevision()
    }

    func unregister(_ workspaceID: WorkspaceID) {
        registeredWorkspaceIDs.remove(workspaceID)
        bumpRevision()
    }

    func enqueue(
        _ request: WorkspaceSceneOpenRequest,
        for workspaceID: WorkspaceID
    ) {
        pendingOpenRequests[workspaceID, default: []].append(request)
        bumpRevision()
    }

    func enqueueActivation(_ location: DocumentLocation) {
        pendingActivations[location.workspaceID, default: []].append(location)
        bumpRevision()
    }

    func takeOpenRequests(
        for workspaceID: WorkspaceID
    ) -> [WorkspaceSceneOpenRequest] {
        let requests = pendingOpenRequests.removeValue(forKey: workspaceID) ?? []
        if !requests.isEmpty {
            bumpRevision()
        }
        return requests
    }

    func takeActivations(
        for workspaceID: WorkspaceID
    ) -> [DocumentLocation] {
        let locations = pendingActivations.removeValue(forKey: workspaceID) ?? []
        if !locations.isEmpty {
            bumpRevision()
        }
        return locations
    }

    private func bumpRevision() {
        revision &+= 1
    }
}
