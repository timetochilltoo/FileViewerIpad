import Foundation

enum DocumentAccessError: LocalizedError, Equatable, Sendable {
    case unsupportedType
    case permissionDenied
    case missingFile
    case staleBookmark
    case unreadableDocument
    case invalidTextEncoding
    case invalidPDF

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            "FileViewer supports Markdown and PDF documents."
        case .permissionDenied:
            "FileViewer does not have permission to read this document."
        case .missingFile:
            "The document could not be found."
        case .staleBookmark:
            "FileViewer no longer has access to this recent document. Open it again from Files."
        case .unreadableDocument:
            "The document could not be read."
        case .invalidTextEncoding:
            "This Markdown document is not valid UTF-8 text."
        case .invalidPDF:
            "The PDF is corrupt, encrypted, or unsupported."
        }
    }
}

protocol DocumentAccessServicing: Sendable {
    func resolveDocument(at url: URL) async throws -> ResolvedDocument
    func resolveDocument(for recent: RecentDocument) async throws -> ResolvedDocument
}

protocol BookmarkStoring: Sendable {
    func bookmarkData(for identity: DocumentIdentity) async throws -> Data?
    func saveBookmarkData(_ data: Data, for identity: DocumentIdentity) async throws
    func removeBookmark(for identity: DocumentIdentity) async throws
}

protocol ReadingStateStoring: Sendable {
    func readingPosition(for identity: DocumentIdentity) async throws -> ReadingPosition?
    func saveReadingPosition(
        _ position: ReadingPosition,
        for identity: DocumentIdentity
    ) async throws
}

protocol RecentDocumentStoring: Sendable {
    func recentDocuments() async -> [RecentDocument]
    func record(_ document: RecentDocument) async
    func remove(identity: DocumentIdentity) async
}

protocol SecurityScopedAccessing: Sendable {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}
