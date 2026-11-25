//
//  ScreenClassIdentityTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Exercises screen identity through the real analytics and experience owners,
//  with controlled transport acknowledgments and presentation scheduling.
//

import XCTest
@testable import Userpilot

final class ScreenClassIdentityTests: XCTestCase {
    private var owner: MockUserpilot!
    private var analytics: AnalyticsPublisher!
    private var experiences: ExperiencesPublisher!
    private var delay: MockExperienceDisplayDelay!

    override func tearDown() {
        experiences?.logout()
        experiences?.mockWaitForQueue()
        analytics = nil
        experiences = nil
        owner = nil
        delay = nil
        super.tearDown()
    }

    private func configure(enabled: Bool = true) {
        let config = Userpilot.Config(token: "SCREEN-CLASS-\(UUID().uuidString)")
            .defaultInstance(false).enableScreenAutoCapture().appFramework(.SwiftUI)
        if enabled { config.enableScreenClassIdentity() }
        owner = MockUserpilot.make(config: config)
        owner.container.owner = nil
        owner.socketManager.isSocketOpened = true
        owner.themeHandler.onGetThemeById = { _ in ThemeData(carousel: nil, slideOut: nil, survey: nil) }
        analytics = AnalyticsPublisher(container: owner.container)
        owner.container.register(AnalyticsPublishing.self, value: analytics!)
        experiences = ExperiencesPublisher(container: owner.container)
        owner.container.register(ExperiencesPublishing.self, value: experiences!)
        delay = MockExperienceDisplayDelay()
        experiences.mockSetDelayUtils(delay)
    }

    private func screen(_ screenClass: String, name: String = "Detail") -> Event {
        Event(type: .screen(name), properties: [
            "screen_name": name,
            "screen_class": "UIHostingController<\(screenClass)>",
            "screen_source": "auto",
            "ui_framework": "SwiftUI"
        ])
    }

    private func publish(_ event: Event) {
        analytics.testPublish(event)
        experiences.mockWaitForQueue()
    }

    private func acknowledgeScreen(response: [String: Any] = [:]) {
        owner.socketManager.completeNext(Constants.Event.screenEvent, nil, Message(payload: response), true)
        analytics.testSettle()
        experiences.mockWaitForQueue()
    }

    func testDefaultModePreservesSameNameThrottleAcrossDifferentClasses() {
        configure(enabled: false)
        XCTAssertFalse(owner.config.enableScreenClassIdentity)
        publish(screen("Cart"))
        publish(screen("SaveCard"))
        XCTAssertEqual(owner.socketManager.requests.count, 1)
        XCTAssertNil(experiences.currentScreenEvent?.screenVisitID)
        XCTAssertEqual(analytics.screenSessionStateMachine?.event.nativeSwiftUIScreenClass, "UIHostingController<Cart>")
    }

    func testDifferentClassesSendImmediatelyAndStartSeparateVisitsWithoutNewWireFields() throws {
        configure()
        publish(screen("Cart"))
        let first = try XCTUnwrap(owner.socketManager.requests.last?.payload)
        let firstVisit = try XCTUnwrap(experiences.currentScreenEvent?.screenVisitID)
        acknowledgeScreen()
        analytics.experiencePublished(.flow, 77)
        publish(screen("SaveCard"))
        let second = try XCTUnwrap(owner.socketManager.requests.last?.payload)
        XCTAssertEqual(second["title"] as? String, "Detail")
        XCTAssertEqual(Set(first.keys), Set(second.keys))
        let firstMetadata = try XCTUnwrap(first["metadata"] as? [String: Any])
        let secondMetadata = try XCTUnwrap(second["metadata"] as? [String: Any])
        XCTAssertEqual(Set(firstMetadata.keys), Set(secondMetadata.keys))
        XCTAssertEqual(secondMetadata["screen_class"] as? String, "UIHostingController<SaveCard>")
        XCTAssertEqual(secondMetadata["seen_contents"] as? [Int], [])
        XCTAssertNotEqual(firstVisit, experiences.currentScreenEvent?.screenVisitID)
        XCTAssertEqual(analytics.screenSessionStateMachine?.seenExperiences, [])
    }

    func testSameClassRepeatIsThrottledAndRetainsVisitAndSeenContent() throws {
        configure()
        publish(screen("Cart"))
        let visit = try XCTUnwrap(experiences.currentScreenEvent?.screenVisitID)
        acknowledgeScreen()
        analytics.experiencePublished(.flow, 77)
        publish(screen("Cart"))
        XCTAssertTrue(owner.socketManager.requests.isEmpty)
        XCTAssertEqual(experiences.currentScreenEvent?.screenVisitID, visit)
        XCTAssertEqual(analytics.screenSessionStateMachine?.seenExperiences, [77])
    }

