//
//  InstanceResolverBindingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Explicit native UI bindings, their detach rules and expiry, and the no-binding/no-claim
//  fast path, all resolved through the real resolver against real view hierarchies.
//

import XCTest
@testable import Userpilot

final class InstanceResolverBindingTests: InstanceResolverTestCase {

    // MARK: - Explicit bindings

    func testViewBinding_beatsViewControllerClassClaim() {
        register("HOST", isDefault: true)
        let vendor = register("VENDOR") { $0.attach(viewControllerClasses: [TenantAVC.self]) }
        let partner = register("PARTNER")
        let controller = TenantAVC()
        show(controller)
        let bound = addLeaf(to: controller.view)

        partner.attachToView(bound.container)

        assertResolves([bound.label, bound.container], to: partner)
        assertResolves([addLeaf(to: controller.view).label, controller], to: vendor)
    }

    func testControllerBinding_ownsItsSubtreeWithoutLoadingItsView() {
        let host = register("HOST", isDefault: true)
        let partner = register("PARTNER")
        let controller = HostVC()

        partner.attachToViewController(controller)

        XCTAssertFalse(controller.isViewLoaded, "Attaching must not load the controller's view")
        assertResolves([controller], to: partner)
        assertResolves([addLeaf(to: controller.view).label], to: partner)
        assertResolves([HostVC()], to: host)
    }

    func testNearestNestedBinding_beatsOuterBinding() {
        register("HOST", isDefault: true)
        let outerOwner = register("OUTER")
        let innerOwner = register("INNER")
        let controller = HostVC()
        show(controller)
        let outer = addLeaf(to: controller.view)
        let inner = addLeaf(to: outer.container)

        outerOwner.attachToView(outer.container)
        innerOwner.attachToView(inner.container)

        assertResolves([inner.label, inner.container], to: innerOwner)
        assertResolves([outer.label, outer.container], to: outerOwner)
    }

    func testExpiredBinding_blocksFallbackToTheDefault() {
        let host = register("HOST", isDefault: true)
        let controller = HostVC()
        show(controller)
        let bound = addLeaf(to: controller.view)
        weak var releasedVendor: MockUserpilot?
        autoreleasepool {
            let vendor = register("VENDOR", retained: false)
            vendor.attachToView(bound.container)
            releasedVendor = vendor
            assertResolves([bound.label], to: vendor)
        }
        XCTAssertNil(releasedVendor, "Precondition: the binding's owner is gone")

        assertResolves([bound.label, bound.container], to: nil, "A removed owner's UI must not fall to the default")
        assertResolves([addLeaf(to: controller.view).label, controller], to: host)
    }

    func testBindingOfAnUnregisteredOwner_blocksFallbackToTheDefault() {
        let host = register("HOST", isDefault: true)
        let vendor = register("VENDOR")
        let controller = HostVC()
        let bound = addLeaf(to: controller.view)
        vendor.attachToView(bound.container)

        registry.unregister(vendor)

        assertResolves([bound.label], to: nil)
        assertResolves([controller], to: host)
    }

    // MARK: - Detach

    func testDetachingOwnBinding_restoresScopeAndDefaultRouting() {
        let host = register("HOST", isDefault: true)
        let vendor = register("VENDOR") { $0.attach(viewControllerClasses: [TenantAVC.self]) }
        let partner = register("PARTNER")
        let claimed = TenantAVC()
        let bound = addLeaf(to: claimed.view)
        let boundController = HostVC()
        partner.attachToView(bound.container)
        partner.attachToViewController(boundController)
        assertResolves([bound.label, boundController], to: partner, "Precondition: bindings are active")

        partner.detachFromView(bound.container)
        partner.detachFromViewController(boundController)

        assertResolves([bound.label], to: vendor)
        assertResolves([boundController], to: host)
    }

