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

public struct AnyAsyncSequence<Element>: AsyncSequence {
    /*private*/ let makeErasedAsyncIterator: @Sendable () -> AsyncIterator

    public struct AsyncIterator: AsyncIteratorProtocol {
        /*private*/ let unerasedNext: () async throws -> Element?

        init<I: AsyncIteratorProtocol>(itr: I) where I.Element == Element {
            var itr = itr
            
            self.unerasedNext = {
                try await itr.next()
            }
        }
        
        public mutating func next() async throws -> Element? {
            try await self.unerasedNext()
        }
    }

    public init<S: AsyncSequence & Sendable>(seq: S) where S.Element == Element {
        self.makeErasedAsyncIterator = {
            AsyncIterator(itr: seq.makeAsyncIterator())
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        self.makeErasedAsyncIterator()
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    public func eraseToAnyAsyncSequence() -> AnyAsyncSequence<Element> {
        AnyAsyncSequence(seq: self)
    }
}

// N.B.: Conformance must be `@unchecked` because AsyncIterators are explcitly non-Sendable.
extension AnyAsyncSequence: @unchecked Sendable where Element: Sendable {}

@available(*, unavailable)
extension AnyAsyncSequence.AsyncIterator: Sendable {}
