//
//  ReadWriteLockTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 07/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class ReadWriteLockTests: XCTestCase {

    var lock: ReadWriteLock!

    override func setUp() {
        super.setUp()
        lock = ReadWriteLock()
    }

    override func tearDown() {
        lock = nil
        super.tearDown()
    }

    func testConcurrentReads() {
        // Arrange
        let expectation1 = expectation(description: "read 1")
        let expectation2 = expectation(description: "read 2")

        // Act
        // Both reads should execute immediately and concurrently (or at least without blocking)
        lock.read {
            expectation1.fulfill()
        }
        lock.read {
            expectation2.fulfill()
        }

        // Assert
        wait(for: [expectation1, expectation2], timeout: 1)
    }

    func testWriteBlocksReads() {
        // Arrange
        let writeStarted = expectation(description: "write started")
        let writeFinished = expectation(description: "write finished")
        let readBlocked = expectation(description: "read blocked until write finished")

        var value = 0

        // Act
        // Start write operation with a delay inside closure
        lock.write {
            value = 42
            writeStarted.fulfill()
            // Sleep 0.2 sec to simulate long write
            Thread.sleep(forTimeInterval: 0.2)
            writeFinished.fulfill()
        }

        // Start read after slight delay, it should wait until write is done
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            self.lock.read {
                XCTAssertEqual(value, 42)
                readBlocked.fulfill()
            }
        }

        // Assert
        wait(for: [writeStarted, writeFinished, readBlocked], timeout: 1)
    }

    func testWritesAreExclusiveAndSerialized() {
        // Arrange
        let write1Started = expectation(description: "write1 started")
        let write1Finished = expectation(description: "write1 finished")
        let write2Started = expectation(description: "write2 started")
        let write2Finished = expectation(description: "write2 finished")

        var value = 0

        // Act
        lock.write {
            value = 1
            write1Started.fulfill()
            Thread.sleep(forTimeInterval: 0.2)
            write1Finished.fulfill()
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            self.lock.write {
                XCTAssertEqual(value, 1)
                value = 2
                write2Started.fulfill()
                Thread.sleep(forTimeInterval: 0.1)
                write2Finished.fulfill()
            }
        }

        // Assert
        wait(for: [write1Started, write1Finished, write2Started, write2Finished], timeout: 2)
        XCTAssertEqual(value, 2)
    }
}
