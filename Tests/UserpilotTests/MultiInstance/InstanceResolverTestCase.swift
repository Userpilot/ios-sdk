//
//  InstanceResolverTestCase.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Shared fixtures for resolver tests: an isolated real registry and resolver, real windows,
//  controller containment and view hierarchies. No routing logic is reimplemented here.
//

import XCTest
@testable import Userpilot

class TenantAVC: UIViewController {}
final class TenantASubclassVC: TenantAVC {}
final class TenantBVC: UIViewController {}
final class HostVC: UIViewController {}
/// Its class name marks it as a SwiftUI hosting wrapper, so scope lookup continues at its parent.
final class WrapperHostingControllerStub: UIViewController {}

/// Counts responder-chain reads so a test can prove that resolution skipped the walk.
final class ResponderCountingView: UIView {
    private(set) var nextReads = 0

    override var next: UIResponder? {
        nextReads += 1
        return super.next
    }
}

class InstanceResolverTestCase: XCTestCase {

    var registry: InstanceRegistry!
    var resolver: InstanceResolver!
    private var windows: [UIWindow] = []
    /// The registry holds instances weakly, as production does; fixtures live until tearDown.
    private var liveInstances: [MockUserpilot] = []
    private var hadAttachments = false

    override func setUp() {
        super.setUp()
        hadAttachments = UserpilotOwnerBinding.hasAttachments.value
        registry = InstanceRegistry()
        resolver = InstanceResolver(registry: registry)
    }

    override func tearDown() {
        windows.forEach { $0.isHidden = true }
        windows = []
        liveInstances = []
        resolver = nil
        registry = nil
        // Production never clears the flag; only fast-path tests clear it for their own scenario.
        if hadAttachments { UserpilotOwnerBinding.hasAttachments.value = true }
        super.tearDown()
    }

    /// Registers a real instance in this test's registry. Tokens are unique per call, so same-token
    /// adoption in the process runtime never merges two fixtures. Pass `retained: false` when the
    /// test itself controls when the instance is released.
    @discardableResult
    func register(
        _ name: String,
        isDefault: Bool = false,
        retained: Bool = true,
        configure: (Userpilot.Config) -> Void = { _ in }
    ) -> MockUserpilot {
        let config = Userpilot.Config(token: "\(name)-\(UUID().uuidString)").defaultInstance(isDefault)
        configure(config)
        let instance = MockUserpilot(config: config)
        registry.register(instance)
        if retained { liveInstances.append(instance) }
        return instance
    }

    /// Displays `root` in a visible window, as an app would.
    @discardableResult
    func show(_ root: UIViewController, in window: UIWindow? = nil) -> UIWindow {
        let window = window ?? makeWindow()
        window.rootViewController = root
        window.isHidden = false
        return window
    }

    func makeWindow() -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        windows.append(window)
        return window
    }

    func embed(_ child: UIViewController, in parent: UIViewController) {
        parent.addChild(child)
        parent.view.addSubview(child.view)
        child.didMove(toParent: parent)
    }

    /// Adds a container with a label to `view`; the label is the innermost source a touch reports.
    func addLeaf(to view: UIView) -> (container: UIView, label: UILabel) {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        let label = UILabel(frame: container.bounds)
        container.addSubview(label)
        view.addSubview(container)
        return (container, label)
    }

    /// Clears the process-wide attachment flag so only this test's claims decide the path.
    func startWithoutAttachments() {
        UserpilotOwnerBinding.hasAttachments.value = false
    }

    func assertResolves(
        _ sources: [UIResponder?],
        to expected: Userpilot?,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (index, source) in sources.enumerated() {
            let resolved = resolver.resolveOwner(from: source)
            XCTAssertTrue(
                resolved === expected,
                "source[\(index)] \(source.map { String(describing: type(of: $0)) } ?? "nil") resolved to "
                    + "\(resolved?.config.token ?? "nil"), expected \(expected?.config.token ?? "nil"). \(message)",
                file: file,
                line: line
            )
        }
    }
}
