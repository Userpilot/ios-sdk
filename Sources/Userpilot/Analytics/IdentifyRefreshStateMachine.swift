//
//  IdentifyRefreshStateMachine.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Owns the policy for `identify` events that carry no new user data ("identify refreshes"):
//  whether to forward one to the backend, and whether a forwarded one still owes a push-token
//  re-assert.
//

import Foundation

/// The facts about an incoming identify event that the refresh policy needs.
///
/// These are computed by `AnalyticsPublisher` from collaborators the state machine deliberately
/// does not own (`DataStoring`, `SocketEvents`), and passed in as one documented value rather than
/// as positional booleans.
internal struct IdentifyRefreshRequest {

    /// The event adds nothing to the cached user (see `User.isSameIdentifyEvent(event:)`).
    let carriesNoNewData: Bool

    /// The event identifies the generated anonymous user, which is excluded from refreshes.
    let isAnonymousUser: Bool

    /// The SDK is replaying a still-pending identify after a socket close, not the host app
    /// calling `identify` again. Replays bypass the per-screen allowance.
    let isPendingReplay: Bool
}

/// What `AnalyticsPublisher` should do with an identify event.
internal enum IdentifyRefreshDecision {

    /// Carries new user data — take the normal path (identify + fake-reload screen event).
    case carriesNewData

    /// Carries nothing new, but forward it so the backend re-affirms the user. No screen event.
    case refresh

    /// Carries nothing new and must be dropped.
    case suppress
}

/**
 * Owns the policy for `identify` events that carry no new user data.
 *
 * Such an event is still forwarded to the backend **once per screen** so the backend can re-affirm
 * the user, and each forwarded refresh owes exactly one push-token re-assert (the token senders are
 * value-guarded, so a returning user whose token is unchanged would otherwise never re-pair
 * token ↔ user).
 *
 * A second, **unmetered** rule lives here too: a screen reload re-sends the identify the host last
 * passed (`recordRequestedIdentify()` → `beginScreenReloadRefresh()`), without reading or spending
 * the allowance above. Both rules answer the same question — "when may the SDK re-send an identify
 * that changes nothing?" — so they are kept together.
 *
 * The allowance lives in a single `State` value. Two independent booleans would allow combinations
 * that cannot occur, and would hide the rule that a screen change must not discard an unsettled
 * token obligation.
 *
 * Thread-safe: identify, screen and socket callbacks arrive from different queues.
 *
 * Mirrored by Android's `IdentifyRefreshStateMachine` — keep both in sync.
 */
internal final class IdentifyRefreshStateMachine {

    /// Lifecycle of the current screen's refresh allowance.
    internal enum State: Equatable {

        /// The current screen has not refreshed the user yet.
        case refreshAllowed

        /// A refresh was forwarded and still owes a push-token re-assert.
        case awaitingPushTokenSync

        /// A refresh was forwarded on this screen and its token sync is done.
        case refreshSettled
    }

    // MARK: - Properties

    private let lock = NSLock()

    private var _state: State = .refreshAllowed

    /// Reload identifies published but not yet resolved by the socket.
    ///
    /// A counter rather than a flag: a screen can reload more than once (two experiences dismissed
    /// in a row), and each reload owes exactly one ack.
    private var outstandingScreenReloadIdentifies = 0

    /// A same-as-cached identify the host passed, with its age in screen changes.
    private struct RequestedIdentify {

        /// The identify to re-send ahead of a reload.
        let event: Event

        /// Screen changes since it was recorded; never exceeds `maxScreenReloadAge`, because
        /// `onScreenChanged()` drops the record instead.
        let screensAgo: Int
    }

    /// The identify the host last passed that carried no new user data, and how many screen
    /// changes ago it arrived. `nil` once it expires, or when the host has passed none.
    ///
    /// Payload and eligibility are one value: a reload needs both, they are set and cleared
    /// together, and pairing them makes an eligible-but-absent identify unrepresentable.
    private var requestedIdentify: RequestedIdentify?

    /// Screen changes a recorded identify stays eligible for: the screen it was recorded on (`0`)
    /// and the one after it (`1`). The grace of one covers the ordering described above.
    private static let maxScreenReloadAge = 1

