//
//  SwiftUITitleCaptureTests.swift
//  UserpilotTests
//
//  Phase-1 (dark) unit tests for the ported SwiftUI title-capture subsystem.
//  These exercise the subsystem in isolation; no production tap path is wired
//  yet (that is Phase 2).
//

// swiftlint:disable file_length identifier_name
// swiftlint:disable:previous blanket_disable_command

import SwiftUI
import XCTest
@testable import Userpilot

// MARK: - SwiftUIScanPolicy

final class SwiftUIScanPolicyTests: XCTestCase {

    func testDefaultsToNotSkipping() {
        let vc = UIViewController()
        XCTAssertFalse(SwiftUIScanPolicy.shouldSkipAccessibility(vc))
    }

    func testSkipThenAllow() {
        let vc = UIViewController()
        SwiftUIScanPolicy.skipAccessibility(for: vc)
        XCTAssertTrue(SwiftUIScanPolicy.shouldSkipAccessibility(vc))
        SwiftUIScanPolicy.allowAccessibility(for: vc)
        XCTAssertFalse(SwiftUIScanPolicy.shouldSkipAccessibility(vc))
    }

    func testOptOutIsPerInstance() {
        let a = UIViewController()
        let b = UIViewController()
        SwiftUIScanPolicy.skipAccessibility(for: a)
        XCTAssertTrue(SwiftUIScanPolicy.shouldSkipAccessibility(a))
        XCTAssertFalse(SwiftUIScanPolicy.shouldSkipAccessibility(b))
    }
}

// MARK: - ScanDebouncer

final class ScanDebouncerTests: XCTestCase {

    func testFireNowRunsAction() {
        let exp = expectation(description: "fired")
        let debouncer = ScanDebouncer(delay: 0.1) { exp.fulfill() }
        debouncer.fireNow()
        wait(for: [exp], timeout: 1.0)
    }

    func testScheduleRunsActionAfterDelay() {
        let exp = expectation(description: "fired after delay")
        let debouncer = ScanDebouncer(delay: 0.1) { exp.fulfill() }
        debouncer.schedule()
        wait(for: [exp], timeout: 1.0)
    }

    func testCancelPreventsAction() {
        let exp = expectation(description: "should not fire")
        exp.isInverted = true
        let debouncer = ScanDebouncer(delay: 0.2) { exp.fulfill() }
        debouncer.schedule()
        debouncer.cancel()
        wait(for: [exp], timeout: 0.6)
    }

    func testRapidSchedulesCoalesceToOneFire() {
        let exp = expectation(description: "fires once")
        var fireCount = 0
        let debouncer = ScanDebouncer(delay: 0.15) {
            fireCount += 1
            exp.fulfill()
        }
        for _ in 0..<10 { debouncer.schedule() }
        wait(for: [exp], timeout: 1.0)
        // Give any extra (incorrectly scheduled) fires time to land.
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)
        XCTAssertEqual(fireCount, 1)
    }

    func testNotTrackingInTestRunLoop() {
        // A unit test run loop is never in UITrackingRunLoopMode.
        XCTAssertFalse(ScanDebouncer.isMainRunLoopTracking())
    }
}

// MARK: - SwiftUIReflection.ViewRecord

final class SwiftUIViewRecordTests: XCTestCase {

    func testInteractiveClassification() {
        let button = SwiftUIReflection.ViewRecord(title: "Save", viewType: "Button", depth: 0, order: 0)
        let text = SwiftUIReflection.ViewRecord(title: "Hello", viewType: "Text", depth: 0, order: 1)
        let link = SwiftUIReflection.ViewRecord(title: "Go", viewType: "NavigationLink", depth: 0, order: 2)
        XCTAssertTrue(button.isInteractive)
        XCTAssertTrue(link.isInteractive)
        XCTAssertFalse(text.isInteractive)
    }
}

// MARK: - Format-pattern matcher (Stage B localized-key matching)

