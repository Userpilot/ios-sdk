//
//  SwiftUITitleCaptureOwnershipTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies that installed native lifecycle hooks use the appearing controller's SDK owner.
//

import ObjectiveC
import XCTest
@testable import Userpilot

private final class OwnedHostingController: UIViewController {}

private extension UIApplication {
    // Hostless tests control only app activity; scheduling, routing and native scans stay real.
    @objc var userpilotTestScanApplicationState: UIApplication.State { .active }
}

final class SwiftUITitleCaptureOwnershipTests: XCTestCase {
    private var defaultInstance: MockUserpilot!
    private var ownerInstance: MockUserpilot!
    private var windows: [UIWindow] = []
    private let logger = MockSwiftUICaptureLogger()
    /// Production hooks schedule on the runtime's cache; tests drive that same cache.
    private var scanCache: SwiftUIScanCache { UserpilotRuntime.shared.scanCache }

    override func setUp() {
        super.setUp()
        exchangeApplicationState()
        SwiftUICaptureHealth._resetForTesting()
        scanCache.stop()
    }

    override func tearDown() {
        scanCache.stop()
        windows.forEach { $0.isHidden = true }
        windows = []
        logger.messages = []
        defaultInstance = nil
        ownerInstance = nil
        SwiftUICaptureHealth._resetForTesting()
        exchangeApplicationState()
        super.tearDown()
    }

    func testAppearingOwnerOptedOut_doesNotUseEnabledDefault() throws {
        try configure(defaultEnabled: true, ownerEnabled: false)
        appearWithCachedTitle()
        XCTAssertEqual(scanCache.inventory().0.map(\.title), ["Save"])
    }

    func testAppearingOwnerOptedIn_doesNotUseDisabledDefault() throws {
        try configure(defaultEnabled: false, ownerEnabled: true)
        appearWithCachedTitle()
        XCTAssertTrue(scanCache.inventory().0.isEmpty,
                      "The enabled owner's appearance must invalidate the previous screen snapshot")
    }

    func testWindowScan_unknownFrameworkSchedulesAndCompletes() throws {
        try configure(defaultEnabled: true, ownerEnabled: true)
        ownerInstance.config.appFramework = nil
        let window = makeWindow()
        scheduleScan(in: window)

        scanCache._testPerformPendingScan()

        assertScanCompleted()
    }

    func testChildAppearance_scansForEnabledChildInsideDisabledRoot() throws {
        try configure(defaultEnabled: false, ownerEnabled: true)
        let window = makeWindow()
        let root = UIViewController()
        window.rootViewController = root
        let child = OwnedHostingController()
        root.addChild(child)
        root.view.addSubview(child.view)
        child.didMove(toParent: root)
        let resolver = UserpilotRuntime.shared.instanceResolver
        XCTAssertTrue(resolver.resolveOwner(from: window) === defaultInstance, "Precondition: disabled root owner")
        XCTAssertTrue(resolver.resolveOwner(from: child) === ownerInstance, "Precondition: enabled child owner")
        scanCache.stop()
        seedSnapshot()
        logger.messages = []

        child.viewDidAppear(false)

        XCTAssertTrue(logger.messages.contains { $0.contains("viewDidAppear vc=") })
        XCTAssertTrue(logger.messages.contains { $0.contains("scheduleRescan(reason=screenAppeared)") })
        scanCache._testPerformPendingScan()
        assertScanCompleted()
    }

