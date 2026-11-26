//
//  InstanceRegistryTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Covers weak membership, explicit default claims, registration order and identity-based removal.
//

import XCTest
@testable import Userpilot

final class InstanceRegistryTests: XCTestCase {

    /// Isolated from the process runtime so each test owns the default claim order.
    private var registry: InstanceRegistry!

    override func setUp() {
        super.setUp()
        registry = InstanceRegistry()
    }

    override func tearDown() {
        registry = nil
        super.tearDown()
    }

    // MARK: - Default slot

    func testRegister_plainConfigBecomesDefault() {
        let instance = makeInstance("A")

        XCTAssertNil(registry.register(instance))
        XCTAssertTrue(registry.default === instance)
    }

    func testRegister_noDefaultWhenAllInstancesOptOut() {
        // Claim-only default: no first-registered fallback, every instance stays reachable by token.
        let first = makeInstance("A", isDefault: false)
        let second = makeInstance("B", isDefault: false)
        registry.register(first)
        registry.register(second)

        XCTAssertNil(registry.default, "No instance claimed the default role")
        XCTAssertTrue(registry.instance(forToken: first.config.token) === first)
        XCTAssertTrue(registry.instance(forToken: second.config.token) === second)
    }

    func testRegister_plainConfigClaimsExplicitDefaultByDefault() {
        let host = makeInstance("HOST")
        let vendor = makeInstance("VENDOR", isDefault: false)
        registry.register(host)
        registry.register(vendor)

        XCTAssertTrue(registry.default === host, "A plain Config must claim the explicit default by default")
        XCTAssertTrue(registry.instance(forToken: vendor.config.token) === vendor)
    }

    func testRegister_explicitDefaultIsSelectedRegardlessOfOrder() {
        let first = makeInstance("A", isDefault: false)
        let explicit = makeInstance("B")
        registry.register(first)
        registry.register(explicit)

        XCTAssertTrue(registry.default === explicit,
                      "The isDefault claimant must be the default, regardless of registration order")
    }

    func testRegister_secondExplicitClaimIsRejected() {
        let firstClaim = makeInstance("A")
        let secondClaim = makeInstance("B")
        registry.register(firstClaim)

        XCTAssertEqual(registry.register(secondClaim), firstClaim.config.token,
                       "The rejected claim reports the existing claimant so the runtime can warn")
        XCTAssertTrue(registry.default === firstClaim, "First isDefault claim wins; later claims must be ignored")
        XCTAssertTrue(registry.isRegistered(secondClaim), "A rejected default claim still registers the instance")
    }

    func testUnregister_releasesDefaultRoleSoDefaultBecomesNil() {
        let optedOut = makeInstance("A", isDefault: false)
        registry.register(optedOut)
        autoreleasepool {
            let explicit = makeInstance("EXPLICIT")
            registry.register(explicit)
            XCTAssertTrue(registry.default === explicit)
        }

        XCTAssertNil(registry.default,
                     "After the claimant deallocates and the other instance opted out, there is no default")

        let nextClaim = makeInstance("NEXT")
        XCTAssertNil(registry.register(nextClaim), "The released role is open to the next claimant")
        XCTAssertTrue(registry.default === nextClaim)
    }

    // MARK: - Lookup

    func testInstanceForToken_returnsRegisteredInstance() {
        let first = makeInstance("A")
        let second = makeInstance("B")
        registry.register(first)
        registry.register(second)

        XCTAssertTrue(registry.instance(forToken: first.config.token) === first)
        XCTAssertTrue(registry.instance(forToken: second.config.token) === second)
        XCTAssertNil(registry.instance(forToken: "TOKEN-UNKNOWN"))
    }

