import Foundation
import UniformTypeIdentifiers

enum DocumentKind: String, CaseIterable, Codable, Sendable {
    case markdown
    case pdf

    static func detect(from url: URL) throws -> DocumentKind {
        switch url.pathExtension.lowercased() {
        case "md", "markdown":
            return .markdown
        case "pdf":
            return .pdf
        default:
            throw DocumentAccessError.unsupportedType
        }
    }

    static var readableContentTypes: [UTType] {
        [
            .pdf,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText
        ]
    }
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

enum LoadedDocumentContent: Hashable, Sendable {
    case markdown(String)
    case pdf(Data)
}

struct ResolvedDocument: Hashable, Sendable {
    let descriptor: DocumentDescriptor
    let content: LoadedDocumentContent
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
    let content: LoadedDocumentContent

    init(
        id: UUID = UUID(),
        document: DocumentDescriptor,
        content: LoadedDocumentContent,
        search: SearchState = SearchState()
    ) {
        self.id = id
        self.document = document
        self.content = content
        self.search = search
        self.readingPosition = switch document.kind {
        case .markdown:
            .markdown(MarkdownReadingPosition())
        case .pdf:
            .pdf(PDFReadingPosition())
        }
    }
}
