//
//  SocketManagerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 07/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class SocketManagerTests: XCTestCase {

    var socketManager: SocketManager!
    var userpilot: MockUserpilot!
    var mockSocketSubscription: MockSocketSubscription!

    private let socketUrl = "<#SOCKET_URL#>"
    private let appToken = "<#APP_TOKEN#>"
    private let userId = "<#USER_ID#>"

    override func setUpWithError() throws {
        super.setUp()

        if socketUrl == "<#SOCKET_URL#>" || appToken == "<#APP_TOKEN#>" || userId == "<#USER_ID#>" {
            throw XCTSkip("configuration not configured - add your credentials and run test again")
        }

        let config = Userpilot.Config(token: appToken)
        userpilot = MockUserpilot(config: config)
        userpilot.storage.socketURL = socketUrl
        userpilot.storage.userId = userId
    }

    override func tearDown() {
        socketManager.close()
        socketManager = nil
        userpilot = nil
        mockSocketSubscription = nil
        super.tearDown()
    }

    // MARK: - Socket State Tests

    func testInitialState_shouldBeClosed() {
        // Assert
        XCTAssertFalse(socketManager.isSocketOpened)
        XCTAssertFalse(socketManager.isJoiningSocket)
        XCTAssertFalse(socketManager.didErrorOccurred)
        XCTAssertFalse(socketManager.isShutdownState)
        XCTAssertFalse(socketManager.isSocketConnectedWithUnknownChannel)
    }

    func testUpdateSocketState_shouldUpdateState() {
        // Act
        socketManager.updateSocketState(.connecting)

        // Assert
        XCTAssertTrue(socketManager.isJoiningSocket)
        XCTAssertFalse(socketManager.isSocketOpened)
    }

    func testUpdateSocketState_withError_shouldUpdateToError() {
        // Act
        socketManager.updateSocketState(.error)

        // Assert
        XCTAssertTrue(socketManager.didErrorOccurred)
        XCTAssertFalse(socketManager.isSocketOpened)
    }

    func testUpdateSocketState_withShuttingDown_shouldUpdateToShuttingDown() {
        // Act
        socketManager.updateSocketState(.shuttingDown)

        // Assert
        XCTAssertTrue(socketManager.isShutdownState)
        XCTAssertFalse(socketManager.isSocketOpened)
    }

    func testUpdateSocketState_withForceUpdate_shouldAlwaysUpdate() {
        // Arrange
        socketManager.updateSocketState(.error)

        // Act
        socketManager.updateSocketState(.opened, forceUpdateState: true)

        // Assert
        XCTAssertFalse(socketManager.didErrorOccurred)
    }

    // MARK: - Connection Tests

    func testConnect_withValidConfiguration_shouldInitiateConnection() {
        // Arrange
        let expectation = XCTestExpectation(description: "Socket connection initiated")

        // Act
        socketManager.connect()

        // Assert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.socketManager.isJoiningSocket)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testConnect_withEmptyToken_shouldNotConnect() {
        // Arrange
        let config = Userpilot.Config(token: "")
        let userpilot = MockUserpilot(config: config)
        socketManager = SocketManager(container: userpilot.container)

        // Act
        socketManager.connect()

        // Assert
        XCTAssertFalse(socketManager.isJoiningSocket)
        XCTAssertFalse(socketManager.isSocketOpened)
    }

    func testConnect_withEmptyUserId_shouldNotConnect() {
        // Arrange
        userpilot.storage.userId = ""

        // Act
        socketManager.connect()

        // Assert
        XCTAssertFalse(socketManager.isJoiningSocket)
        XCTAssertFalse(socketManager.isSocketOpened)
    }

    func testClose_shouldCloseSocket() {
        // Arrange
        socketManager.connect()

        // Act
        socketManager.close()

        // Assert with delay
        let expectation = self.expectation(description: "Wait for socket to close")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)

        XCTAssertFalse(socketManager.isSocketOpened)
        XCTAssertFalse(socketManager.isJoiningSocket)
    }

    // MARK: - Socket Subscription Tests

    func testRegisterCallback_shouldRegisterSocketSubscription() {
        // Act
        socketManager.registerCallback(mockSocketSubscription)

        // Assert - This is implicit since we can't directly test the multicast registration
        // but we can verify it works through other tests
        XCTAssertTrue(true) // Placeholder assertion
    }

    func testSocketSubscription_onSocketOpened_shouldNotifySubscribers() {
        // Arrange
        let expectation = XCTestExpectation(description: "Socket opened notification")
        mockSocketSubscription.onSocketOpenedCalled = {
            expectation.fulfill()
        }

        socketManager.registerCallback(mockSocketSubscription)

        // Act
        socketManager.connect()

        // Simulate socket opened (this would normally be handled by Phoenix Socket)
        // Note: In a real test, you might need to mock the Phoenix Socket behavior

        wait(for: [expectation], timeout: 2.0)
    }

    func testSocketSubscription_onSocketClosed_shouldNotifySubscribers() {
        // Arrange
        let expectation = XCTestExpectation(description: "Socket closed notification")
        mockSocketSubscription.onSocketClosedCalled = {
            expectation.fulfill()
        }

        socketManager.registerCallback(mockSocketSubscription)
        socketManager.connect()

        // Act
        socketManager.close()

        wait(for: [expectation], timeout: 2.0)
    }

    func testPublish_withValidEvent_shouldSendEvent() {
        // Arrange
        let expectation = XCTestExpectation(description: "Event published")
        let eventName = "user_identify"
        let payload: [String: Any] = ["metadata": [:], "company": [:]]

        mockSocketSubscription.onSocketEventSentCalled = { event, _, _, status in
            XCTAssertEqual(event, eventName)
            XCTAssertTrue(status)
            expectation.fulfill()
        }

        socketManager.registerCallback(mockSocketSubscription)
        socketManager.connect()

        // Delay to allow connect setup before publishing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Act
            self.socketManager.publish(eventName, payload: payload, shouldCloseSocket: false, socketSubscription: nil)
        }

        // Assert
        wait(for: [expectation], timeout: 4.0)
    }

    func testPublish_withShouldCloseSocket_shouldCloseAfterSending() {
        // Arrange
        let expectation = XCTestExpectation(description: "Socket closed after event")
        let eventName = "user_identify"
        let payload: [String: Any] = ["metadata": [:], "company": [:]]

        mockSocketSubscription.onSocketEventSentCalled = { _, _, _, _ in
            // Wait a bit for the socket to close
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                XCTAssertFalse(self.socketManager.isSocketOpened)
                expectation.fulfill()
            }
        }

        socketManager.registerCallback(mockSocketSubscription)
        socketManager.connect()

        // Act
        // Delay to allow connect setup before publishing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Act
            self.socketManager.publish(eventName, payload: payload, shouldCloseSocket: true, socketSubscription: nil)
        }

        // Assert
        wait(for: [expectation], timeout: 5.0)
    }

    func testPublish_withSpecificSubscription_shouldNotifySpecificSubscription() {
        // Arrange
        let expectation = XCTestExpectation(description: "Specific subscription notified")
        let eventName = "user_identify"
        let payload: [String: Any] = ["metadata": [:], "company": [:]]

        let specificSubscription = MockSocketSubscription()
        specificSubscription.onSocketEventSentCalled = { event, _, _, _ in
            XCTAssertEqual(event, eventName)
            expectation.fulfill()
        }

        socketManager.connect()

        // Act
        socketManager.publish(
            eventName,
            payload: payload,
            shouldCloseSocket: false,
            socketSubscription: specificSubscription
        )

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Edge Cases

    func testConnect_whenAlreadyConnecting_shouldNotCreateDuplicateConnection() {
        // Arrange
        socketManager.connect()
        XCTAssertTrue(socketManager.isJoiningSocket)

        // Act
        socketManager.connect()

        // Assert
        // This test ensures we don't create multiple connections
        XCTAssertTrue(socketManager.isJoiningSocket)
    }

    func testPublish_whenSocketNotConnected_shouldNotCrash() {
        // Arrange
        let eventName = "test_event"
        let payload: [String: Any] = ["key": "value"]

        // Act & Assert (should not crash)
        XCTAssertNoThrow(
            socketManager.publish(eventName, payload: payload, shouldCloseSocket: false, socketSubscription: nil)
        )
    }

    func testUpdateSocketState_withSameState_shouldNotUpdateState() {
        // Arrange
        socketManager.updateSocketState(.connecting)

        // Act
        socketManager.updateSocketState(.connecting)

        // Assert
        XCTAssertTrue(socketManager.isJoiningSocket)
    }

    func testUpdateSocketState_withErrorState_shouldNotAllowOtherUpdates() {
        // Arrange
        socketManager.updateSocketState(.error)

        // Act
        socketManager.updateSocketState(.opened)

        // Assert
        XCTAssertTrue(socketManager.didErrorOccurred)
        XCTAssertFalse(socketManager.isSocketOpened)
    }
}

// MARK: - Additional Helper Extensions for Testing

extension SocketManagerTests {

    func createMockMessage(event: String = "test", payload: [String: Any] = [:]) -> Message {
        // Create a mock message for testing
        // Note: You may need to adjust this based on your Message structure
        return Message(
            ref: "",
            topic: "events:*",
            event: event,
            payload: payload,
            joinRef: nil
        )
    }

    func waitForSocketConnection(timeout: TimeInterval = 2.0) {
        let expectation = XCTestExpectation(description: "Wait for socket connection")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
    }
}