final class SwiftUIFormatPatternTests: XCTestCase {

    func testIntegerInterpolation() {
        XCTAssertTrue(SwiftUITitleResolver.matchesFormatPattern("Tapped 5 times",
                                                                pattern: "Tapped %lld times"))
    }

    func testFloatInterpolation() {
        XCTAssertTrue(SwiftUITitleResolver.matchesFormatPattern("Total: $4.99",
                                                                pattern: "Total: $%.2f"))
    }

    func testNonMatchingLiteral() {
        XCTAssertFalse(SwiftUITitleResolver.matchesFormatPattern("Goodbye",
                                                                 pattern: "Tapped %lld times"))
    }

    func testLeadingTokenMatches() {
        XCTAssertTrue(SwiftUITitleResolver.matchesFormatPattern("42 items",
                                                                pattern: "%lld items"))
    }

    func testOrderMatters() {
        // The literal chunks must appear IN ORDER.
        XCTAssertFalse(SwiftUITitleResolver.matchesFormatPattern("times 5 Tapped",
                                                                 pattern: "Tapped %lld times"))
    }
}

// MARK: - Display-list hit-frame inference

final class DisplayListTextMapHitFrameTests: XCTestCase {

    func testInheritedControlFrameOwnsNestedText() {
        let rowFrame = CGRect(x: 16, y: 400, width: 360, height: 74)
        let textColumnFrame = CGRect(x: 70, y: 415, width: 220, height: 40)
        let immediateSiblingFrame = CGRect(x: 70, y: 440, width: 180, height: 16)
        let titleFrame = CGRect(x: 70, y: 415, width: 58, height: 20)

        let hitFrame = DisplayListTextMap._testHitFrame(
            forText: titleFrame,
            parentFrame: textColumnFrame,
            prevSibling: immediateSiblingFrame,
            controlFrame: rowFrame
        )

        XCTAssertEqual(hitFrame, rowFrame)
        XCTAssertTrue(hitFrame.contains(CGPoint(x: 30, y: 437)),
                      "taps on the row background should map to the row's text title")
    }

    func testEntryMapsWindowPointThroughLayerIntoHitFrame() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 240, height: 180))
        let host = UIView(frame: window.bounds)
        window.addSubview(host)

        let textLayer = CALayer()
        textLayer.frame = CGRect(x: 74, y: 120, width: 140, height: 22)
        host.layer.addSublayer(textLayer)

        let entry = DisplayListTextMap.Entry(
            title: "UI Components",
            textFrame: CGRect(x: 74, y: 120, width: 140, height: 22),
            hitFrame: CGRect(x: 20, y: 100, width: 200, height: 64),
            layer: textLayer
        )

        XCTAssertTrue(entry.containsWindowPoint(CGPoint(x: 30, y: 132), in: window))
        XCTAssertFalse(entry.containsWindowPoint(CGPoint(x: 30, y: 30), in: window))
    }
}

// MARK: - SwiftUIReflection inventory extraction

private struct DemoScreen: View {
    var body: some View {
        VStack {
            Text("Welcome")
            Button("Save") {}
            NavigationLink("Details", destination: Text("Destination Content"))
        }
    }
}

@available(iOS 15.0, *)
private struct GroupBoxButtonScreen: View {
    var body: some View {
        GroupBox("Buttons") {
            VStack {
                Button("Confirm Order") {}
                Button("Add to Cart") {}
            }
        }
    }
}

private final class DemoModel: ObservableObject {}

private struct EnvironmentDependentScreen: View {
    @EnvironmentObject var model: DemoModel
    var body: some View {
        Button("Should Not Crash") {}
    }
}

private final class BodyEvaluationProbe {
    var count = 0

    func record() {
        count += 1
    }
}

private struct StatefulBodyProbeScreen: View {
    @State private var isEnabled = true
    let probe: BodyEvaluationProbe

