import SwiftUI

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel
    let documentAccess: any DocumentAccessServicing
    let documentRegistry: DocumentAccessRegistry

    @State private var isShowingImporter = false

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
                        .onDelete { offsets in
                            let tabIDs = offsets.compactMap { index in
                                model.tabs.indices.contains(index)
                                    ? model.tabs[index].id
                                    : nil
                            }
                            Task {
                                for tabID in tabIDs {
                                    await model.closeTab(
                                        tabID,
                                        registry: documentRegistry
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("FileViewer")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Open Document", systemImage: "folder") {
                        isShowingImporter = true
                    }
                    .keyboardShortcut("o", modifiers: .command)
                }
            }
        } detail: {
            if let tab = model.selectedTab {
                documentView(for: tab)
                    .navigationTitle(tab.document.identity.displayName)
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    "No Document Open",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Open a Markdown or PDF document to begin reading.")
                )
                .accessibilityIdentifier("empty-workspace")
            }
        }
        .overlay {
            if model.isOpeningDocument {
                ProgressView("Opening document…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: DocumentKind.readableContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                Task {
                    await model.openDocument(
                        at: url,
                        using: documentAccess,
                        registry: documentRegistry
                    )
                }
            case let .failure(error):
                model.presentOpenError(error)
            }
        }
        .alert(
            "Unable to Open Document",
            isPresented: Binding(
                get: { model.presentedError != nil },
                set: { isPresented in
                    if !isPresented {
                        model.dismissError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                model.dismissError()
            }
        } message: {
            Text(model.presentedError ?? "")
        }
    }

    @ViewBuilder
    private func documentView(for tab: DocumentTab) -> some View {
        switch tab.content {
        case let .markdown(text):
            MarkdownReaderView(text: text)
        case let .pdf(data):
            PDFReaderView(data: data)
        }
    }
}

#Preview {
    let bookmarks = UserDefaultsBookmarkStore(
        defaults: UserDefaults(suiteName: "WorkspaceViewPreview")!
    )
    WorkspaceView(
        model: WorkspaceModel(),
        documentAccess: DocumentAccessService(bookmarks: bookmarks),
        documentRegistry: DocumentAccessRegistry()
    )
}
