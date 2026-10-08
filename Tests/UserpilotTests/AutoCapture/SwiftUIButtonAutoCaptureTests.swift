//
//  SwiftUIButtonAutoCaptureTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Covers the `enableSwiftUIButtonAutoCapture` switch: which gates turn tap-end capture and
//  title capture on, the local health breaker, the tap-point label filter, and the title
//  enrichment's privacy rules for a regular window tap.
//

import XCTest
@testable import Userpilot

/// Recognized by `SwiftUIDetection.isHostingView` (runtime class name contains "HostingView").
private final class StubHostingView: UIView {}

private var isIOS26OrLater: Bool {
    if #available(iOS 26.0, *) { return true }
    return false
}

private func makeConfig(
    buttonCapture: Bool = true,
    interactionCapture: Bool = true,
    framework: Userpilot.AppFramework? = .SwiftUI
) -> Userpilot.Config {
    let config = Userpilot.Config(token: "NX-\(UUID().uuidString)")
        .enableInteractionAutoCapture(interactionCapture)
        .enableSwiftUIButtonAutoCapture(buttonCapture)
    config.appFramework = framework
    return config
}

// MARK: - Configuration gates

final class SwiftUIButtonAutoCapturePolicyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SwiftUICaptureHealth._resetForTesting()
    }

    override func tearDown() {
        SwiftUICaptureHealth._resetForTesting()
        super.tearDown()
    }

    func testOffByDefault_keepsTouchBeganCaptureAndInstallsNothing() {
        let config = Userpilot.Config(token: "NX-\(UUID().uuidString)")
            .enableInteractionAutoCapture()
            .appFramework(.SwiftUI)

        XCTAssertFalse(config.enableSwiftUIButtonAutoCapture)
        XCTAssertFalse(SwiftUITitleCapturePolicy.isFeatureEnabled(config))
        XCTAssertFalse(SwiftUITitleCapturePolicy.capturesClicksOnTapEnd(config))
        XCTAssertFalse(SwiftUITitleCapturePolicy.shouldInstall(config: config))
        XCTAssertFalse(SwiftUITitleCapturePolicy.shouldRun(
            config: config, isSwiftUIHost: true
        ))
    }

    func testEnabledInSwiftUIApp_movesClicksToTapEndAndInstallsTitleCapture_onIOS26Only() {
        let config = makeConfig()

        XCTAssertEqual(SwiftUITitleCapturePolicy.capturesClicksOnTapEnd(config), isIOS26OrLater)
        XCTAssertEqual(SwiftUITitleCapturePolicy.shouldInstall(config: config), isIOS26OrLater)
        XCTAssertEqual(SwiftUITitleCapturePolicy.shouldRun(
            config: config, isSwiftUIHost: true
        ), isIOS26OrLater)
    }

    func testRequiresInteractionAutoCapture() {
        let config = makeConfig(interactionCapture: false)

        XCTAssertFalse(SwiftUITitleCapturePolicy.isFeatureEnabled(config))
        XCTAssertFalse(SwiftUITitleCapturePolicy.capturesClicksOnTapEnd(config))
        XCTAssertFalse(SwiftUITitleCapturePolicy.shouldInstall(config: config))
    }

    func testUIKitApp_keepsTouchBeganCaptureAndSkipsTitleCapture() {
        let config = makeConfig(framework: .UIKit)

        XCTAssertFalse(SwiftUITitleCapturePolicy.capturesClicksOnTapEnd(config))
        XCTAssertFalse(SwiftUITitleCapturePolicy.shouldInstall(config: config))
        XCTAssertFalse(SwiftUITitleCapturePolicy.shouldRun(
            config: config, isSwiftUIHost: true
        ))
    }

    func testWrapperHost_keepsTouchBeganCapture() {
        let config = makeConfig()
            .additionalProperties([WrapperSDKConstants.pluginType: WrapperSDKConstants.pluginTypeReactNative])

        XCTAssertTrue(config.isWrapperSDK)
        XCTAssertFalse(SwiftUITitleCapturePolicy.capturesClicksOnTapEnd(config))
    }

    func testUndetectedFramework_installsTitleCaptureButKeepsTouchBeganCapture() throws {
        try XCTSkipUnless(isIOS26OrLater, "SwiftUI button autocapture runs on iOS 26 and later only")
        let config = makeConfig(framework: nil)

        XCTAssertTrue(SwiftUITitleCapturePolicy.shouldInstall(config: config))
        XCTAssertFalse(SwiftUITitleCapturePolicy.capturesClicksOnTapEnd(config))
        XCTAssertTrue(SwiftUITitleCapturePolicy.shouldRun(
            config: config, isSwiftUIHost: true
        ))
        XCTAssertFalse(SwiftUITitleCapturePolicy.shouldRun(
            config: config, isSwiftUIHost: false
        ))
    }

    func testTitleCaptureRequiresTextCapture_tapEndCaptureDoesNot() throws {
        try XCTSkipUnless(isIOS26OrLater, "SwiftUI button autocapture runs on iOS 26 and later only")
        let config = makeConfig().enableInteractionTextCapture(false)

        XCTAssertTrue(SwiftUITitleCapturePolicy.capturesClicksOnTapEnd(config))
        XCTAssertFalse(SwiftUITitleCapturePolicy.shouldInstall(config: config))
        XCTAssertFalse(SwiftUITitleCapturePolicy.shouldRun(
            config: config, isSwiftUIHost: true
        ))
    }

    func testCircuitBreaker_stopsTitleCaptureAfterThreeConsecutiveStructuralFailures() throws {
        try XCTSkipUnless(isIOS26OrLater, "SwiftUI button autocapture runs on iOS 26 and later only")
        let config = makeConfig()

        // A structural failure: hosting views found, but no display list (or unpaired text).
        func failedScan() -> Bool {
            SwiftUICaptureHealth.recordScan(hosts: 1, locatedLists: 0, textItems: 0, pairedEntries: 0)
        }
        // No hosting views, or a located list on a screen without text, is not a failure.
        XCTAssertFalse(SwiftUICaptureHealth.recordScan(hosts: 0, locatedLists: 0, textItems: 0, pairedEntries: 0))
        XCTAssertFalse(failedScan())
        XCTAssertFalse(failedScan())
        // A healthy scan resets the run, so the two failures above never trip the breaker.
        XCTAssertFalse(SwiftUICaptureHealth.recordScan(hosts: 1, locatedLists: 1, textItems: 0, pairedEntries: 0))
        XCTAssertFalse(failedScan())
        XCTAssertFalse(SwiftUICaptureHealth.recordScan(hosts: 1, locatedLists: 1, textItems: 3, pairedEntries: 0))
        XCTAssertTrue(SwiftUITitleCapturePolicy.shouldRun(
            config: config, isSwiftUIHost: true
        ))

        XCTAssertTrue(failedScan())

        XCTAssertTrue(SwiftUICaptureHealth.isTripped)
        XCTAssertFalse(SwiftUITitleCapturePolicy.shouldRun(
            config: config, isSwiftUIHost: true
        ))
        // The breaker only stops title capture; tap-end click capture keeps one click per tap.
        XCTAssertTrue(SwiftUITitleCapturePolicy.capturesClicksOnTapEnd(config))
    }

}

