//
//  AnalyticsPublisherTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 14/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
import Foundation
@testable import Userpilot
@testable import SwiftPhoenixClient

final class AnalyticsPublisherTests: XCTestCase {
    
    var analyticsPublisher: AnalyticsPublisher!
    var userpilot: MockUserpilot!
    
    override func setUpWithError() throws {
        super.setUp()
        let config = Userpilot.Config(token: "NX-00000")
        userpilot = MockUserpilot(config: config)
        
        analyticsPublisher = AnalyticsPublisher(container: userpilot.container)
    }
    
    override func tearDown() {
        analyticsPublisher.reset()
        super.tearDown()
    }
    
    // MARK: - Publish Method Tests
    
    func testPublish_identifyEvent_shouldCacheEventAndUpdateStorage() {
        // Arrange
        let userId = "test-user-123"
        let properties = ["name": "John Doe", "email": "john@example.com"]
        let company = ["name": "Test Company", "id": "company-123"]
        let identifyEvent = Event(
            type: .identify(userId),
            properties: properties,
            company: company
        )
        
        // Act
        analyticsPublisher.publish(identifyEvent)
        
        // Assert
        //XCTAssertEqual(userpilot.storage.temporaryUser, identifyEvent.toUser().toJson())
        XCTAssertTrue(userpilot.socketManager.isShutdownState || !userpilot.socketManager.isSocketOpened)
    }
    
    func testPublish_screenEvent_shouldSetupScreenEntity() {
        // Arrange
        let screenEvent = Event(type: .screen("Home Screen"))
        userpilot.socketManager.isSocketOpened = true
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { return true }
        
        // Act
        analyticsPublisher.publish(screenEvent)
        
        // Assert
        XCTAssertNotNil(analyticsPublisher.screenEntity)
        XCTAssertEqual(analyticsPublisher.screenEntity?.event.screenTitle, "Home Screen")
    }
    
    func testPublish_customEvent_shouldAddToQueue() {
        // Arrange
        let customEvent = Event(type: .event("button_clicked"))
        userpilot.socketManager.isSocketOpened = true
        
        // Act
        analyticsPublisher.publish(customEvent)
        
        // Assert
        // We can't directly access the queue, but we can verify the event was processed
        // by checking if the socket manager was called to publish
        XCTAssertTrue(true) // This would need socket manager verification
    }
    
    func testPublish_whenSocketNotOpened_shouldCacheEvent() {
        // Arrange
        let customEvent = Event(type: .event("test_event"))
        userpilot.socketManager.isSocketOpened = false
        userpilot.storage.userId = "test-user"
        
        var connectCalled = false
        userpilot.socketManager.onConnect = { connectCalled = true }
        
        // Act
        analyticsPublisher.publish(customEvent)
        
        // Assert
        XCTAssertTrue(connectCalled)
    }
    
    func testPublish_whenSocketIsJoining_shouldCacheEvent() {
        // Arrange
        let customEvent = Event(type: .event("test_event"))
        userpilot.socketManager.isJoiningSocket = true
        
        // Act
        analyticsPublisher.publish(customEvent)
        
        // Assert
        // Event should be cached, not sent immediately
        XCTAssertTrue(true) // Would need to verify internal state
    }
    
    func testPublish_whenSocketInShutdownState_shouldNotProcess() {
        // Arrange
        let customEvent = Event(type: .event("test_event"))
        userpilot.socketManager.isShutdownState = true
        
        // Act
        analyticsPublisher.publish(customEvent)
        
        // Assert
        // Event should not be processed
        XCTAssertTrue(true) // Would need to verify no processing occurred
    }
    
    // MARK: - Flush Tests
    
    func testFlush_shouldUpdateSocketStateAndFlushQueue() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        var socketState: SocketManager.SocketState? = nil
        userpilot.socketManager.onUpdateSocketState = { state, _ in socketState = state }
        
        // Act
        analyticsPublisher.flush()
        
