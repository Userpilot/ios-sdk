//
//  ScreenHierarchyTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies containment snapshots and additive wrapper screen metadata.
//

import SwiftUI
import UIKit
import XCTest
@testable import Userpilot

final class ScreenHierarchyTests: XCTestCase {
    func testLiveStackDropsPoppedScreensAndKeepsRepeatedClasses() {
        let main = HierarchyMainController()
        let posts = HierarchyPostsController()
        let profile = HierarchyProfileController()
        let settings = HierarchySettingsController()
        let navigation = UINavigationController(rootViewController: main)
        XCTAssertEqual(main.captureScreenHierarchy(), ["HierarchyMainController"])
        navigation.pushViewController(posts, animated: false)
        let postsSnapshot = posts.captureScreenHierarchy()
        XCTAssertEqual(postsSnapshot, ["HierarchyMainController", "HierarchyPostsController"])
        navigation.popViewController(animated: false)
        navigation.pushViewController(profile, animated: false)
        navigation.pushViewController(settings, animated: false)
        XCTAssertEqual(settings.captureScreenHierarchy(), [
            "HierarchyMainController", "HierarchyProfileController", "HierarchySettingsController"
        ])
        XCTAssertEqual(postsSnapshot, ["HierarchyMainController", "HierarchyPostsController"])
        XCTAssertNil(profile.captureScreenHierarchy())
        let secondSettings = HierarchySettingsController()
        navigation.pushViewController(secondSettings, animated: false)
        XCTAssertEqual(secondSettings.captureScreenHierarchy()?.suffix(2), [
            "HierarchySettingsController", "HierarchySettingsController"
        ])
    }

    func testUnknownSwiftUIAndOversizedStacksAreOmitted() {
        XCTAssertNil(UIViewController().captureScreenHierarchy())
        let hosted = UIHostingController(rootView: Text("Screen"))
        let navigation = UINavigationController(rootViewController: hosted)
        XCTAssertNil(hosted.captureScreenHierarchy())
        let controllers = (0..<65).map { _ in UIViewController() }
        navigation.setViewControllers(controllers, animated: false)
        XCTAssertNil(controllers.last?.captureScreenHierarchy())
    }

    func testInvalidWrapperStackIsOmittedEntirely() {
        for hierarchy in [["Main", " ", "Settings"], Array(repeating: "Page", count: 65), []] {
            let payload = ScreenTrackingPayload(screenTitle: "Settings", screenHierarchy: hierarchy)
            XCTAssertNil(payload.toWrapperScreenProperties()["screen_hierarchy"])
        }
    }

    func testNavigationCapturesAncestorsWithoutEarlierStackEntries() {
        let cart = UIViewController()
        let detail = HierarchyDetailController()
        let navigation = UINavigationController(rootViewController: cart)
        let tabs = UITabBarController()
        tabs.viewControllers = [navigation, UIViewController()]
        navigation.pushViewController(detail, animated: false)

        let captured = detail.captureScreenContainerHierarchy()
        XCTAssertEqual(captured, ["UITabBarController", "UINavigationController", "HierarchyDetailController"])
        navigation.popViewController(animated: false)
        XCTAssertEqual(cart.captureScreenContainerHierarchy(), [
            "UITabBarController", "UINavigationController", "UIViewController"
        ])
        XCTAssertEqual(captured?.last, "HierarchyDetailController")
    }

    func testModalTraversesOwnContainerBeforePresentingAncestors() {
        let presenter = UIViewController()
        let tabs = UITabBarController()
        tabs.viewControllers = [presenter]
        let modal = HierarchyModalController()
        modal.presenter = presenter
        let child = HierarchyDetailController()
        modal.addChild(child)

        XCTAssertEqual(child.captureScreenContainerHierarchy(), [
            "UITabBarController", "UIViewController", "HierarchyModalController", "HierarchyDetailController"
        ])
    }

    func testRepeatedContainerClassesAreRetainedAndCyclesAreOmitted() {
        let outer = HierarchyModalController()
        let inner = HierarchyModalController()
        outer.addChild(inner)
        XCTAssertEqual(inner.captureScreenContainerHierarchy(), [
            "HierarchyModalController", "HierarchyModalController"
        ])
        outer.presenter = inner
        XCTAssertNil(inner.captureScreenContainerHierarchy())
        outer.presenter = nil
    }

