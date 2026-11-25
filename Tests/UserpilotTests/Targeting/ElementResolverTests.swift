//
//  ElementResolverTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Host identity, nested ownership and autocapture-independent targeting regressions.
//

import XCTest
@testable import Userpilot

final class ElementResolverTests: InstanceResolverTestCase {
    private let selector = ElementSelector(properties: SelectorProperties(accessibilityIdentifier: "target").toMap())

    func testResolve_keepsAdmittedWindowWhenAnotherWindowHasSameIdentifier() throws {
        let owner = register("owner", isDefault: true)
        let first = makeTargetWindow()
        let second = makeTargetWindow()
        let targeting = makeTargeting(owner)
        let host = try XCTUnwrap(targeting.admitHost(in: first.window))
        second.window.makeKey()

        let target = try targeting.resolve(selector: selector, in: host).get()

        XCTAssertTrue(target.view === first.target)
        XCTAssertFalse(target.view === second.target)
    }

    func testResolve_childOwnerUnderForeignRootFiltersOnlyCandidates() throws {
        let rootOwner = register("root", isDefault: true)
        let childOwner = register("child")
        let fixture = makeTargetWindow()
        fixture.window.attachUserpilotOwner(rootOwner)
        fixture.target.attachUserpilotOwner(childOwner)
        let root = try XCTUnwrap(fixture.window.rootViewController)
        let sibling = addTarget(to: root.view)
        let targeting = makeTargeting(childOwner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))

        let target = try targeting.resolve(selector: selector, in: host).get()
        let fullTree = try XCTUnwrap(targeting.captureLayout(in: host))