    var body: some View {
        probe.record()
        return Button(isEnabled ? "Stateful Save" : "Stateful Disabled") {}
    }
}

final class SwiftUIReflectionTests: XCTestCase {

    func testExtractsButtonTitle() {
        let host = UIHostingController(rootView: DemoScreen())
        let records = SwiftUIReflection.extractInventory(from: host)

        let interactiveTitles = records.filter(\.isInteractive).map(\.title)
        XCTAssertTrue(interactiveTitles.contains("Save"),
                      "expected to find the Button title 'Save'; got \(records.map(\.description))")
    }

    func testButtonIsClassifiedInteractive() {
        let host = UIHostingController(rootView: DemoScreen())
        let records = SwiftUIReflection.extractInventory(from: host)
        let save = records.first { $0.title == "Save" }
        XCTAssertEqual(save?.viewType, "Button")
        XCTAssertEqual(save?.isInteractive, true)
    }

    @available(iOS 15.0, *)
    func testExtractsButtonsInsideGroupBox() {
        let host = UIHostingController(rootView: GroupBoxButtonScreen())
        let records = SwiftUIReflection.extractInventory(from: host)

        let interactiveTitles = records.filter(\.isInteractive).map(\.title)
        XCTAssertTrue(interactiveTitles.contains("Confirm Order"),
                      "expected GroupBox button title; got \(records.map(\.description))")
        XCTAssertTrue(interactiveTitles.contains("Add to Cart"),
                      "expected GroupBox button title; got \(records.map(\.description))")
    }

    func testDestinationContentIsNotInventoried() {
        // A NavigationLink's destination is an off-screen subtree and must be
        // pruned — its text should never appear in the inventory.
        let host = UIHostingController(rootView: DemoScreen())
        let records = SwiftUIReflection.extractInventory(from: host)
        XCTAssertFalse(records.map(\.title).contains("Destination Content"))
    }

    func testEnvironmentObjectScreenDoesNotCrash() {
        // The @EnvironmentObject is never injected here; evaluating body would
        // trap. The trap guard must skip body evaluation and degrade safely.
        let host = UIHostingController(rootView: EnvironmentDependentScreen())
        let records = SwiftUIReflection.extractInventory(from: host)
        // Reaching this line without a crash is the assertion.
        XCTAssertGreaterThanOrEqual(records.count, 0)
    }

    func testWarningProneStateBodyIsSkippedWhenPolicyAvoidsIt() {
        let probe = BodyEvaluationProbe()
        let host = UIHostingController(rootView: StatefulBodyProbeScreen(probe: probe))

        let records = SwiftUIReflection.extractInventory(
            from: host,
            bodyEvaluationPolicy: .avoidWarningProneState
        )

        XCTAssertEqual(probe.count, 0,
                       "stateful body should not be evaluated when warning-prone state is avoided")
        XCTAssertFalse(records.map(\.title).contains("Stateful Save"))
    }

    func testWarningProneStateBodyIsAllowedForLastResortPolicy() {
        let probe = BodyEvaluationProbe()
        let host = UIHostingController(rootView: StatefulBodyProbeScreen(probe: probe))

        let records = SwiftUIReflection.extractInventory(
            from: host,
            bodyEvaluationPolicy: .allowWarningProneAsLastResort
        )

        XCTAssertGreaterThan(probe.count, 0, "last-resort policy should preserve reflection fallback")
        XCTAssertTrue(records.filter(\.isInteractive).map(\.title).contains("Stateful Save"),
                      "expected stateful button title; got \(records.map(\.description))")
    }

    func testScanCacheSelectsAvoidPolicyWhenTextMapExists() {
        let entry = DisplayListTextMap.Entry(
            title: "Rendered",
            textFrame: .zero,
            hitFrame: .zero,
            layer: nil
        )

        XCTAssertEqual(
            SwiftUIScanCache.reflectionPolicy(forTextMap: [entry]),
            .avoidWarningProneState
        )
    }

