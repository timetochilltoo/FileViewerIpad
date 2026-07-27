import CryptoKit
import CoreGraphics
import Foundation

struct SystemSecurityScopedAccessor: SecurityScopedAccessing {
    func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

actor UserDefaultsBookmarkStore: BookmarkStoring {
    private let defaults: UserDefaults
    private let storageKey = "bookmarks.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func bookmarkData(for identity: DocumentIdentity) -> Data? {
        records()[identity.persistentID]
    }

    func saveBookmarkData(_ data: Data, for identity: DocumentIdentity) {
        var records = records()
        records[identity.persistentID] = data
        defaults.set(records, forKey: storageKey)
    }

    func removeBookmark(for identity: DocumentIdentity) {
        var records = records()
        records.removeValue(forKey: identity.persistentID)
        defaults.set(records, forKey: storageKey)
    }

    private func records() -> [String: Data] {
        defaults.dictionary(forKey: storageKey)?
            .compactMapValues { $0 as? Data } ?? [:]
    }
}

struct DocumentAccessService: DocumentAccessServicing {
    private let bookmarks: any BookmarkStoring
    private let recents: any RecentDocumentStoring
    private let securityScope: any SecurityScopedAccessing

    init(
        bookmarks: any BookmarkStoring,
        recents: any RecentDocumentStoring,
        securityScope: any SecurityScopedAccessing = SystemSecurityScopedAccessor()
    ) {
        self.bookmarks = bookmarks
        self.recents = recents
        self.securityScope = securityScope
    }

    func resolveDocument(at url: URL) async throws -> ResolvedDocument {
        try await resolveDocument(at: url, preferredIdentity: nil)
    }

    func resolveDocument(for recent: RecentDocument) async throws -> ResolvedDocument {
        guard let bookmarkData = try await bookmarks.bookmarkData(
            for: recent.identity
        ) else {
            throw DocumentAccessError.staleBookmark
        }

        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw DocumentAccessError.staleBookmark
        }

        let resolved = try await resolveDocument(
            at: url,
            preferredIdentity: recent.identity
        )

        if isStale {
            let refreshedData = try? url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: [.fileResourceIdentifierKey],
                relativeTo: nil
            )
            if let refreshedData {
                try await bookmarks.saveBookmarkData(
                    refreshedData,
                    for: resolved.descriptor.identity
                )
            }
        }

        return resolved
    }

    private func resolveDocument(
        at url: URL,
        preferredIdentity: DocumentIdentity?
    ) async throws -> ResolvedDocument {
        let kind = try DocumentKind.detect(from: url)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DocumentAccessError.missingFile
        }

        let didStartAccess = securityScope.startAccessing(url)
        defer {
            if didStartAccess {
                securityScope.stopAccessing(url)
            }
        }

        let data = try coordinatedRead(from: url)
        let bookmarkData = try? url.bookmarkData(
            // iOS marks `.withSecurityScope` unavailable. Document-provider URLs
            // retain their access grant in a regular bookmark that is resolved
            // before calling `startAccessingSecurityScopedResource()` again.
            options: .minimalBookmark,
            includingResourceValuesForKeys: [.fileResourceIdentifierKey],
            relativeTo: nil
        )
        let identity = preferredIdentity.map {
            DocumentIdentity(
                persistentID: $0.persistentID,
                displayName: url.lastPathComponent
            )
        } ?? documentIdentity(for: url, bookmarkData: bookmarkData)

        let content: LoadedDocumentContent
        switch kind {
        case .markdown:
            guard let text = String(data: data, encoding: .utf8) else {
                throw DocumentAccessError.invalidTextEncoding
            }
            content = .markdown(text)
        case .pdf:
            guard let provider = CGDataProvider(data: data as CFData),
                  CGPDFDocument(provider) != nil else {
                throw DocumentAccessError.invalidPDF
            }
            content = .pdf(data)
        }

        if let bookmarkData {
            try await bookmarks.saveBookmarkData(bookmarkData, for: identity)
        }

        let resolved = ResolvedDocument(
            descriptor: DocumentDescriptor(identity: identity, kind: kind),
            content: content
        )
        await recents.record(
            RecentDocument(
                identity: identity,
                kind: kind,
                lastOpenedAt: Date()
            )
        )
        return resolved
    }

    private func coordinatedRead(from url: URL) throws -> Data {
        var coordinationError: NSError?
        var readResult: Result<Data, Error>?
        let coordinator = NSFileCoordinator()

        coordinator.coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            readResult = Result {
                try Data(contentsOf: coordinatedURL, options: .mappedIfSafe)
            }
        }

        if let coordinationError {
            if coordinationError.domain == NSCocoaErrorDomain,
               coordinationError.code == NSFileReadNoSuchFileError {
                throw DocumentAccessError.missingFile
            }
            if coordinationError.domain == NSCocoaErrorDomain,
               coordinationError.code == NSFileReadNoPermissionError {
                throw DocumentAccessError.permissionDenied
            }
            throw DocumentAccessError.unreadableDocument
        }

        guard let readResult else {
            throw DocumentAccessError.unreadableDocument
        }

        do {
            return try readResult.get()
        } catch CocoaError.fileReadNoSuchFile {
            throw DocumentAccessError.missingFile
        } catch CocoaError.fileReadNoPermission {
            throw DocumentAccessError.permissionDenied
        } catch {
            throw DocumentAccessError.unreadableDocument
        }
    }

    private func documentIdentity(
        for url: URL,
        bookmarkData: Data?
    ) -> DocumentIdentity {
        let resourceID = try? url.resourceValues(
            forKeys: [.fileResourceIdentifierKey, .volumeIdentifierKey]
        )

        let persistentSource: String
        if let fileID = resourceID?.fileResourceIdentifier {
            persistentSource = [
                String(describing: resourceID?.volumeIdentifier),
                String(describing: fileID)
            ].joined(separator: ":")
        } else if let bookmarkData {
            persistentSource = bookmarkData.base64EncodedString()
        } else {
            persistentSource = url.standardizedFileURL.absoluteString
        }

        let digest = SHA256.hash(data: Data(persistentSource.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        return DocumentIdentity(
            persistentID: digest,
            displayName: url.lastPathComponent
        )
    }
}
