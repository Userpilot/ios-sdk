//
//  MultiInstanceIntegrationTests.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

private class HostScreenVC: UIViewController {}
private class VendorScreenVC: UIViewController {}

/// End-to-end style assertions that two Userpilot instances coexist correctly:
/// each gets its own analytics destination, autocapture events route to the
/// right tenant, and config-affecting flags are honoured per instance.
final class MultiInstanceIntegrationTests: XCTestCase {

    private var hostInstance: MockUserpilot!
    private var vendorInstance: MockUserpilot!

    override func setUpWithError() throws {
        Userpilot.Registry.shared.resetForTesting()

        // Host uses a plain Config: `isDefault` now defaults to `true`, so the host
        // claims the default role without an explicit `defaultInstance()` call.
        hostInstance = MockUserpilot(config: Userpilot.Config(token: "HOST"))

        // Vendor MUST opt out of the default role (it would otherwise claim it on a
        // before-host init and trigger a rejected-claim warning).
        let vendorConfig = Userpilot.Config(token: "VENDOR")
            .defaultInstance(false)
            .attach(viewControllerClasses: [VendorScreenVC.self])
        vendorInstance = MockUserpilot(config: vendorConfig)
    }

    override func tearDownWithError() throws {
        hostInstance = nil
        vendorInstance = nil
        Userpilot.Registry.shared.resetForTesting()
    }

    // MARK: - Per-tenant identify isolation

    func testIdentify_eachInstancePublishesToOwnAnalytics() throws {
        var hostEvents: [Event] = []
        var vendorEvents: [Event] = []
        hostInstance.analyticsPublisher.onPublish = { hostEvents.append($0) }
        vendorInstance.analyticsPublisher.onPublish = { vendorEvents.append($0) }

        hostInstance.identify(userId: "host-user")
        vendorInstance.identify(userId: "vendor-user")

        XCTAssertEqual(hostEvents.count, 1)
        XCTAssertEqual(vendorEvents.count, 1)

        guard case let .identify(hostId) = hostEvents[0].type else {
            return XCTFail("Expected identify event for host")
        }
        guard case let .identify(vendorId) = vendorEvents[0].type else {
            return XCTFail("Expected identify event for vendor")
        }
        XCTAssertEqual(hostId, "host-user")
        XCTAssertEqual(vendorId, "vendor-user")
    }

    // MARK: - Resolver routes to correct tenant

    func testResolver_routesScopedVCsToVendorAndUnscopedToHost() throws {
        let scoped = InstanceResolver.shared.target(forViewController: VendorScreenVC())
        XCTAssertTrue(scoped === vendorInstance, "Scoped VC must resolve to vendor")

        let unscoped = InstanceResolver.shared.target(forViewController: HostScreenVC())
        XCTAssertTrue(unscoped === hostInstance, "Unscoped VC must fall back to host (default)")
    }

    // MARK: - Per-tenant overlay window

    func testEachInstance_hasIndependentOverlayWindow() throws {
        let hostOverlay = hostInstance.experienceOverlayWindow
        let vendorOverlay = vendorInstance.experienceOverlayWindow

        XCTAssertFalse(hostOverlay === vendorOverlay, "Each Userpilot instance must own a distinct overlay window")
        XCTAssertNotEqual(
            hostOverlay.windowLevel,
            vendorOverlay.windowLevel,
            "Overlays at the same windowLevel would collide in z-ordering"
        )
    }

    func testOverlayWindow_isMarkedAsUserpilotWindowAndRootScreenIsIgnored() throws {
        let overlay = hostInstance.experienceOverlayWindow
        guard let rootViewController = overlay.rootViewController else {
            return XCTFail("Overlay must install a presentation root view controller")
        }

        _ = rootViewController.view

        XCTAssertTrue(overlay.isUserpilotWindow)
        XCTAssertFalse(UIWindow().isUserpilotWindow)
        XCTAssertEqual(
            objc_getAssociatedObject(
                rootViewController,
                &ScreenNameTracker.untrackedScreenKey
            ) as? Bool,
            true,
            "Overlay root must not be autocaptured as an app screen because that resets pending experiences"
        )
    }

    func testOverlayWindow_prepareForPresentationReshowsHiddenIdleWindow() throws {
        let overlay = hostInstance.experienceOverlayWindow

        XCTAssertFalse(overlay.isHidden)
        overlay.hideIfIdle()
        XCTAssertTrue(overlay.isHidden)

        overlay.prepareForPresentation()
        XCTAssertFalse(
            overlay.isHidden,
            "Presenting on a hidden overlay drives lifecycle and seen events, but draws no UI"
        )
    }