        XCTAssertTrue(target.view === fixture.target)
        XCTAssertEqual(fullTree.matches(for: try XCTUnwrap(targeting.inflateSelector(from: selector))).count, 2)
        XCTAssertFalse(target.view === sibling)
    }

    func testResolve_removedOwnerCannotFallBackToDefault() throws {
        register("default", isDefault: true)
        let owner = register("removed")
        let fixture = makeTargetWindow()
        fixture.target.attachUserpilotOwner(owner)
        let targeting = makeTargeting(owner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))
        registry.unregister(owner)

        XCTAssertFalse(targeting.isValid(host))
        XCTAssertNil(targeting.captureLayout(in: host))
        assertLayoutUnavailable(targeting.resolve(selector: selector, in: host))
    }

    func testResolve_reboundCandidateDoesNotSwitchOwner() throws {
        let owner = register("owner", isDefault: true)
        let replacement = register("replacement")
        let fixture = makeTargetWindow()
        let targeting = makeTargeting(owner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))
        fixture.target.attachUserpilotOwner(replacement)

        guard case .failure(.notFound) = targeting.resolve(selector: selector, in: host) else {
            return XCTFail("A rebound candidate must not resolve for its previous owner")
        }
    }

    func testCapture_lastBindingTransferredInvalidatesAdmittedHost() throws {
        let rootOwner = register("root", isDefault: true)
        let childOwner = register("child")
        let fixture = makeTargetWindow()
        fixture.target.attachUserpilotOwner(childOwner)
        let targeting = makeTargeting(childOwner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))
        fixture.target.attachUserpilotOwner(rootOwner)

        XCTAssertFalse(targeting.isValid(host))
        XCTAssertNil(targeting.captureLayout(in: host))
        assertLayoutUnavailable(targeting.resolve(selector: selector, in: host))
    }

    func testResolve_hiddenOwnedChildRetainsHostForLaterRecovery() throws {
        register("root", isDefault: true)
        let childOwner = register("child")
        let fixture = makeTargetWindow()
        fixture.target.attachUserpilotOwner(childOwner)
        let targeting = makeTargeting(childOwner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))
        fixture.target.isHidden = true

        XCTAssertTrue(targeting.isValid(host))
        guard case .failure(.notFound) = targeting.resolve(selector: selector, in: host) else {
            return XCTFail("A hidden target is not found, and recoverable")
        }
        fixture.target.isHidden = false
        XCTAssertTrue(try targeting.resolve(selector: selector, in: host).get().view === fixture.target)
    }

    func testResolve_transparentAncestorIsNotVisibleWhileHiddenAncestorOrZeroSizeIsNotFound() throws {
        let owner = register("owner", isDefault: true)
        let fixture = makeTargetWindow()
        let container = try XCTUnwrap(fixture.target.superview)
        let targeting = makeTargeting(owner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))

        container.alpha = 0.005
        assertNotVisible(targeting.resolve(selector: selector, in: host), "transparent ancestor")
        container.alpha = 1

        container.isHidden = true
        assertNotFound(targeting.resolve(selector: selector, in: host), "hidden ancestor")
        container.isHidden = false

        fixture.target.frame.size = .zero
        assertNotFound(targeting.resolve(selector: selector, in: host), "zero size")
    }

    func testResolve_hiddenDuplicateDoesNotReplaceVisibleMatch() throws {
        let owner = register("owner", isDefault: true)
        let fixture = makeTargetWindow()
        let root = try XCTUnwrap(fixture.window.rootViewController)
        addTarget(to: root.view).isHidden = true
        let targeting = makeTargeting(owner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))

        XCTAssertTrue(try targeting.resolve(selector: selector, in: host).get().view === fixture.target)
    }

    func testResolve_offScreenTargetIsNotFound() throws {
        let owner = register("owner", isDefault: true)
        let fixture = makeTargetWindow()
        let targeting = makeTargeting(owner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))
        fixture.target.frame.origin.y = 5_000

        assertNotFound(targeting.resolve(selector: selector, in: host), "off screen")
    }

    func testResolve_clippedCentreIsNotFoundAndACutEdgeWithAVisibleMiddleResolves() throws {
        let owner = register("owner", isDefault: true)
        let fixture = makeTargetWindow()
        let clip = UIView(frame: CGRect(x: 0, y: 200, width: 300, height: 100))
        clip.clipsToBounds = true
        fixture.target.superview?.addSubview(clip)
        clip.addSubview(fixture.target)
        let targeting = makeTargeting(owner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))

        fixture.target.frame.origin.y = 150
        assertNotFound(targeting.resolve(selector: selector, in: host), "clipped centre")
        fixture.target.frame.origin.y = 70
        XCTAssertTrue(try targeting.resolve(selector: selector, in: host).get().view === fixture.target,
                      "A partly clipped target with a visible centre still resolves")
    }

    func testResolve_onlyAnOpaqueCoverOverTheCentreReportsOverlapped() throws {
        let owner = register("owner", isDefault: true)
        let fixture = makeTargetWindow()
        let cover = UIView(frame: fixture.target.frame)
        cover.backgroundColor = .white
        fixture.target.superview?.addSubview(cover)
        let targeting = makeTargeting(owner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))

        guard case .failure(.overlapped(matchCount: 1)) = targeting.resolve(selector: selector, in: host) else {
            return XCTFail("An opaque view over the centre must report overlapped")
        }
        cover.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        XCTAssertNoThrow(try targeting.resolve(selector: selector, in: host).get(), "translucent cover")
        cover.backgroundColor = .white
        cover.frame.size.width = 10
        XCTAssertNoThrow(try targeting.resolve(selector: selector, in: host).get(), "edge-only cover")
        cover.frame = fixture.target.frame
        cover.superview?.insertSubview(cover, belowSubview: fixture.target)
        XCTAssertNoThrow(try targeting.resolve(selector: selector, in: host).get(), "view drawn below")
    }

    func testResolve_absentTargetStaysNotFound() throws {
        let owner = register("owner", isDefault: true)
        let fixture = makeTargetWindow()
        fixture.target.accessibilityIdentifier = "other"
        let targeting = makeTargeting(owner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))

        guard case .failure(.notFound) = targeting.resolve(selector: selector, in: host) else {
            return XCTFail("A selector with no candidate anywhere must report notFound")
        }
    }

    func testCaptureAndResolve_workWhenAutocaptureIsDisabledAndStopped() throws {
        let owner = register("disabled", isDefault: true) {
            $0.enableScreenAutoCapture = false
            $0.enableInteractionAutoCapture = false
        }
        owner.stopAutoCapture()
        let fixture = makeTargetWindow()
        let targeting = makeTargeting(owner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))

        XCTAssertTrue(targeting.isValid(host), "A newly admitted legacy window must remain valid")
        XCTAssertTrue(try targeting.resolve(selector: selector, in: host).get().view === fixture.target)
        let tree = try XCTUnwrap(targeting.captureLayout(in: host))
        XCTAssertEqual(tree.matches(for: try XCTUnwrap(targeting.inflateSelector(from: selector))).count, 1)
        let identity = try XCTUnwrap(targeting.inflateSelector(from: selector))
        XCTAssertEqual(tree.matches(for: identity).first?.node.bounds, fixture.target.frame)
    }

    func testCapture_replacedRootInvalidatesHostWithoutSelectingAnotherWindow() throws {
        let owner = register("owner", isDefault: true)
        let fixture = makeTargetWindow()
        let targeting = makeTargeting(owner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))
        fixture.window.rootViewController = UIViewController()
        _ = makeTargetWindow()

        XCTAssertFalse(targeting.isValid(host))
        assertLayoutUnavailable(targeting.resolve(selector: selector, in: host))
    }

    private func makeTargeting(_ owner: Userpilot, instanceResolver: InstanceResolving? = nil) -> ElementResolver {
        let container = DIContainer()
        container.owner = owner
        container.register(Userpilot.Config.self, value: owner.config)
        container.register(InstanceRegistering.self, value: registry)
        container.register(InstanceResolving.self, value: instanceResolver ?? resolver)
        container.register(UserpilotElementTargetingStrategy.self, value: NativeElementTargetingStrategy())
        return ElementResolver(container: container)
    }

    private func makeTargetWindow() -> (window: UIWindow, target: UIView) {
        let controller = UIViewController()
        let window = show(controller)
        controller.view.frame = window.bounds
        let target = addTarget(to: controller.view)
        window.layoutIfNeeded()
        return (window, target)
    }

    private func addTarget(to parent: UIView) -> UIView {
        let target = UIView(frame: CGRect(x: 20, y: 80, width: 100, height: 40))
        target.accessibilityIdentifier = "target"
        parent.addSubview(target)
        return target
    }

    private func assertLayoutUnavailable(
        _ result: Result<ResolvedTarget, TargetResolutionError>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(.layoutUnavailable) = result else {
            return XCTFail("An invalid host must report layoutUnavailable", file: file, line: line)
        }
    }

    private func assertNotFound(
        _ result: Result<ResolvedTarget, TargetResolutionError>,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(.notFound) = result else {
            return XCTFail("Expected notFound for \(message), got \(result)", file: file, line: line)
        }
    }

    private func assertNotVisible(
        _ result: Result<ResolvedTarget, TargetResolutionError>,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(.notVisible(matchCount: 1)) = result else {
            return XCTFail("Expected notVisible for \(message), got \(result)", file: file, line: line)
        }
    }
}

