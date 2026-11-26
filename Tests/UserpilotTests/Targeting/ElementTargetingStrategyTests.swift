//
//  ElementTargetingStrategyTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies strategy isolation and logical wrapper ownership, geometry and capture encoding.
//

import XCTest
@testable import Userpilot

final class ElementTargetingStrategyTests: InstanceResolverTestCase {
    func testLogicalElementUsesOwnBoundsAndNativeHostOwnership() throws {
        let strategy = TestElementTargetingStrategy()
        let owner = register("wrapper", isDefault: true) { $0.elementTargetingStrategy(strategy) }
        let window = show(UIViewController())
        strategy.node = logicalNode(in: window)
        let targeting = makeTargeting(owner, strategy: strategy)
        let host = try XCTUnwrap(targeting.admitHost(in: window))
        let payload = Data(#"{"properties":{"wrapper_id":"checkout","unset":null}}"#.utf8)
        let selector = try JSONDecoder().decode(ElementSelector.self, from: payload)

        let target = try targeting.resolve(selector: selector, in: host).get()

        XCTAssertNil(target.view, "A logical element must not borrow its host's geometry")
        XCTAssertEqual(target.rect, strategy.node?.bounds)
        XCTAssertEqual(strategy.inflatedProperties, [["wrapper_id": "checkout"]])
        XCTAssertTrue(strategy.capturedRoot === window)
    }

    func testCustomStrategyDoesNotReplaceAnotherInstancesStrategy() throws {
        let strategy = TestElementTargetingStrategy()
        let wrapper = register("wrapper") { $0.elementTargetingStrategy(strategy) }
        let native = register("native", isDefault: true)
        let wrapperStrategy = wrapper.container.resolve(UserpilotElementTargetingStrategy.self)
        let nativeStrategy = native.container.resolve(UserpilotElementTargetingStrategy.self)

        XCTAssertTrue(wrapperStrategy === strategy)
        XCTAssertTrue(nativeStrategy is NativeElementTargetingStrategy)
        XCTAssertNil(nativeStrategy.inflateSelector(from: ["wrapper_id": "checkout"]))
        XCTAssertNotNil(wrapperStrategy.inflateSelector(from: ["wrapper_id": "checkout"]))
    }

    func testLogicalElementCannotMatchForeignOwnershipSurface() throws {
        let owner = register("owner", isDefault: true)
        let foreign = register("foreign")
        let controller = UIViewController()
        let window = show(controller)
        let source = UIView(frame: CGRect(x: 10, y: 10, width: 150, height: 100))
        controller.view.addSubview(source)
        source.attachUserpilotOwner(foreign)
        let strategy = TestElementTargetingStrategy()
        strategy.node = logicalNode(in: source)
        let targeting = makeTargeting(owner, strategy: strategy)
        let host = try XCTUnwrap(targeting.admitHost(in: window))

        guard case .failure(.notFound) = targeting.resolve(
            selector: ElementSelector(properties: ["wrapper_id": "checkout"]), in: host
        ) else { return XCTFail("Foreign wrapper content must not be targeted") }
        XCTAssertNotNil(targeting.captureLayout(in: host), "Builder still captures the full admitted host")
    }

    func testWrapperElementCountsOnlyWithASizeAndItsMiddleOnTheVisibleScreen() throws {
        let strategy = TestElementTargetingStrategy()
        let owner = register("wrapper", isDefault: true) { $0.elementTargetingStrategy(strategy) }
        let window = show(UIViewController())
        let targeting = makeTargeting(owner, strategy: strategy)
        let host = try XCTUnwrap(targeting.admitHost(in: window))
        let selector = ElementSelector(properties: ["wrapper_id": "checkout"])

        // Only the top 10 pt of a 30 pt element is visible, so its middle is clipped.
        strategy.node = logicalNode(in: window, visible: CGRect(x: 40, y: 100, width: 80, height: 10))
        guard case .failure(.notFound) = targeting.resolve(selector: selector, in: host) else {
            return XCTFail("A wrapper element whose middle is clipped is not there yet")
        }
        strategy.node = logicalNode(in: window, frame: CGRect(x: 40, y: 100, width: 0, height: 0))
        guard case .failure(.notFound) = targeting.resolve(selector: selector, in: host) else {
            return XCTFail("A zero-size wrapper element is not found")
        }
        strategy.node = logicalNode(in: window, visible: CGRect(x: 40, y: 100, width: 80, height: 20))
        XCTAssertNoThrow(try targeting.resolve(selector: selector, in: host).get(), "cut edge, visible middle")
        XCTAssertEqual(strategy.captureCalls, 3, "The strategy's layout is read once per search")
    }

    func testClippedDuplicateDoesNotMakeTheVisibleMatchAmbiguous() throws {
        let strategy = TestElementTargetingStrategy()
        let owner = register("wrapper", isDefault: true) { $0.elementTargetingStrategy(strategy) }
        let window = show(UIViewController())
        let visible = logicalNode(in: window)
        let clipped = logicalNode(in: window, visible: CGRect(x: 40, y: 100, width: 80, height: 5))
        strategy.node = ElementNode(nodeID: "root", nativeType: "WrapperRoot", displayName: nil,
                                    bounds: window.bounds, visibleBounds: window.bounds, selector: nil,
                                    children: [clipped, visible], ownershipView: window)
        let targeting = makeTargeting(owner, strategy: strategy)
        let host = try XCTUnwrap(targeting.admitHost(in: window))

        let target = try targeting.resolve(
            selector: ElementSelector(properties: ["wrapper_id": "checkout"]), in: host
        ).get()
        XCTAssertEqual(target.rect, visible.visibleBounds)
    }

    func testTransparentHostMakesItsElementsNotVisible() throws {
        let strategy = TestElementTargetingStrategy()
        let owner = register("wrapper", isDefault: true) { $0.elementTargetingStrategy(strategy) }
        let controller = UIViewController()
        let window = show(controller)
        let host = UIView(frame: window.bounds)
        controller.view.addSubview(host)
        strategy.node = logicalNode(in: host)
        let targeting = makeTargeting(owner, strategy: strategy)
        let admitted = try XCTUnwrap(targeting.admitHost(in: window))

        host.alpha = 0
        guard case .failure(.notVisible(matchCount: 1)) = targeting.resolve(
            selector: ElementSelector(properties: ["wrapper_id": "checkout"]), in: admitted
        ) else { return XCTFail("An element in a transparent WebView or Flutter view cannot be seen") }
    }

    func testTransparentWebElementOnTheVisibleScreenIsNotVisible() throws {
        let strategy = TestElementTargetingStrategy()
        let owner = register("wrapper", isDefault: true) { $0.elementTargetingStrategy(strategy) }
        let window = show(UIViewController())
        let node = logicalNode(in: window)
        node.isTransparent = true
        strategy.node = node
        let targeting = makeTargeting(owner, strategy: strategy)
        let host = try XCTUnwrap(targeting.admitHost(in: window))

        guard case .failure(.notVisible(matchCount: 1)) = targeting.resolve(
            selector: ElementSelector(properties: ["wrapper_id": "checkout"]), in: host
        ) else { return XCTFail("A transparent web element must report notVisible") }
    }

    func testScreenEndAsksTheStrategyFirstAndThenTheNativeScrollState() throws {
        let strategy = TestElementTargetingStrategy()
        let owner = register("wrapper", isDefault: true) { $0.elementTargetingStrategy(strategy) }
        let window = show(UIViewController())
        let targeting = makeTargeting(owner, strategy: strategy)
        let host = try XCTUnwrap(targeting.admitHost(in: window))

        strategy.scrolledToEnd = false
        XCTAssertEqual(targeting.isScreenAtEnd(in: host), false)
        // Nothing on this screen scrolls, so native detection answers at end.
        strategy.scrolledToEnd = nil
        XCTAssertEqual(targeting.isScreenAtEnd(in: host), true)
    }

    func testCaptureSerializationPreservesCustomSelectorAndOmitsOwnership() throws {
        var source: UIView? = UIView()
        let node = logicalNode(in: try XCTUnwrap(source))
        let encoded = try JSONEncoder().encode(node)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        XCTAssertEqual(json["selector"] as? [String: String], ["wrapper_id": "checkout"])
        XCTAssertNil(json["view"])
        XCTAssertNil(json["ownershipView"])
        source = nil
        XCTAssertNil(node.ownershipView, "The capture must not retain its wrapper host")
    }

    private func logicalNode(
        in source: UIView, value: String = "checkout", frame: CGRect = CGRect(x: 40, y: 100, width: 80, height: 30),
        visible: CGRect? = nil
    ) -> ElementNode {
        ElementNode(nodeID: "logical", nativeType: "WrapperButton", displayName: nil,
                    bounds: frame, visibleBounds: visible ?? frame,
                    selector: TestElementSelector(value: value), children: [], ownershipView: source)
    }

    private func makeTargeting(
        _ owner: Userpilot, strategy: UserpilotElementTargetingStrategy
    ) -> ElementResolver {
        let container = DIContainer()
        container.owner = owner
        container.register(Userpilot.Config.self, value: owner.config)
        container.register(InstanceRegistering.self, value: registry)
        container.register(InstanceResolving.self, value: resolver)
        container.register(UserpilotElementTargetingStrategy.self, value: strategy)
        return ElementResolver(container: container)
    }
}

final class TestElementSelector: UserpilotElementSelector {
    let value: String
    init(value: String) { self.value = value }
    func toMap() -> [String: String] { ["wrapper_id": value] }
    func evaluateMatch(_ target: UserpilotElementSelector) -> Int {
        toMap() == target.toMap() ? 10_000 : 0
    }
}

final class TestElementTargetingStrategy: UserpilotElementTargetingStrategy {
    var node: ElementNode?
    var scrolledToEnd: Bool?
    private(set) var captureCalls = 0
    weak var capturedRoot: UIView?
    var inflatedProperties: [[String: String]] = []
    var screenshot: UserpilotScreenshot?
    weak var capturedWindow: UIWindow?

