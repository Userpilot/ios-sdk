//
//  BootManagerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 14/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class BootManagerTests: XCTestCase {

    private class MockBootComponent: BootUp {
        var started = false

        func start() {
            started = true
        }
    }

    private class NonBootComponent {}

    func testInitializeCallsStartOnBootComponents() {
        let component1 = MockBootComponent()
        let component2 = MockBootComponent()

        let bootManager = BootManager(components: [component1, component2])
        bootManager.initialize()

        XCTAssertTrue(component1.started)
        XCTAssertTrue(component2.started)
    }

    func testInitializeSkipsNonBootComponents() {
        let component1 = MockBootComponent()
        let component2 = NonBootComponent() // Does NOT conform to BootUp

        let bootManager = BootManager(components: [component1, component2])
        bootManager.initialize()

        XCTAssertTrue(component1.started) // ✅ should be called
        // 🚫 No crash or misbehavior from NonBootComponent
    }

    func testInitializeHandlesEmptyComponentList() {
        let bootManager = BootManager(components: [])
        bootManager.initialize() // Should not crash or do anything

        // Nothing to assert; test passes if no exceptions are thrown
    }
}
