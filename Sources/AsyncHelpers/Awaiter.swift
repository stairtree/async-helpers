//===----------------------------------------------------------------------===//
//
// This source file is part of the AsyncHelpers open source project
//
// Copyright (c) Stairtree GmbH
// Licensed under the MIT license
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

public actor Awaiter {
    enum State {
        case waiting(waiters: [CheckedContinuation<Void, Never>])
        case ready
    }
    private var state: State = .waiting(waiters: [])
    
    public init() {}
    
    private func addToWaiters() async {
        switch self.state {
        case .ready:
            return
        case var .waiting(waiters: waiters):
            await withCheckedContinuation { cont in
                waiters.append(cont)
                self.state = .waiting(waiters: waiters)
            }
        }
    }
    
    public func trigger() {
        guard case .waiting(waiters: var waiters) = self.state else {
            fatalError("Triggering in invalid state")
        }
        
        if waiters.isEmpty {
            self.state = .ready
            return
        }

        while !waiters.isEmpty {
            let nextWaiter = waiters.removeFirst()
            self.state = .waiting(waiters: waiters)
            nextWaiter.resume()
        }
        self.state = .ready
    }
    
    public func awaitUntilTriggered<T: Sendable>(
        _ block: @Sendable @escaping () async throws -> T
    ) async rethrows -> T {
        await self.addToWaiters()
        return try await block()
    }
}
