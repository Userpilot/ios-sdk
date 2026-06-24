//
//  UserpilotTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 02/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

class UserpilotTests: XCTestCase {
    var userpilot: MockUserpilot!
    var token: String!

    override func setUpWithError() throws {
        token = "NX-\(UUID().uuidString)"
        let config = Userpilot.Config(token: token).defaultInstance(false)
        userpilot = MockUserpilot(config: config)
    }

    override func tearDownWithError() throws {
        userpilot = nil
        token = nil
        try super.tearDownWithError()
    }

    // MARK: - Version

    /// Tests that the SDK version string is properly formatted
    func testSdkVersionFormatIsValid() throws {
        // Act
        let version = userpilot.version()

        // Assert
        let tokens = version.split(separator: ".")
        XCTAssertTrue(tokens.count > 2)
        XCTAssertNotNil(Int(tokens[0]))
        XCTAssertNotNil(Int(tokens[1]))
    }

    // MARK: - Identify

    /// Verifies that empty user Id does not trigger identify tracking
    func testIdentify_doesNotTrack_whenUserIdIsEmpty() throws {
        // Arrange
        var trackedUpdates = false
        userpilot.analyticsPublisher.onPublish = { _ in trackedUpdates = true }

        // Act
        userpilot.identify(userId: "", properties: nil)

        // Assert
        XCTAssertFalse(trackedUpdates)
    }

    /// Verifies that a valid user Id triggers identify tracking
    func testIdentify_tracksEvent_whenUserIdIsValid() throws {
        // Arrange
        var trackedEvent: Event?
        userpilot.analyticsPublisher.onPublish = { event in trackedEvent = event }

        // Act
        userpilot.identify(userId: "default-00000")

        // Assert
        let lastUpdate = try XCTUnwrap(trackedEvent)
        guard case let .identify(userId) = lastUpdate.type else {
            return XCTFail("Expected an identify event")
        }
        XCTAssertEqual(userId, "default-00000")
    }

    /// Verifies that user properties and company are passed correctly during identify
    func testIdentify_tracksUserPropertiesAndCompanyCorrectly() throws {
        // Arrange
        var trackedUserId: String?
        var trackedProperties: Payload?
        var trackedCompany: Payload?

        userpilot.onIdentify = { userId, properties, company in
            trackedUserId = userId
            trackedProperties = properties
            trackedCompany = company
        }

        // Act
        userpilot.identify(
            userId: "default-00000",
            properties: ["email": "test@mail.com"],
            company: ["id": "1"]
        )

        // Assert
        XCTAssertEqual(trackedUserId, "default-00000", "User Id should be 'default-00000'")

        guard let properties = trackedProperties ?? nil else {
            return XCTFail("Properties should not be nil")
        }
        XCTAssertEqual(properties["email"] as? String, "test@mail.com")

        guard let company = trackedCompany ?? nil else {
            return XCTFail("Company should not be nil")
        }
        XCTAssertEqual(company["id"] as? String, "1")
    }

    // MARK: - Anonymous

    /// Verifies that anonymous Id is prefixed with app token
    func testAnonymous_generatesUserIdWithAppTokenPrefix() throws {
        // Arrange
        var trackedEvent: Event?
        userpilot.analyticsPublisher.onPublish = { event in trackedEvent = event }

        // Act
        userpilot.anonymous()

        // Assert
        let lastUpdate = try XCTUnwrap(trackedEvent)
        guard case let .identify(userId) = lastUpdate.type else {
            return XCTFail("Expected an identify event")
        }
        XCTAssertTrue(userId.hasPrefix(token))
    }
    
    func testAnonymous_generatesUserIdWithAppTokenPrefix_andCachesIt() throws {
        // Arrange
        var trackedEvents: [Event] = []
        userpilot.analyticsPublisher.onPublish = { event in
            trackedEvents.append(event)
        }

        // Act
        userpilot.anonymous() // First call, should generate new ID
        userpilot.anonymous() // Second call, should reuse the same ID

        // Assert
        XCTAssertEqual(trackedEvents.count, 2, "Two identify events should be published")

        let firstEvent = try XCTUnwrap(trackedEvents.first)
        guard case let .identify(firstUserId) = firstEvent.type else {
            return XCTFail("Expected an identify event for first call")
        }
        XCTAssertTrue(firstUserId.hasPrefix(token), "User ID should have app token prefix")

        let secondEvent = try XCTUnwrap(trackedEvents.last)
        guard case let .identify(secondUserId) = secondEvent.type else {
            return XCTFail("Expected an identify event for second call")
        }
        XCTAssertEqual(firstUserId, secondUserId, "Second call should reuse the cached user ID")
    }

    // MARK: - Screen

