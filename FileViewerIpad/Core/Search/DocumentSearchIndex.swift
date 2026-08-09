import Foundation
import PDFKit

enum DocumentSearchIndex {
    static func ranges(in text: String, query: String) -> [NSRange] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        let source = text as NSString
        let queryLength = (query as NSString).length
        guard queryLength > 0 else { return [] }

        var results: [NSRange] = []
        var searchLocation = 0
        while searchLocation < source.length {
            let searchRange = NSRange(
                location: searchLocation,
                length: source.length - searchLocation
            )
            let match = source.range(
                of: query,
                options: [.caseInsensitive],
                range: searchRange
            )
            guard match.location != NSNotFound else { break }
            results.append(match)
            searchLocation = match.location + max(match.length, 1)
        }
        return results
    }

    static func ranges(
        in content: LoadedDocumentContent,
        query: String
    ) -> [NSRange] {
        switch content {
        case let .markdown(text):
            return ranges(in: text, query: query)
        case let .pdf(data):
            guard let document = PDFDocument(data: data),
                  let text = document.string else {
                return []
            }
            return ranges(in: text, query: query)
        }
    }

    static func clampedMatchIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }
}
