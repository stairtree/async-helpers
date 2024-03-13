// Courtesy of Rob Napier and Alexander Cyon
// See https://gist.github.com/rnapier/af027808dcfca84686f063963e2a29f5

import Dispatch
#if os(Linux)
import let CDispatch.NSEC_PER_SEC
#endif

func firstResult<R>(from tasks: [@Sendable () async throws -> R]) async throws -> R? where R: Sendable {
    return try await withThrowingTaskGroup(of: R.self) { group in
        for task in tasks {
            group.addTask { try await task() }
        }
        // First finished child task wins, cancel the other task.
        let result = try await group.next()
        group.cancelAll()
        return result
    }
}

public struct TimedOutError: Error, Equatable {}
func timeout<R>(seconds: Double) -> @Sendable () async throws -> R {
    return {
        try await Task.sleep(nanoseconds: UInt64(seconds * Double(NSEC_PER_SEC)))
        throw TimedOutError()
    }
}

/// Runs an async task with a timeout.
///
/// - Parameters:
///   - maxDuration: The duration in seconds `work` is allowed to run before timing out.
///   - work: The async operation to perform.
/// - Returns: Returns the result of `work` if it completed in time.
/// - Throws: Throws ``TimedOutError`` if the timeout expires before `work` completes.
///   If `work` throws an error before the timeout expires, that error is propagated to the caller.
public func withTimeout<R>(
    _ maxDuration: Double,
    do work: @escaping @Sendable () async throws -> R
) async throws -> R where R: Sendable {
    try await firstResult(from: [work, timeout(seconds: maxDuration)])!
}