    func testAllInstances_excludesDeallocatedAndKeepsRegistrationOrder() {
        let first = makeInstance("A")
        registry.register(first)
        autoreleasepool {
            _ = registry.register(makeInstance("DEALLOC"))
        }
        let last = makeInstance("C")
        registry.register(last)

        let live = registry.allInstances
        XCTAssertEqual(live.count, 2)
        XCTAssertTrue(live.first === first)
        XCTAssertTrue(live.last === last)
    }

    func testRegistry_doesNotRetainInstances() {
        weak var weakInstance: MockUserpilot?
        autoreleasepool {
            let instance = makeInstance("WEAK")
            registry.register(instance)
            weakInstance = instance
            XCTAssertNotNil(weakInstance)
        }

        XCTAssertNil(weakInstance, "Registry must hold instances weakly so their natural lifetime is not extended")
    }

    // MARK: - Registration order

    func testRegistrationIndex_isStableAcrossLookups() {
        let first = makeInstance("ORDER-A")
        let second = makeInstance("ORDER-B")
        registry.register(first)
        registry.register(second)

        XCTAssertEqual(registry.registrationIndex(forToken: first.config.token), 0)
        XCTAssertEqual(registry.registrationIndex(forToken: second.config.token), 1)
        XCTAssertEqual(registry.registrationIndex(forToken: first.config.token), 0)
    }

    func testUnregister_compactsRegistrationOrder() {
        let first = makeInstance("A")
        let removed = makeInstance("B")
        let last = makeInstance("C")
        [first, removed, last].forEach { registry.register($0) }

        registry.unregister(removed)

        XCTAssertNil(registry.registrationIndex(forToken: removed.config.token))
        XCTAssertEqual(registry.registrationIndex(forToken: last.config.token), 1)
        XCTAssertEqual(registry.allInstances.map(\.config.token), [first.config.token, last.config.token])
    }

    // MARK: - Identity

    func testUnregisteringUnregisteredObject_keepsTheOwnerRegistered() {
        let owner = makeInstance("OWNER")
        registry.register(owner)
        let unregistered = makeInstance("UNREGISTERED")
        XCTAssertFalse(unregistered === owner)

        registry.unregister(unregistered)

        XCTAssertTrue(registry.instance(forToken: owner.config.token) === owner)
        XCTAssertTrue(registry.isRegistered(owner))
        XCTAssertFalse(registry.isRegistered(unregistered))
        XCTAssertTrue(registry.default === owner)
    }

    func testLateUnregisterOfReplacedInstance_keepsTheReplacement() {
        // Weak references clear before deinit runs, so a replacement can register under the
        // token before the released instance's deinit reaches unregister.
        let replaced = makeInstance("REPLACED")
        UserpilotRuntime.shared.removeInstance(replaced)
        let replacement = MockUserpilot.make(config: Userpilot.Config(token: replaced.config.token))
        XCTAssertFalse(replacement === replaced, "Precondition: a replacement is a different object")
        registry.register(replaced)
        registry.register(replacement)

        XCTAssertFalse(registry.isRegistered(replaced))
        registry.unregister(replaced)

        XCTAssertTrue(registry.instance(forToken: replacement.config.token) === replacement)
        XCTAssertTrue(registry.isRegistered(replacement))
    }

    // MARK: - Concurrent access

    func testRegistry_concurrentReadsDoNotDeadlock() {
        let instance = makeInstance("CONCURRENT")
        registry.register(instance)
        let token = instance.config.token
        let reads = expectation(description: "concurrent reads")
        reads.expectedFulfillmentCount = 50

        for _ in 0..<50 {
            DispatchQueue.global().async { [registry] in
                _ = registry?.default
                _ = registry?.allInstances
                _ = registry?.instance(forToken: token)
                reads.fulfill()
            }
        }

        wait(for: [reads], timeout: 2.0)
    }

    // MARK: - Helpers

    private func makeInstance(_ name: String, isDefault: Bool = true) -> MockUserpilot {
        MockUserpilot.make(config: Userpilot.Config(token: "\(name)-\(UUID().uuidString)").defaultInstance(isDefault))
    }
}
