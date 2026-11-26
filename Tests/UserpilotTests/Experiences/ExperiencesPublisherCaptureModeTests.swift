//
//  ExperiencesPublisherCaptureModeTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies Builder capture mode blocks every instance's experiences without touching analytics' busy gate.
//

import XCTest
@testable import Userpilot

final class ExperiencesPublisherCaptureModeTests: XCTestCase {

    /// One SDK instance with a real publisher, a mock presentation host and a manual display delay.
    private struct Instance {
        let userpilot: MockUserpilot
        let publisher: ExperiencesPublisher
        let host: MockExperiencePresentationHost
        let delay: MockExperienceDisplayDelay
    }

    private var instances: [Instance] = []
    private var publishedEvents: [SDKEvent] = []
    /// Another instance's coordinator, as the owner of the process-wide capture mode.
    private let captureOwner = MockBuilderCaptureCoordinator()

    override func setUp() {
        super.setUp()
        BuilderCaptureMode.reset()
        let main = makeInstance()
        main.userpilot.analyticsPublisher.onPublishInternalSDKEvent = { [weak self] in
            self?.publishedEvents.append($0)
        }
    }

    override func tearDown() {
        BuilderCaptureMode.reset()
        for instance in instances {
            instance.publisher.logout()
            settle(instance.publisher)
        }
        instances.removeAll()
        publishedEvents.removeAll()
        super.tearDown()
    }

    private var main: Instance { instances[0] }

    func testSocketScreenAndTrackContentIsDroppedInEveryInstance() {
        makeInstance()
        BuilderCaptureMode.begin(captureOwner)

        for instance in instances {
            receiveScreen(on: instance.publisher)
            var track = MockContentFactory.makeFlowContentPayload()
            track["request_id"] = NSNull()
            instance.publisher.onNewMessage(Message(payload: ["payload": track]))
            instance.publisher.mockWaitForQueue()

            XCTAssertFalse(instance.delay.hasAction)
            XCTAssertTrue(instance.publisher.canRequestScreenEvent())
        }
    }

    func testTriggerExperienceAndPreviewsAreDropped() {
        var previewRequests = 0
        main.userpilot.remoteSource.onFetchPreviewExperience = { _, _ in previewRequests += 1 }
        BuilderCaptureMode.begin(captureOwner)

        main.publisher.triggerExperience("flow-a")
        main.publisher.triggerPreviewExperience("preview-a", [URLQueryItem(name: "type", value: "flow")])
        settle(main.publisher)

        XCTAssertTrue(main.userpilot.analyticsPublisher.requests.isEmpty)
        XCTAssertEqual(previewRequests, 0)
        XCTAssertTrue(main.publisher.canRequestScreenEvent())
    }

    func testOperationInItsDisplayDelayAtStartIsNeverPresented() throws {
        receiveScreen(on: main.publisher)
        XCTAssertTrue(main.delay.hasAction)

        BuilderCaptureMode.begin(captureOwner)
        try main.delay.fire()
        settle(main.publisher)

        XCTAssertNil(main.host.presentedExperience)
        XCTAssertNil(main.publisher.activeRendererID)
        XCTAssertTrue(main.publisher.canRequestScreenEvent(), "The dropped operation released admission")
        XCTAssertTrue(publishedEvents.isEmpty, "No renderer, so no seen event")
    }

    func testRepeatScreenEventsAreStillAllowed() {
        BuilderCaptureMode.begin(captureOwner)

        XCTAssertTrue(main.publisher.canRequestScreenEvent())
    }

    func testNextScreenEventAfterCaptureModeEndsAdmitsContent() {
        BuilderCaptureMode.begin(captureOwner)
        receiveScreen(on: main.publisher)
        XCTAssertFalse(main.delay.hasAction)

        BuilderCaptureMode.end(captureOwner)
        receiveScreen(on: main.publisher)

        XCTAssertTrue(main.delay.hasAction, "Nothing is replayed; the next screen reply is admitted")
    }

    func testFlagSetOnMainIsReadOffMain() {
        BuilderCaptureMode.begin(captureOwner)
        let publisher = main.publisher
        let read = expectation(description: "read off main")
        var observed = false
        DispatchQueue.global().async {
            observed = BuilderCaptureMode.isActive
            publisher.onSocketEventSent(Constants.Event.screenEvent,
                                        [Constants.Analytics.screenTitleProperty: "Home"],
                                        Message(payload: MockContentFactory.makeFlowContentPayload()), true)
            read.fulfill()
        }
        wait(for: [read], timeout: 2)
        settle(publisher)

        XCTAssertTrue(observed)
        XCTAssertFalse(main.delay.hasAction)
    }

    // MARK: - Helpers

    @discardableResult
    private func makeInstance() -> Instance {
        let userpilot = MockUserpilot.make(
            config: Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false))
        // Keep presentation on the mock host so no overlay window or animation enters these tests.
        userpilot.container.owner = nil
        userpilot.container.register(LifecycleMonitoring.self, value: LifecycleMonitor(
            notificationCenter: NotificationCenter(), applicationState: { .inactive }
        ))
        userpilot.themeHandler.onGetThemeById = { _ in ThemeData(carousel: nil, slideOut: nil, survey: nil) }
        let publisher = ExperiencesPublisher(container: userpilot.container)
        userpilot.container.register(ExperiencesPublishing.self, value: publisher)
        let host = MockExperiencePresentationHost()
        publisher.topViewControllerProvider = { [weak host] in host }
        let delay = MockExperienceDisplayDelay()
        publisher.mockSetDelayUtils(delay)
        publisher.updateScreen("Home")
        publisher.mockWaitForQueue()
        let instance = Instance(userpilot: userpilot, publisher: publisher, host: host, delay: delay)
        instances.append(instance)
        return instance
    }

    private func receiveScreen(on publisher: ExperiencesPublisher) {
        publisher.onSocketEventSent(Constants.Event.screenEvent,
                                    [Constants.Analytics.screenTitleProperty: "Home"],
                                    Message(payload: MockContentFactory.makeFlowContentPayload()), true)
        publisher.mockWaitForQueue()
    }

    /// Drain both ownership boundaries without advancing the injected display delay or using sleeps.
    private func settle(_ publisher: ExperiencesPublisher) {
        publisher.mockWaitForQueue()
        let drained = expectation(description: "main callbacks processed")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
        publisher.mockWaitForQueue()
    }
}
