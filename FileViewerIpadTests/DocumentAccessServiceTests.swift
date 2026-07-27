import Foundation
import XCTest
@testable import FileViewerIpad

final class DocumentAccessServiceTests: XCTestCase {
    func testReadsMarkdownAndBalancesStartedSecurityScope() async throws {
        let scope = RecordingSecurityScope(startResult: true)
        let bookmarks = InMemoryBookmarkStore()
        let service = DocumentAccessService(
            bookmarks: bookmarks,
            recents: InMemoryRecentDocumentStore(),
            securityScope: scope
        )
        let url = temporaryURL(extension: "md")
        try Data("# Heading\n\nBody".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await service.resolveDocument(at: url)

        XCTAssertEqual(document.descriptor.kind, .markdown)
        XCTAssertEqual(document.descriptor.identity.displayName, url.lastPathComponent)
        XCTAssertEqual(document.content, .markdown("# Heading\n\nBody"))
        XCTAssertEqual(scope.startedURLs, [url])
        XCTAssertEqual(scope.stoppedURLs, [url])
    }

    func testDoesNotStopSecurityScopeWhenStartReturnsFalse() async throws {
        let scope = RecordingSecurityScope(startResult: false)
        let service = DocumentAccessService(
            bookmarks: InMemoryBookmarkStore(),
            recents: InMemoryRecentDocumentStore(),
            securityScope: scope
        )
        let url = temporaryURL(extension: "markdown")
        try Data("Readable local text".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try await service.resolveDocument(at: url)

        XCTAssertEqual(scope.startedURLs, [url])
        XCTAssertTrue(scope.stoppedURLs.isEmpty)
    }

    func testRejectsUnsupportedExtensionBeforeReading() async {
        let scope = RecordingSecurityScope(startResult: true)
        let service = DocumentAccessService(
            bookmarks: InMemoryBookmarkStore(),
            recents: InMemoryRecentDocumentStore(),
            securityScope: scope
        )
        let url = temporaryURL(extension: "txt")

        await XCTAssertThrowsErrorAsync(
            try await service.resolveDocument(at: url)
        ) { error in
            XCTAssertEqual(error as? DocumentAccessError, .unsupportedType)
        }
        XCTAssertTrue(scope.startedURLs.isEmpty)
    }

    func testRejectsNonUTF8MarkdownAndStillBalancesScope() async throws {
        let scope = RecordingSecurityScope(startResult: true)
        let service = DocumentAccessService(
            bookmarks: InMemoryBookmarkStore(),
            recents: InMemoryRecentDocumentStore(),
            securityScope: scope
        )
        let url = temporaryURL(extension: "md")
        try Data([0xFF, 0xFE]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        await XCTAssertThrowsErrorAsync(
            try await service.resolveDocument(at: url)
        ) { error in
            XCTAssertEqual(error as? DocumentAccessError, .invalidTextEncoding)
        }
        XCTAssertEqual(scope.startedURLs, [url])
        XCTAssertEqual(scope.stoppedURLs, [url])
    }

    func testRejectsInvalidPDFAndStillBalancesScope() async throws {
        let scope = RecordingSecurityScope(startResult: true)
        let service = DocumentAccessService(
            bookmarks: InMemoryBookmarkStore(),
            recents: InMemoryRecentDocumentStore(),
            securityScope: scope
        )
        let url = temporaryURL(extension: "pdf")
        try Data("not a PDF".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        await XCTAssertThrowsErrorAsync(
            try await service.resolveDocument(at: url)
        ) { error in
            XCTAssertEqual(error as? DocumentAccessError, .invalidPDF)
        }
        XCTAssertEqual(scope.startedURLs, [url])
        XCTAssertEqual(scope.stoppedURLs, [url])
    }

    func testReopensRecentDocumentFromBookmark() async throws {
        let url = temporaryURL(extension: "md")
        try Data("# Reopened".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let identity = DocumentIdentity(
            persistentID: "saved-identity",
            displayName: "Previous Name.md"
        )
        let bookmarks = InMemoryBookmarkStore()
        let bookmarkData = try url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try await bookmarks.saveBookmarkData(bookmarkData, for: identity)
        let recents = InMemoryRecentDocumentStore()
        let scope = RecordingSecurityScope(startResult: true)
        let service = DocumentAccessService(
            bookmarks: bookmarks,
            recents: recents,
            securityScope: scope
        )

        let document = try await service.resolveDocument(
            for: RecentDocument(
                identity: identity,
                kind: .markdown,
                lastOpenedAt: .distantPast
            )
        )

        XCTAssertEqual(document.descriptor.identity.persistentID, "saved-identity")
        XCTAssertEqual(document.descriptor.identity.displayName, url.lastPathComponent)
        XCTAssertEqual(document.content, .markdown("# Reopened"))
        XCTAssertEqual(scope.startedURLs, [url])
        XCTAssertEqual(scope.stoppedURLs, [url])
        let storedRecents = await recents.recentDocuments()
        XCTAssertEqual(storedRecents.first?.identity, document.descriptor.identity)
    }

    func testRecentWithoutBookmarkReportsStaleAccess() async {
        let service = DocumentAccessService(
            bookmarks: InMemoryBookmarkStore(),
            recents: InMemoryRecentDocumentStore()
        )
        let recent = RecentDocument(
            identity: DocumentIdentity(
                persistentID: "missing-bookmark",
                displayName: "Missing.md"
            ),
            kind: .markdown,
            lastOpenedAt: .now
        )

        await XCTAssertThrowsErrorAsync(
            try await service.resolveDocument(for: recent)
        ) { error in
            XCTAssertEqual(error as? DocumentAccessError, .staleBookmark)
        }
    }

    private func temporaryURL(extension pathExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
    }
}

private final class RecordingSecurityScope: SecurityScopedAccessing, @unchecked Sendable {
    private let lock = NSLock()
    private let startResult: Bool
    private var _startedURLs: [URL] = []
    private var _stoppedURLs: [URL] = []

    init(startResult: Bool) {
        self.startResult = startResult
    }

    var startedURLs: [URL] {
        lock.withLock { _startedURLs }
    }

    var stoppedURLs: [URL] {
        lock.withLock { _stoppedURLs }
    }

    func startAccessing(_ url: URL) -> Bool {
        lock.withLock {
            _startedURLs.append(url)
        }
        return startResult
    }

    func stopAccessing(_ url: URL) {
        lock.withLock {
            _stoppedURLs.append(url)
        }
    }
}

private actor InMemoryBookmarkStore: BookmarkStoring {
    private var values: [DocumentIdentity: Data] = [:]

    func bookmarkData(for identity: DocumentIdentity) -> Data? {
        values[identity]
    }

    func saveBookmarkData(_ data: Data, for identity: DocumentIdentity) {
        values[identity] = data
    }

    func removeBookmark(for identity: DocumentIdentity) {
        values.removeValue(forKey: identity)
    }
}

private actor InMemoryRecentDocumentStore: RecentDocumentStoring {
    private var values: [RecentDocument] = []

    func recentDocuments() -> [RecentDocument] {
        values
    }

    func record(_ document: RecentDocument) {
        values.removeAll { $0.identity == document.identity }
        values.insert(document, at: 0)
    }

    func remove(identity: DocumentIdentity) {
        values.removeAll { $0.identity == identity }
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
