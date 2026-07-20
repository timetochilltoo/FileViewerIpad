import Foundation

protocol DocumentAccessServicing: Sendable {
    func resolveDocument(at url: URL) async throws -> DocumentDescriptor
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

protocol SecurityScopedAccessing: Sendable {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

