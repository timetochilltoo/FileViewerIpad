import Observation
import PDFKit
import SwiftUI

struct PDFOutlineEntry: Identifiable, Hashable {
    let id: String
    let depth: Int
    let title: String
    let pageIndex: Int?
}

enum PDFNavigatorMode: String, CaseIterable, Identifiable {
    case pages = "Pages"
    case outline = "Outline"

    var id: Self { self }
}

@MainActor
@Observable
final class PDFReaderModel {
    let document: PDFDocument
    private(set) var currentPage = 1
    private(set) var pageCount: Int
    private(set) var outlineEntries: [PDFOutlineEntry]
    var isNavigatorPresented = false
    var navigatorMode: PDFNavigatorMode = .pages
    weak var pdfView: PDFView?
    private var thumbnails: [Int: UIImage] = [:]
    private var searchSelections: [PDFSelection] = []
    private var lastSearchQuery = ""
    private var lastSearchRequestID: UUID?
    private var lastAppliedReadingPosition: PDFReadingPosition?
    var onReadingPositionChanged: ((ReadingPosition) -> Void)?

    init?(data: Data) {
        guard let document = PDFDocument(data: data) else {
            return nil
        }
        self.document = document
        self.pageCount = document.pageCount
        self.outlineEntries = Self.extractOutline(from: document)
    }

    func attach(
        _ view: PDFView,
        readingPosition: PDFReadingPosition? = nil
    ) {
        pdfView = view
        if let readingPosition {
            restore(readingPosition)
        }
        synchronizePage()
    }

    func restore(_ position: PDFReadingPosition) {
        lastAppliedReadingPosition = position
        if position.scale != 1.0, position.scale > 0 {
            pdfView?.scaleFactor = CGFloat(position.scale)
        }
        goToPage(at: position.page - 1)
    }

    func applyReadingPosition(_ position: PDFReadingPosition?) {
        guard let position, position != lastAppliedReadingPosition else {
            return
        }
        restore(position)
        synchronizePage()
    }

    func firstPage() {
        guard let page = document.page(at: 0) else { return }
        pdfView?.go(to: page)
    }

    func previousPage() {
        pdfView?.goToPreviousPage(nil)
    }

    func nextPage() {
        pdfView?.goToNextPage(nil)
    }

    func lastPage() {
        guard pageCount > 0, let page = document.page(at: pageCount - 1) else {
            return
        }
        pdfView?.go(to: page)
    }

    func goToPage(at index: Int) {
        guard (0..<pageCount).contains(index),
              let page = document.page(at: index) else {
            return
        }
        pdfView?.go(to: page)
    }

    func zoomIn() {
        pdfView?.zoomIn(nil)
    }

    func zoomOut() {
        pdfView?.zoomOut(nil)
    }

    func synchronizePage() {
        guard let currentPDFPage = pdfView?.currentPage else { return }
        let index = document.index(for: currentPDFPage)
        guard index != NSNotFound, (0..<pageCount).contains(index) else { return }
        currentPage = index + 1
        let position = PDFReadingPosition(
            page: currentPage,
            scale: Double(pdfView?.scaleFactor ?? 1.0)
        )
        lastAppliedReadingPosition = position
        onReadingPositionChanged?(.pdf(position))
    }

    func applySearch(_ state: SearchState) {
        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if query != lastSearchQuery {
            lastSearchQuery = query
            searchSelections = query.isEmpty
                ? []
                : document.findString(query, withOptions: [.caseInsensitive])
            pdfView?.highlightedSelections = searchSelections
        }

        guard !searchSelections.isEmpty,
              lastSearchRequestID != state.navigationRequestID else {
            if searchSelections.isEmpty {
                pdfView?.highlightedSelections = nil
            }
            return
        }
        lastSearchRequestID = state.navigationRequestID
        let index = DocumentSearchIndex.clampedMatchIndex(
            state.currentMatchIndex,
            count: searchSelections.count
        )
        pdfView?.go(to: searchSelections[index])
    }

    func thumbnail(at index: Int) -> UIImage? {
        guard (0..<pageCount).contains(index) else { return nil }
        if let cached = thumbnails[index] {
            return cached
        }
        guard let page = document.page(at: index) else { return nil }
        let image = page.thumbnail(
            of: CGSize(width: 96, height: 128),
            for: .cropBox
        )
        thumbnails[index] = image
        return image
    }

    private static func extractOutline(
        from document: PDFDocument
    ) -> [PDFOutlineEntry] {
        guard let root = document.outlineRoot else { return [] }
        var entries: [PDFOutlineEntry] = []

        func appendChildren(
            of outline: PDFOutline,
            depth: Int,
            path: String
        ) {
            for index in 0..<outline.numberOfChildren {
                guard let child = outline.child(at: index) else { continue }
                let childPath = "\(path).\(index)"
                let title = child.label?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let destination = child.destination
                    ?? (child.action as? PDFActionGoTo)?.destination
                let pageIndex: Int?
                if let page = destination?.page {
                    let index = document.index(for: page)
                    pageIndex = index == NSNotFound
                        || !(0..<document.pageCount).contains(index)
                        ? nil
                        : index
                } else {
                    pageIndex = nil
                }

                if let title, !title.isEmpty {
                    entries.append(
                        PDFOutlineEntry(
                            id: childPath,
                            depth: depth,
                            title: title,
                            pageIndex: pageIndex
                        )
                    )
                }
                appendChildren(
                    of: child,
                    depth: depth + 1,
                    path: childPath
                )
            }
        }

        appendChildren(of: root, depth: 0, path: "root")
        return entries
    }
}

struct PDFReaderView: View {
    @State private var model: PDFReaderModel?
    let search: SearchState
    let readingPosition: ReadingPosition
    let onReadingPositionChanged: (ReadingPosition) -> Void