// MARK: - Ownership Reuse

extension ElementResolverTests {

    func testResolve_multiInstanceReusesOwnershipInsteadOfWalkingTheWindowPerCheck() throws {
        register("root", isDefault: true)
        let childOwner = register("child")
        let fixture = makeTargetWindow()
        let root = try XCTUnwrap(fixture.window.rootViewController)
        for _ in 0..<200 {
            root.view.insertSubview(UIView(frame: .zero), at: 0)
        }
        fixture.target.attachUserpilotOwner(childOwner)
        let counting = CountingInstanceResolver(resolver)
        let targeting = makeTargeting(childOwner, instanceResolver: counting)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))
        counting.reads = 0

        XCTAssertTrue(try targeting.resolve(selector: selector, in: host).get().view === fixture.target)
        XCTAssertLessThan(counting.reads, 20, "each host check must reuse the owned view, not walk 200 views")
    }

    func testValidate_ownedViewRemovedFromWindowIsNotReused() throws {
        register("root", isDefault: true)
        let childOwner = register("child")
        let fixture = makeTargetWindow()
        fixture.target.attachUserpilotOwner(childOwner)
        let targeting = makeTargeting(childOwner)
        let host = try XCTUnwrap(targeting.admitHost(in: fixture.window))

        fixture.target.removeFromSuperview()

        XCTAssertFalse(targeting.isValid(host), "a detached view keeps its binding but no longer owns the window")
    }
}

/// Counts ownership lookups on the real resolver.
private final class CountingInstanceResolver: InstanceResolving {
    private let base: InstanceResolving
    var reads = 0

    init(_ base: InstanceResolving) {
        self.base = base
    }

    var sourceAffectsOwner: Bool { base.sourceAffectsOwner }

    func resolveOwner(from responder: UIResponder?) -> Userpilot? {
        reads += 1
        return base.resolveOwner(from: responder)
    }
}
