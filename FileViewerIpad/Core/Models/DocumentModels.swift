import Foundation

enum DocumentKind: String, CaseIterable, Codable, Sendable {
    case markdown
    case pdf
}

struct DocumentIdentity: Hashable, Codable, Sendable {
    let persistentID: String
    let displayName: String
}

struct DocumentDescriptor: Identifiable, Hashable, Codable, Sendable {
    var id: DocumentIdentity { identity }

    let identity: DocumentIdentity
    let kind: DocumentKind
}

struct SearchState: Hashable, Codable, Sendable {
    var query = ""
    var currentMatchIndex = 0
    var matchCount = 0
    var navigationRequestID = UUID()
}

struct PDFReadingPosition: Hashable, Codable, Sendable {
    var page = 1
    var scale = 1.0
}

struct MarkdownReadingPosition: Hashable, Codable, Sendable {
    var visibleUTF16Location = 0
    var fallbackScrollOffset = 0.0
}

enum ReadingPosition: Hashable, Codable, Sendable {
    case markdown(MarkdownReadingPosition)
    case pdf(PDFReadingPosition)
}

struct DocumentTab: Identifiable, Hashable, Sendable {
    let id: UUID
    let document: DocumentDescriptor
    var search: SearchState
    var readingPosition: ReadingPosition

    init(
        id: UUID = UUID(),
        document: DocumentDescriptor,
        search: SearchState = SearchState()
    ) {
        self.id = id
        self.document = document
        self.search = search
        self.readingPosition = switch document.kind {
        case .markdown:
            .markdown(MarkdownReadingPosition())
        case .pdf:
            .pdf(PDFReadingPosition())
        }
    }
}