    func captureLayout(in rootView: UIView, completion: @escaping (ElementNode?) -> Void) {
        capturedRoot = rootView
        captureCalls += 1
        completion(node)
    }
    func inflateSelector(from properties: [String: String]) -> UserpilotElementSelector? {
        inflatedProperties.append(properties)
        return properties["wrapper_id"].map { TestElementSelector(value: $0) }
    }
    func captureScreenshot(in window: UIWindow) -> UserpilotScreenshot? {
        capturedWindow = window
        return screenshot
    }
    func isScrolledToEnd(in rootView: UIView, completion: @escaping (NSNumber?) -> Void) {
        completion(scrolledToEnd.map { NSNumber(value: $0) })
    }
}

extension ElementTargeting {
    func captureLayout(in host: ElementTargetHost) -> ElementNode? {
        var finished = false
        var tree: ElementNode?
        captureLayout(in: host) { tree = $0; finished = true }
        XCTAssertTrue(finished, "This fixture must be a native inline capture")
        return tree
    }

    func resolve(
        selector: ElementSelector, in host: ElementTargetHost
    ) -> Result<ResolvedTarget, TargetResolutionError> {
        var result: Result<ResolvedTarget, TargetResolutionError>?
        resolve(selector: selector, in: host) { result = $0 }
        XCTAssertNotNil(result, "Use the completion API for asynchronous WebView fixtures")
        return result ?? .failure(.layoutUnavailable)
    }

    func isScreenAtEnd(in host: ElementTargetHost) -> Bool? {
        var answer: Bool?
        isScreenAtEnd(in: host) { answer = $0 }
        return answer
    }
}
