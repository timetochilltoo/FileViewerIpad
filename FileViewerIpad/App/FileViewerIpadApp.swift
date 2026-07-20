import SwiftUI

@main
struct FileViewerIpadApp: App {
    var body: some Scene {
        WindowGroup {
            WorkspaceSceneRoot()
        }
    }
}

private struct WorkspaceSceneRoot: View {
    @State private var model = WorkspaceModel()

    var body: some View {
        WorkspaceView(model: model)
    }
}

