//
//  InteractionEventCacheTests.swift
//  Userpilot SDK
//
//  Debounced text and slider capture through each owner's real coordinator debouncer,
//  observed at the owner's analytics publication boundary.
//

import XCTest
@testable import Userpilot

final class InteractionEventCacheTests: XCTestCase {

    private var userpilot: MockUserpilot!

    /// Delivered lengths live on each field, so every test starts from fresh fields with no history.
    private let length = 12

    private var debounceTimeout: TimeInterval { Constants.AutoCapture.interactionDebounceInterval + 0.5 }

    override func setUp() {
        super.setUp()
        userpilot = makeOwner()
    }

    override func tearDown() {
        userpilot = nil
        super.tearDown()
    }

    // MARK: - Debounce and delivery

    func testDebouncedInteractionPublishesLatestPayloadForSameView() {
        let view = UITextField()
        var publishedEvents: [Event] = []
        let expectation = XCTestExpectation(description: "debounced interaction published")
        userpilot.analyticsPublisher.onPublish = { event in
            publishedEvents.append(event)
            expectation.fulfill()
        }

        send(length, targetClass: "FirstTextField", for: view, owner: userpilot)
        send(length + 1, targetClass: "LatestTextField", for: view, owner: userpilot)

        wait(for: [expectation], timeout: debounceTimeout)

        XCTAssertEqual(publishedEvents.count, 1)
        XCTAssertEqual(publishedEvents.first?.interactionEventName, InteractionEventType.textChange.rawValue)
        XCTAssertEqual(
            publishedEvents.first?.properties?[Constants.AutoCapture.targetClass] as? String,
            "LatestTextField"
        )
        XCTAssertEqual(publishedEvents.first?.properties?[Constants.AutoCapture.textLength] as? Int, length + 1)
    }

    func testDeliveredTextLengthIsDeduplicatedUntilAnotherLengthIsDelivered() {
        let view = UITextField()
        let published = record(userpilot)
        let firstDelivery = XCTestExpectation(description: "first text interaction published")
        published.onPublish = { firstDelivery.fulfill() }

        send(length, for: view, owner: userpilot)
        wait(for: [firstDelivery], timeout: debounceTimeout)
        XCTAssertEqual(published.textLengths, [length])

        let duplicateDelivery = XCTestExpectation(description: "duplicate text length should not publish")
        duplicateDelivery.isInverted = true
        published.onPublish = { duplicateDelivery.fulfill() }
        send(length, for: view, owner: userpilot)
        wait(for: [duplicateDelivery], timeout: Constants.AutoCapture.interactionDebounceInterval + 0.2)

        // Only the last delivered length is suppressed: a new length re-arms the earlier one.
        published.onPublish = nil
        send(length + 1, for: view, owner: userpilot)
        userpilot.autoCaptureCoordinator.flushPendingInteractions()
        send(length, for: view, owner: userpilot)
        userpilot.autoCaptureCoordinator.flushPendingInteractions()
        XCTAssertEqual(published.textLengths, [length, length + 1, length])
    }

    func testFlushPendingPublishesInlineAndRetainsDeliveredDeduplication() {
        let view = UITextField()
        let published = record(userpilot)

        send(length, for: view, owner: userpilot)
        userpilot.autoCaptureCoordinator.flushPendingInteractions()
        XCTAssertEqual(published.textLengths, [length])

        send(length, for: view, owner: userpilot)
        userpilot.autoCaptureCoordinator.flushPendingInteractions()
        XCTAssertEqual(published.textLengths, [length])
    }

    func testTextLengthDeduplication_isScopedToOwnerAndView() {
        let other = makeOwner()
        let view = UITextField()
        let otherView = UITextField()
        let published = record(userpilot)
        let otherPublished = record(other)

        send(length, for: view, owner: userpilot)
        userpilot.autoCaptureCoordinator.flushPendingInteractions()
        send(length, for: view, owner: userpilot)
        send(length, for: view, owner: other)
        send(length, for: otherView, owner: userpilot)
        userpilot.autoCaptureCoordinator.flushPendingInteractions()
        other.autoCaptureCoordinator.flushPendingInteractions()

        XCTAssertEqual(published.textLengths, [length, length],
                       "The repeated length is dropped only for the view that already delivered it")
        XCTAssertEqual(otherPublished.textLengths, [length],
                       "Another owner's delivery history must not suppress this owner's text change")
    }

