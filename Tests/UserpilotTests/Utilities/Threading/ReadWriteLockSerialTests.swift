//
//  ReadWriteLockSerialTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 07/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class ReadWriteLockSerialTests: XCTestCase {

    var lock: ReadWriteLockSerial!

    override func setUp() {
        super.setUp()
        lock = ReadWriteLockSerial(label: "test.readWriteLockSerial")
    }

    override func tearDown() {
        lock = nil
        super.tearDown()
    }

    func testReadReturnsValue() {
        // Act
        let expected = 42
        let result = lock.read {
            return expected
        }

        // Assert
        XCTAssertEqual(result, expected)
    }

    func testWriteReturnsValue() {
        // Act
        let expected = "hello"
        let result = lock.write {
            return expected
        }

        // Assert
        XCTAssertEqual(result, expected)
    }

    func testReadsAndWritesAreSerialized() {
        // Arrange
        var value = 0

        let group = DispatchGroup()

        // Act
        // Write 1 increments value to 1
        group.enter()
        DispatchQueue.global().async {
            self.lock.write {
                value += 1
                Thread.sleep(forTimeInterval: 0.1) // simulate work
            }
            group.leave()
        }

        // Read value after write 1
        group.enter()
        DispatchQueue.global().async {
            let val = self.lock.read {
                return value
            }
            XCTAssertEqual(val, 1)
            group.leave()
        }

        // Write 2 increments value to 2
        group.enter()
        DispatchQueue.global().async {
            self.lock.write {
                value += 1
                Thread.sleep(forTimeInterval: 0.1)
            }
            group.leave()
        }

        // Read value after write 2
        group.enter()
        DispatchQueue.global().async {
            let val = self.lock.read {
                return value
            }
            XCTAssertEqual(val, 2)
            group.leave()
        }

        // Assert
        let result = group.wait(timeout: .now() + 1)
        XCTAssertEqual(result, .success, "All operations should complete")
    }
}