// MARK: - Tap-point label filter

final class SwiftUIButtonTapPointTextTests: XCTestCase {

    /// A SwiftUI-style container whose UIKit subviews are two unrelated controls side by side
    /// (a segmented Picker's segments): the first label is not under the tap.
    private func makeSegments() -> (window: UIWindow, container: UIView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
        let container = UIView(frame: window.bounds)
        window.addSubview(container)
        let left = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 44))
        left.text = "Monthly"
        let right = UILabel(frame: CGRect(x: 100, y: 0, width: 100, height: 44))
        right.text = "Yearly"
        container.addSubview(left)
        container.addSubview(right)
        return (window, container)
    }

    func testTextUnderTheTapIsUsedOnlyWhenLimitedToTheTapPoint() {
        let (window, container) = makeSegments()
        let tapOnRight = CGPoint(x: 150, y: 22)

        let legacy = container.buildWindowInteractionProperties(at: tapOnRight, in: window)
        let limited = container.buildWindowInteractionProperties(
            at: tapOnRight,
            in: window,
            limitsTextToTapPoint: true
        )

        XCTAssertEqual(legacy[Constants.AutoCapture.targetText] as? String, "Monthly",
                       "without SwiftUI button autocapture the first label still wins, as before")
        XCTAssertEqual(limited[Constants.AutoCapture.targetText] as? String, "Yearly")
        XCTAssertEqual(limited[Constants.AutoCapture.targetClass] as? String,
                       legacy[Constants.AutoCapture.targetClass] as? String)
        XCTAssertEqual(limited[Constants.AutoCapture.hierarchy] as? String,
                       legacy[Constants.AutoCapture.hierarchy] as? String)
    }

    func testTapOutsideEveryLabelHasNoText() {
        let (window, container) = makeSegments()
        container.subviews.forEach { $0.frame.size.height = 20 }

        withExtendedLifetime(window) {
            XCTAssertNil(container.getTextContent(containing: CGPoint(x: 150, y: 40)))
            XCTAssertEqual(container.getTextContent(), "Monthly")
        }
    }
}

