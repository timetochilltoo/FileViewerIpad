import SwiftUI
#if DEBUG
import UIKit
#endif

@main
struct FileViewerIpadApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            WorkspaceSceneRoot()
                .environment(environment)
        }
    }
}

private struct WorkspaceSceneRoot: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: WorkspaceModel

    init() {
        let model = WorkspaceModel()
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
                context.beginPage()
                "Phase 1 PDF".draw(at: CGPoint(x: 72, y: 72))
            }
            model.open(
                ResolvedDocument(
                    descriptor: descriptor,
                    content: .pdf(data)
                )
            )
        }
#endif
        _model = State(initialValue: model)
    }

    var body: some View {
        WorkspaceView(
            model: model,
            documentAccess: environment.documentAccess,
            documentRegistry: environment.documentRegistry
        )
    }
}
