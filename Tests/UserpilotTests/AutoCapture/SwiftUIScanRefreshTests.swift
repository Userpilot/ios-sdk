//
//  SwiftUIScanRefreshTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 12/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Covers hosting-root publication and replacing a tapped host's reflection inventory.
//

import SwiftUI
import XCTest
@testable import Userpilot

private struct RefreshButton: View {
    let title: String
    var body: some View { Button(title) {}.buttonStyle(.plain) }
}

final class SwiftUIScanRefreshTests: XCTestCase {
    private var owner: MockUserpilot!
    private var window: UIWindow!
    private var events: [Event] = []
    private var cache: SwiftUIScanCache { UserpilotRuntime.shared.scanCache }

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard #available(iOS 26.0, *) else { throw XCTSkip("SwiftUI button capture requires iOS 26") }
        SwiftUICaptureHealth._resetForTesting()
        cache.stop()
        let config = Userpilot.Config(token: "REFRESH-\(UUID().uuidString)")
            .defaultInstance(false).appFramework(.SwiftUI)
        owner = MockUserpilot(config: config)
        _ = owner.autoCaptureCoordinator
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        window.rootViewController = UIViewController()
        window.isHidden = false
        owner.analyticsPublisher.onPublish = { [weak self] in self?.events.append($0) }
        config.enableInteractionAutoCapture().enableSwiftUIButtonAutoCapture()
    }

    override func tearDown() {
        cache.stop()
        window?.isHidden = true
        window = nil
        owner = nil
        events = []
        SwiftUICaptureHealth._resetForTesting()
        super.tearDown()
    }

    func testResolvedHostingRoot_publishesOriginalPropertiesWithTitle() throws {
        let host = addHost("Save", y: 0)
        seedTitle("Save", in: host)
        let point = CGPoint(x: 40, y: 40)
        let original = host.view.buildWindowInteractionProperties(at: point, in: window, limitsTextToTapPoint: true)

        window.handleRegularViewTap(on: host.view, target: owner, window: window, point: point)

        XCTAssertEqual(events.count, 1)
        let properties = try XCTUnwrap(events.first?.properties)
        XCTAssertEqual(properties[Constants.AutoCapture.targetText] as? String, "Save")
        XCTAssertEqual(properties[Constants.AutoCapture.targetClass] as? String,
                       original[Constants.AutoCapture.targetClass] as? String)
        XCTAssertEqual(properties[Constants.AutoCapture.hierarchy] as? String,
                       original[Constants.AutoCapture.hierarchy] as? String)
    }

    func testUnresolvedHostingRoot_remainsFiltered() {
        let host = addHost("Save", y: 0)
        cache._testSeedSnapshot(textMap: [], inventory: [])
        window.handleRegularViewTap(on: host.view, target: owner, window: window, point: CGPoint(x: 290, y: 90))
        XCTAssertTrue(events.isEmpty)
    }

    func testIgnoredResolvedHostingRoot_doesNotPublish() {
        let host = addHost("Save", y: 0)
        seedTitle("Save", in: host)
        host.view.userpilotIgnoreInteractions = true
        window.handleRegularViewTap(on: host.view, target: owner, window: window, point: CGPoint(x: 40, y: 40))
        XCTAssertTrue(events.isEmpty)
    }

    func testRedactedResolvedHostingRoot_publishesPlaceholder() {
        let host = addHost("Save", y: 0)
        seedTitle("Save", in: host)
        host.view.userpilotRedactText = true
        window.handleRegularViewTap(on: host.view, target: owner, window: window, point: CGPoint(x: 40, y: 40))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.properties?[Constants.AutoCapture.targetText] as? String, "****")
    }

    func testCacheMiss_refreshesInteractiveTitlesAndPreservesSiblingHost() {
        let first = addHost("First", y: 0)
        let second = addHost("Second", y: 120)
        cache._testSeedSnapshot(textMap: [], inventory: SwiftUIReflection.extractInventory(from: first))

        refresh(second)

        XCTAssertEqual(Set(cache.textResolution().interactive.map(\.title)), ["First", "Second"])
    }

    func testCacheMiss_replacesTitlesRemovedFromTappedHost() {
        let first = addHost("First", y: 0)
        let second = addHost("Old", y: 120)
        let inventory = [first, second].flatMap { SwiftUIReflection.extractInventory(from: $0) }
        cache._testSeedSnapshot(textMap: [], inventory: inventory)
        second.rootView = RefreshButton(title: "New")

        refresh(second)

        XCTAssertEqual(Set(cache.textResolution().interactive.map(\.title)), ["First", "New"])
    }

    func testSDKOverlayAppearance_doesNotInvalidateOrReplaceAppSnapshot() {
        let host = addHost("Save", y: 0)
        let overlay = ExperienceOverlayWindow(owningInstance: owner)
        let overlayHost = UIHostingController(rootView: RefreshButton(title: "SDK content"))
        overlay.rootViewController = overlayHost
        owner.attachToViewController(overlayHost)
        AutoCaptureSwizzler.swizzleSwiftUIScanScheduling()
        overlay.isHidden = false
        // Discard app-window scans queued by fixture construction before testing the overlay hook.
        cache.stop()
        seedTitle("Save", in: host)
        overlayHost.viewDidAppear(false)
        cache.scheduleRescan(reason: .screenAppeared, window: overlay, owner: owner)

        cache._testPerformPendingScan()

        XCTAssertEqual(cache.textResolution().interactive.map(\.title), ["Save"])
        overlay.isHidden = true
    }

    func testResolvedControlSignal_doesNotAdmitOtherPrivateViewsOrKeyboard() {
        let config = owner.config
        for className in ["_UITextLayoutCanvasView", "_NSView", "UIKBKeyView"] {
            let properties = [Constants.AutoCapture.targetClass: className, Constants.AutoCapture.targetText: "Save"]
            XCTAssertFalse(WindowTouchFilter.shouldPublishWindowLevelTouch(
                properties, config: config, resolvedSwiftUIControl: true
            ), className)
        }
        let properties = [Constants.AutoCapture.targetClass: "_UIHostingView<Control>",
                          Constants.AutoCapture.targetText: "Save",
                          Constants.AutoCapture.hierarchy: "UIWindow/UIKeyboardImpl/_UIHostingView"]
        XCTAssertFalse(WindowTouchFilter.shouldPublishWindowLevelTouch(
            properties, config: config, resolvedSwiftUIControl: true
        ))
    }

    func testHostingRootMetadata_aloneOrWithFeatureDisabledRemainsFiltered() {
        let properties = [Constants.AutoCapture.targetClass: "_UIHostingView<Control>",
                          Constants.AutoCapture.targetText: "Save"]
        XCTAssertFalse(WindowTouchFilter.shouldPublishWindowLevelTouch(properties, config: owner.config))
        owner.config.enableSwiftUIButtonAutoCapture(false)
        XCTAssertFalse(WindowTouchFilter.shouldPublishWindowLevelTouch(
            properties, config: owner.config, resolvedSwiftUIControl: true
        ))
    }

    private func addHost(_ title: String, y originY: CGFloat) -> UIHostingController<RefreshButton> {
        let host = UIHostingController(rootView: RefreshButton(title: title))
        owner.attachToViewController(host)
        let parent = window.rootViewController!
        parent.addChild(host)
        host.view.frame = CGRect(x: 0, y: originY, width: 300, height: 100)
        parent.view.addSubview(host.view)
        host.didMove(toParent: parent)
        return host
    }

    private func seedTitle(_ title: String, in host: UIViewController) {
        let layer = CALayer()
        layer.frame = CGRect(x: 10, y: 10, width: 100, height: 60)
        host.view.layer.addSublayer(layer)
        let entry = DisplayListTextMap.Entry(title: title, textFrame: layer.frame, hitFrame: layer.frame, layer: layer)
        cache._testSeedSnapshot(
            textMap: [entry], inventory: SwiftUIReflection.extractInventory(from: host), inventoryHost: host
        )
    }

    private func refresh(_ host: UIViewController) {
        cache.prepareForTapResolution(at: CGPoint(x: 40, y: 160), in: window, tappedView: host.view, owner: owner)
    }
}