// MARK: - Title enrichment

final class SwiftUIButtonTitleEnrichmentTests: XCTestCase {

    private let tap = CGPoint(x: 40, y: 60)

    override func setUp() {
        super.setUp()
        SwiftUICaptureHealth._resetForTesting()
    }

    override func tearDown() {
        SwiftUIScanCache.shared.clearCaches()
        SwiftUICaptureHealth._resetForTesting()
        super.tearDown()
    }

    /// A tapped SwiftUI content view (inside `container`) with no UIKit text, and a fresh scan
    /// snapshot in which SwiftUI rendered the interactive "Save" button under `tap`.
    private func makeRenderedSaveButton(in container: UIView = UIView()) -> (window: UIWindow, tapped: UIView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        container.frame = window.bounds
        let tapped = UIView(frame: window.bounds)
        window.addSubview(container)
        container.addSubview(tapped)
        // Hidden layers are treated as recycled lazy rows and never hit.
        window.isHidden = false

        let textLayer = CALayer()
        textLayer.frame = CGRect(x: 20, y: 50, width: 100, height: 30)
        tapped.layer.addSublayer(textLayer)
        let entry = DisplayListTextMap.Entry(
            title: "Save",
            textFrame: textLayer.frame,
            hitFrame: textLayer.frame,
            layer: textLayer
        )
        SwiftUIScanCache.shared._testSeedSnapshot(
            textMap: [entry],
            inventory: [SwiftUIReflection.ViewRecord(title: "Save", viewType: "Button", depth: 0, order: 0)]
        )
        return (window, tapped)
    }

    private func enrich(_ tapped: UIView, in window: UIWindow, config: Userpilot.Config,
                        properties: [String: Any] = [:]) -> [String: Any] {
        var properties = properties
        tapped.addSwiftUITitle(
            to: &properties, at: tap, in: window, config: config
        )
        return properties
    }

    func testFillsMissingTargetTextWithTheRenderedTitle() throws {
        try XCTSkipUnless(isIOS26OrLater, "SwiftUI button autocapture runs on iOS 26 and later only")
        let (window, tapped) = makeRenderedSaveButton()

        let properties = enrich(tapped, in: window, config: makeConfig())

        XCTAssertEqual(properties as NSDictionary, [Constants.AutoCapture.targetText: "Save"] as NSDictionary)
    }

    func testKeepsTextAlreadyResolvedFromUIKit() throws {
        try XCTSkipUnless(isIOS26OrLater, "SwiftUI button autocapture runs on iOS 26 and later only")
        let (window, tapped) = makeRenderedSaveButton()

        let properties = enrich(tapped, in: window, config: makeConfig(),
                                properties: [Constants.AutoCapture.targetText: "UIKit Title"])

        XCTAssertEqual(properties[Constants.AutoCapture.targetText] as? String, "UIKit Title")
    }

