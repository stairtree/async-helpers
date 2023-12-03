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

// Vendored from NIO 2.62.0 commit 702cd7c56d5d44eeba73fdf83918339b26dc855c on 2023-12-02

//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Provides locked access to `Value`.
///
/// - note: ``LockedValueBox`` has reference semantics and holds the `Value`
///         alongside a lock behind a reference.
///
/// This is no different than creating a ``FastLock`` and protecting all
/// accesses to a value using the lock. But it's easy to forget to actually
/// acquire/release the lock in the correct place. ``LockedValueBox`` makes
/// that much easier.
extension Locking {
    public struct LockedValueBox<Value> {
        
        @usableFromInline
        internal let _storage: LockStorage<Value>

        /// Initialize the `Value`.
        @inlinable
        public init(_ value: Value) {
            self._storage = .create(value: value)
        }

        /// Access the `Value`, allowing mutation of it.
        @inlinable
        public func withLockedValue<T>(_ mutate: (inout Value) throws -> T) rethrows -> T {
            return try self._storage.withLockedValue(mutate)
        }
    }
}

extension Locking.LockedValueBox: Sendable where Value: Sendable {}
