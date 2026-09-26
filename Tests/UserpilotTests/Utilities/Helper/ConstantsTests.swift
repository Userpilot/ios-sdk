//
//  MulticastTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 14/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class ConstantsTests: XCTestCase {

    func testDispatchQueueConstants() {
        XCTAssertEqual(Constants.DispatchQueues.eventQueue, "com.userpilot.event-queue")
        XCTAssertEqual(Constants.DispatchQueues.experienceQueue, "com.userpilot.experience-queue")
        XCTAssertEqual(Constants.DispatchQueues.diContainerQueue, "com.userpilot.dicontainer-queue")
        XCTAssertEqual(Constants.DispatchQueues.throttleQueue, "com.userpilot.throttle-queue")
    }

    func testGeneralConstants() {
        XCTAssertEqual(Constants.RemoteSource.socketPath, "/mobile/v1/events/websocket")
        XCTAssertEqual(Constants.Analytics.sessionDuration, 1800, accuracy: 0.1)
        XCTAssertEqual(Constants.RemoteSource.configurationDuration, 1800, accuracy: 0.1)
    }

    func testUserpilotLoggingConstants() {
        XCTAssertEqual(UserpilotLogging.subsystem, "com.userpilot.sdk")
        XCTAssertEqual(UserpilotLogging.general, "general")
    }
}
