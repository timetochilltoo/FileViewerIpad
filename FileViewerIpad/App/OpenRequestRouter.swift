import Foundation

actor OpenRequestRouter {
    private let suppressionInterval: TimeInterval
    private var recentClaims: [String: Date] = [:]

    init(suppressionInterval: TimeInterval = 2) {
        self.suppressionInterval = suppressionInterval
    }

    func claim(_ url: URL, now: Date = Date()) -> Bool {
        recentClaims = recentClaims.filter {
            now.timeIntervalSince($0.value) < suppressionInterval
        }

        let key = url.standardizedFileURL.absoluteString
        if let previous = recentClaims[key],
           now.timeIntervalSince(previous) < suppressionInterval {
            return false
        }

        recentClaims[key] = now
        return true
    }
}