    /// Verifies that an empty screen name does not trigger screen tracking
    func testScreen_doesNotTrack_whenTitleIsEmpty() throws {
        // Arrange
        var trackedUpdates = false
        userpilot.analyticsPublisher.onPublish = { _ in trackedUpdates = true }

        // Act
        userpilot.screen("")

        // Assert
        XCTAssertFalse(trackedUpdates)
    }

    /// Verifies that a valid screen name is tracked
    func testScreen_tracksEvent_whenTitleIsValid() throws {
        // Arrange
        var trackedEvent: Event?
        userpilot.analyticsPublisher.onPublish = { event in trackedEvent = event }

        // Act
        userpilot.screen("Profile")

        let lastUpdate = try XCTUnwrap(trackedEvent)
        guard case let .screen(title) = lastUpdate.type else {
            return XCTFail("Expected a screen event")
        }

        // Assert
        XCTAssertEqual(title, "Profile")
    }

    // MARK: - Event

    /// Verifies that an empty event name does not trigger tracking
    func testTrack_doesNotSendEvent_whenNameIsEmpty() throws {
        // Arrange
        var trackedUpdates = false
        userpilot.analyticsPublisher.onPublish = { _ in trackedUpdates = true }

        // Act
        userpilot.track(eventName: "")

        // Assert
        XCTAssertFalse(trackedUpdates)
    }

    /// Verifies that a valid event is tracked with its properties
    func testTrack_sendsEvent_whenNameAndPropertiesAreValid() throws {
        // Arrange
        var trackedEvent: Event?
        userpilot.analyticsPublisher.onPublish = { event in trackedEvent = event }

        // Act
        userpilot.track(eventName: "Added to Cart", properties: ["itemId": "sku_456", "price": 29])

        // Assert
        let lastUpdate = try XCTUnwrap(trackedEvent)
        guard case let .event(title) = lastUpdate.type else {
            return XCTFail("Expected an event")
        }
        XCTAssertEqual(title, "Added to Cart")
        XCTAssertEqual(lastUpdate.properties?["itemId"] as? String, "sku_456")
        XCTAssertEqual(lastUpdate.properties?["price"] as? Int, 29)
    }

    // MARK: - Logout

    /// Verifies logout clears all user-related data and emits logout event
    func testLogout_resetsUserAndEmitsLogoutEvent() throws {
        // Arrange
        var logoutCalled = false
        userpilot.analyticsPublisher.onLogout = { _, _ in logoutCalled = true }

        // Act
        userpilot.logout()

        // Assert
        XCTAssertTrue(logoutCalled)
        XCTAssertNil(userpilot.storage.pushToken)
        XCTAssertEqual(userpilot.storage.userId, "")
        XCTAssertEqual(userpilot.storage.user, "")
    }

    // MARK: - Clean

    /// Verifies that clean clears stored token and userId
    func testClean_clearsUserIdAndPushToken() throws {
        // Act
        userpilot.clean()

        // Assert
        XCTAssertNil(userpilot.storage.pushToken)
        XCTAssertEqual(userpilot.storage.userId, "")
    }

    // MARK: - Settings

    /// Verifies that settings returns merged data from user, app, and auto-properties
    func testSettings_returnsMergedUserAppAndAutoProperties() throws {
        // Arrange
        let expectedUser: [String: Any] = [
            "userId": "default-00000",
            "properties": ["email": "test@mail.com"],
            "company": ["id": "1"]
        ]
        let userData = try JSONSerialization.data(withJSONObject: expectedUser, options: [])
        userpilot.storage.user = String(data: userData, encoding: .utf8) ?? ""

        // Act
        let settings = userpilot.settings()

        // Assert
        XCTAssertEqual(settings["Token"] as? String, token)
        XCTAssertEqual(settings["SDK version"] as? String, userpilot.version())

        let user = settings["User"] as? [String: Any]
        XCTAssertEqual(user?["userId"] as? String, "default-00000")
        XCTAssertEqual((user?["properties"] as? [String: Any])?["email"] as? String, "test@mail.com")
        XCTAssertEqual((user?["company"] as? [String: Any])?["id"] as? String, "1")

        let autoProps = settings["Auto properties"] as? [String: Any]
        XCTAssertEqual(autoProps?[AutoPropertyDecorator.osKey] as? String, "iOS")

        let appProps = settings["App properties"] as? [String: Any]
        XCTAssertEqual(appProps?[AutoPropertyDecorator.appNameKey] as? String, Bundle.main.displayName)
    }

    // MARK: - Trigger Experience

    /// Verifies empty experience Id does not trigger any experience
    func testTriggerExperience_doesNotFire_whenIdIsEmpty() throws {
        // Arrange
        var experienceTriggered = false
        userpilot.experiencesPublisher.onTriggerExperience = { _ in experienceTriggered = true }

        // Act
        userpilot.triggerExperience("")

        // Assert
        XCTAssertFalse(experienceTriggered)
    }

