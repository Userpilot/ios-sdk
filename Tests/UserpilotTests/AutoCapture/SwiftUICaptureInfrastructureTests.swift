//
//  SwiftUICaptureInfrastructureTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Checks concurrent type memoization and SDK-owned diagnostic formatting and callbacks.
//

import XCTest
@testable import Userpilot

private final class CaptureLogger: MockLogger {
    var messages: [String] = []
    var onMessage: (() -> Void)?

    override func debug(_ message: StaticString, _ args: CVarArg...) {
        messages.append(UPLogger.formattedMessage(message, args: args))
        onMessage?()
    }
}

final class SwiftUICaptureInfrastructureTests: XCTestCase {
    func testConcurrentTypeLookups_returnOneCachedValue() throws {
        final class Value {}
        let memo = TypeNameMemo { _ in Value() }
        let lock = NSLock()
        var results: [Value] = []

        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            let value = memo(Int.self)
            lock.withLock { results.append(value) }
        }

        let first = try XCTUnwrap(results.first)
        XCTAssertEqual(results.count, 100)
        XCTAssertTrue(results.allSatisfy { $0 === first })
        XCTAssertTrue(memo(Int.self) === first)
        XCTAssertFalse(memo(String.self) === first)
    }

    func testScanDiagnostics_useSuppliedLoggerAndKeepPercentSignsLiteral() throws {
        let logger = CaptureLogger()
        logger.debugSwiftUICapture("Save 50% — %@")

        let message = try XCTUnwrap(logger.messages.first)
        XCTAssertEqual(logger.messages.count, 1)
        XCTAssertTrue(message.hasPrefix("[UP-SUI] +"))
        XCTAssertTrue(message.hasSuffix("ms  Save 50% — %@"))
        XCTAssertTrue(logger.loggedInfos.isEmpty)
    }

    func testSnapshotDiagnostics_invokeLoggerAfterUnlocking() {
        let logger = CaptureLogger()
        let cache = SwiftUIScanCache.shared
        defer { cache.clearCaches() }
        cache._testSeedSnapshot(
            textMap: [], inventory: [.init(title: "Save", viewType: "Button", depth: 0, order: 0)]
        )
        var observedTitles: [String] = []
        logger.onMessage = {
            // A logger may call SDK code. Re-entering a read must not find its lock still held.
            observedTitles = cache.inventory().0.map(\.title)
        }

        _ = cache.inventory(logger: logger)

        XCTAssertEqual(observedTitles, ["Save"])
        XCTAssertEqual(logger.messages.count, 1)
    }
}
