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
 * All state lives in a single `State` value. Two independent booleans would allow combinations that
 * cannot occur, and would hide the rule that a screen change must not discard an unsettled token
 * obligation.
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

    /// A genuinely new screen re-opens the refresh allowance.
    internal func onScreenChanged() {
        lock.lock()
        defer { lock.unlock() }

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
    }
}
