//
//  SwiftUITitleCaptureV10Tests.swift
//  UserpilotTests
//
//  Regression tests for the v10 hardening of the SwiftUI title-capture
//  subsystem (see REVIEW-VALIDATION-AND-FIX-PLAN_v10.md):
//    F1 — generation-stamped, stale-aware scan cache.
//    F3 — wall-clock deadline on reflection extraction.
//    F5 — locked read of `isAutoCaptureStopped`.
//
//  All tests here are deterministic and run without a live SwiftUI render where
//  possible (F1 via the `_testSeedSnapshot` seam; F3 via an immediate deadline).
//

import SwiftUI
import XCTest

@testable import Userpilot

// MARK: - F1: generation / stale-aware cache

final class SwiftUIScanCacheGenerationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SwiftUIScanCache.shared.clearCaches()
    }

    override func tearDown() {
        SwiftUIScanCache.shared.clearCaches()
        super.tearDown()
    }

    private func sampleInventory() -> [SwiftUIReflection.ViewRecord] {
        [SwiftUIReflection.ViewRecord(title: "Save", viewType: "Button", depth: 0, order: 0)]
    }

    private func sampleTextMap() -> [DisplayListTextMap.Entry] {
        [DisplayListTextMap.Entry(title: "Save", textFrame: .zero, hitFrame: .zero, layer: nil)]
    }

    func testFreshSeededSnapshotReturnsThroughAccessors() {
        SwiftUIScanCache.shared._testSeedSnapshot(
            textMap: sampleTextMap(),
            inventory: sampleInventory())
        let (records, _) = SwiftUIScanCache.shared.inventory()
        let (textMap, interactive) = SwiftUIScanCache.shared.textResolution()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(textMap.count, 1)
        XCTAssertEqual(interactive.first?.title, "Save")
    }

    func testMarkScreenChangedInvalidatesAccessors() {
        SwiftUIScanCache.shared._testSeedSnapshot(
            textMap: sampleTextMap(),
            inventory: sampleInventory())
        // A new screen appeared but no scan has run yet → readers must return
        // empty rather than the previous screen's snapshot.
        SwiftUIScanCache.shared.markScreenChanged()
        let (records, host) = SwiftUIScanCache.shared.inventory()
        let (textMap, interactive) = SwiftUIScanCache.shared.textResolution()
        XCTAssertTrue(records.isEmpty)
        XCTAssertNil(host)
        XCTAssertTrue(textMap.isEmpty)
        XCTAssertTrue(interactive.isEmpty)
    }

    func testStaleSeedIsRejected() {
        SwiftUIScanCache.shared._testSeedSnapshot(
            textMap: sampleTextMap(),
            inventory: sampleInventory(),
            fresh: false)
        let (records, _) = SwiftUIScanCache.shared.inventory()
        let (textMap, _) = SwiftUIScanCache.shared.textResolution()
        XCTAssertTrue(
            records.isEmpty, "a snapshot stamped with a prior generation must not resolve")
        XCTAssertTrue(textMap.isEmpty)
    }

    func testClearCachesResetsGeneration() {
        SwiftUIScanCache.shared._testSeedSnapshot(
            textMap: sampleTextMap(),
            inventory: sampleInventory())
        SwiftUIScanCache.shared.clearCaches()
        let (records, _) = SwiftUIScanCache.shared.inventory()
        XCTAssertTrue(records.isEmpty)
    }

    func testSeedSnapshotCanSetInventoryHost() {
        let host = UIViewController()
        SwiftUIScanCache.shared._testSeedSnapshot(
            textMap: sampleTextMap(),
            inventory: sampleInventory(),
            inventoryHost: host)
        let (_, returnedHost) = SwiftUIScanCache.shared.inventory()
        XCTAssertTrue(returnedHost === host)
    }
}

// MARK: - F3: reflection extraction deadline

private struct DeadlineProbeScreen: View {
    var body: some View {
        VStack {
            Button("Alpha") {}
            Button("Beta") {}
        }
    }
}

final class SwiftUIReflectionDeadlineTests: XCTestCase {

    func testPastDeadlineAbortsBeforeCollecting() {
        let host = UIHostingController(rootView: DeadlineProbeScreen())
        let records = SwiftUIReflection.extractInventory(
            from: host,
            deadline: Date().addingTimeInterval(-1)  // already expired
        )
        XCTAssertTrue(
            records.isEmpty,
            "an expired deadline must abort the walk before collecting records")
    }

    func testNilDeadlineStillExtractsTitles() {
        // The default (no deadline) preserves today's node/depth-bounded walk.
        let host = UIHostingController(rootView: DeadlineProbeScreen())
        let records = SwiftUIReflection.extractInventory(from: host)
        let titles = records.filter(\.isInteractive).map(\.title)
        XCTAssertTrue(
            titles.contains("Alpha"),
            "default extraction should still find button titles; got \(records.map(\.description))")
    }
}

// MARK: - Stage B styled-control fallback with empty inventory (NavigationStack)

#if DEBUG
    /// Regression: on a SwiftUI `NavigationStack` the reflection inventory is empty
    /// (the root's body re-evaluates to an empty navigation state), but the
    /// display-list text map still carries the on-screen button titles. Stage B must
    /// resolve the styled control geometrically via its `isStyledControl` fallback
    /// instead of bailing because `interactive` is empty.
    final class SwiftUITitleResolverEmptyInventoryTests: XCTestCase {

        override func tearDown() {
            SwiftUIScanCache.shared.clearCaches()
            super.tearDown()
        }

        func testStyledControlResolvesFromTextMapWhenInventoryEmpty() {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
            let content = UIView(frame: window.bounds)
            window.addSubview(content)
            window.isHidden = false

            // A drawing layer in the window's layer tree (superlayer != nil),
            // identity-mapped to window coordinates so `layer.convert` is a no-op.
            let layer = CALayer()
            layer.frame = window.bounds
            window.layer.addSublayer(layer)

            // Text at content origin; the hit frame is a 44pt-tall button background
            // enclosing it → `isStyledControl` is true.
            let entry = DisplayListTextMap.Entry(
                title: "Confirm Order",
                textFrame: CGRect(x: 0, y: 0, width: 80, height: 20),
                hitFrame: CGRect(x: 100, y: 10, width: 160, height: 44),
                layer: layer
            )
            // EMPTY inventory → no interactive records (the NavigationStack case).
            SwiftUIScanCache.shared._testSeedSnapshot(textMap: [entry], inventory: [])

            let title = SwiftUITitleResolver.shared.resolveTitle(
                at: CGPoint(x: 150, y: 30), in: window)
            XCTAssertEqual(
                title, "Confirm Order",
                "styled-control fallback must resolve from the text map even with an empty inventory"
            )
        }
    }
#endif

// MARK: - F5: locked stop/resume read

final class AutocaptureStopResumeReadTests: XCTestCase {

    override func tearDown() {
        // Never leave the global flag stopped for other suites.
        AutocaptureViewConfiguration.resumeAutoCapture()
        super.tearDown()
    }

    func testStopThenResumeTogglesLockedRead() {
        AutocaptureViewConfiguration.resumeAutoCapture()
        XCTAssertFalse(AutocaptureViewConfiguration.isAutoCaptureStopped)

        AutocaptureViewConfiguration.stopAutoCapture()
        XCTAssertTrue(AutocaptureViewConfiguration.isAutoCaptureStopped)

        AutocaptureViewConfiguration.resumeAutoCapture()
        XCTAssertFalse(AutocaptureViewConfiguration.isAutoCaptureStopped)
    }
}
