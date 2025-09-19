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

// Vendored from NIO 2.86.0

//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import ucrt
import WinSDK
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(Bionic)
@preconcurrency import Bionic
#elseif canImport(WASILibc)
@preconcurrency import WASILibc
#if canImport(wasi_pthread)
import wasi_pthread
#endif
#else
#error("The concurrency lock module was unable to identify your C library.")
#endif

extension Locking {
    /// A `Lock` with a built-in state variable.
    ///
    /// This class provides a convenience addition to `Lock`: it provides the ability to wait
    /// until the state variable is set to a specific value to acquire the lock.
    public final class ConditionLock<T: Equatable> {
        private var _value: T
        private let mutex: FastLock
#if os(Windows)
        private let cond: UnsafeMutablePointer<CONDITION_VARIABLE> =
        UnsafeMutablePointer.allocate(capacity: 1)
#elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
        private let cond: UnsafeMutablePointer<pthread_cond_t> =
        UnsafeMutablePointer.allocate(capacity: 1)
#endif
        
        /// Create the lock, and initialize the state variable to `value`.
        ///
        /// - Parameter value: The initial value to give the state variable.
        public init(value: T) {
            self._value = value
            self.mutex = FastLock()
#if os(Windows)
            InitializeConditionVariable(self.cond)
#elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
            let err = pthread_cond_init(self.cond, nil)
            precondition(err == 0, "\(#function) failed in pthread_cond with error \(err)")
#endif
        }
        
        deinit {
#if os(Windows)
            // condition variables do not need to be explicitly destroyed
#elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
            let err = pthread_cond_destroy(self.cond)
            precondition(err == 0, "\(#function) failed in pthread_cond with error \(err)")
            self.cond.deallocate()
#endif
        }
        
        /// Acquire the lock, regardless of the value of the state variable.
        public func lock() {
            self.mutex.lock()
        }
        
        /// Release the lock, regardless of the value of the state variable.
        public func unlock() {
            self.mutex.unlock()
        }
        
        /// The value of the state variable.
        ///
        /// Obtaining the value of the state variable requires acquiring the lock.
        /// This means that it is not safe to access this property while holding the
        /// lock: it is only safe to use it when not holding it.
        public var value: T {
            self.lock()
            defer {
                self.unlock()
            }
            return self._value
        }
        
        /// Acquire the lock when the state variable is equal to `wantedValue`.
        ///
        /// - Parameter wantedValue: The value to wait for the state variable
        ///     to have before acquiring the lock.
        public func lock(whenValue wantedValue: T) {
            self.lock()
            while true {
                if self._value == wantedValue {
                    break
                }
                self.mutex.withLockPrimitive { mutex in
#if os(Windows)
                    let result = SleepConditionVariableSRW(self.cond, mutex, INFINITE, 0)
                    precondition(result, "\(#function) failed in SleepConditionVariableSRW with error \(GetLastError())")
#elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
                    let err = pthread_cond_wait(self.cond, mutex)
                    precondition(err == 0, "\(#function) failed in pthread_cond with error \(err)")
#endif
                }
            }
        }
        
        /// Acquire the lock when the state variable is equal to `wantedValue`,
        /// waiting no more than `timeoutSeconds` seconds.
        ///
        /// - Parameter wantedValue: The value to wait for the state variable
        ///     to have before acquiring the lock.
        /// - Parameter timeoutSeconds: The number of seconds to wait to acquire
        ///     the lock before giving up.
        /// - Returns: `true` if the lock was acquired, `false` if the wait timed out.
        public func lock(whenValue wantedValue: T, timeoutSeconds: Double) -> Bool {
            precondition(timeoutSeconds >= 0)
            
#if os(Windows)
            var dwMilliseconds: DWORD = DWORD(timeoutSeconds * 1000)
            
            self.lock()
            while true {
                if self._value == wantedValue {
                    return true
                }
                
                let dwWaitStart = timeGetTime()
                let result = self.mutex.withLockPrimitive { mutex in
                    SleepConditionVariableSRW(self.cond, mutex, dwMilliseconds, 0)
                }
                if !result {
                    let dwError = GetLastError()
                    if dwError == ERROR_TIMEOUT {
                        self.unlock()
                        return false
                    }
                    fatalError("SleepConditionVariableSRW: \(dwError)")
                }
                // NOTE: this may be a spurious wakeup, adjust the timeout accordingly
                dwMilliseconds = dwMilliseconds - (timeGetTime() - dwWaitStart)
            }
#elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
            let nsecPerSec: Int64 = 1_000_000_000
            self.lock()
            // the timeout as a (seconds, nano seconds) pair
            let timeoutNS = Int64(timeoutSeconds * Double(nsecPerSec))
            
            var curTime = timeval()
            gettimeofday(&curTime, nil)
            
            let allNSecs: Int64 = timeoutNS + Int64(curTime.tv_usec) * 1000
            let tvSec = curTime.tv_sec + time_t((allNSecs / nsecPerSec))
            
            var timeoutAbs = timespec(
                tv_sec: tvSec,
                tv_nsec: Int(allNSecs % nsecPerSec)
            )
            assert(timeoutAbs.tv_nsec >= 0 && timeoutAbs.tv_nsec < Int(nsecPerSec))
            assert(timeoutAbs.tv_sec >= curTime.tv_sec)
            return self.mutex.withLockPrimitive { mutex -> Bool in
                while true {
                    if self._value == wantedValue {
                        return true
                    }
                    switch pthread_cond_timedwait(self.cond, mutex, &timeoutAbs) {
                    case 0:
                        continue
                    case ETIMEDOUT:
                        self.unlock()
                        return false
                    case let e:
                        fatalError("caught error \(e) when calling pthread_cond_timedwait")
                    }
                }
            }
#else
            return true
#endif
        }
        
        /// Release the lock, setting the state variable to `newValue`.
        ///
        /// - Parameter newValue: The value to give to the state variable when we
        ///     release the lock.
        public func unlock(withValue newValue: T) {
            self._value = newValue
            self.unlock()
#if os(Windows)
            WakeAllConditionVariable(self.cond)
#elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
            let err = pthread_cond_broadcast(self.cond)
            precondition(err == 0, "\(#function) failed in pthread_cond with error \(err)")
#endif
        }
    }
    
    /// A utility function that runs the body code only in debug builds, without
    /// emitting compiler warnings.
    ///
    /// This is currently the only way to do this in Swift: see
    /// https://forums.swift.org/t/support-debug-only-code/11037 for a discussion.
    @inlinable
    internal func debugOnly(_ body: () -> Void) {
        assert(
            {
                body()
                return true
            }()
        )
    }
}

extension Locking.ConditionLock: @unchecked Sendable {}