    func testRedactedSubtreeUnderTheTapPublishesThePlaceholder() throws {
        try XCTSkipUnless(isIOS26OrLater, "SwiftUI button autocapture runs on iOS 26 and later only")
        let (window, tapped) = makeRenderedSaveButton()
        let redactCarrier = UIView(frame: CGRect(x: 20, y: 50, width: 100, height: 30))
        redactCarrier.userpilotRedactText = true
        tapped.addSubview(redactCarrier)

        let properties = enrich(tapped, in: window, config: makeConfig())

        XCTAssertEqual(properties[Constants.AutoCapture.targetText] as? String, Constants.AutoCapture.reductText)
    }

    func testRedactedAncestorPublishesThePlaceholder() throws {
        try XCTSkipUnless(isIOS26OrLater, "SwiftUI button autocapture runs on iOS 26 and later only")
        let (window, tapped) = makeRenderedSaveButton()
        // Above the tapped view, so only the responder-chain privacy check can see it.
        tapped.superview?.userpilotRedactText = true

        let properties = enrich(tapped, in: window, config: makeConfig())

        XCTAssertEqual(properties[Constants.AutoCapture.targetText] as? String, Constants.AutoCapture.reductText)
    }

    func testIgnoredSubtreeUnderTheTapLeavesTargetTextUnset() throws {
        try XCTSkipUnless(isIOS26OrLater, "SwiftUI button autocapture runs on iOS 26 and later only")
        let (window, tapped) = makeRenderedSaveButton()
        let ignoreCarrier = UIView(frame: CGRect(x: 20, y: 50, width: 100, height: 30))
        ignoreCarrier.userpilotIgnoreInteractions = true
        tapped.addSubview(ignoreCarrier)

        let properties = enrich(tapped, in: window, config: makeConfig())

        XCTAssertNil(properties[Constants.AutoCapture.targetText])
    }

    /// SwiftUI's `.userpilotRedactText()` / `.userpilotIgnoreInteractions()` flag the hidden
    /// carrier's parent: a platform-view host BESIDE the deepest tapped view in the hosting view.
    private func addFlaggedSibling(_ flag: ReferenceWritableKeyPath<UIView, Bool>, below tapped: UIView) {
        let carrierHost = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 120))
        carrierHost[keyPath: flag] = true
        tapped.superview?.insertSubview(carrierHost, belowSubview: tapped)
    }

    func testRedactedSiblingUnderTheTapPublishesThePlaceholder() throws {
        try XCTSkipUnless(isIOS26OrLater, "SwiftUI button autocapture runs on iOS 26 and later only")
        let (window, tapped) = makeRenderedSaveButton(in: StubHostingView())
        addFlaggedSibling(\.userpilotRedactText, below: tapped)

        let properties = enrich(tapped, in: window, config: makeConfig())

        XCTAssertEqual(properties[Constants.AutoCapture.targetText] as? String, Constants.AutoCapture.reductText,
                       "a redacted SwiftUI subtree under the tap must never publish its rendered title")
    }

    func testIgnoredSiblingUnderTheTapLeavesTargetTextUnset() throws {
        try XCTSkipUnless(isIOS26OrLater, "SwiftUI button autocapture runs on iOS 26 and later only")
        let (window, tapped) = makeRenderedSaveButton(in: StubHostingView())
        addFlaggedSibling(\.userpilotIgnoreInteractions, below: tapped)

        let properties = enrich(tapped, in: window, config: makeConfig())

        XCTAssertNil(properties[Constants.AutoCapture.targetText])
    }

    func testDisabledFeatureLeavesTargetTextUnset() {
        let (window, tapped) = makeRenderedSaveButton()

        let properties = enrich(tapped, in: window, config: makeConfig(buttonCapture: false))

        XCTAssertNil(properties[Constants.AutoCapture.targetText])
    }
}
