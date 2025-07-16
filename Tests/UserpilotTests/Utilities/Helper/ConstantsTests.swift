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
        XCTAssertEqual(DispatchQueueConstants.EVENT_QUEUE, "userpilot-event-queue")
        XCTAssertEqual(DispatchQueueConstants.EXPERIENCE_QUEUE, "userpilot-experience-queue")
        XCTAssertEqual(DispatchQueueConstants.DI_CONTAINER_QUEUE, "userpilot-dicontainer")
        XCTAssertEqual(DispatchQueueConstants.THROTTLE_QUEUE, "userpilot-throttle-queue")
    }

    func testGeneralConstants() {
        XCTAssertEqual(GeneralConstants.PATH_NAME, "/mobile/v1/events/websocket")
        XCTAssertEqual(GeneralConstants.SESSION_DURATION, 1800, accuracy: 0.1)
        XCTAssertEqual(GeneralConstants.CONFIGURATION_DURATION, 1800, accuracy: 0.1)
        XCTAssertEqual(GeneralConstants.USERPILOT_LOGGING_CATEOGRY, "general")
    }
}
