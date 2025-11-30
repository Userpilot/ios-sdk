//
//  AtomicReferenceTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 23/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest

@testable import Userpilot

class AtomicReferenceTests: XCTestCase {

    // MARK: - Basic Operations Tests

    func testInitialValue() {
        let atomicInt = AtomicReference<Int>(42)
        XCTAssertEqual(atomicInt.value, 42)

        let atomicString = AtomicReference<String>("hello")
        XCTAssertEqual(atomicString.value, "hello")
    }

    func testGetAndSet() {
        let atomic = AtomicReference<String>("initial")
        XCTAssertEqual(atomic.value, "initial")

        atomic.value = "updated"
        XCTAssertEqual(atomic.value, "updated")
    }

    func testGetAndSetWithReturnValue() {
        let atomic = AtomicReference<Int>(10)

        let oldValue = atomic.getAndSet(20)
        XCTAssertEqual(oldValue, 10)
        XCTAssertEqual(atomic.value, 20)
    }

    func testCompareAndSet_Success() {
        let atomic = AtomicReference<String>("expected")

        let success = atomic.compareAndSet(expected: "expected", new: "new")
        XCTAssertTrue(success)
        XCTAssertEqual(atomic.value, "new")
    }

    func testCompareAndSet_Failure() {
        let atomic = AtomicReference<String>("actual")

        let success = atomic.compareAndSet(expected: "different", new: "new")
        XCTAssertFalse(success)
        XCTAssertEqual(atomic.value, "actual")
    }

    func testUpdate() {
        let atomic = AtomicReference<Int>(5)

        let newValue = atomic.update { $0 * 2 }
        XCTAssertEqual(newValue, 10)
        XCTAssertEqual(atomic.value, 10)
    }

    func testRead() {
        let atomic = AtomicReference<String>("test")

        let uppercased = atomic.read { $0.uppercased() }
        XCTAssertEqual(uppercased, "TEST")
        XCTAssertEqual(atomic.value, "test")  // Original value unchanged
    }

    // MARK: - Thread Safety Tests

    func testThreadSafety_ConcurrentWrites() {
        let atomic = AtomicReference<Int>(0)
        let iterations = 1000
        let expectation = self.expectation(description: "All threads complete")
        let group = DispatchGroup()

        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                atomic.update { $0 + 1 }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(atomic.value, iterations)
    }

    func testThreadSafety_ConcurrentReadsAndWrites() {
        let atomic = AtomicReference<Int>(0)
        let writeIterations = 500
        let readIterations = 500
        let expectation = self.expectation(description: "All operations complete")
        let group = DispatchGroup()

        // Writers
        for _ in 0..<writeIterations {
            group.enter()
            DispatchQueue.global().async {
                atomic.update { $0 + 1 }
                group.leave()
            }
        }

        // Readers
        for _ in 0..<readIterations {
            group.enter()
            DispatchQueue.global().async {
                _ = atomic.value
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(atomic.value, writeIterations)
    }

    func testThreadSafety_CompareAndSet() {
        let atomic = AtomicReference<Int>(0)
        let iterations = 100
        let expectation = self.expectation(description: "All CAS operations complete")
        let group = DispatchGroup()
        var successCount = 0
        let lock = NSLock()

        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                var attempts = 0
                var success = false
                while !success && attempts < 100 {
                    let current = atomic.value
                    success = atomic.compareAndSet(expected: current, new: current + 1)
                    attempts += 1
                }

                if success {
                    lock.lock()
                    successCount += 1
                    lock.unlock()
                }

                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(atomic.value, iterations)
        XCTAssertEqual(successCount, iterations)
    }

    // MARK: - Complex Type Tests

    func testWithCustomStruct() {
        struct Counter {
            var count: Int
            var name: String
        }

        let atomic = AtomicReference<Counter>(Counter(count: 0, name: "test"))

        atomic.update { counter in
            var updated = counter
            updated.count += 1
            return updated
        }

        let result = atomic.read { $0 }
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.name, "test")
    }

    func testWithOptionalValue() {
        let atomic = AtomicReference<String?>(nil)
        XCTAssertNil(atomic.value)

        atomic.value = "not nil"
        XCTAssertEqual(atomic.value, "not nil")

        atomic.value = nil
        XCTAssertNil(atomic.value)
    }

    func testWithArrayValue() {
        let atomic = AtomicReference<[Int]>([1, 2, 3])

        atomic.update { array in
            var newArray = array
            newArray.append(4)
            return newArray
        }

        XCTAssertEqual(atomic.value, [1, 2, 3, 4])
    }
}