    /// The current state. Exposed for assertions; callers must not derive control flow from it.
    internal var state: State {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    // MARK: - Transitions

    /**
     * Classifies an incoming identify event and advances the allowance when it is forwarded.
     *
     * - Parameter request: The facts about the incoming identify event.
     * - Returns: The decision `AnalyticsPublisher` should act on.
     */
    internal func transition(_ request: IdentifyRefreshRequest) -> IdentifyRefreshDecision {
        lock.lock()
        defer { lock.unlock() }

        guard request.carriesNoNewData else { return .carriesNewData }

        // `anonymous()` re-sends the same generated id with no properties, so there is nothing to
        // refresh. Suppress without touching the allowance: an anonymous call must not spend the
        // current screen's refresh on behalf of a real user.
        guard !request.isAnonymousUser else { return .suppress }

        // A replay of a still-pending identify is the SDK reconnecting, not the host app calling
        // again. It must go through, and it re-arms the token obligation because the original
        // forward never reached the backend.
        if request.isPendingReplay {
            _state = .awaitingPushTokenSync
            return .refresh
        }

        switch _state {
        case .refreshAllowed:
            _state = .awaitingPushTokenSync
            return .refresh
        case .awaitingPushTokenSync, .refreshSettled:
            return .suppress
        }
    }

    /**
     * Records the identify the host passed carrying no new user data, arming the next screen reload
     * to re-send it.
     *
     * Called whether that identify was forwarded (`.refresh`) or dropped (`.suppress`, once this
     * screen's allowance is spent) — what matters is that the host asked for the user to be
     * re-stated, not whether the allowance had room.
     *
     * Anonymous identifies never reach this: `transition(_:)` drops them before the allowance, so
     * the generated anonymous user can never arm a reload.
     *
     * - Parameter event: The identify to re-send ahead of a reload.
     */
    internal func recordRequestedIdentify(_ event: Event) {
        lock.lock()
        defer { lock.unlock() }

        requestedIdentify = RequestedIdentify(event: event, screensAgo: 0)
    }

    /**
     * Hands back the identify a screen reload should re-state the user with, claiming the ack it
     * will owe.
     *
     * Armed only by `recordRequestedIdentify(_:)` — a reload on a screen where the host never
     * called `identify` goes out alone. Once armed it applies to **every** reload in range, rather
     * than once per screen: by the time an experience is dismissed, the screen's own allowance has
     * normally been spent by the identify that opened it.
     *
     * Deliberately unmetered — it neither reads nor advances `state`, and owes no push-token
     * re-assert. The token ↔ user pairing `consumePushTokenSync()` exists to repair is a
     * returning-user problem; a reload happens mid-session on a user the backend has already seen.
     *
     * - Returns: The identify to publish ahead of the screen event, or `nil` to reload alone.
     */
    internal func beginScreenReloadRefresh() -> Event? {
        lock.lock()
        defer { lock.unlock() }

        // No age check: `onScreenChanged()` drops the record once it expires, so anything held
        // here is eligible by construction.
        guard let recorded = requestedIdentify else { return nil }
        outstandingScreenReloadIdentifies += 1
        return recorded.event
    }

    /**
     * Claims the resolution of an identify sent by `beginScreenReloadRefresh(_:)`, if one is
     * outstanding.
     *
     * A reload identify never enters the analytics queue, so its ack owns no queue head and must
     * not drive the queue — `AnalyticsPublisher` swallows the resolution this claims.
     *
     * - Returns: `true` when the ack belongs to a reload identify.
     */
    internal func consumeScreenReloadIdentifyAck() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard outstandingScreenReloadIdentifies > 0 else { return false }
        outstandingScreenReloadIdentifies -= 1
        return true
    }

    /**
     * Claims the pending push-token re-assert, if one is owed.
     *
     * - Returns: `true` exactly once per forwarded refresh.
     */
    internal func consumePushTokenSync() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard _state == .awaitingPushTokenSync else { return false }
        _state = .refreshSettled
        return true
    }

    /// A genuinely new screen re-opens the refresh allowance and ages the recorded identify.
    internal func onScreenChanged() {
        lock.lock()
        defer { lock.unlock() }

        // Aged before the allowance check below: the recorded identify expires by screen count
        // regardless of whether the allowance is held open by an unsettled token obligation.
        if let recorded = requestedIdentify {
            let aged = recorded.screensAgo + 1
            requestedIdentify = aged <= Self.maxScreenReloadAge
                ? RequestedIdentify(event: recorded.event, screensAgo: aged)
                : nil
        }

        // A pending token sync belongs to an identify that has not reached the backend yet, not to
        // the screen it was requested on. Keep suppressing until it settles — re-sending an
        // identical identify before the first one lands would only add noise.
        guard _state != .awaitingPushTokenSync else { return }
        _state = .refreshAllowed
    }

    /// Logout or user switch: the next user starts with a fresh allowance and owes nothing.
    internal func onUserChanged() {
        lock.lock()
        defer { lock.unlock() }

        _state = .refreshAllowed
        // The socket closes on a user change, so a reload identify in flight will never resolve.
        // Left outstanding, its stale claim would swallow the next user's first identify ack.
        outstandingScreenReloadIdentifies = 0
        // The next user must re-state itself before any reload speaks on its behalf.
        requestedIdentify = nil
    }
}
