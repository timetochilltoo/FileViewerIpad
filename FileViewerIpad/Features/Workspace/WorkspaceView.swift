import SwiftUI

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedTabID) {
                Section("Open Documents") {
                    if model.tabs.isEmpty {
                        Text("No open documents")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.tabs) { tab in
                            Label(
                                tab.document.identity.displayName,
                                systemImage: tab.document.kind == .pdf
                                    ? "doc.richtext"
                                    : "doc.plaintext"
                            )
                            .tag(tab.id)
                        }
                    }
                }
            }
            .navigationTitle("FileViewer")
        } detail: {
            if let tab = model.selectedTab {
                ContentUnavailableView(
                    tab.document.identity.displayName,
                    systemImage: tab.document.kind == .pdf
                        ? "doc.richtext"
                        : "doc.plaintext",
                    description: Text("The document reader will be added in the next phase.")
                )
            } else {
                ContentUnavailableView(
                    "No Document Open",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Open a Markdown or PDF document to begin reading.")
                )
                .accessibilityIdentifier("empty-workspace")
            }
        }
    }
}

#Preview {
    WorkspaceView(model: WorkspaceModel())
}

