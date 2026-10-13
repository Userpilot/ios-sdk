//
//  InstanceResolverTests.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Routes real UIKit sources through configured scopes (VC class > window > bundle) and the
//  explicit default. Bindings, detach and the no-claim fast path live in InstanceResolverBindingTests.
//

import XCTest
@testable import Userpilot

final class InstanceResolverTests: InstanceResolverTestCase {

    // MARK: - Default routing

    func testDefaultOnly_resolvesEverySourceToTheDefault() {
        startWithoutAttachments()
        let host = register("HOST", isDefault: true)
        let controller = HostVC()
        let window = show(controller)
        let sources: [UIResponder?] = [addLeaf(to: controller.view).label, controller, window, nil, UIView()]

        assertResolves(sources, to: host, "fast path")
        // After any binding exists in the process, the same sources take the full walk.
        UserpilotOwnerBinding.hasAttachments.value = true
        assertResolves(sources, to: host, "full path")
    }

    func testTarget_whenNoInstanceClaimsAndNoDefault_returnsNil() {
        // Instances exist, but none claimed the default role or this UI: no registration-order fallback.
        register("VENDOR-A")
        register("VENDOR-B") { $0.attach(viewControllerClasses: [TenantAVC.self]) }
        let controller = HostVC()
        let window = show(controller)

        assertResolves([UIView(), addLeaf(to: controller.view).label, controller, window, nil], to: nil)
    }

    // MARK: - VC-class scope

    func testTarget_byViewControllerClass_returnsClaimingInstance() {
        register("HOST", isDefault: true)
        let vendor = register("VENDOR") { $0.attach(viewControllerClasses: [TenantAVC.self]) }

        assertResolves([TenantAVC()], to: vendor)
    }

    func testTarget_byViewControllerSubclass_returnsClaimingInstance() {
        register("HOST", isDefault: true)
        let vendor = register("VENDOR") { $0.attach(viewControllerClasses: [TenantAVC.self]) }

        assertResolves([TenantASubclassVC()], to: vendor, "Subclasses of attached classes resolve to the claimant")
    }

    func testTarget_unattachedViewController_returnsDefault() {
        let host = register("HOST", isDefault: true)
        register("VENDOR") { $0.attach(viewControllerClasses: [TenantAVC.self]) }

        assertResolves([HostVC()], to: host, "Unscoped VCs must fall back to the registered default instance")
    }

    func testTarget_forSourceView_walksResponderChainToOwningVC() {
        register("HOST", isDefault: true)
        let vendor = register("VENDOR") { $0.attach(viewControllerClasses: [TenantAVC.self]) }
        let controller = TenantAVC()
        let leaf = addLeaf(to: controller.view)

        assertResolves([leaf.label, leaf.container, controller.view], to: vendor)
    }

    func testEmbeddedVendorController_ownsOnlyItsSubtree() {
        let host = register("HOST", isDefault: true)
        let vendor = register("VENDOR") { $0.attach(viewControllerClasses: [TenantAVC.self]) }
        let hostScreen = HostVC()
        let window = show(hostScreen)
        let vendorPanel = TenantAVC()
        embed(vendorPanel, in: hostScreen)

        assertResolves([addLeaf(to: vendorPanel.view).label, vendorPanel], to: vendor)
        assertResolves([addLeaf(to: hostScreen.view).label, hostScreen, window], to: host)
    }

    func testTarget_swiftUIHostingControllerWalksOutward() {
        register("HOST", isDefault: true)
        let vendor = register("VENDOR") { $0.attach(viewControllerClasses: [TenantAVC.self]) }
        let outer = TenantAVC()
        let inner = WrapperHostingControllerStub()
        embed(inner, in: outer)

        assertResolves([inner, addLeaf(to: inner.view).label], to: vendor,
                       "Generic hosting/wrapper VCs must defer scope resolution to the parent VC")
    }

    func testTarget_forNilSource_returnsDefault() {
        let host = register("HOST", isDefault: true)
        register("VENDOR") { $0.attach(viewControllerClasses: [TenantAVC.self]) }

        assertResolves([nil], to: host)
    }