    /// Screens are rebuilt all the time, and a new field can be allocated at a released field's
    /// address. It starts with no delivery history, so its first text change publishes.
    func testFieldAtAReleasedFieldsAddress_doesNotInheritItsDeliveredLength() throws {
        let published = record(userpilot)
        weak var released: UITextField?
        var releasedAddress: ObjectIdentifier?
        autoreleasepool {
            let closedField = UITextField()
            released = closedField
            releasedAddress = ObjectIdentifier(closedField)
            send(length, for: closedField, owner: userpilot)
            userpilot.autoCaptureCoordinator.flushPendingInteractions()
        }
        // The allocator normally hands the freed block straight to the next field.
        var reusingField: UITextField?
        for _ in 0..<20 where reusingField == nil {
            autoreleasepool {
                let candidate = UITextField()
                if ObjectIdentifier(candidate) == releasedAddress { reusingField = candidate }
            }
        }
        XCTAssertNil(released, "Precondition: the first field was deallocated")
        let newField = try XCTUnwrap(reusingField, "Precondition: a new field reused the released field's address")

        send(length, for: newField, owner: userpilot)
        userpilot.autoCaptureCoordinator.flushPendingInteractions()

        XCTAssertEqual(published.textLengths, [length, length])
    }

    // MARK: - Per-owner isolation

    func testTwoOwnersOnSameView_eachDeliversItsOwnPendingInteraction() {
        let other = makeOwner()
        let view = UITextField()
        let ownerDelivered = XCTestExpectation(description: "first owner delivered")
        let otherDelivered = XCTestExpectation(description: "second owner delivered")
        let published = record(userpilot)
        let otherPublished = record(other)
        published.onPublish = { ownerDelivered.fulfill() }
        otherPublished.onPublish = { otherDelivered.fulfill() }

        send(length, for: view, owner: userpilot)
        send(length + 1, for: view, owner: other)

        wait(for: [ownerDelivered, otherDelivered], timeout: debounceTimeout)
        XCTAssertEqual(published.textLengths, [length])
        XCTAssertEqual(otherPublished.textLengths, [length + 1])
    }

    func testStoppingOneOwner_keepsAnotherOwnersPendingInteraction() {
        let other = makeOwner()
        let view = UITextField()
        let published = record(userpilot)
        let otherPublished = record(other)

        send(length, for: view, owner: userpilot)
        send(length + 1, for: view, owner: other)
        userpilot.autoCaptureCoordinator.stopAutoCapture()
        userpilot.autoCaptureCoordinator.flushPendingInteractions()
        other.autoCaptureCoordinator.flushPendingInteractions()

        XCTAssertTrue(published.events.isEmpty)
        XCTAssertEqual(otherPublished.textLengths, [length + 1])
    }

    func testFlushingOneOwner_leavesAnotherOwnersInteractionPending() {
        let other = makeOwner()
        let view = UITextField()
        let published = record(userpilot)
        let otherPublished = record(other)

        send(length, for: view, owner: userpilot)
        send(length + 1, for: view, owner: other)
        userpilot.autoCaptureCoordinator.flushPendingInteractions()

        XCTAssertEqual(published.textLengths, [length])
        XCTAssertTrue(otherPublished.events.isEmpty, "A screen change of one owner must not flush another's text")

        other.autoCaptureCoordinator.flushPendingInteractions()
        XCTAssertEqual(otherPublished.textLengths, [length + 1])
    }

    // MARK: - Stop / resume

    func testStopDropsPendingInteraction_andResumeDeliversOnlyNewOnes() {
        let typedBeforeStop = UITextField()
        let typedAfterResume = UITextField()
        let published = record(userpilot)

        send(length, targetClass: "BeforeStop", for: typedBeforeStop, owner: userpilot)
        userpilot.autoCaptureCoordinator.stopAutoCapture()
        userpilot.autoCaptureCoordinator.resumeAutoCapture()
        send(length + 1, targetClass: "AfterResume", for: typedAfterResume, owner: userpilot)
        userpilot.autoCaptureCoordinator.flushPendingInteractions()

        XCTAssertEqual(published.textLengths, [length + 1], "Text typed before stop must not publish after resume")
    }

