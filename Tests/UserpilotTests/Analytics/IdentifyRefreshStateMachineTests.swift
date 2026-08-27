//
//  IdentifyRefreshStateMachineTests.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class IdentifyRefreshStateMachineTests: XCTestCase {

    private var sut: IdentifyRefreshStateMachine!

    override func setUp() {
        super.setUp()
        sut = IdentifyRefreshStateMachine()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// An identify that adds nothing to the cached user — the case the policy exists for.
    private func unchangedIdentify() -> IdentifyRefreshRequest {
        IdentifyRefreshRequest(carriesNoNewData: true, isAnonymousUser: false, isPendingReplay: false)
    }

    private func changedIdentify() -> IdentifyRefreshRequest {
        IdentifyRefreshRequest(carriesNoNewData: false, isAnonymousUser: false, isPendingReplay: false)
    }

    private func anonymousIdentify() -> IdentifyRefreshRequest {
        IdentifyRefreshRequest(carriesNoNewData: true, isAnonymousUser: true, isPendingReplay: false)
    }

    private func pendingReplay() -> IdentifyRefreshRequest {
        IdentifyRefreshRequest(carriesNoNewData: true, isAnonymousUser: false, isPendingReplay: true)
    }

    /// Drives the machine to `.refreshSettled`: one forwarded refresh whose token sync completed.
    private func settleARefresh() {
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)
        XCTAssertTrue(sut.consumePushTokenSync())
        XCTAssertEqual(sut.state, .refreshSettled)
    }

    // MARK: - Initial state

    func testNewMachineAllowsARefreshAndOwesNoTokenSync() {
        XCTAssertEqual(sut.state, .refreshAllowed)
        XCTAssertFalse(sut.consumePushTokenSync())
    }

    // MARK: - Events carrying new data

    func testIdentifyWithNewDataTakesTheNormalPathAndDoesNotSpendTheAllowance() {
        XCTAssertEqual(sut.transition(changedIdentify()), .carriesNewData)
        XCTAssertEqual(sut.state, .refreshAllowed)

        // The allowance must survive: an unchanged identify on this same screen is still owed a
        // refresh. If `carriesNewData` consumed the allowance this would come back `.suppress`.
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)
    }

    // MARK: - Anonymous users

    func testAnonymousIdentifyIsSuppressedWithoutSpendingTheScreenAllowance() {
        XCTAssertEqual(sut.transition(anonymousIdentify()), .suppress)
        XCTAssertEqual(sut.state, .refreshAllowed)

        // An `anonymous()` call must not burn a real user's refresh for this screen.
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)
        XCTAssertEqual(sut.state, .awaitingPushTokenSync)
    }

    func testAnonymousIdentifyIsSuppressedEvenWhileATokenSyncIsOutstanding() {
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)

        XCTAssertEqual(sut.transition(anonymousIdentify()), .suppress)
        // The outstanding obligation is untouched by the anonymous call.
        XCTAssertEqual(sut.state, .awaitingPushTokenSync)
        XCTAssertTrue(sut.consumePushTokenSync())
    }

    // MARK: - Once per screen

    func testFirstUnchangedIdentifyOnAScreenIsForwardedAndOwesATokenSync() {
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)
        XCTAssertEqual(sut.state, .awaitingPushTokenSync)
    }

    func testSecondUnchangedIdentifyOnTheSameScreenIsSuppressed() {
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)

        XCTAssertEqual(sut.transition(unchangedIdentify()), .suppress)
        XCTAssertEqual(sut.state, .awaitingPushTokenSync)
    }

    func testUnchangedIdentifyIsStillSuppressedOnTheSameScreenAfterTheTokenSyncSettles() {
        settleARefresh()

        XCTAssertEqual(sut.transition(unchangedIdentify()), .suppress)
        XCTAssertEqual(sut.state, .refreshSettled)
    }

    // MARK: - Pending replay

    func testPendingReplayIsForwardedEvenWhenTheScreenAllowanceIsAlreadySpent() {
        settleARefresh()

        // The SDK reconnecting must not be throttled by the host app's per-screen allowance.
        XCTAssertEqual(sut.transition(pendingReplay()), .refresh)
    }

    func testPendingReplayReArmsTheTokenObligationBecauseTheFirstForwardNeverLanded() {
        settleARefresh()

        XCTAssertEqual(sut.transition(pendingReplay()), .refresh)
        XCTAssertEqual(sut.state, .awaitingPushTokenSync)
        XCTAssertTrue(sut.consumePushTokenSync())
    }

    func testAnonymousPendingReplayIsStillSuppressed() {
        // Anonymous is checked before the replay bypass — a generated id has nothing to refresh.
        let anonymousReplay = IdentifyRefreshRequest(
            carriesNoNewData: true,
            isAnonymousUser: true,
            isPendingReplay: true
        )

        XCTAssertEqual(sut.transition(anonymousReplay), .suppress)
        XCTAssertEqual(sut.state, .refreshAllowed)
    }

    // MARK: - Push token obligation

    func testTokenSyncIsClaimableExactlyOncePerForwardedRefresh() {
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)

        XCTAssertTrue(sut.consumePushTokenSync())
        XCTAssertFalse(sut.consumePushTokenSync())
        XCTAssertEqual(sut.state, .refreshSettled)
    }

    func testTokenSyncIsNotClaimableWhenNoRefreshWasForwarded() {
        // `.refreshAllowed` — nothing forwarded yet.
        XCTAssertFalse(sut.consumePushTokenSync())

        // `.carriesNewData` takes the normal path and owes no re-assert of its own.
        XCTAssertEqual(sut.transition(changedIdentify()), .carriesNewData)
        XCTAssertFalse(sut.consumePushTokenSync())
    }

    // MARK: - Screen changes

    func testScreenChangeReopensTheAllowanceOnceTheTokenSyncHasSettled() {
        settleARefresh()

        sut.onScreenChanged()
        XCTAssertEqual(sut.state, .refreshAllowed)
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)
    }

    func testScreenChangeDoesNotDiscardAnUnsettledTokenObligation() {
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)
        XCTAssertEqual(sut.state, .awaitingPushTokenSync)

        // Deliberate: the obligation belongs to an identify that has not reached the backend yet,
        // not to the screen it was requested on. Re-sending before the first one lands is noise.
        sut.onScreenChanged()

        XCTAssertEqual(sut.state, .awaitingPushTokenSync)
        XCTAssertEqual(sut.transition(unchangedIdentify()), .suppress)
        XCTAssertTrue(sut.consumePushTokenSync())
    }

    func testAllowanceReopensOnTheScreenChangeThatFollowsAResolvedObligation() {
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)

        // Screen change while the obligation is outstanding: held.
        sut.onScreenChanged()
        XCTAssertEqual(sut.transition(unchangedIdentify()), .suppress)

        // Obligation settles, then the next screen change reopens the allowance.
        XCTAssertTrue(sut.consumePushTokenSync())
        sut.onScreenChanged()

        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)
    }

    func testRepeatedScreenChangesDoNotAccumulateExtraRefreshes() {
        sut.onScreenChanged()
        sut.onScreenChanged()
        sut.onScreenChanged()

        // A screen change opens one allowance, not one per call.
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)
        XCTAssertEqual(sut.transition(unchangedIdentify()), .suppress)
    }

    // MARK: - User changes

    func testUserChangeResetsTheAllowanceFromASettledRefresh() {
        settleARefresh()

        sut.onUserChanged()

        XCTAssertEqual(sut.state, .refreshAllowed)
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)
    }

    func testUserChangeClearsAnUnsettledTokenObligation() {
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)
        XCTAssertEqual(sut.state, .awaitingPushTokenSync)

        // Logout / user switch: the previous user's obligation must not follow the next user.
        sut.onUserChanged()

        XCTAssertEqual(sut.state, .refreshAllowed)
        XCTAssertFalse(sut.consumePushTokenSync())
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)
    }

    // MARK: - Thread safety

    func testConcurrentTransitionsForwardExactlyOneRefresh() {
        let iterations = 200
        let lock = NSLock()
        var refreshCount = 0

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            let decision = self.sut.transition(self.unchangedIdentify())
            lock.lock()
            if decision == .refresh { refreshCount += 1 }
            lock.unlock()
        }

        // The whole point of the allowance: one forwarded refresh, no matter how many callers race.
        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(sut.state, .awaitingPushTokenSync)
    }

    func testConcurrentTokenSyncClaimsSucceedExactlyOnce() {
        XCTAssertEqual(sut.transition(unchangedIdentify()), .refresh)

        let iterations = 200
        let lock = NSLock()
        var claims = 0

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            let claimed = self.sut.consumePushTokenSync()
            lock.lock()
            if claimed { claims += 1 }
            lock.unlock()
        }

        // A double claim would publish the push token twice for one identify refresh.
        XCTAssertEqual(claims, 1)
        XCTAssertEqual(sut.state, .refreshSettled)
    }
}
