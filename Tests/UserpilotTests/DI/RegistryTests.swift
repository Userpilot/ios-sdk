//
//  RegistryTests.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class RegistryTests: XCTestCase {

    override func setUpWithError() throws {
        // Each test starts with a clean registry so cross-test order does not
        // leak stale weak entries into `default` / `instance(forToken:)` lookups.
        Userpilot.Registry.shared.resetForTesting()
    }

    override func tearDownWithError() throws {
        Userpilot.Registry.shared.resetForTesting()
    }

    // MARK: - Default slot

    func testRegister_plainConfigBecomesDefault() throws {
        // A plain Config has `isDefault == true`, so the (only) instance claims the
        // default role on registration.
        let mock = MockUserpilot(config: Userpilot.Config(token: "TOKEN-A"))
        XCTAssertTrue(Userpilot.Registry.shared.default === mock)
        XCTAssertTrue(Userpilot.shared === mock)
        _ = mock // keep alive
    }

    func testRegister_noDefaultWhenAllInstancesOptOut() throws {
        // Default resolution is claim-only with no first-registered fallback. If
        // every live instance opts out via `defaultInstance(false)`, there is no
        // default at all and `Userpilot.shared` is `nil`. Each instance is still
        // reachable by token. (This is a misconfiguration in practice: the host
        // app is expected to keep the `isDefault` default of `true`.)
        let first = MockUserpilot(config: Userpilot.Config(token: "TOKEN-A").defaultInstance(false))
        let second = MockUserpilot(config: Userpilot.Config(token: "TOKEN-B").defaultInstance(false))

        XCTAssertNil(Userpilot.shared, "No instance claimed the default role")
        XCTAssertTrue(Userpilot.instance(forToken: "TOKEN-A") === first)
        XCTAssertTrue(Userpilot.instance(forToken: "TOKEN-B") === second)
        _ = first
        _ = second
    }

    func testRegister_plainConfigClaimsExplicitDefaultByDefault() throws {
        // `isDefault` now defaults to `true`, so a host app that does nothing special
        // claims the explicit-default role on registration — order-independent.
        let host = MockUserpilot(config: Userpilot.Config(token: "HOST"))
        let vendor = MockUserpilot(config: Userpilot.Config(token: "VENDOR").defaultInstance(false))

        XCTAssertTrue(Userpilot.shared === host,
                      "A plain Config must claim the explicit default by default")
        XCTAssertTrue(Userpilot.instance(forToken: "VENDOR") === vendor)
        _ = host
        _ = vendor
    }

    // MARK: - Lookup

    func testInstanceForToken_returnsRegisteredInstance() throws {
        let mockA = MockUserpilot(config: Userpilot.Config(token: "TOKEN-A"))
        let mockB = MockUserpilot(config: Userpilot.Config(token: "TOKEN-B"))

        XCTAssertTrue(Userpilot.instance(forToken: "TOKEN-A") === mockA)
        XCTAssertTrue(Userpilot.instance(forToken: "TOKEN-B") === mockB)
        XCTAssertNil(Userpilot.instance(forToken: "TOKEN-UNKNOWN"))
    }

    func testAllInstances_excludesDeallocated() throws {
        let mockA = MockUserpilot(config: Userpilot.Config(token: "TOKEN-A"))

        autoreleasepool {
            _ = MockUserpilot(config: Userpilot.Config(token: "TOKEN-DEALLOC"))
            // mock goes out of scope at the end of the autorelease pool
        }

        let live = Userpilot.Registry.shared.allInstances
        XCTAssertEqual(live.count, 1)
        XCTAssertTrue(live.first === mockA)
        _ = mockA
    }

    // MARK: - Weak references

    func testRegistry_doesNotRetainInstances() throws {
        weak var weakRef: MockUserpilot?

        autoreleasepool {
            let mock = MockUserpilot(config: Userpilot.Config(token: "TOKEN-WEAK"))
            weakRef = mock
            XCTAssertNotNil(weakRef)
        }

        // Drain main queue once so any deferred work releases the instance.
        let exp = expectation(description: "drain")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertNil(weakRef, "Registry must hold instances weakly so their natural lifetime is not extended")
    }

    // MARK: - Idempotent init

    func testDoubleInit_sameToken_returnsExistingInstanceFromRegistry() throws {
        // Idempotent factory ("get-or-create"): a second `Userpilot(config:)` call
        // with the same token MUST NOT replace the registry entry. The first
        // instance stays canonical; the second is allowed to construct (it
        // simply adopts the existing container — see `Userpilot.init(config:)`)
        // but does NOT take over the registry slot.
        let first = MockUserpilot(config: Userpilot.Config(token: "TOKEN-DUP"))
        _ = MockUserpilot(config: Userpilot.Config(token: "TOKEN-DUP"))

        XCTAssertTrue(Userpilot.instance(forToken: "TOKEN-DUP") === first)
        XCTAssertTrue(Userpilot.shared === first)
        _ = first
    }

    // MARK: - Registration index

    func testRegistrationIndex_isStableAcrossLookups() throws {
        let mockA = MockUserpilot(config: Userpilot.Config(token: "ORDER-A"))
        let mockB = MockUserpilot(config: Userpilot.Config(token: "ORDER-B"))

        XCTAssertEqual(Userpilot.Registry.shared.registrationIndex(forToken: "ORDER-A"), 0)
        XCTAssertEqual(Userpilot.Registry.shared.registrationIndex(forToken: "ORDER-B"), 1)
        _ = mockA
        _ = mockB
    }

    // MARK: - Explicit `isDefault` claims

    func testRegister_explicitDefaultIsSelectedRegardlessOfOrder() throws {
        // The default role is claim-based and order-independent: an instance that
        // opts in via `Config.defaultInstance(true)` is the default even when
        // another instance registered earlier (that earlier instance opted out).
        let first = MockUserpilot(config: Userpilot.Config(token: "TOKEN-A").defaultInstance(false))
        let explicit = MockUserpilot(
            config: Userpilot.Config(token: "TOKEN-B").defaultInstance()
        )

        XCTAssertTrue(Userpilot.shared === explicit,
                      "The isDefault claimant must be the default, regardless of registration order")
        _ = first
        _ = explicit
    }

    func testRegister_secondExplicitClaimIsRejected() throws {
        // Conflict policy: first claim wins. A second instance that opts in
        // with `defaultInstance(true)` does NOT displace the existing
        // claimant — `Userpilot.shared` continues to return the first.
        let firstClaim = MockUserpilot(
            config: Userpilot.Config(token: "TOKEN-A").defaultInstance()
        )
        let secondClaim = MockUserpilot(
            config: Userpilot.Config(token: "TOKEN-B").defaultInstance()
        )

        XCTAssertTrue(Userpilot.shared === firstClaim,
                      "First isDefault claim wins; later claims must be ignored")
        XCTAssertTrue(Userpilot.instance(forToken: "TOKEN-B") === secondClaim)
        _ = firstClaim
        _ = secondClaim
    }

    func testUnregister_releasesDefaultRoleSoDefaultBecomesNil() throws {
        // When the default claimant is unregistered (e.g. deallocated), the role
        // re-opens. With no first-registered fallback, `default` becomes `nil`
        // until another instance claims it — never a stale weak reference. The
        // other live instance opted out, so it is NOT auto-promoted.
        let optedOut = MockUserpilot(config: Userpilot.Config(token: "TOKEN-A").defaultInstance(false))

        autoreleasepool {
            let explicit = MockUserpilot(
                config: Userpilot.Config(token: "TOKEN-EXPLICIT").defaultInstance()
            )
            // While alive: explicit holds the default role.
            XCTAssertTrue(Userpilot.shared === explicit)
            // `explicit` goes out of scope at the end of the autorelease pool.
        }

        // Drain main queue so the weak reference clears.
        let exp = expectation(description: "drain")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertNil(Userpilot.shared,
                     "After the claimant deallocates and the other instance opted out, there is no default")
        _ = optedOut
    }

    // MARK: - Concurrent access

    func testRegistry_concurrentReadsDoNotDeadlock() throws {
        let mockA = MockUserpilot(config: Userpilot.Config(token: "CONCURRENT-A"))
        _ = mockA

        let exp = expectation(description: "concurrent reads")
        exp.expectedFulfillmentCount = 50

        for _ in 0..<50 {
            DispatchQueue.global().async {
                _ = Userpilot.Registry.shared.default
                _ = Userpilot.Registry.shared.allInstances
                _ = Userpilot.Registry.shared.instance(forToken: "CONCURRENT-A")
                exp.fulfill()
            }
        }

        wait(for: [exp], timeout: 2.0)
    }
}

// swiftlint:enable all