    func testStoppedOwner_rejectsInteractionsScheduledWhileStopped() {
        let view = UITextField()
        let published = record(userpilot)

        userpilot.autoCaptureCoordinator.stopAutoCapture()
        send(length, for: view, owner: userpilot)
        userpilot.autoCaptureCoordinator.resumeAutoCapture()
        userpilot.autoCaptureCoordinator.flushPendingInteractions()
        XCTAssertTrue(published.events.isEmpty)

        send(length, for: view, owner: userpilot)
        userpilot.autoCaptureCoordinator.flushPendingInteractions()
        XCTAssertEqual(published.textLengths, [length])
    }

    func testStopAutoCapture_cancelsTimerDelivery() {
        let view = UITextField()
        let expectation = XCTestExpectation(description: "pending interaction should be cancelled")
        expectation.isInverted = true
        userpilot.analyticsPublisher.onPublish = { _ in expectation.fulfill() }

        send(length, for: view, owner: userpilot)
        userpilot.autoCaptureCoordinator.stopAutoCapture()

        wait(for: [expectation], timeout: Constants.AutoCapture.interactionDebounceInterval + 0.2)
    }

    // MARK: - Owner lifetime

    func testDeliveryIsDropped_whenOwnerIsUnregisteredBeforeDebounceFires() {
        let view = UITextField()
        let token = userpilot.config.token
        let noDelivery = XCTestExpectation(description: "removed owner must not publish")
        noDelivery.isInverted = true
        userpilot.analyticsPublisher.onPublish = { _ in noDelivery.fulfill() }

        send(length, for: view, owner: userpilot)
        UserpilotRuntime.shared.removeInstance(userpilot)
        let replacement = MockUserpilot.make(
            config: Userpilot.Config(token: token).enableInteractionAutoCapture().defaultInstance(false)
        )
        XCTAssertFalse(replacement === userpilot, "Precondition: replacement is a new owner")
        replacement.analyticsPublisher.onPublish = { _ in noDelivery.fulfill() }

        wait(for: [noDelivery], timeout: debounceTimeout)
    }

    func testPendingInteraction_doesNotRetainItsOwnerOrField() {
        weak var releasedOwner: MockUserpilot?
        weak var releasedField: UITextField?
        let pending: PendingInteraction = autoreleasepool {
            let owner = makeOwner()
            let field = UITextField()
            releasedOwner = owner
            releasedField = field
            return PendingInteraction(
                payload: textPayload(length: length), textLengthForDedupe: length, owner: owner, view: field
            )
        }

        XCTAssertNil(releasedOwner)
        XCTAssertNil(releasedField)
        XCTAssertNil(pending.owner)
        XCTAssertNil(pending.view)
    }

    // MARK: - Helpers

    private func makeOwner() -> MockUserpilot {
        MockUserpilot.make(
            config: Userpilot.Config(token: "NX-\(UUID().uuidString)")
                .enableInteractionAutoCapture()
                .appFramework(.UIKit)
                .defaultInstance(false)
        )
    }

    private func send(_ length: Int, targetClass: String = "UITextField", for view: UIView, owner: Userpilot) {
        InteractionEventCache.sendDebouncedInteraction(
            textPayload(length: length, targetClass: targetClass),
            for: view,
            owner: owner,
            textLengthForDedupe: length
        )
    }

    private func textPayload(length: Int, targetClass: String = "UITextField") -> InteractionPayload {
        var payload = InteractionPayload(interactionType: .textFieldChanged, elementType: targetClass)
        payload.sourceProperties = [Constants.AutoCapture.textLength: length]
        return payload
    }

    private func record(_ owner: MockUserpilot) -> PublishedEvents {
        let published = PublishedEvents()
        owner.analyticsPublisher.onPublish = { [published] in published.append($0) }
        return published
    }
}

/// Events that reached one owner's analytics publisher.
private final class PublishedEvents {
    private(set) var events: [Event] = []
    var onPublish: (() -> Void)?

    var textLengths: [Int] { events.compactMap { $0.properties?[Constants.AutoCapture.textLength] as? Int } }

    func append(_ event: Event) {
        events.append(event)
        onPublish?()
    }
}