    /// Verifies valid experience Id triggers experience
    func testTriggerExperience_fires_whenIdIsValid() throws {
        // Arrange
        var experienceTriggered = false
        userpilot.experiencesPublisher.onTriggerExperience = { _ in experienceTriggered = true }

        // Act
        userpilot.triggerExperience("EX-1234")

        // Assert
        XCTAssertTrue(experienceTriggered)
    }

    /// Verifies that ending an experience invokes the handler
    func testEndExperience_invokesHandler() throws {
        // Arrange
        var experienceEnded = false
        userpilot.experiencesPublisher.onEndExperience = { _ in experienceEnded = true }

        // Act
        userpilot.endExperience()

        // Assert
        XCTAssertTrue(experienceEnded)
    }

    // MARK: - Push

    /// Verifies that push token is passed to the push monitor
    func testSetPushToken_passesTokenToPushNotificationMonitor() throws {
        // Arrange
        let token = Data("some-token".utf8)

        let setExpectation = expectation(description: "Token set")
        userpilot.pushNotificationMonitor.onSetPushToken = {
            XCTAssertEqual($0, token)
            setExpectation.fulfill()
        }

        // Act
        userpilot.setPushToken(token)

        // Assert
        waitForExpectations(timeout: 1)
    }

    // MARK: - Memory Management

    /// Verifies deallocation of all injected components using weak references
    func testMemory_allComponentsDeallocatedOnRelease() throws {
        // Arrange
        weak var weakUserpilot: Userpilot?
        weak var weakConfig: Userpilot.Config?
        weak var weakAnalyticsPublishing: AnalyticsPublishing?
        weak var weakDataStoring: DataStoring?
        weak var weakSessionMonitoring: SessionMonitoring?
        weak var weakAutoPropertyDecoration: AutoPropertyDecoratoring?
        weak var weakSocketManager: SocketEvents?
        weak var weakSDKSettingsDetector: SDKSettingsDetectoring?
        weak var weakThemeHandler: ThemeHandling?
        weak var weakImageLoader: ImageLoading?
        weak var weakPushNotificationMonitor: PushNotificationMonitoring?

        // Act
        autoreleasepool {
            let userpilot = Userpilot(
                config: Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false)
            )

            weakUserpilot = userpilot
            weakConfig = userpilot.container.resolve(Userpilot.Config.self)
            weakAnalyticsPublishing = userpilot.container.resolve(AnalyticsPublishing.self)
            weakDataStoring = userpilot.container.resolve(DataStoring.self)
            weakSessionMonitoring = userpilot.container.resolve(SessionMonitoring.self)
            weakAutoPropertyDecoration = userpilot.container.resolve(AutoPropertyDecoratoring.self)
            weakSocketManager = userpilot.container.resolve(SocketEvents.self)
            weakSDKSettingsDetector = userpilot.container.resolve(SDKSettingsDetectoring.self)
            weakThemeHandler = userpilot.container.resolve(ThemeHandling.self)
            weakImageLoader = userpilot.container.resolve(ImageLoading.self)
            weakPushNotificationMonitor = userpilot.container.resolve(PushNotificationMonitoring.self)

            XCTAssertNotNil(weakUserpilot)
        }

        let expectation = XCTestExpectation(description: "Async cleanup completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert
        XCTAssertNil(weakUserpilot)
        XCTAssertNil(weakAnalyticsPublishing)
        XCTAssertNil(weakDataStoring)
        XCTAssertNil(weakSessionMonitoring)
        XCTAssertNil(weakAutoPropertyDecoration)
        XCTAssertNil(weakSocketManager)
        XCTAssertNil(weakSDKSettingsDetector)
        XCTAssertNil(weakThemeHandler)
        XCTAssertNil(weakImageLoader)
        XCTAssertNil(weakPushNotificationMonitor)
        XCTAssertNil(weakConfig)
    }

    /// Verifies DI container is thread-safe during concurrent access
    func testDIContainer_allowsThreadSafeAccess() throws {
        // Arrange
        let dispatchGroup = DispatchGroup()
        let completeExpectation = expectation(description: "multi thread")
        completeExpectation.expectedFulfillmentCount = 100

        // Act
        let container = DIContainer()

        for _ in 0..<100 {
            dispatchGroup.enter()
            DispatchQueue.global().async {
                let dep = Userpilot.Config(token: "<app_token>")
                container.register(Userpilot.Config.self, value: dep)
                _ = container.resolve(Userpilot.Config.self)
                completeExpectation.fulfill()
                dispatchGroup.leave()
            }
        }

        // Assert
        waitForExpectations(timeout: 2)
    }
}

// swiftlint:enable all
