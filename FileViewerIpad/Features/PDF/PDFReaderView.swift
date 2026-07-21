import Observation
import PDFKit
import SwiftUI

@MainActor
@Observable
final class PDFReaderModel {
    let document: PDFDocument
    private(set) var currentPage = 1
    private(set) var pageCount: Int
    weak var pdfView: PDFView?

    init?(data: Data) {
        guard let document = PDFDocument(data: data) else {
            return nil
        }
        self.document = document
        self.pageCount = document.pageCount
    }

    func attach(_ view: PDFView) {
        pdfView = view
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
    }
}

struct PDFReaderView: View {
    @State private var model: PDFReaderModel?

    init(data: Data) {
        _model = State(initialValue: PDFReaderModel(data: data))
    }

    var body: some View {
        if let model {
            PDFKitContainer(model: model)
                .safeAreaInset(edge: .bottom) {
                    controls(model)
                }
                .accessibilityIdentifier("pdf-reader")
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

private struct PDFKitContainer: UIViewRepresentable {
    let model: PDFReaderModel

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
        model.attach(view)
        context.coordinator.observe(view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== model.document {
            view.document = model.document
            view.autoScales = true
        }
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
