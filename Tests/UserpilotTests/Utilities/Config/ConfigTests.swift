//
//  ConfigTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 07/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class EnvironmentTests: XCTestCase {

    var userpilot: MockUserpilot!

    override func setUp() {
        super.setUp()
        let config = Userpilot.Config(token: "NX-00000")
        userpilot = MockUserpilot(config: config)
        userpilot.storage.socketURL = "wss://socket.prod.example.com"
    }
    
    func test_getSocketURL_returnsFromStorageInProduction() {
        // Act
        let result = Environment.getSocketURL(storage: userpilot.storage)

        // Assert
        XCTAssertEqual(result, "wss://socket.prod.example.com")
    }

    func test_getClientToken_returnsFromConfigInProduction() {
        // Act
        let result = Environment.getClientToken(config: userpilot.config)

        // Assert
        XCTAssertEqual(result, "NX-00000")
    }
}
