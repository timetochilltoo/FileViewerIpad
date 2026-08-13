import SwiftUI

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel
    let documentAccess: any DocumentAccessServicing
    let documentRegistry: DocumentAccessRegistry
    let recentStore: any RecentDocumentStoring
    let readingState: any ReadingStateStoring
    let sceneSessionStore: any SceneSessionStoring
    let openRequestRouter: OpenRequestRouter
    let sceneCoordinator: WorkspaceSceneCoordinator

    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase

    @State private var isShowingImporter = false
    @State private var isShowingNewWindowImporter = false
    @State private var readingPositionReadyTabIDs: Set<DocumentTab.ID> = []
    @State private var hasCompletedInitialSessionRestore = false
#if DEBUG
    @State private var isUITestSessionPersisted = false
#endif

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
                                await persistSession()
                            }
                        }
                    }
                }

                if !model.recentDocuments.isEmpty {
                    Section("Recent Documents") {
                        ForEach(model.recentDocuments) { recent in
                            Button {
                                open(recent)
                            } label: {
                                Label(
                                    recent.identity.displayName,
                                    systemImage: recent.kind == .pdf
                                        ? "doc.richtext"
                                        : "doc.plaintext"
                                )
                                .contextMenu {
                                    Button(
                                        "Open in New Window",
                                        systemImage: "rectangle.badge.plus"
                                    ) {
                                        openInNewWindow(recent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            let identities = offsets.compactMap { index in
                                model.recentDocuments.indices.contains(index)
                                    ? model.recentDocuments[index].identity
                                    : nil
                            }
                            Task {
                                for identity in identities {
                                    await model.removeRecent(
                                        identity,
                                        using: recentStore
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("FileViewer")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Open Document", systemImage: "folder") {
                        isShowingImporter = true
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    Menu {
                        Button("New Window", systemImage: "plus.square.on.square") {
                            openNewWindow()
                        }
                        Button(
                            "Open in New Window",
                            systemImage: "rectangle.badge.plus"
                        ) {
                            isShowingNewWindowImporter = true
                        }
                    } label: {
                        Label("Window Actions", systemImage: "rectangle.on.rectangle")
                    }
                    .accessibilityIdentifier("window-actions")
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
                open(url)
            case let .failure(error):
                model.presentOpenError(error)
            }
        }
        .fileImporter(
            isPresented: $isShowingNewWindowImporter,
            allowedContentTypes: DocumentKind.readableContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                openInNewWindow(url)
            case let .failure(error):
                model.presentOpenError(error)
            }
        }
        .alert(
            model.presentedErrorTitle,
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
        .task {
            sceneCoordinator.register(model.id)
            readingPositionReadyTabIDs.formUnion(model.tabs.map(\.id))
            await model.refreshRecents(using: recentStore)

#if DEBUG
            await seedUITestStaleSessionIfRequested()
#endif
            guard await restoreSavedSessionIfNeeded() else { return }
            hasCompletedInitialSessionRestore = true
            await processSceneRequests()
#if DEBUG
            await seedUITestSessionIfRequested()
#endif
            await persistSession()
        }
        .onDisappear {
            sceneCoordinator.unregister(model.id)
            Task {
                await persistSession()
                await model.closeAllTabs(registry: documentRegistry)
            }
        }
        .onChange(of: model.selectedTabID) { _, _ in
            Task {
                await persistSession()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            Task {
                await persistSession()
            }
        }
        .onChange(of: sceneCoordinator.revision) { _, _ in
            Task {
                await processSceneRequests()
            }
        }
        .onOpenURL { url in
            Task {
                guard await openRequestRouter.claim(url) else { return }
                await openAndRefresh(url)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            open(url)
            return true
        }
        .searchable(
            text: Binding(
                get: { model.selectedSearchQuery },
                set: { model.updateSearchQuery($0) }
            ),
            placement: .toolbar,
            prompt: "Search document"
        )
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                if let status = model.searchStatusText {
                    Text(status)
                        .foregroundStyle(
                            status == "No matches" ? .orange : .secondary
                        )
                        .accessibilityIdentifier("search-status")
                }
                if model.selectedTab?.search.matchCount ?? 0 > 0 {
                    Button("Previous Match", systemImage: "chevron.up") {
                        model.previousSearchMatch()
                    }
                    Button("Next Match", systemImage: "chevron.down") {
                        model.nextSearchMatch()
                    }
                }
            }
        }
#if DEBUG
        .overlay(alignment: .bottomTrailing) {
            if isUITestSessionPersisted {
                Text("Session persisted")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .accessibilityIdentifier("session-persisted")
            }
        }
#endif
    }

    @ViewBuilder
    private func documentView(for tab: DocumentTab) -> some View {
        switch tab.content {
        case let .markdown(text):
            MarkdownReaderView(
                text: text,
                search: tab.search,
                readingPosition: tab.readingPosition,
                onReadingPositionChanged: { position in
                    guard readingPositionReadyTabIDs.contains(tab.id) else {
                        return
                    }
                    model.updateReadingPosition(
                        position,
                        for: tab.id,
                        using: readingState
                    )
                }
            )
        case let .pdf(data):
            PDFReaderView(
                data: data,
                search: tab.search,
                readingPosition: tab.readingPosition,
                onReadingPositionChanged: { position in
                    guard readingPositionReadyTabIDs.contains(tab.id) else {
                        return
                    }
                    model.updateReadingPosition(
                        position,
                        for: tab.id,
                        using: readingState
                    )
                }
            )
        }
    }

    private func open(_ url: URL) {
        Task {
            await openAndRefresh(url)
        }
    }

    private func open(_ recent: RecentDocument) {
        Task {
            await openRecentAndRefresh(recent)
        }
    }

    private func openAndRefresh(_ url: URL) async {
        let result = await model.openDocument(
            at: url,
            using: documentAccess,
            registry: documentRegistry
        )
        await handle(result)
        await model.refreshRecents(using: recentStore)
        await persistSession()
    }

    private func openRecentAndRefresh(_ recent: RecentDocument) async {
        let result = await model.openRecentDocument(
            recent,
            using: documentAccess,
            registry: documentRegistry
        )
        await handle(result)
        await model.refreshRecents(using: recentStore)
        await persistSession()
    }

    private func handle(_ result: WorkspaceOpenResult?) async {
        switch result {
        case let .opened(tabID), let .selectedExisting(tabID):
            await restorePosition(for: tabID)
        case let .activateExisting(location):
            sceneCoordinator.enqueueActivation(location)
            openWindow(value: WorkspaceSceneValue(workspaceID: location.workspaceID))
        case nil:
            break
        }
    }

    private func restorePosition(for tabID: DocumentTab.ID) async {
        await model.restoreReadingPosition(for: tabID, using: readingState)
        readingPositionReadyTabIDs.insert(tabID)
    }

    private func openNewWindow() {
        openWindow(value: WorkspaceSceneValue())
    }

    private func openInNewWindow(_ url: URL) {
        let sceneValue = WorkspaceSceneValue()
        sceneCoordinator.enqueue(.url(url), for: sceneValue.workspaceID)
        openWindow(value: sceneValue)
    }

    private func openInNewWindow(_ recent: RecentDocument) {
        let sceneValue = WorkspaceSceneValue()
        sceneCoordinator.enqueue(.recent(recent), for: sceneValue.workspaceID)
        openWindow(value: sceneValue)
    }

    private func processSceneRequests() async {
        for location in sceneCoordinator.takeActivations(for: model.id) {
            model.selectTab(location.tabID)
            await restorePosition(for: location.tabID)
        }

        for request in sceneCoordinator.takeOpenRequests(for: model.id) {
            switch request {
            case let .url(url):
                await openAndRefresh(url)
            case let .recent(recent):
                await openRecentAndRefresh(recent)
            }
        }
    }

    private func restoreSavedSessionIfNeeded() async -> Bool {
        guard sessionPersistenceIsEnabled, model.tabs.isEmpty,
              let session = await sceneSessionStore.session(for: model.id) else {
            return true
        }

        let result = await model.restoreSession(
            session,
            using: documentAccess,
            registry: documentRegistry,
            readingState: readingState
        )
        readingPositionReadyTabIDs.formUnion(result.restoredTabIDs)
        return !result.wasCancelled
    }

    private func persistSession() async {
        guard sessionPersistenceIsEnabled,
              hasCompletedInitialSessionRestore else {
            return
        }

        if let session = model.sessionSnapshot() {
            await sceneSessionStore.saveSession(session, for: model.id)
        } else {
            await sceneSessionStore.removeSession(for: model.id)
        }
    }

    private var sessionPersistenceIsEnabled: Bool {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return !arguments.contains("--ui-test-markdown")
            && !arguments.contains("--ui-test-pdf")
#else
        return true
#endif
    }

#if DEBUG
    private func seedUITestStaleSessionIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains(
            "--ui-test-session-stale"
        ) else {
            return
        }

        let missingDocument = WorkspaceSessionDocument(
            identity: DocumentIdentity(
                persistentID: "ui-test-missing-session-document",
                displayName: "MissingSession.md"
            ),
            kind: .markdown
        )
        await sceneSessionStore.saveSession(
            WorkspaceSession(
                documents: [missingDocument],
                selectedDocumentPersistentID: missingDocument.identity.persistentID
            ),
            for: model.id
        )
    }

    private func seedUITestSessionIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains(
            "--ui-test-session-seed"
        ) else {
            return
        }

        do {
            let documentsDirectory = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let fixtureURL = documentsDirectory
                .appendingPathComponent("SessionRestoration.md")
            let fixture = "# Restored Session Document\n\n"
                + "This Markdown file was reopened from a saved scene session."
            try Data(fixture.utf8).write(to: fixtureURL, options: .atomic)
            await openAndRefresh(fixtureURL)
            isUITestSessionPersisted = model.tabs.contains {
                $0.document.identity.displayName == fixtureURL.lastPathComponent
            }
        } catch {
            model.presentOpenError(error)
        }
    }
#endif
}

#Preview {
    let bookmarks = UserDefaultsBookmarkStore(
        defaults: UserDefaults(suiteName: "WorkspaceViewPreview")!
    )
    let recents = UserDefaultsRecentDocumentStore(
        defaults: UserDefaults(suiteName: "WorkspaceViewPreview")!
    )
    WorkspaceView(
        model: WorkspaceModel(),
        documentAccess: DocumentAccessService(
            bookmarks: bookmarks,
            recents: recents
        ),
        documentRegistry: DocumentAccessRegistry(),
        recentStore: recents,
        readingState: UserDefaultsReadingStateStore(
            suiteName: "WorkspaceViewPreview"
        ),
        sceneSessionStore: UserDefaultsSceneSessionStore(
            suiteName: "WorkspaceViewPreview"
        ),
        openRequestRouter: OpenRequestRouter(),
        sceneCoordinator: WorkspaceSceneCoordinator()
    )
}