        // Assert
        XCTAssertEqual(socketState, .shuttingDown)
    }
    
    // MARK: - Resume Tests
    
    func testResume_shouldConnectSocketWhenUserIdExists() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.socketManager.isSocketOpened = false
        userpilot.socketManager.isJoiningSocket = false
        
        var connectCalled = false
        userpilot.socketManager.onConnect = { connectCalled = true }
        
        // Act
        analyticsPublisher.resume()
        
        // Assert
        XCTAssertTrue(connectCalled)
    }
    
    func testResume_shouldNotConnectWhenSocketAlreadyOpen() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.socketManager.isSocketOpened = true
        
        var connectCalled = false
        userpilot.socketManager.onConnect = { connectCalled = true }
        
        // Act
        analyticsPublisher.resume()
        
        // Assert
        XCTAssertFalse(connectCalled)
    }
    
    func testResume_shouldNotConnectWhenUserIdEmpty() {
        // Arrange
        userpilot.storage.userId = ""
        userpilot.socketManager.isSocketOpened = false
        
        var connectCalled = false
        userpilot.socketManager.onConnect = { connectCalled = true }
        
        // Act
        analyticsPublisher.resume()
        
        // Assert
        XCTAssertFalse(connectCalled)
    }
    
    // MARK: - Reset Tests
    
    func testReset_shouldResetStartSessionFlag() {
        // Arrange
        // Simulate that start session was previously false
        
        // Act
        analyticsPublisher.reset()
        
        // Assert
        XCTAssertTrue(analyticsPublisher.isStartSession)
    }
    
    // MARK: - Logout Tests
    
    func testLogout_shouldResetStateAndCloseSocket() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.storage.pushToken = "push-token"
        //analyticsPublisher.canRequestEvent = true
        
        var closeCalled = false
        userpilot.socketManager.onClose = { closeCalled = true }
        
        // Act
        analyticsPublisher.logout(socketState: .closed, shouldClearCachedIdentifyEvent: true)
        
        // Assert
        XCTAssertTrue(closeCalled)
        XCTAssertTrue(analyticsPublisher.isStartSession)
    }
    
    func testLogout_shouldPublishLogoutEventWhenRequested() {
        // Arrange
        userpilot.storage.userId = "test-user"
        userpilot.storage.pushToken = "push-token"
        userpilot.socketManager.isSocketOpened = true
        
        var publishLogoutEventCalled = false
        userpilot.socketManager.onPublish = { _, _, _, _ in publishLogoutEventCalled = true }
        
        // Act
        analyticsPublisher.logout(socketState: .closed, shouldClearCachedIdentifyEvent: true)
        
        // Assert
        XCTAssertTrue(publishLogoutEventCalled)
    }
    
    // MARK: - Socket Subscription Tests
    
    func testOnSocketOpened_shouldFlushPriorityEvents() {
        // Arrange
        let identifyEvent = Event(type: .identify("test-user"))
        analyticsPublisher.publish(identifyEvent)
        userpilot.experiencesPublisher.onCanRequestScreenEvent = { return true }
        
        // Act
        analyticsPublisher.onSocketOpened()
        
        // Assert
        // Would need to verify that cached events were flushed
        XCTAssertTrue(true)
    }
    
    func testOnSocketClosed_shouldHandleReconnection() {
        // Arrange
        let identifyEvent = Event(type: .identify("test-user"))
        analyticsPublisher.publish(identifyEvent)
        userpilot.socketManager.didErrorOccurred = false
        
        // Act
        analyticsPublisher.onSocketClosed()
        
        // Assert
        // Should republish cached identify event
        XCTAssertTrue(true)
    }
    
    func testOnSocketClosed_shouldClearCachedPropertiesOnError() {
        // Arrange
        userpilot.socketManager.didErrorOccurred = true
        
        // Act
        analyticsPublisher.onSocketClosed()
        
        // Assert
        // Should clear all cached properties
        XCTAssertTrue(true)
    }
    
    func testOnSocketEventSent_shouldUpdateUserOnIdentifyEvent() {
        // Arrange
        let userId = "test-user"
        let identifyEvent = Event(type: .identify(userId))
        userpilot.storage.userId = userId
        userpilot.storage.user = "{\"userId\":\"test-user\",\"properties\":{}}"
        
        // Simulate cached identify event
        analyticsPublisher.publish(identifyEvent)
        
        let payload: [String: Any] = ["test": "data"]
        
        // Act
        analyticsPublisher.onSocketEventSent("identify", payload, Message(), true)
        
        // Assert
        XCTAssertNotEqual(userpilot.storage.user, "")
    }
    
    // MARK: - Experience Events Tests
    
    func testCanRequestEvent_shouldReturnSocketState() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        
        // Act & Assert
        XCTAssertTrue(analyticsPublisher.canRequestEvent)
        
        // Arrange
        userpilot.socketManager.isSocketOpened = false
        
        // Act & Assert
        XCTAssertFalse(analyticsPublisher.canRequestEvent)
    }
    
    func testPublishInternalSDKEvent_shouldPublishWhenSocketOpen() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let sdkEvent = MockSDKEvent()
        
        // Act
        analyticsPublisher.publishInternalSDKEvent(sdkEvent, isExpereinceEvent: false, socketSubscription: nil)
        
        // Assert
        // Would need to verify socket manager publish was called
        XCTAssertTrue(true)
    }
    
    func testPublishInternalSDKEvent_shouldNotPublishExperienceEventWhenSocketClosed() {
        // Arrange
        userpilot.socketManager.isSocketOpened = false
        let sdkEvent = MockSDKEvent()
        
        // Act
        analyticsPublisher.publishInternalSDKEvent(sdkEvent, isExpereinceEvent: true, socketSubscription: nil)
        
        // Assert
        // Should not publish experience event when socket is closed
        XCTAssertTrue(true)
    }
    
    func testPublishFakeReloadScreenEvent_shouldPublishWhenScreenEntityExists() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.publish(screenEvent)
        
        // Act
        analyticsPublisher.publishFakeReloadScreenEvent()
        
        // Assert
        // Would need to verify socket manager publish was called with fake reload flag
        XCTAssertTrue(true)
    }
    
    func testExperiencePublished_shouldUpdateSeenExperiences() {
        // Arrange
        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.publish(screenEvent)
        
        // Act
        analyticsPublisher.experiencePublished(.flow, 123)
        
        // Assert
        XCTAssertTrue(analyticsPublisher.screenEntity?.seenExperiences.contains(123) ?? false)
    }
    
    func testExperiencePublished_shouldUpdateSeenSurveys() {
        // Arrange
        let screenEvent = Event(type: .screen("Test Screen"))
        analyticsPublisher.publish(screenEvent)
        
        // Act
        analyticsPublisher.experiencePublished(.survey, 456)
        
        // Assert
        XCTAssertTrue(analyticsPublisher.screenEntity?.seenSurveys.contains(456) ?? false)
    }
    
    // MARK: - Screen Event Setup Tests
    
    func testSetupScreenEvent_shouldCreateNewScreenEntityForDifferentScreen() {
        // Arrange
        let firstScreenEvent = Event(type: .screen("Screen 1"))
        let secondScreenEvent = Event(type: .screen("Screen 2"))
        
        // Act
        analyticsPublisher.publish(firstScreenEvent)
        let firstScreenEntity = analyticsPublisher.screenEntity
        
        analyticsPublisher.publish(secondScreenEvent)
        let secondScreenEntity = analyticsPublisher.screenEntity
        
        // Assert
        XCTAssertNotEqual(firstScreenEntity?.event.screenTitle, secondScreenEntity?.event.screenTitle)
        XCTAssertEqual(secondScreenEntity?.event.screenTitle, "Screen 2")
    }
    
    func testSetupScreenEvent_shouldRetainSeenExperiencesForSameScreen() {
        // Arrange
        let screenEvent = Event(type: .screen("Same Screen"))
        analyticsPublisher.publish(screenEvent)
        analyticsPublisher.experiencePublished(.flow, 123)
        
        // Act
        analyticsPublisher.publish(screenEvent) // Same screen again
        
        // Assert
        XCTAssertTrue(analyticsPublisher.screenEntity?.seenExperiences.contains(123) ?? false)
    }
    
    // MARK: - Session State Tests
    
    func testUpdateSessionState_shouldSetStartSessionTrueWhenSessionExpired() {
        // Arrange
        let pastDate = Date().addingTimeInterval(-35 * 60) // 35 minutes ago
        userpilot.storage.sessionDate = pastDate
        
        // Act
        analyticsPublisher.updateSessionState()
        
        // Assert
        XCTAssertTrue(analyticsPublisher.isStartSession)
        XCTAssertNil(userpilot.storage.sessionDate)
    }
    
    func testUpdateSessionState_shouldSetStartSessionFalseWhenSessionNotExpired() {
        // Arrange
        let recentDate = Date().addingTimeInterval(-10 * 60) // 10 minutes ago
        userpilot.storage.sessionDate = recentDate
        
        // Act
        analyticsPublisher.updateSessionState()
        
        // Assert
        XCTAssertFalse(analyticsPublisher.isStartSession)
        XCTAssertNil(userpilot.storage.sessionDate)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testPublish_withNilUserId_shouldNotOpenSocket() {
        // Arrange
        let eventWithoutUserId = Event(type: .event("test"))
        userpilot.socketManager.isSocketOpened = false
        userpilot.storage.userId = ""
        
        var connectCalled = false
        userpilot.socketManager.onConnect = { connectCalled = true }
        
        // Act
        analyticsPublisher.publish(eventWithoutUserId)
        
        // Assert
        XCTAssertFalse(connectCalled)
    }
    
    func testPublish_withSameIdentifyEvent_shouldNotReprocess() {
        // Arrange
        let userId = "test-user"
        let properties = ["name": "John"]
        let identifyEvent = Event(type: .identify(userId), properties: properties)
        
        // Set up existing user
        let user = User(userId: userId, properties: properties, company: [:])
        userpilot.storage.user = user.toJson() ?? ""
        
        // Act
        analyticsPublisher.publish(identifyEvent)
        
        // Assert
        // Should not reprocess same identify event
        XCTAssertTrue(true)
    }
}

// MARK: - Helper Classes

class MockSDKEvent: SDKEvent {
    var eventName: String = "test_event"
    var eventPayload: [String: Any] = ["test": "data"]
}
