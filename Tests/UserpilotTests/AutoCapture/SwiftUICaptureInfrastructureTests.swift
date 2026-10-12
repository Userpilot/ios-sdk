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

private final class ScanFixtureHostingView: UIView {}

final class MockSwiftUICaptureLogger: MockLogger {
    var messages: [String] = []
    var onMessage: (() -> Void)?

    override func debug(_ message: StaticString, _ args: CVarArg...) {
        messages.append(UPLogger.formattedMessage(message, args: args))
        onMessage?()
    }
}

final class SwiftUICaptureInfrastructureTests: XCTestCase {
    func testSharedScanner_preservesHostOnlyVersusWholeWindowScope() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let firstHost = ScanFixtureHostingView(frame: window.bounds)
        let secondHost = ScanFixtureHostingView(frame: window.bounds)
        window.addSubview(firstHost)
        window.addSubview(secondHost)

        let oneShot = SwiftUIScanner.scanTextMap(under: firstHost, budget: SwiftUIScanBudget.background, logger: nil)
        let fullScan = SwiftUIScanner.scanTextMap(under: window, budget: SwiftUIScanBudget.background, logger: nil)

        XCTAssertEqual(oneShot.hostCount, 1)
        XCTAssertEqual(fullScan.hostCount, 2)
    }

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
        let logger = MockSwiftUICaptureLogger()
        logger.debugSwiftUICapture("Save 50% — %@")

        let message = try XCTUnwrap(logger.messages.first)
        XCTAssertEqual(logger.messages.count, 1)
        XCTAssertTrue(message.hasPrefix("[UP-SUI] +"))
        XCTAssertTrue(message.hasSuffix("ms  Save 50% — %@"))
        XCTAssertTrue(logger.loggedInfos.isEmpty)
    }

    func testTitleDiagnostics_keepFullTextCountsAndChunkShape() {
        let logger = MockSwiftUICaptureLogger()
        let titles = (0..<8).map { "Title \($0)" } + ["Save 50% — %@"]
        var evaluations = 0
        func readTitles() -> [String] {
            evaluations += 1
            return titles
        }
        logger.debugSwiftUITitles("textMap titles", readTitles())
        logger.debugSwiftUITitles("interactive titles", [])

        XCTAssertEqual(evaluations, 1)
        XCTAssertEqual(logger.messages.count, 3)
        XCTAssertTrue(logger.messages[0].hasSuffix("textMap titles(9)[0..<8]: \(Array(titles.prefix(8)))"))
        XCTAssertTrue(logger.messages[1].hasSuffix("textMap titles(9)[8..<9]: \(Array(titles.suffix(1)))"))
        XCTAssertTrue(logger.messages[2].hasSuffix("interactive titles(0): []"))
    }

    func testConditionalDiagnostic_withNilMessageDoesNotLog() {
        let logger = MockSwiftUICaptureLogger()

        logger.debugSwiftUICapture(nil)

        XCTAssertTrue(logger.messages.isEmpty)
    }

    func testResolvedAndUnresolvedTitles_appearInDebugDiagnostics() {
        let logger = MockSwiftUICaptureLogger()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        window.isHidden = false
        defer {
            window.isHidden = true
            UserpilotRuntime.shared.scanCache.clearCaches()
        }
        let layer = CALayer()
        layer.frame = CGRect(x: 20, y: 50, width: 100, height: 30)
        window.layer.addSublayer(layer)
        let sensitiveTitle = "private-survey-answer"
        let entry = DisplayListTextMap.Entry(title: sensitiveTitle, textFrame: layer.frame,
                                            hitFrame: layer.frame, layer: layer)
        UserpilotRuntime.shared.scanCache._testSeedSnapshot(
            textMap: [entry],
            inventory: [.init(title: sensitiveTitle, viewType: "Button", depth: 0, order: 0)]
        )
        let resolver = SwiftUITitleResolver.shared
        XCTAssertEqual(resolver.resolveTitle(at: CGPoint(x: 40, y: 60), in: window,
                                             captureAccessibility: false, logger: logger), sensitiveTitle)
        UserpilotRuntime.shared.scanCache._testSeedSnapshot(textMap: [entry], inventory: [])
        XCTAssertNil(resolver.resolveTitle(at: CGPoint(x: 40, y: 60), in: window,
                                          captureAccessibility: false, logger: logger))

        XCTAssertTrue(logger.messages.contains { $0.contains("STAGE B (display-list)") && $0.contains(sensitiveTitle) })
        XCTAssertTrue(logger.messages.contains { $0.contains("candidates under tap") && $0.contains(sensitiveTitle) })
    }

    func testSnapshotDiagnostics_invokeLoggerAfterUnlocking() {
        let logger = MockSwiftUICaptureLogger()
        let cache = UserpilotRuntime.shared.scanCache
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