    private func exchangeApplicationState() {
        let original = class_getInstanceMethod(UIApplication.self, #selector(getter: UIApplication.applicationState))!
        let replacement = class_getInstanceMethod(UIApplication.self,
                                                  #selector(getter: UIApplication.userpilotTestScanApplicationState))!
        method_exchangeImplementations(original, replacement)
    }

    func testDeferredScan_rechecksOwnerOptOut() throws {
        try configure(defaultEnabled: true, ownerEnabled: true)
        scheduleScan(in: makeWindow())
        ownerInstance.config.enableSwiftUIButtonAutoCapture(false)

        scanCache._testPerformPendingScan()

        assertNoScan()
    }

    func testStopThenResume_allowsPendingScanToComplete() throws {
        try configure(defaultEnabled: true, ownerEnabled: true)
        scheduleScan(in: makeWindow())
        ownerInstance.autoCaptureCoordinator.stopAutoCapture()
        ownerInstance.autoCaptureCoordinator.resumeAutoCapture()

        scanCache._testPerformPendingScan()

        assertScanCompleted()
    }

    func testStoppingDifferentOwner_preservesPendingScan() throws {
        try configure(defaultEnabled: true, ownerEnabled: true)
        scheduleScan(in: makeWindow())
        defaultInstance.autoCaptureCoordinator.stopAutoCapture()

        scanCache._testPerformPendingScan()

        assertScanCompleted()
    }

    func testDeferredScan_stoppedOwnerKeepsExistingSnapshot() throws {
        try configure(defaultEnabled: true, ownerEnabled: true)
        scheduleScan(in: makeWindow())
        ownerInstance.autoCaptureCoordinator.stopAutoCapture()

        scanCache._testPerformPendingScan()

        assertNoScan()
    }

    func testDeferredScan_rejectsUIKitDetectedAfterScheduling() throws {
        try configure(defaultEnabled: true, ownerEnabled: true)
        ownerInstance.config.appFramework = nil
        scheduleScan(in: makeWindow())
        ownerInstance.config.appFramework = .UIKit

        scanCache._testPerformPendingScan()

        assertNoScan()
    }

    func testReleasedOwner_doesNotFallBackToDefaultInstance() throws {
        try configure(defaultEnabled: true, ownerEnabled: true)
        let window = makeWindow()
        scheduleScan(in: window)
        weak var releasedOwner: MockUserpilot?
        releasedOwner = ownerInstance
        ownerInstance = nil
        XCTAssertNil(releasedOwner, "Pending scans must not retain the requesting SDK instance")

        scanCache._testPerformPendingScan()

        assertNoScan()
    }

    func testScanOnce_stoppedOwnerKeepsExistingSnapshot() throws {
        try configure(defaultEnabled: true, ownerEnabled: true)
        let window = makeWindow()
        ownerInstance.autoCaptureCoordinator.stopAutoCapture()
        seedSnapshot()
        logger.messages = []

        scanCache.scanOnceCurrentScreen(for: window.rootViewController!)

        assertNoScan()
        XCTAssertFalse(logger.messages.contains { $0.contains("scanOnceCurrentScreen DONE") })
    }

    func testPendingScan_doesNotRetainItsWindow() throws {
        try configure(defaultEnabled: true, ownerEnabled: true)
        weak var releasedWindow: UIWindow?
        autoreleasepool {
            let window = makeWindow()
            releasedWindow = window
            scheduleScan(in: window)
            window.isHidden = true
            windows.removeAll()
        }

        XCTAssertNil(releasedWindow)
        scanCache._testPerformPendingScan()
        assertNoScan()
    }

    func testTapInDifferentWindow_refreshesOnlyTappedHostWhenGenerationIsCurrent() throws {
        try configure(defaultEnabled: true, ownerEnabled: true)
        let firstWindow = makeWindow()
        let secondWindow = makeWindow()
        let textLayer = CALayer()
        textLayer.frame = firstWindow.bounds
        firstWindow.layer.addSublayer(textLayer)
        let entry = DisplayListTextMap.Entry(title: "Save", textFrame: textLayer.frame,
                                            hitFrame: textLayer.frame, layer: textLayer)
        scanCache._testSeedSnapshot(
            textMap: [entry], inventory: [.init(title: "Save", viewType: "Button", depth: 0, order: 0)]
        )
        logger.messages = []

        scanCache.prepareForTapResolution(
            at: .zero, in: secondWindow, tappedView: secondWindow.rootViewController!.view, owner: ownerInstance
        )

        XCTAssertTrue(logger.messages.contains { $0.contains("cache misses tap point → refresh tapped host only") })
        XCTAssertFalse(logger.messages.contains { $0.contains("performScan(") })
    }

    private func makeWindow() -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        window.rootViewController = OwnedHostingController()
        window.isHidden = false
        windows.append(window)
        return window
    }

    private func scheduleScan(in window: UIWindow) {
        scanCache.stop()
        seedSnapshot()
        logger.messages = []
        scanCache.scheduleRescan(reason: .screenAppeared, window: window, owner: ownerInstance)
        XCTAssertTrue(logger.messages.contains { $0.contains("scheduleRescan(reason=screenAppeared)") },
                      "The test must admit pending work before asserting its outcome")
        logger.messages = []
    }

    private func seedSnapshot() {
        scanCache._testSeedSnapshot(
            textMap: [], inventory: [.init(title: "Save", viewType: "Button", depth: 0, order: 0)]
        )
    }

    private func assertScanCompleted(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(logger.messages.contains { $0.contains("performScan(screenAppeared) DONE") },
                      "Scheduling or deferring alone does not prove scanning completed", file: file, line: line)
        XCTAssertTrue(scanCache.inventory().0.isEmpty,
                      "The native empty-window scan must replace the seeded snapshot", file: file, line: line)
    }

    private func assertNoScan(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(logger.messages.contains { $0.contains("performScan(") }, file: file, line: line)
        XCTAssertEqual(scanCache.inventory().0.map(\.title), ["Save"], file: file, line: line)
    }

    private func configure(defaultEnabled: Bool, ownerEnabled: Bool) throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("SwiftUI button autocapture runs on iOS 26 and later only")
        }
        func config(enabled: Bool) -> Userpilot.Config {
            let config = Userpilot.Config(token: "NX-\(UUID().uuidString)")
                .enableInteractionAutoCapture(true)
                .enableSwiftUIButtonAutoCapture(enabled)
            config.appFramework = .SwiftUI
            return config
        }
        defaultInstance = MockUserpilot(config: config(enabled: defaultEnabled))
        ownerInstance = MockUserpilot(config: config(enabled: ownerEnabled)
            .attach(viewControllerClasses: [OwnedHostingController.self]))
        ownerInstance.config.logger = logger
        // Install the same process-wide hook used in production, through the enabled coordinator.
        _ = defaultInstance.autoCaptureCoordinator
        _ = ownerInstance.autoCaptureCoordinator
    }

    private func appearWithCachedTitle() {
        scanCache._testSeedSnapshot(
            textMap: [],
            inventory: [.init(title: "Save", viewType: "Button", depth: 0, order: 0)]
        )
        let controller = OwnedHostingController()
        controller.loadViewIfNeeded()
        controller.viewDidAppear(false)
    }
}
