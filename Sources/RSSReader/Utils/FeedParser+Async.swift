import Foundation
import FeedKit

extension FeedParser {
    /// Modern Concurrency (async/await) wrapper for FeedKit's parsing function.
    func parseAsync() async throws -> FeedKit.Feed {
        return try await withCheckedThrowingContinuation { continuation in
            self.parseAsync(queue: .global()) { result in
                switch result {
                case .success(let feed):
                    continuation.resume(returning: feed)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
