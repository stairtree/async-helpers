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
    @usableFromInline
    /*private*/ let makeErasedAsyncIterator: @Sendable () -> AsyncIterator

    public struct AsyncIterator: AsyncIteratorProtocol {
        @usableFromInline
        /*private*/ let unerasedNext: () async throws -> Element?

        @usableFromInline
        init<I: AsyncIteratorProtocol>(itr: I) where I.Element == Element {
            var itr = itr
            
            self.unerasedNext = {
                try await itr.next()
            }
        }
        
        @inlinable
        public mutating func next() async throws -> Element? {
            try await self.unerasedNext()
        }
    }

    @inlinable
    public init<S: AsyncSequence & Sendable>(seq: S) where S.Element == Element {
        self.makeErasedAsyncIterator = {
            AsyncIterator(itr: seq.makeAsyncIterator())
        }
    }

    @inlinable
    public func makeAsyncIterator() -> AsyncIterator {
        self.makeErasedAsyncIterator()
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    @inlinable
    public func eraseToAnyAsyncSequence() -> AnyAsyncSequence<Element> {
        AnyAsyncSequence(seq: self)
    }
}

// N.B.: Conformance must be `@unchecked` because AsyncIterators are explcitly non-Sendable.
extension AnyAsyncSequence: @unchecked Sendable where Element: Sendable {}

@available(*, unavailable)
extension AnyAsyncSequence.AsyncIterator: Sendable {}