    func testAnotherLiveInstance_cannotDetachABinding() {
        let host = register("HOST", isDefault: true)
        let vendor = register("VENDOR")
        let controller = HostVC()
        let bound = addLeaf(to: controller.view)
        let boundController = TenantBVC()
        vendor.attachToView(bound.container)
        vendor.attachToViewController(boundController)

        host.detachFromView(bound.container)
        host.detachFromViewController(boundController)

        assertResolves([bound.label, boundController], to: vendor)
    }

    func testAnyInstance_canDetachAnExpiredBinding() {
        let host = register("HOST", isDefault: true)
        let controller = HostVC()
        let bound = addLeaf(to: controller.view)
        let boundController = TenantBVC()
        weak var releasedVendor: MockUserpilot?
        autoreleasepool {
            let vendor = register("VENDOR", retained: false)
            vendor.attachToView(bound.container)
            vendor.attachToViewController(boundController)
            releasedVendor = vendor
        }
        XCTAssertNil(releasedVendor, "Precondition: the binding's owner is gone")
        assertResolves([bound.label, boundController], to: nil, "Precondition: the expired binding blocks fallback")

        host.detachFromView(bound.container)
        host.detachFromViewController(boundController)

        assertResolves([bound.label, boundController], to: host)
    }

    // MARK: - Fast path

    func testWithoutBindingsOrClaims_resolutionSkipsTheResponderWalkAndMatchesTheFullPath() {
        startWithoutAttachments()
        let host = register("HOST", isDefault: true)
        let vendor = register("VENDOR")
        let hostScreen = HostVC()
        let window = show(hostScreen)
        let vendorPanel = TenantAVC()
        embed(vendorPanel, in: hostScreen)
        let probe = ResponderCountingView()
        vendorPanel.view.addSubview(probe)
        let sources: [UIResponder?] = [probe, vendorPanel, addLeaf(to: hostScreen.view).label, hostScreen, window, nil]

        XCTAssertFalse(resolver.sourceAffectsOwner)
        assertResolves(sources, to: host)
        XCTAssertEqual(probe.nextReads, 0, "Without bindings or claims the per-event responder walk is skipped")

        // A claim that matches nothing here forces the full walk, which must reach the same owner.
        vendor.config.attach(viewControllerClasses: [TenantBVC.self])
        XCTAssertTrue(resolver.sourceAffectsOwner)
        assertResolves(sources, to: host)
        XCTAssertGreaterThan(probe.nextReads, 0, "Precondition: the full path walked the responder chain")
    }

    func testWithoutBindings_aConfiguredClaimStillRoutesAwayFromTheDefault() {
        startWithoutAttachments()
        let host = register("HOST", isDefault: true)
        let hostScreen = HostVC()
        show(hostScreen)
        let vendorPanel = TenantAVC()
        embed(vendorPanel, in: hostScreen)
        let probe = ResponderCountingView()
        vendorPanel.view.addSubview(probe)

        autoreleasepool {
            let vendor = register("VENDOR", retained: false) { $0.attach(viewControllerClasses: [TenantAVC.self]) }
            XCTAssertTrue(resolver.sourceAffectsOwner)
            assertResolves([probe, vendorPanel], to: vendor)
        }

        // Releasing the only claimant returns every source to the default through the fast path.
        let readsWhileClaimed = probe.nextReads
        XCTAssertFalse(resolver.sourceAffectsOwner)
        assertResolves([probe, vendorPanel], to: host)
        XCTAssertEqual(probe.nextReads, readsWhileClaimed)
    }

    func testFirstBinding_switchesResolutionToTheFullPath() {
        startWithoutAttachments()
        let host = register("HOST", isDefault: true)
        let partner = register("PARTNER")
        XCTAssertFalse(resolver.sourceAffectsOwner)
        let controller = HostVC()
        let bound = addLeaf(to: controller.view)

        partner.attachToView(bound.container)

        XCTAssertTrue(resolver.sourceAffectsOwner, "Touches must resolve from the innermost view once UI is bound")
        assertResolves([bound.label], to: partner)
        assertResolves([controller], to: host)
    }
}
