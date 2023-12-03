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

import XCTest
import AsyncHelpers

final class AsyncHelpersTests: XCTestCase {
    func testAsyncSequenceTypeEraser() async {
        let baseSequence = AsyncStream<String>.init(bufferingPolicy: .unbounded) { continuation in
            continuation.yield("hello 1")
            continuation.yield("hello 2")
            continuation.yield("hello 3")
            continuation.finish()
        }
        let erasedSequence = baseSequence.eraseToAnyAsyncSequence()
        var iterator = erasedSequence.makeAsyncIterator()
        
        await XCTAssertEqualAsync(try await iterator.next(), "hello 1")
        await XCTAssertEqualAsync(try await iterator.next(), "hello 2")
        await XCTAssertEqualAsync(try await iterator.next(), "hello 3")
        await XCTAssertNilAsync(try await iterator.next())
    }
    
    func testAwaiter() async {
        let awaiter = Awaiter()
        let expectation1 = XCTestExpectation(description: "Did get unblocked 1")
        let expectation2 = XCTestExpectation(description: "Did get unblocked 2")
        
        Task { await awaiter.awaitUntilTriggered { expectation1.fulfill() } }
        Task { await awaiter.awaitUntilTriggered { expectation2.fulfill() } }
        
        await awaiter.trigger()
        #if canImport(Darwin) || swift(>=5.10)
        await XCTAssertEqualAsync(await XCTWaiter().fulfillment(of: [expectation1, expectation2], timeout: 0.1), .completed)
        #else
        XCTAssertEqual(XCTWaiter().wait(for: [expectation1, expectation2], timeout: 0.1), .completed)
        #endif
    }
    
    /// We don't test the locking implementations here for two reasons:
    ///
    /// 1. The implementations are taken from NIO, which has its own robust tests already.
    /// 2. There's not much useful testing that could be done without quite a bit of work anyhow.
}

func XCTAssertEqualAsync<T>(
    _ expression1: @autoclosure () async throws -> T,
    _ expression2: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async where T: Equatable {
    do {
        let expr1 = try await expression1(), expr2 = try await expression2()
        return XCTAssertEqual(expr1, expr2, message(), file: file, line: line)
    } catch {
        return XCTAssertEqual(try { () -> Bool in throw error }(), false, message(), file: file, line: line)
    }
}

func XCTAssertNilAsync(
    _ expression: @autoclosure () async throws -> Any?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath, line: UInt = #line
) async {
    do {
        let result = try await expression()
        return XCTAssertNil(result, message(), file: file, line: line)
    } catch {
        return XCTAssertNil(try { throw error }(), message(), file: file, line: line)
    }
}
