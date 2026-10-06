//
//  InteractionEventCacheTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class InteractionEventCacheTests: XCTestCase {

    private var userpilot: MockUserpilot!

    override func setUp() {
        super.setUp()
        Userpilot.Registry.shared.resetForTesting()
        InteractionEventCache.cancelAll()
        userpilot = MockUserpilot(
            config: Userpilot.Config(token: "NX-\(UUID().uuidString)")
                .enableInteractionAutoCapture()
                .appFramework(.UIKit)
        )
    }

    override func tearDown() {
        InteractionEventCache.cancelAll()
        userpilot = nil
        Userpilot.Registry.shared.resetForTesting()
        super.tearDown()
    }

    func testDebouncedInteractionPublishesLatestPayloadForSameView() {
        let view = UIView()
        var publishedEvents: [Event] = []
        let expectation = XCTestExpectation(description: "debounced interaction published")

        userpilot.analyticsPublisher.onPublish = { event in
            publishedEvents.append(event)
            expectation.fulfill()
        }

        InteractionEventCache.sendDebouncedInteraction(
            textPayload(length: 1, targetClass: "FirstTextField"),
            for: view,
            textLengthForDedupe: 1
        )
        InteractionEventCache.sendDebouncedInteraction(
            textPayload(length: 2, targetClass: "LatestTextField"),
            for: view,
            textLengthForDedupe: 2
        )

        wait(for: [expectation], timeout: Constants.AutoCapture.interactionDebounceInterval + 0.5)

        XCTAssertEqual(publishedEvents.count, 1)
        XCTAssertEqual(publishedEvents.first?.interactionEventName, InteractionEventType.textChange.rawValue)
        XCTAssertEqual(
            publishedEvents.first?.properties?[Constants.AutoCapture.targetClass] as? String,
            "LatestTextField"
        )
        XCTAssertEqual(publishedEvents.first?.properties?[Constants.AutoCapture.textLength] as? Int, 2)
    }

    func testDeliveredTextLengthIsDeduplicatedUntilCacheIsFlushed() {
        let view = UIView()
        var publishedEvents: [Event] = []
        let firstDelivery = XCTestExpectation(description: "first text interaction published")

        userpilot.analyticsPublisher.onPublish = { event in
            publishedEvents.append(event)
            firstDelivery.fulfill()
        }

        InteractionEventCache.sendDebouncedInteraction(
            textPayload(length: 3),
            for: view,
            textLengthForDedupe: 3
        )

        wait(for: [firstDelivery], timeout: Constants.AutoCapture.interactionDebounceInterval + 0.5)
        XCTAssertEqual(publishedEvents.count, 1)

        let duplicateDelivery = XCTestExpectation(description: "duplicate text length should not publish")
        duplicateDelivery.isInverted = true
        userpilot.analyticsPublisher.onPublish = { _ in
            duplicateDelivery.fulfill()
        }

        InteractionEventCache.sendDebouncedInteraction(
            textPayload(length: 3),
            for: view,
            textLengthForDedupe: 3
        )

        wait(for: [duplicateDelivery], timeout: Constants.AutoCapture.interactionDebounceInterval + 0.2)

        InteractionEventCache.cancelAll()

        let afterFlushDelivery = XCTestExpectation(description: "same text length publishes after cache flush")
        userpilot.analyticsPublisher.onPublish = { event in
            publishedEvents.append(event)
            afterFlushDelivery.fulfill()
        }

        InteractionEventCache.sendDebouncedInteraction(
            textPayload(length: 3),
            for: view,
            textLengthForDedupe: 3
        )

        wait(for: [afterFlushDelivery], timeout: Constants.AutoCapture.interactionDebounceInterval + 0.5)
        XCTAssertEqual(publishedEvents.count, 2)
    }

    func testFlushAllCancelsPendingInteractionDelivery() {
        let view = UIView()
        let expectation = XCTestExpectation(description: "pending interaction should be cancelled")
        expectation.isInverted = true

        userpilot.analyticsPublisher.onPublish = { _ in
            expectation.fulfill()
        }

        InteractionEventCache.sendDebouncedInteraction(
            textPayload(length: 4),
            for: view,
            textLengthForDedupe: 4
        )
        InteractionEventCache.cancelAll()

        wait(for: [expectation], timeout: Constants.AutoCapture.interactionDebounceInterval + 0.2)
    }

    private func textPayload(length: Int, targetClass: String = "UITextField") -> InteractionPayload {
        var payload = InteractionPayload(interactionType: .textFieldChanged, elementType: targetClass)
        payload.sourceProperties = [Constants.AutoCapture.textLength: length]
        return payload
    }

    func testFlushPendingPublishesInlineAndRetainsDeliveredDeduplication() {
        let view = UIView()
        var lengths: [Int] = []
        userpilot.analyticsPublisher.onPublish = { event in
            if let length = event.properties?[Constants.AutoCapture.textLength] as? Int { lengths.append(length) }
        }

        InteractionEventCache.sendDebouncedInteraction(textPayload(length: 3), for: view, textLengthForDedupe: 3)
        InteractionEventCache.flushPendingInteractions()
        XCTAssertEqual(lengths, [3])

        InteractionEventCache.sendDebouncedInteraction(textPayload(length: 3), for: view, textLengthForDedupe: 3)
        InteractionEventCache.flushPendingInteractions()
        XCTAssertEqual(lengths, [3])

        InteractionEventCache.cancelAll()
        InteractionEventCache.sendDebouncedInteraction(textPayload(length: 3), for: view, textLengthForDedupe: 3)
        InteractionEventCache.flushPendingInteractions()
        XCTAssertEqual(lengths, [3, 3])
    }

    func testPendingInteractionDoesNotRetainItsSource() {
        var view: UIView? = UIView()
        weak var source = view
        let pending = PendingInteraction(
            payload: textPayload(length: 1), textLengthForDedupe: 1, debounceKey: "test", source: view
        )

        view = nil

        XCTAssertNil(source)
        XCTAssertNil(pending.source)
    }
}