    func testGeneratedReloadPreservesClassAndVisitButNavigationClearsSeenContent() throws {
        configure()
        publish(screen("Cart"))
        let visit = experiences.currentScreenEvent?.screenVisitID
        acknowledgeScreen()
        analytics.experiencePublished(.flow, 77)
        XCTAssertTrue(analytics.publishFakeReloadScreenEvent(isFakeReload: true))
        analytics.testSettle()
        let metadata = try XCTUnwrap(owner.socketManager.requests.last?.payload?["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["screen_class"] as? String, "UIHostingController<Cart>")
        XCTAssertEqual(metadata["fake_reload"] as? Bool, true)
        XCTAssertEqual(metadata["seen_contents"] as? [Int], [77])
        XCTAssertEqual(experiences.currentScreenEvent?.screenVisitID, visit)
        acknowledgeScreen()
        publish(screen("SaveCard"))
        XCTAssertEqual(analytics.screenSessionStateMachine?.seenExperiences, [])
        XCTAssertEqual(owner.socketManager.requests.count, 1)
    }

    func testScreenCapturedBeforeIdentifyRetainsMetadataInGeneratedScreen() throws {
        configure()
        owner.storage.userId = ""
        publish(screen("Cart"))
        XCTAssertTrue(owner.socketManager.requests.isEmpty)
        publish(Event(type: .identify("first-user")))
        owner.socketManager.completeNext(Constants.Event.identifyEvent)
        analytics.testSettle()
        let payload = try XCTUnwrap(owner.socketManager.requests.last?.payload)
        let metadata = try XCTUnwrap(payload["metadata"] as? [String: Any])
        XCTAssertEqual(payload["title"] as? String, "Detail")
        XCTAssertEqual(metadata["screen_class"] as? String, "UIHostingController<Cart>")
        XCTAssertEqual(metadata["is_session_start"] as? Bool, true)
        XCTAssertEqual(metadata["fake_reload"] as? Bool, false)
        XCTAssertNotNil(analytics.screenSessionStateMachine?.event.screenVisitID)
    }

    func testLateResponseCannotShowAfterSameNameClassChangeAndReturn() throws {
        configure()
        publish(screen("Cart"))
        let old = try XCTUnwrap(owner.socketManager.requests.first)
        let oldVisit = experiences.currentScreenEvent?.screenVisitID
        publish(screen("SaveCard"))
        publish(screen("Cart"))
        XCTAssertNotEqual(oldVisit, experiences.currentScreenEvent?.screenVisitID)
        old.completion?(Message(payload: MockContentFactory.makeFlowContentPayload()), true)
        analytics.testSettle()
        experiences.mockWaitForQueue()
        XCTAssertNil(experiences.activeExperience)
        XCTAssertFalse(delay.hasAction)
    }

    func testCurrentResponseSchedulesContentAndClassChangeCancelsPreparation() {
        configure()
        publish(screen("Cart"))
        acknowledgeScreen(response: MockContentFactory.makeFlowContentPayload())
        XCTAssertTrue(delay.hasAction)
        XCTAssertFalse(experiences.canRequestScreenEvent())
        publish(screen("SaveCard"))
        XCTAssertFalse(delay.hasAction)
        XCTAssertNil(experiences.activeExperience)
    }

    func testManualAndMissingClassScreensKeepNameBasedIdentity() {
        configure()
        publish(Event(type: .screen("Manual")))
        publish(Event(type: .screen("Manual")))
        XCTAssertEqual(owner.socketManager.requests.count, 1)
        XCTAssertNil(experiences.currentScreenEvent?.screenVisitID)
        acknowledgeScreen()
        publish(Event(type: .screen("Missing"), properties: ["screen_source": "auto", "ui_framework": "SwiftUI"]))
        publish(Event(type: .screen("Missing"), properties: ["screen_source": "auto", "ui_framework": "SwiftUI"]))
        XCTAssertEqual(owner.socketManager.requests.count, 1)
        XCTAssertNil(experiences.currentScreenEvent?.screenVisitID)
    }

    func testOfflineRoundTripPreservesClassButNeverPersistsVisitID() throws {
        configure()
        publish(screen("Cart"))
        let event = try XCTUnwrap(experiences.currentScreenEvent)
        XCTAssertNotNil(event.screenVisitID)
        let encoded = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(Event.self, from: encoded)
        XCTAssertEqual(decoded.screenIdentityKey(classAware: true), event.screenIdentityKey(classAware: true))
        XCTAssertEqual(decoded.nativeSwiftUIScreenClass, event.nativeSwiftUIScreenClass)
        XCTAssertNil(decoded.screenVisitID)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(json["screenVisitID"])
        XCTAssertNil(json["screen_identity"])
    }
}
