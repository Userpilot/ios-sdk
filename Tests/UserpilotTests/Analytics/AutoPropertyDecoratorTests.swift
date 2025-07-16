//
//  AutoPropertyDecoratorTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 06/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class AutoPropertyDecoratorTests: XCTestCase {

    var decorator: AutoPropertyDecorator!
    var userpilot: MockUserpilot!

    override func setUpWithError() throws {
        let config = Userpilot.Config(token: "NX-00000")
        userpilot = MockUserpilot(config: config)
        decorator = AutoPropertyDecorator(container: userpilot.container)
    }

    /// Verifies that auto properties contain all expected keys
    func testAutoPropertiesContainExpectedKeys() {
        // Act
        let autoProps = decorator.autoProperties

        // Assert
        let expectedKeys: Set<String> = [
            AutoPropertyDecorator.osKey,
            AutoPropertyDecorator.osVersionKey,
            AutoPropertyDecorator.deviceTypeKey,
            AutoPropertyDecorator.appVersionKey,
            AutoPropertyDecorator.screenWidthKey,
            AutoPropertyDecorator.screenHeightKey
        ]

        for key in expectedKeys {
            XCTAssertTrue(autoProps.keys.contains(key), "Missing key: \(key)")
        }
    }

    /// Verifies that app properties contain all expected keys
    func testAppPropertiesContainExpectedKeys() {
        // Act
        let appProps = decorator.appProperties

        // Assert
        let expectedKeys: Set<String> = [
            AutoPropertyDecorator.appNameKey,
            AutoPropertyDecorator.appIdentifierKey
        ]

        for key in expectedKeys {
            XCTAssertTrue(appProps.keys.contains(key), "Missing key: \(key)")
        }
    }

}