    init(
        data: Data,
        search: SearchState = SearchState(),
        readingPosition: ReadingPosition = .pdf(PDFReadingPosition()),
        onReadingPositionChanged: @escaping (ReadingPosition) -> Void = { _ in }
    ) {
        _model = State(initialValue: PDFReaderModel(data: data))
        self.search = search
        self.readingPosition = readingPosition
        self.onReadingPositionChanged = onReadingPositionChanged
    }

    var body: some View {
        if let model {
            PDFKitContainer(
                model: model,
                search: search,
                readingPosition: readingPosition,
                onReadingPositionChanged: onReadingPositionChanged
            )
                .safeAreaInset(edge: .bottom) {
                    controls(model)
                }
                .accessibilityIdentifier("pdf-reader")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("PDF Navigator", systemImage: "sidebar.right") {
                            model.isNavigatorPresented.toggle()
                        }
                    }
                }
        .inspector(
            isPresented: Binding(
                get: { model.isNavigatorPresented },
                set: { model.isNavigatorPresented = $0 }
            )
        ) {
                    PDFNavigatorView(model: model)
                        .inspectorColumnWidth(min: 220, ideal: 260, max: 340)
                }
        } else {
            ContentUnavailableView(
                "Unable to Open PDF",
                systemImage: "exclamationmark.triangle",
                description: Text("The PDF is corrupt, encrypted, or unsupported.")
            )
        }
    }

    private func controls(_ model: PDFReaderModel) -> some View {
        HStack(spacing: 4) {
            Button("First Page", systemImage: "backward.end.fill") {
                model.firstPage()
            }
            Button("Previous Page", systemImage: "chevron.left") {
                model.previousPage()
            }

            Text("\(model.currentPage) of \(model.pageCount)")
                .font(.callout.monospacedDigit())
                .frame(minWidth: 76)
                .accessibilityLabel("Page \(model.currentPage) of \(model.pageCount)")
                .accessibilityIdentifier("pdf-page-indicator")

            Button("Next Page", systemImage: "chevron.right") {
                model.nextPage()
            }
            Button("Last Page", systemImage: "forward.end.fill") {
                model.lastPage()
            }

            Divider()
                .frame(height: 24)

            Button("Zoom Out", systemImage: "minus.magnifyingglass") {
                model.zoomOut()
            }
            Button("Zoom In", systemImage: "plus.magnifyingglass") {
                model.zoomIn()
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom, 8)
    }
}

private struct PDFNavigatorView: View {
    @Bindable var model: PDFReaderModel

    var body: some View {
        VStack(spacing: 0) {
            Text("PDF Contents")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)

            Picker("PDF Navigation", selection: $model.navigatorMode) {
                ForEach(PDFNavigatorMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch model.navigatorMode {
            case .pages:
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(0..<model.pageCount, id: \.self) { index in
                            Button {
                                model.goToPage(at: index)
                            } label: {
                                VStack(spacing: 6) {
                                    if let image = model.thumbnail(at: index) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: 132)
                                            .shadow(radius: 1)
                                    }
                                    Text("Page \(index + 1)")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(6)
                                .background(
                                    model.currentPage == index + 1
                                        ? Color.accentColor.opacity(0.14)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            case .outline:
                if model.outlineEntries.isEmpty {
                    ContentUnavailableView(
                        "No Outline",
                        systemImage: "list.bullet.indent",
                        description: Text("This PDF does not contain an outline.")
                    )
                } else {
                    List(model.outlineEntries) { entry in
                        Button {
                            if let pageIndex = entry.pageIndex {
                                model.goToPage(at: pageIndex)
                            }
                        } label: {
                            HStack {
                                Text(entry.title)
                                    .lineLimit(2)
                                Spacer()
                                if let pageIndex = entry.pageIndex {
                                    Text("\(pageIndex + 1)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.leading, CGFloat(entry.depth) * 14)
                        }
                        .buttonStyle(.plain)
                        .disabled(entry.pageIndex == nil)
                    }
                    .listStyle(.plain)
                }
            }
        }
    }
}

private struct PDFKitContainer: UIViewRepresentable {
    let model: PDFReaderModel
    let search: SearchState
    let readingPosition: ReadingPosition
    let onReadingPositionChanged: (ReadingPosition) -> Void

    private var pdfReadingPosition: PDFReadingPosition? {
        guard case let .pdf(position) = readingPosition else { return nil }
        return position
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = model.document
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.backgroundColor = .secondarySystemBackground
        model.onReadingPositionChanged = onReadingPositionChanged
        model.attach(
            view,
            readingPosition: pdfReadingPosition
        )
        model.applySearch(search)
        context.coordinator.observe(view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== model.document {
            view.document = model.document
            view.autoScales = true
        }
        model.onReadingPositionChanged = onReadingPositionChanged
        model.applyReadingPosition(pdfReadingPosition)
        model.applySearch(search)
    }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    @MainActor
    final class Coordinator: NSObject {
        private let model: PDFReaderModel
        nonisolated(unsafe) private var pageObserver: NSObjectProtocol?

        init(model: PDFReaderModel) {
            self.model = model
        }

        func observe(_ view: PDFView) {
            pageObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged,
                object: view,
                queue: .main
            ) { [weak model] _ in
                Task { @MainActor in
                    model?.synchronizePage()
                }
            }
        }

        func stopObserving() {
            if let pageObserver {
                NotificationCenter.default.removeObserver(pageObserver)
            }
            pageObserver = nil
        }

        deinit {
            if let pageObserver {
                NotificationCenter.default.removeObserver(pageObserver)
            }
        }
    }
}