    // MARK: - Window and bundle scope

    func testTarget_byWindow_resolvesToOwningInstance() {
        let host = register("HOST", isDefault: true)
        let vendorWindow = makeWindow()
        let vendor = register("VENDOR") { $0.attach(windows: [vendorWindow]) }
        let vendorRoot = HostVC()
        show(vendorRoot, in: vendorWindow)
        let hostRoot = HostVC()
        let hostWindow = show(hostRoot)

        assertResolves([vendorWindow, vendorRoot, addLeaf(to: vendorRoot.view).label], to: vendor)
        assertResolves([hostWindow, hostRoot, addLeaf(to: hostRoot.view).label], to: host)
    }

    func testBundleClaim_ownsControllersDeclaredInThatBundle() throws {
        let host = register("HOST", isDefault: true)
        let testBundle = Bundle(for: TenantBVC.self)
        XCTAssertFalse(try XCTUnwrap(testBundle.bundleIdentifier).isEmpty, "Precondition: a claimable bundle")
        let vendor = register("VENDOR") { $0.attach(bundles: [testBundle]) }
        let claimedController = TenantBVC()
        let unclaimedController = UIViewController()

        assertResolves([claimedController, addLeaf(to: claimedController.view).label], to: vendor)
        assertResolves([unclaimedController, addLeaf(to: unclaimedController.view).label], to: host,
                       "A UIKit-declared controller is outside the claimed bundle")
    }

    func testScopePrecedence_classBeatsWindowBeatsBundle_regardlessOfRegistrationOrder() {
        let claimedWindow = makeWindow()
        // Least specific registers first, so registration order alone would pick the wrong owner.
        let bundleOwner = register("BUNDLE") { $0.attach(bundles: [Bundle(for: HostVC.self)]) }
        let windowOwner = register("WINDOW") { $0.attach(windows: [claimedWindow]) }
        let classOwner = register("CLASS") { $0.attach(viewControllerClasses: [TenantAVC.self]) }
        let classClaimed = TenantAVC()
        show(classClaimed, in: claimedWindow)
        let windowClaimed = HostVC()
        embed(windowClaimed, in: classClaimed)

        assertResolves([classClaimed], to: classOwner)
        assertResolves([windowClaimed], to: windowOwner)
        assertResolves([HostVC()], to: bundleOwner)
    }

    // MARK: - Non-default instances

    func testSoleNonDefaultInstance_ownsOnlyItsClaimedUI() {
        let vendor = register("VENDOR") { $0.attach(viewControllerClasses: [TenantAVC.self]) }
        let hostScreen = HostVC()
        let window = show(hostScreen)
        let vendorPanel = TenantAVC()
        embed(vendorPanel, in: hostScreen)

        assertResolves([addLeaf(to: vendorPanel.view).label, vendorPanel], to: vendor)
        assertResolves([addLeaf(to: hostScreen.view).label, hostScreen, window, nil], to: nil,
                       "Being the only instance never makes a non-default instance the fallback")
    }

    func testSoleNonDefaultInstanceWithoutClaims_ownsNothing() {
        startWithoutAttachments()
        register("VENDOR")
        let controller = HostVC()
        let window = show(controller)

        assertResolves([addLeaf(to: controller.view).label, controller, window, nil], to: nil)
    }

    // MARK: - Injected registry

    func testResolvesOnlyFromItsInjectedRegistry() {
        // Instances also register in the process runtime; this resolver must ignore that registry.
        let processOnlyClaimant = MockUserpilot.make(
            config: Userpilot.Config(token: "PROCESS-\(UUID().uuidString)")
                .defaultInstance(false)
                .attach(viewControllerClasses: [TenantBVC.self])
        )
        let host = register("HOST", isDefault: true)
        let vendor = register("VENDOR") { $0.attach(viewControllerClasses: [TenantAVC.self]) }

        assertResolves([TenantAVC()], to: vendor)
        assertResolves([TenantBVC(), HostVC()], to: host)
        XCTAssertTrue(UserpilotRuntime.shared.instanceRegistry.isRegistered(processOnlyClaimant))
    }
}