    func testWrapperHierarchyIsOptionalAndPreservedThroughOfflineEncoding() throws {
        let owner = MockUserpilot(config: Userpilot.Config(token: "HIERARCHY-\(UUID().uuidString)")
            .additionalProperties([WrapperSDKConstants.pluginType: WrapperSDKConstants.pluginTypeFlutter])
            .defaultInstance(false))
        let coordinator = AutoCaptureCoordinater(container: owner.container)
        var events: [Event] = []
        owner.analyticsPublisher.onPublish = { events.append($0) }
        coordinator.trackExternalAutoCaptureScreen("Cart")
        var hierarchy = ["Root", "Checkout", "Cart"]
        coordinator.trackExternalAutoCaptureScreen("Cart", screenHierarchy: hierarchy)
        hierarchy.removeLast()

        XCTAssertNil(events.first?.properties?["screen_hierarchy"])
        let event = try XCTUnwrap(events.last)
        XCTAssertEqual(event.screenTitle, "Cart")
        XCTAssertEqual(event.properties?["screen_hierarchy"] as? [String], ["Root", "Checkout", "Cart"])
        XCTAssertNil(event.properties?["screen_class"])
        let decoded = try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(event))
        XCTAssertEqual(decoded.properties?["screen_hierarchy"] as? [String], ["Root", "Checkout", "Cart"])
    }

    func testIdentifyRefreshRetainsCapturedHierarchyWithoutAddingLegacyFields() {
        let owner = MockUserpilot(config: Userpilot.Config(token: "HIERARCHY-\(UUID().uuidString)")
            .defaultInstance(false))
        let publisher = AnalyticsPublisher(container: owner.container)
        owner.storage.userId = "user-1"
        owner.socketManager.isSocketOpened = true
        owner.experiencesPublisher.updateScreen("Settings")
        let tracker = owner.container.resolve(ScreenNameTracking.self)
        var payload = ScreenTrackingPayload(screenTitle: "Settings", screenHierarchy: ["Main", "Settings"])
        payload.screenContainerHierarchy = ["UINavigationController", "Settings"]
        tracker.updateScreen(with: payload)
        var screens: [Payload] = []
        owner.socketManager.onPublish = { name, data in
            if name == Constants.Event.screenEvent { screens.append(data) }
        }

        publisher.publish(Event(type: .identify("user-1")))
        publisher.onSocketEventSent(Constants.Event.identifyEvent, nil, Message(), true)

        XCTAssertEqual(screens.count, 1)
        let metadata = screens.first??[Constants.Analytics.metaDataProperty] as? [String: Any]
        XCTAssertEqual(metadata?["screen_hierarchy"] as? [String], ["Main", "Settings"])
        XCTAssertEqual(metadata?["screen_container_hierarchy"] as? [String], ["UINavigationController", "Settings"])
        XCTAssertNil(metadata?["screen_class"])
    }

    func testNativePayloadAddsHierarchyOnlyToScreenMetadata() {
        let controller = HierarchyDetailController()
        let navigation = UINavigationController(rootViewController: controller)
        var payload = ScreenTrackingPayload(screenTitle: controller.screenClassName)
        payload.screenContainerHierarchy = controller.captureScreenContainerHierarchy()
        payload.screenHierarchy = controller.captureScreenHierarchy()
        XCTAssertEqual(payload.toDictionary()["screen_container_hierarchy"] as? [String], [
            "UINavigationController", "HierarchyDetailController"
        ])
        let tracker = ScreenNameTracker(container: DIContainer())
        tracker.updateScreen(with: payload)
        XCTAssertNil(tracker.buildScreenDictionaryForEvent()["screen_hierarchy"])
        XCTAssertEqual(payload.screenClass, "HierarchyDetailController")
        withExtendedLifetime(navigation) {}
    }
}

private final class HierarchyDetailController: UIViewController {}

private final class HierarchyModalController: UIViewController {
    weak var presenter: UIViewController?
    override var presentingViewController: UIViewController? { presenter }
}

private final class HierarchyMainController: UIViewController {}
private final class HierarchyPostsController: UIViewController {}
private final class HierarchyProfileController: UIViewController {}
private final class HierarchySettingsController: UIViewController {}