    func testScanCacheSelectsLastResortPolicyWhenTextMapIsEmpty() {
        XCTAssertEqual(
            SwiftUIScanCache.reflectionPolicy(forTextMap: []),
            .allowWarningProneAsLastResort
        )
    }

    func testScanCacheMergesInventoriesFromMultipleHosts() {
        let parent = UIViewController()
        let child = UIViewController()
        let parentRecord = SwiftUIReflection.ViewRecord(
            title: "Confirm Order",
            viewType: "Button",
            depth: 1,
            order: 1
        )
        let childRecord = SwiftUIReflection.ViewRecord(
            title: "Open Detail Screen",
            viewType: "NavigationLink",
            depth: 1,
            order: 1
        )

        let merged = SwiftUIScanCache.mergeInventories([
            (records: [parentRecord], host: parent),
            (records: [childRecord], host: child)
        ])

        let interactiveTitles = merged.records.filter(\.isInteractive).map(\.title)
        XCTAssertTrue(interactiveTitles.contains("Confirm Order"))
        XCTAssertTrue(interactiveTitles.contains("Open Detail Screen"))
        XCTAssertTrue(merged.host === child)
    }
}

// MARK: - SwiftUITitleResolver stage selection (Stage B → Stage C fallthrough)

#if DEBUG
/// Guards the fix for GroupBox-wrapped buttons: when GroupBox renders its
/// background as a material/compositing layer subtree, the display-list ↔ layer
/// paint-order pairing desyncs, so the text map is NON-EMPTY but matches no
/// entry at tap time. Stage B used to be authoritative there and returned nil
/// (event fired with no title). It must now fall THROUGH to the Stage C y-band
/// inventory match so an approximate title is still emitted.
final class SwiftUITitleResolverStageTests: XCTestCase {

    override func tearDown() {
        SwiftUIScanCache.shared.clearCaches()
        super.tearDown()
    }

    /// A window with one full-size, hittable subview so `resolveTitle`'s
    /// `window.hitTest` returns a non-nil hit (required to reach Stage C).
    private func makeHittableWindow(height: CGFloat) -> (UIWindow, CGPoint) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: height))
        let content = UIView(frame: window.bounds)
        window.addSubview(content)
        window.isHidden = false
        // Top third of the container → y-band index 0 of a 3-item inventory.
        return (window, CGPoint(x: 150, y: height * 0.1))
    }

    func testNonEmptyButUnmatchedTextMapFallsThroughToStageC() {
        let height: CGFloat = 600
        let (window, point) = makeHittableWindow(height: height)

        // Non-empty text map whose entries can NEVER match: nil layer means
        // `textMapTitle` skips every entry (the desync condition).
        let unmatchable = [
            DisplayListTextMap.Entry(title: "Confirm Order", textFrame: .zero,
                                     hitFrame: .zero, layer: nil),
            DisplayListTextMap.Entry(title: "Add to Cart", textFrame: .zero,
                                     hitFrame: .zero, layer: nil)
        ]
        // y-band picks from the interactive inventory in order; index 0 here.
        let inventory = [
            SwiftUIReflection.ViewRecord(title: "Confirm Order", viewType: "Button", depth: 0, order: 0),
            SwiftUIReflection.ViewRecord(title: "Add to Cart", viewType: "Button", depth: 0, order: 1),
            SwiftUIReflection.ViewRecord(title: "Custom Styled Button", viewType: "Button", depth: 0, order: 2)
        ]
        SwiftUIScanCache.shared._testSeedSnapshot(textMap: unmatchable, inventory: inventory)

        let title = SwiftUITitleResolver.shared.resolveTitle(at: point, in: window)

        // Pre-fix this returned nil (authoritative Stage B). It must now resolve
        // via the Stage C y-band fallthrough.
        XCTAssertEqual(title, "Confirm Order",
                       "non-empty-but-unmatched text map should fall through to Stage C y-band")
    }
}
#endif
