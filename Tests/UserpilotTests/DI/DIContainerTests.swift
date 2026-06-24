//
//  DIContainerTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class DIContainerTests: XCTestCase {

    func testRegisterValueResolvesAndCanBeOverridden() {
        let container = DIContainer()

        container.register(String.self, value: "first")
        XCTAssertEqual(container.resolve(String.self), "first")

        container.register(String.self, value: "second")
        XCTAssertEqual(container.resolve(String.self), "second")
    }

    func testLazyRegistrationInitializesOnFirstResolveAndReusesInstance() {
        let container = DIContainer()
        var initializerCallCount = 0

        container.registerLazy(CountingService.self) {
            initializerCallCount += 1
            return CountingService(id: initializerCallCount)
        }

        XCTAssertEqual(initializerCallCount, 0)

        let first = container.resolve(CountingService.self)
        let second = container.resolve(CountingService.self)

        XCTAssertTrue(first === second)
        XCTAssertEqual(first.id, 1)
        XCTAssertEqual(initializerCallCount, 1)
    }

    func testContainerAwareLazyRegistrationReceivesSameContainer() {
        let container = DIContainer()
        container.register(String.self, value: "dependency")

        container.registerLazy(DependentService.self) { resolver in
            DependentService(value: resolver.resolve(String.self))
        }

        XCTAssertEqual(container.resolve(DependentService.self).value, "dependency")
    }

    func testEagerRegistrationInitializesImmediatelyAndCachesInstance() {
        let container = DIContainer()
        var initializerCallCount = 0

        container.registerEager(CountingService.self) { _ in
            initializerCallCount += 1
            return CountingService(id: initializerCallCount)
        }

        XCTAssertEqual(initializerCallCount, 1)

        let first = container.resolve(CountingService.self)
        let second = container.resolve(CountingService.self)

        XCTAssertTrue(first === second)
        XCTAssertEqual(first.id, 1)
        XCTAssertEqual(initializerCallCount, 1)
    }

    func testConcurrentResolveOfRegisteredValueKeepsContainerConsistent() {
        let container = DIContainer()
        let group = DispatchGroup()
        let lock = NSLock()
        var resolvedValues: [Int] = []

        container.register(Int.self, value: 42)
        XCTAssertEqual(container.resolve(Int.self), 42)

        for _ in 0..<100 {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let value = container.resolve(Int.self)
                lock.lock()
                resolvedValues.append(value)
                lock.unlock()
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(resolvedValues.count, 100)
        XCTAssertTrue(resolvedValues.allSatisfy { $0 == 42 })
    }
}

private final class CountingService {
    let id: Int

    init(id: Int) {
        self.id = id
    }
}

private final class DependentService {
    let value: String

    init(value: String) {
        self.value = value
    }
}