    // MARK: - Shared dropping

    func testShared_returnsHostInstanceWhenBothCoexist() throws {
        XCTAssertTrue(Userpilot.shared === hostInstance)
        // Vendor instance is reachable by token, not by `Userpilot.shared`.
        XCTAssertTrue(Userpilot.instance(forToken: "VENDOR") === vendorInstance)
    }

    // MARK: - External-source forwarding

    func testVendorInteraction_isForwardedToHostWhenHostOptsIn() throws {
        Userpilot.Registry.shared.resetForTesting()

        let host = MockUserpilot(
            config: Userpilot.Config(token: "HOST-FWD").allowReceiveEventsFromExternalSource()
        )
        let vendor = MockUserpilot(
            config: Userpilot.Config(token: "VENDOR-FWD")
                .defaultInstance(false)
                .enableInteractionAutoCapture()
        )

        var hostEvents: [Event] = []
        var vendorEvents: [Event] = []
        host.analyticsPublisher.onPublish = { hostEvents.append($0) }
        vendor.analyticsPublisher.onPublish = { vendorEvents.append($0) }

        let payload = InteractionPayload(interactionType: .tap, elementType: "UIButton")
        vendor.autoCaptureCoordinator.handleInteractionEvent(payload)

        XCTAssertEqual(vendorEvents.count, 1, "Vendor still publishes its own event")
        XCTAssertEqual(hostEvents.count, 1, "Host (default) receives the forwarded copy")
        _ = host
        _ = vendor
    }

    func testVendorInteraction_isNotForwardedWhenHostDoesNotOptIn() throws {
        Userpilot.Registry.shared.resetForTesting()

        // Host does NOT opt in (default `allowReceiveEventsFromExternalSource == false`).
        let host = MockUserpilot(config: Userpilot.Config(token: "HOST-NOFWD"))
        let vendor = MockUserpilot(
            config: Userpilot.Config(token: "VENDOR-NOFWD")
                .defaultInstance(false)
                .enableInteractionAutoCapture()
        )

        var hostEvents: [Event] = []
        var vendorEvents: [Event] = []
        host.analyticsPublisher.onPublish = { hostEvents.append($0) }
        vendor.analyticsPublisher.onPublish = { vendorEvents.append($0) }

        let payload = InteractionPayload(interactionType: .tap, elementType: "UIButton")
        vendor.autoCaptureCoordinator.handleInteractionEvent(payload)

        XCTAssertEqual(vendorEvents.count, 1, "Vendor still publishes its own event")
        XCTAssertTrue(hostEvents.isEmpty, "Without opt-in, vendor events must not reach the host")
        _ = host
        _ = vendor
    }

    func testDefaultInstanceInteraction_isNotForwardedToItself() throws {
        Userpilot.Registry.shared.resetForTesting()

        // Default host opts in AND emits its own interaction: it must not duplicate the
        // event to itself.
        let host = MockUserpilot(
            config: Userpilot.Config(token: "HOST-SELF")
                .allowReceiveEventsFromExternalSource()
                .enableInteractionAutoCapture()
        )

        var hostEvents: [Event] = []
        host.analyticsPublisher.onPublish = { hostEvents.append($0) }

        let payload = InteractionPayload(interactionType: .tap, elementType: "UIButton")
        host.autoCaptureCoordinator.handleInteractionEvent(payload)

        XCTAssertEqual(hostEvents.count, 1, "The default instance must not self-forward its own events")
        _ = host
    }

    // MARK: - Config scope additive

    func testConfigAttach_isCumulative() throws {
        let bundleIdentifier = "com.test.bundle"
        // Mix a single-element call with a multi-element call to assert that calls
        // are additive (not replacing) and that array input merges correctly.
        let config = Userpilot.Config(token: "CUMULATIVE")
            .attach(viewControllerClasses: [VendorScreenVC.self])
            .attach(viewControllerClasses: [HostScreenVC.self])

        XCTAssertEqual(config.attachedViewControllerClasses.count, 2)
        XCTAssertTrue(config.attachedViewControllerClasses.contains(where: { $0 == VendorScreenVC.self }))
        XCTAssertTrue(config.attachedViewControllerClasses.contains(where: { $0 == HostScreenVC.self }))
        _ = bundleIdentifier
    }
}

// swiftlint:enable all
