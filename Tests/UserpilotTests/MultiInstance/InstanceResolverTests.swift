//
//  InstanceResolverTests.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

/// Custom view-controller subclasses used to exercise the resolver's VC-class scope rules.
private class TenantAVC: UIViewController {}
private class TenantASubclassVC: TenantAVC {}
private class TenantBVC: UIViewController {}
private class HostVC: UIViewController {}
private class WrapperHostingControllerStub: UIViewController {} // pretend SwiftUI hosting

final class InstanceResolverTests: XCTestCase {

    private var hostInstance: MockUserpilot!
    private var vendorInstance: MockUserpilot!

    override func setUpWithError() throws {
        Userpilot.Registry.shared.resetForTesting()

        // Host app's default instance — claims nothing explicitly so it acts as
        // the catch-all owner for unscoped UI.
        hostInstance = MockUserpilot(config: Userpilot.Config(token: "HOST-TOKEN"))

        // Vendor SDK's secondary instance — claims a custom VC class so events
        // originating from `TenantAVC` (or its subclasses) attribute to it.
        let vendorConfig = Userpilot.Config(token: "VENDOR-TOKEN")
            .attach(viewControllerClasses: [TenantAVC.self])
        vendorInstance = MockUserpilot(config: vendorConfig)
    }

    override func tearDownWithError() throws {
        hostInstance = nil
        vendorInstance = nil
        Userpilot.Registry.shared.resetForTesting()
    }

    // MARK: - VC-class match

    func testTarget_byViewControllerClass_returnsClaimingInstance() throws {
        let vc = TenantAVC()
        let resolved = InstanceResolver.shared.target(forViewController: vc)
        XCTAssertTrue(resolved === vendorInstance)
    }

    func testTarget_byViewControllerSubclass_returnsClaimingInstance() throws {
        let vc = TenantASubclassVC()
        let resolved = InstanceResolver.shared.target(forViewController: vc)
        XCTAssertTrue(resolved === vendorInstance, "Subclasses of attached classes must also resolve to the claiming instance")
    }

    func testTarget_unattachedViewController_returnsDefault() throws {
        let vc = HostVC()
        let resolved = InstanceResolver.shared.target(forViewController: vc)
        XCTAssertTrue(resolved === hostInstance, "Unscoped VCs must fall back to the registered default instance")
    }

    // MARK: - Window match

    func testTarget_byWindow_resolvesToOwningInstance() throws {
        let window = UIWindow(frame: .zero)
        // Re-register vendor with a window scope.
        Userpilot.Registry.shared.resetForTesting()
        let host = MockUserpilot(config: Userpilot.Config(token: "HOST"))
        let vendorConfig = Userpilot.Config(token: "VENDOR").attach(windows: [window])
        let vendor = MockUserpilot(config: vendorConfig)

        // Window-level autocapture hooks resolve from the window object itself.
        let vc = HostVC()
        window.rootViewController = vc
        let resolved = InstanceResolver.shared.target(forSource: window)
        XCTAssertTrue(resolved === vendor)

        _ = host
        _ = vendor
        _ = window
    }

    // MARK: - Source resolution via responder chain

    func testTarget_forSourceView_walksResponderChainToOwningVC() throws {
        let vc = TenantAVC()
        let view = UIView()
        vc.view.addSubview(view)
        // `view` is now in TenantAVC's view tree → its responder chain reaches TenantAVC.

        let resolved = InstanceResolver.shared.target(forSource: view)
        XCTAssertTrue(resolved === vendorInstance)
    }

    func testTarget_forNilSource_returnsDefault() throws {
        let resolved = InstanceResolver.shared.target(forSource: nil)
        XCTAssertTrue(resolved === hostInstance)
    }

    // MARK: - SwiftUI-style outward walk

    func testTarget_swiftUIHostingControllerWalksOutward() throws {
        // Outer VC is owned by vendor.
        let outer = TenantAVC()
        // Inner VC's class name contains "HostingController" → resolver walks outward
        // through it to the parent and matches the claimed class on the parent.
        let inner = WrapperHostingControllerStub()
        outer.addChild(inner)
        outer.view.addSubview(inner.view)
        inner.didMove(toParent: outer)

        let resolved = InstanceResolver.shared.target(forViewController: inner)
        XCTAssertTrue(
            resolved === vendorInstance,
            "Generic hosting/wrapper VCs must defer scope resolution to the parent VC"
        )
    }

    // MARK: - Default fallback

    func testTarget_whenNoInstanceClaimsAndNoDefault_returnsNil() throws {
        // Reset registry so there is no default at all.
        Userpilot.Registry.shared.resetForTesting()

        let resolved = InstanceResolver.shared.target(forSource: UIView())
        XCTAssertNil(resolved)
    }

    // MARK: - Injected registry seam

    func testTarget_resolvesThroughInjectedRegistry() throws {
        // A resolver built with a substitute registry resolves entirely from it —
        // proving consumers no longer depend on `Registry.shared`.
        let fake = FakeInstanceRegistry()
        let host = MockUserpilot(config: Userpilot.Config(token: "FAKE-HOST"))
        let vendor = MockUserpilot(
            config: Userpilot.Config(token: "FAKE-VENDOR").attach(viewControllerClasses: [TenantBVC.self])
        )
        fake.instances = [host, vendor]
        fake.defaultInstance = host

        let resolver = InstanceResolver(registry: fake)

        // Class match resolves to the vendor via the injected registry.
        XCTAssertTrue(resolver.target(forViewController: TenantBVC()) === vendor)
        // Unscoped VC falls back to the injected default.
        XCTAssertTrue(resolver.target(forViewController: HostVC()) === host)

        _ = host
        _ = vendor
    }
}

// swiftlint:enable all
