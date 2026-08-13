import SwiftUI
#if DEBUG
import UIKit
#endif

@main
struct FileViewerIpadApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup(
            id: "workspace",
            for: WorkspaceSceneValue.self,
            content: { $sceneValue in
                WorkspaceSceneRoot(sceneValue: sceneValue)
                    .environment(environment)
            },
            defaultValue: { Self.defaultSceneValue() }
        )
    }

    private static func defaultSceneValue() -> WorkspaceSceneValue {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-test-session-seed")
            || arguments.contains("--ui-test-session-restore")
            || arguments.contains("--ui-test-session-stale") {
            return WorkspaceSceneValue(
                workspaceID: WorkspaceID(
                    rawValue: UUID(
                        uuidString: "A67B1164-E29C-4E2F-A87B-5A783CB30260"
                    )!
                )
            )
        }
#endif
        return WorkspaceSceneValue()
    }
}

private struct WorkspaceSceneRoot: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: WorkspaceModel

    init(sceneValue: WorkspaceSceneValue) {
        let model = Self.makeInitialModel(workspaceID: sceneValue.workspaceID)
        _model = State(initialValue: model)
    }

    var body: some View {
        WorkspaceView(
            model: model,
            documentAccess: environment.documentAccess,
            documentRegistry: environment.documentRegistry,
            recentStore: environment.recentDocuments,
            readingState: environment.readingState,
            sceneSessionStore: environment.sceneSessions,
            openRequestRouter: environment.openRequestRouter,
            sceneCoordinator: environment.sceneCoordinator
        )
    }

    private static func makeInitialModel(workspaceID: WorkspaceID) -> WorkspaceModel {
        let model = WorkspaceModel(id: workspaceID)
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-markdown") {
            let descriptor = DocumentDescriptor(
                identity: DocumentIdentity(
                    persistentID: "ui-test-markdown",
                    displayName: "Phase1.md"
                ),
                kind: .markdown
            )
            model.open(
                ResolvedDocument(
                    descriptor: descriptor,
                    content: .markdown("# Phase 1 Test Document\n\nSelectable Markdown body.")
                )
            )
        } else if ProcessInfo.processInfo.arguments.contains("--ui-test-pdf") {
            let descriptor = DocumentDescriptor(
                identity: DocumentIdentity(
                    persistentID: "ui-test-pdf",
                    displayName: "Phase1.pdf"
                ),
                kind: .pdf
            )
            let renderer = UIGraphicsPDFRenderer(
                bounds: CGRect(x: 0, y: 0, width: 612, height: 792)
            )
            let data = renderer.pdfData { context in
                for page in 1...2 {
                    context.beginPage()
                    "Phase 1 PDF — Page \(page)"
                        .draw(at: CGPoint(x: 72, y: 72))
                }
            }
            model.open(
                ResolvedDocument(
                    descriptor: descriptor,
                    content: .pdf(data)
                )
            )
        }
#endif
        return model
    }
}
