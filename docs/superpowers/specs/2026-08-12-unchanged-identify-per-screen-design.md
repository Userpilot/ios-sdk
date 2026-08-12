# Identify refresh — forward an unchanged `identify` once per screen, re-assert the push token

**Date:** 2026-08-12
**Platforms:** iOS (`ios-sdk`) **and** Android (`userpilot-android-sdk`) — one design, mirrored
**Public API impact:** none on either platform (no new/changed `@objc` or public Kotlin surface, no config option)

Vocabulary used throughout: an **identify refresh** is an `identify` event that carries no new user
data but is forwarded anyway so the backend re-affirms the user. It is not a "duplicate" — the SDK
sends it on purpose.

---

## 1. Current behaviour (identical on both platforms)

**iOS** — [`AnalyticsPublisher.didHandleIdentifyEvent`](../../../Sources/Userpilot/Analytics/AnalyticsPublisher.swift#L341-L354):

```swift
guard !(storage.user.isNotEmpty && User.fromJson(storage.user).isSameIdentifyEvent(event: event)) else {
    return true   // ignore
}
```

**Android** — [`AnalyticsPublisher.handleIdentifyEvent`](../../../../userpilot-android-sdk/userpilot/src/main/java/com/userpilot/analytics/AnalyticsPublisher.kt#L258-L269):

```kotlin
if (storage.user.isNotEmpty() && storage.user.toUser().isSameIdentifyEvent(event)) {
    return true   // ignore
}
```

`User.isSameIdentifyEvent` uses **partial-update** semantics on both platforms — the event's
properties/company must be a *subset* of the cached user with equal values. So "identical" really
means *"adds nothing to the cached user"*.

Three consequences of the unconditional drop:

1. **The backend never sees the identify.** `storage.user` survives process death (UserDefaults /
   SharedPreferences), so on a warm launch an app that identifies the same user produces no
   `identify` frame for the entire session.
2. **The drop happens before the socket-state guards**, so `handleClosedSocket` → connect never
   runs for it either.
3. **The device push token is never re-asserted.** Both platforms value-guard the token send —
   iOS [`setPushToken`](../../../Sources/Userpilot/PushNotification/PushNotificationMonitor.swift#L99-L117)
   (`storage.pushToken != newToken`), Android
   [`sendFCMToken` / `checkFCMToken`](../../../../userpilot-android-sdk/userpilot/src/main/java/com/userpilot/pushNotifications/PushNotificationHandler.kt)
   (`it != storage.pushNotificationToken`, checked twice). A returning user whose token has not
   changed can never re-pair token ↔ user on the backend.

For an identify that **does** carry new data with the same `userId`, both publishers call
`flushPriorityEvents(fakeReloadScreenEvent: true)`, which publishes the `identify` frame **and** a
screen frame with `fake_reload: true` + `is_session_start` + `seen_contents` + `seen_surveys`. That
screen frame is what drives backend experience re-evaluation.

---

## 2. Goal

An `identify` from the host app that carries no new user data must:

- still reach the backend, **at most once per screen**;
- **also re-publish the push token event** (`user_token`);
- **not** emit the fake-reload screen frame (nothing changed ⇒ nothing to re-evaluate);
- **not apply to anonymous users** — `anonymous()` keeps today's drop-it behaviour.

## 3. Decisions

| # | Decision | Chosen |
|---|---|---|
| 1 | When is `user_token` re-published? | Only when the refresh is actually forwarded. Property-change identifies keep today's value-guarded token behaviour. |
| 2 | What re-opens the once-per-screen allowance? | A genuine **screen change**, and **logout / user switch**. *Not* app foreground. |
| 3 | Refresh while the socket is closed (cold start)? | Cache it, open the socket, let `onSocketOpened` flush it; the token sync fires after that flush. |
| 4 | Anonymous users | **Excluded.** A refresh request for the anonymous id is suppressed and does **not** consume the screen allowance. |
| 5 | Where does the state live? | A dedicated `IdentifyRefreshStateMachine` per SDK instance — one enum value, no boolean flags. |

---

## 4. `IdentifyRefreshStateMachine` — the shared design

### 4.1 Why a state machine and not two booleans

The naive implementation needs two independent facts: *"has this screen already refreshed?"* and
*"does a forwarded refresh still owe a token sync?"*. Two booleans make four combinations, one of
which is nonsense (`settled && !forwarded`), and they hide an ordering rule that is easy to get
wrong: **a screen change must not silently discard an unsettled token obligation.** Folding both
into a single three-state value makes the illegal combination unrepresentable and turns that
ordering rule into an explicit transition.

Android already has the precedent — [`ScreenSessionStateMachine`](../../../../userpilot-android-sdk/userpilot/src/main/java/com/userpilot/analytics/ScreenSessionStateMachine.kt)
is a `@Synchronized internal class`, Koin-`scoped`, constructor-injected into `AnalyticsPublisher`,
exposing `transition(...)` plus intent-named mutators and a sealed decision type. The new machine
follows that shape exactly, and iOS gets the same class so the two SDKs read the same.

### 4.2 States

| State | Meaning |
|---|---|
| `refreshAllowed` / `REFRESH_ALLOWED` | The current screen has not refreshed the user yet. Initial state. |
| `awaitingPushTokenSync` / `AWAITING_PUSH_TOKEN_SYNC` | A refresh was forwarded and still owes a push-token re-assert. |
| `refreshSettled` / `REFRESH_SETTLED` | A refresh was forwarded on this screen and its token sync is done. |

### 4.3 Input and output value types

The machine owns the **policy**; it does not own `Storage` or `SocketManager`. The three facts it
cannot compute itself arrive in one documented value type rather than as positional booleans:

```swift
/// The facts about an incoming identify event that the refresh policy needs.
internal struct IdentifyRefreshRequest {
    /// The event adds nothing to the cached user (`User.isSameIdentifyEvent`).
    let carriesNoNewData: Bool
    /// The event identifies the generated anonymous user, which is excluded from refreshes.
    let isAnonymousUser: Bool
    /// The SDK is replaying a still-pending identify after a socket close, not the host app
    /// calling `identify` again. Replays bypass the per-screen allowance.
    let isPendingReplay: Bool
}

/// What the publisher should do with an identify event.
internal enum IdentifyRefreshDecision {
    /// Carries new user data — take the normal path (identify + fake-reload screen event).
    case carriesNewData
    /// Carries nothing new, but forward it so the backend re-affirms the user. No screen event.
    case refresh
    /// Carries nothing new and must be dropped.
    case suppress
}
```

Kotlin is the same shape (`internal data class IdentifyRefreshRequest`,
`internal enum class IdentifyRefreshDecision { CARRIES_NEW_DATA, REFRESH, SUPPRESS }`).

### 4.4 Transition table

| From | Call | Guard | To | Result |
|---|---|---|---|---|
| any | `transition` | `!carriesNoNewData` | *unchanged* | `carriesNewData` |
| any | `transition` | `isAnonymousUser` | *unchanged* | `suppress` |
| any | `transition` | `isPendingReplay` | `awaitingPushTokenSync` | `refresh` |
| `refreshAllowed` | `transition` | — | `awaitingPushTokenSync` | `refresh` |
| `awaitingPushTokenSync` | `transition` | — | *unchanged* | `suppress` |
| `refreshSettled` | `transition` | — | *unchanged* | `suppress` |
| `awaitingPushTokenSync` | `consumePushTokenSync` | — | `refreshSettled` | `true` |
| others | `consumePushTokenSync` | — | *unchanged* | `false` |
| `awaitingPushTokenSync` | `onScreenChanged` | — | *unchanged* | — |
| others | `onScreenChanged` | — | `refreshAllowed` | — |
| any | `onUserChanged` | — | `refreshAllowed` | — |

Two transitions deserve their reasoning spelled out in code comments:

- **`onScreenChanged` is a no-op while awaiting a token sync.** The obligation belongs to an
  identify that has not reached the backend yet, not to the screen it was requested on. And
  re-sending an identical identify before the first one lands would be pure noise — so continuing
  to suppress until it settles is the correct behaviour, not a compromise.
- **`isPendingReplay` bypasses the allowance.** `onSocketClosed` re-enters the *public* `publish`
  with the cached identify (iOS [:775](../../../Sources/Userpilot/Analytics/AnalyticsPublisher.swift#L775),
  Android `onSocketClosed` → `cachedIdentifyEvent?.let { publish(it) }`). Without the bypass that
  replay would hit an already-consumed allowance, get suppressed, and the reconnect would silently
  lose the user. A **pending** identify (`cachedIdentifyEvent != nil`) while the socket is **not
  open** can only be an SDK replay, because a successful send clears `cachedIdentifyEvent` in
  `onSocketEventSent`.

### 4.5 Swift implementation — `Sources/Userpilot/Analytics/IdentifyRefreshStateMachine.swift` (new)

```swift
/// Owns the policy for `identify` events that carry no new user data.
///
/// Such an event is still forwarded to the backend **once per screen** so the backend can
/// re-affirm the user, and each forwarded refresh owes one push-token re-assert (the token
/// senders are value-guarded and would otherwise never re-pair token ↔ user).
///
/// All state lives in a single `State` value: two independent booleans would allow
/// combinations that cannot occur and would hide the rule that a screen change must not
/// discard an unsettled token obligation.
///
/// Thread-safe: identify, screen and socket callbacks arrive from different queues.
/// (Mirrors Android's `IdentifyRefreshStateMachine`; keep both in sync.)
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

    private let lock = NSLock()
    private var _state: State = .refreshAllowed

    /// Current state. Exposed for assertions; callers must not derive control flow from it.
    internal var state: State {
        lock.lock(); defer { lock.unlock() }
        return _state
    }

    /// Classifies an incoming identify event and advances the allowance when it is forwarded.
    internal func transition(_ request: IdentifyRefreshRequest) -> IdentifyRefreshDecision {
        lock.lock(); defer { lock.unlock() }

        guard request.carriesNoNewData else { return .carriesNewData }

        // `anonymous()` re-sends the same generated id with no properties, so there is nothing
        // to refresh. Suppress without touching the allowance: an anonymous call must not spend
        // the screen's refresh on behalf of a real user.
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

    /// Claims the pending push-token re-assert, if one is owed.
    /// - Returns: `true` exactly once per forwarded refresh.
    internal func consumePushTokenSync() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard _state == .awaitingPushTokenSync else { return false }
        _state = .refreshSettled
        return true
    }

    /// A genuinely new screen re-opens the allowance.
    internal func onScreenChanged() {
        lock.lock(); defer { lock.unlock() }
        // A pending token sync belongs to an identify that has not reached the backend yet, not
        // to the screen it was requested on. Keep suppressing until it settles — re-sending an
        // identical identify before the first one lands would only add noise.
        guard _state != .awaitingPushTokenSync else { return }
        _state = .refreshAllowed
    }

    /// Logout or user switch: the next user starts with a fresh allowance and owes nothing.
    internal func onUserChanged() {
        lock.lock(); defer { lock.unlock() }
        _state = .refreshAllowed
    }
}
```

`ReadWriteLock` is **not** usable here — its `write(closure:)` is `async(flags: .barrier)` and
cannot return a decision synchronously. `NSLock` is the right primitive.

### 4.6 Kotlin implementation — `userpilot/src/main/java/com/userpilot/analytics/IdentifyRefreshStateMachine.kt` (new)

Same doc comment and identical semantics; `@Synchronized` instead of `NSLock`, matching
`ScreenSessionStateMachine`:

```kotlin
internal class IdentifyRefreshStateMachine {

    internal enum class State { REFRESH_ALLOWED, AWAITING_PUSH_TOKEN_SYNC, REFRESH_SETTLED }

    var state: State = State.REFRESH_ALLOWED
        @Synchronized get
        private set

    @Synchronized
    fun transition(request: IdentifyRefreshRequest): IdentifyRefreshDecision {
        if (!request.carriesNoNewData) return IdentifyRefreshDecision.CARRIES_NEW_DATA
        if (request.isAnonymousUser) return IdentifyRefreshDecision.SUPPRESS

        if (request.isPendingReplay) {
            state = State.AWAITING_PUSH_TOKEN_SYNC
            return IdentifyRefreshDecision.REFRESH
        }

        return when (state) {
            State.REFRESH_ALLOWED -> {
                state = State.AWAITING_PUSH_TOKEN_SYNC
                IdentifyRefreshDecision.REFRESH
            }
            State.AWAITING_PUSH_TOKEN_SYNC,
            State.REFRESH_SETTLED -> IdentifyRefreshDecision.SUPPRESS
        }
    }

    @Synchronized
    fun consumePushTokenSync(): Boolean {
        if (state != State.AWAITING_PUSH_TOKEN_SYNC) return false
        state = State.REFRESH_SETTLED
        return true
    }

    @Synchronized
    fun onScreenChanged() {
        if (state == State.AWAITING_PUSH_TOKEN_SYNC) return
        state = State.REFRESH_ALLOWED
    }

    @Synchronized
    fun onUserChanged() {
        state = State.REFRESH_ALLOWED
    }
}
```

### 4.7 Wiring — each platform's existing precedent

| | iOS | Android |
|---|---|---|
| Ownership | `private let identifyRefreshStateMachine = IdentifyRefreshStateMachine()` on `AnalyticsPublisher`, mirroring `eventThrottle` (small stateful policy objects are not DI-registered on iOS) | Koin `scoped { IdentifyRefreshStateMachine() }` + constructor param on `AnalyticsPublisher`, mirroring `ScreenSessionStateMachine` |
| Scope | per `Userpilot` instance | per Koin scope = per `Userpilot` instance |

The class and its API are identical; only the wiring follows each repo's convention. Both are
directly unit-testable in isolation, which is the point.

---

## 5. iOS changes

### 5.1 `Sources/Userpilot/Analytics/IdentifyRefreshStateMachine.swift` — new

Contains `IdentifyRefreshRequest`, `IdentifyRefreshDecision`, `IdentifyRefreshStateMachine` (§4.3, §4.5).

### 5.2 `Sources/Userpilot/Analytics/AnalyticsPublisher.swift`

**(a) Lazy push-monitor resolver**, next to `experiencesPublisher` / `sessionMonitorer` (~line 135):

```swift
/// Push notification monitoring, used to re-assert the device token for a returning user.
///
/// `AnalyticsPublishing` is registered *before* `PushNotificationMonitoring` in
/// `initializeContainer()`, and `PushNotificationMonitor.init` resolves this publisher, so this
/// must never be resolved from `init` — only on demand.
private weak var pushNotificationMonitor: PushNotificationMonitoring? {
    return container?.resolve(PushNotificationMonitoring.self)
}
```

`DIContainer.resolve` `fatalError`s on an unregistered type
([DIContainer.swift:124](../../../Sources/Userpilot/DI/DIContainer.swift#L124)), and
[Userpilot.swift:228-230](../../../Sources/Userpilot/Userpilot.swift#L228-L230) registers
`AnalyticsPublishing` **one line before** `PushNotificationMonitoring` — resolving from `init`
would crash on SDK init.

**(b) Own the state machine**, next to `eventThrottle` (~line 155):

```swift
/// Policy for identify events that carry no new user data.
private let identifyRefreshStateMachine = IdentifyRefreshStateMachine()
```

**(c) Replace `didHandleIdentifyEvent(_:)`** ([:335-354](../../../Sources/Userpilot/Analytics/AnalyticsPublisher.swift#L335-L354))
with a classifier plus a decision-returning handler:

```swift
/// Builds the refresh request from the collaborators the state machine deliberately does not own.
private func identifyRefreshRequest(for event: Event) -> IdentifyRefreshRequest {
    IdentifyRefreshRequest(
        carriesNoNewData: storage.user.isNotEmpty
            && User.fromJson(storage.user).isSameIdentifyEvent(event: event),
        isAnonymousUser: storage.anonymousUserId.isNotEmpty
            && event.userId == storage.anonymousUserId,
        // A pending identify has not reached the backend yet, so this is `onSocketClosed`
        // replaying it, not a fresh host-app call.
        isPendingReplay: cachedIdentifyEvent != nil && !socketManager.isSocketOpened
    )
}

/**
 * Runs an identify event through the refresh policy and, unless it is suppressed, caches it as
 * the pending identify event.
 *
 * - Parameter event: The identify event to handle
 * - Returns: The policy decision for this event
 */
private func handleIdentifyEvent(_ event: Event) -> IdentifyRefreshDecision {
    let decision = identifyRefreshStateMachine.transition(identifyRefreshRequest(for: event))
    guard decision != .suppress else { return decision }

    // Update cached user
    storage.temporaryUser = event.toUser().toJson()
    cachedIdentifyEvent = event

    return decision
}
```

**(d) `publish(_:)`** ([:301-333](../../../Sources/Userpilot/Analytics/AnalyticsPublisher.swift#L301-L333)) —
every socket guard keeps its order; only the de-dup call site changes:

```swift
// nil for non-identify events
let refreshDecision = event.isIdentifyEvent ? handleIdentifyEvent(event) : nil

// Nothing new for the backend, and this screen already refreshed the user
guard refreshDecision != .suppress else { return }

// … existing isShutdownState / isJoiningSocket / isSocketOpened guards unchanged …

processEvent(event, isIdentifyRefresh: refreshDecision == .refresh)
```

**(e) `processEvent`** gains a defaulted parameter and forwards it:

```swift
private func processEvent(_ event: Event, isIdentifyRefresh: Bool = false) {
    switch event.type {
    case .identify:
        identify(event, isIdentifyRefresh: isIdentifyRefresh)
    …
```

**(f) `identify(_:)`** ([:429-441](../../../Sources/Userpilot/Analytics/AnalyticsPublisher.swift#L429-L441)):

```swift
private func identify(_ event: Event, isIdentifyRefresh: Bool = false) {
    tryCatch {
        guard let userId = event.userId else { return }

        // If new user ID detected, close socket and clean up
        if storage.userId.isNotEmpty && userId != storage.userId {
            userpilot?.clean()
            logout(socketState: .switchingUser)
            return
        }

        if isIdentifyRefresh {
            // Nothing about the user changed, so the backend has nothing to re-evaluate:
            // send the identify alone and skip the fake-reload screen event.
            flushPriorityEvents(canRequestScreenEvent: false)
            syncPushTokenIfNeeded()
            return
        }

        flushPriorityEvents(fakeReloadScreenEvent: true)
    }
}
```

Suppressing the screen frame reuses the **existing** `canRequestScreenEvent:` parameter, which
also skips `screenNameTracker.updateScreen`, `experiencesPublisher?.updateSceen(_:)` and the screen
`broadcastEvent` — they all live inside the `if let screenViewEntity, canRequestScreenEvent` block
([:638-665](../../../Sources/Userpilot/Analytics/AnalyticsPublisher.swift#L638-L665)). No new plumbing.

The internal recursion at [:626](../../../Sources/Userpilot/Analytics/AnalyticsPublisher.swift#L626)
calls `identify(cachedIdentifyEvent)` and picks up the `false` default — correct, that branch is a
user switch.

**(g) New helper:**

```swift
/**
 * Re-publishes the device push token owed by a forwarded identify refresh.
 *
 * `PushNotificationMonitor.setPushToken` only publishes when the token value changes, so a
 * returning user whose token is unchanged would otherwise never re-pair token ↔ user on the
 * backend. Called after the identify is on the wire so the backend sees the user first.
 */
private func syncPushTokenIfNeeded() {
    // Check the socket first: an obligation must not be consumed while it cannot be fulfilled.
    guard canRequestEvent, identifyRefreshStateMachine.consumePushTokenSync() else { return }
    pushNotificationMonitor?.resyncPushToken()
}
```

**(h) `onSocketOpened()`** ([:760-763](../../../Sources/Userpilot/Analytics/AnalyticsPublisher.swift#L760-L763)) — append:

```swift
// Cold-start path: the refresh was cached while the socket was down and has just been flushed.
syncPushTokenIfNeeded()
```

**(i) `setupScreenEvent(_:)`** — inside the `if isScreenTitleChanged` branch
([:569](../../../Sources/Userpilot/Analytics/AnalyticsPublisher.swift#L569)):

```swift
// A genuinely new screen re-opens the refresh allowance.
identifyRefreshStateMachine.onScreenChanged()
```

Deliberately **not** in the `else` branch: a repeat of the same screen title is the same screen.

**(j) `logout(...)`** ([:244-245](../../../Sources/Userpilot/Analytics/AnalyticsPublisher.swift#L244-L245)),
next to `startSession = true`:

```swift
// A new user starts with a fresh allowance and owes no token sync.
identifyRefreshStateMachine.onUserChanged()
```

This also closes the theoretical hole where `storage.userId` and `storage.user.userId` diverge,
`identify` takes the user-switch branch, and a stale obligation would re-assert the old token
against the new user.

**(k) `reset()`** ([:276-279](../../../Sources/Userpilot/Analytics/AnalyticsPublisher.swift#L276-L279)) —
add `identifyRefreshStateMachine.onUserChanged()`. No production caller today (tests only), but
leaving new state out of a method named `reset` is a latent bug.

**(l) DEBUG accessors** in the existing `#if DEBUG` extension ([:852-862](../../../Sources/Userpilot/Analytics/AnalyticsPublisher.swift#L852-L862)):

```swift
func mockGetCachedIdentifyEvent() -> Event? { cachedIdentifyEvent }
func mockIdentifyRefreshState() -> IdentifyRefreshStateMachine.State { identifyRefreshStateMachine.state }
```

### 5.3 `Sources/Userpilot/PushNotification/PushNotificationMonitor.swift`

Protocol addition to `PushNotificationMonitoring` (~line 28):

```swift
/// Re-publishes the current device token even when its value has not changed.
///
/// `setPushToken(_:)` is value-guarded and is therefore a no-op for a returning user whose
/// token is unchanged. This re-asserts the token ↔ user pairing on the backend.
func resyncPushToken()
```

Implementation — extract the hex conversion so both senders share it:

```swift
/// Hex representation of a raw APNs device token.
private func hexString(from deviceToken: Data) -> String {
    deviceToken.map { String(format: "%02x", $0) }.joined()
}

func resyncPushToken() {
    // Prefer the token the OS handed us this launch; fall back to the persisted one for a warm
    // start where `didRegisterForRemoteNotificationsWithDeviceToken` has not fired yet.
    let token = cachedToken.map(hexString(from:)) ?? storage.pushToken
    guard
        let token,
        token.isNotEmpty,
        analyticsPublisher.canRequestEvent
    else { return }

    analyticsPublisher.publishInternalSDKEvent(
        PushNotificationTokenEvent(
            appToken: config.token,
            userId: storage.userId,
            token: token),
        socketSubscription: self)
}
```

`setPushToken(_:)` keeps its `storage.pushToken != newToken` guard untouched and only swaps its
inline hex expression for `hexString(from:)`. `onSocketEventSent` already persists
`payload["token"]` for `user_token`, so a re-sync harmlessly rewrites the same value.

### 5.4 `Tests/UserpilotTests/MockUserpilot.swift`

```swift
// MockPushNotificationMonitor
var onResyncPushToken: (() -> Void)?
func resyncPushToken() {
    onResyncPushToken?()
}
```

---

## 6. Android changes

### 6.1 `userpilot/src/main/java/com/userpilot/analytics/IdentifyRefreshStateMachine.kt` — new

Contains `IdentifyRefreshRequest`, `IdentifyRefreshDecision`, `IdentifyRefreshStateMachine` (§4.3, §4.6).

### 6.2 `userpilot/src/main/java/com/userpilot/di/AnalyticsKoin.kt`

```kotlin
scoped { IdentifyRefreshStateMachine() }
```
placed next to `scoped { ScreenSessionStateMachine() }`, and threaded into the `AnalyticsPublisher`
definition as:

```kotlin
identifyRefreshStateMachine = get(),
pushNotificationHandlerProvider = { get() },
```

**Why a provider lambda for the handler, not `get()`:** `PushNotificationHandler.init` calls
`socketManager.setSocketSubscriptionListener(this)`, which `delegate.add(...)`s it to the listener
list. Passing `get()` directly would construct the handler *before* `AnalyticsPublisher.init`
registers itself, changing the global `onSocketEventSent` callback order in a shipped SDK for no
benefit. A `() -> PushNotificationHandler` defers construction to first use — the first identify
refresh — preserving today's ordering, and is trivially fakeable in tests. (There is no Koin cycle
either way: the handler resolves `analyticsPublisher` via lazy `by scope.inject`.)

### 6.3 `userpilot/src/main/java/com/userpilot/analytics/AnalyticsPublisher.kt`

**(a) Constructor** ([:56-68](../../../../userpilot-android-sdk/userpilot/src/main/java/com/userpilot/analytics/AnalyticsPublisher.kt#L56-L68)) —
two new params after `screenSessionStateMachine`:

```kotlin
private val identifyRefreshStateMachine: IdentifyRefreshStateMachine,
/** Deferred so the handler is not constructed before this publisher registers its socket listener. */
private val pushNotificationHandlerProvider: () -> PushNotificationHandler,
```

The class already carries `@Suppress("TooManyFunctions", "LongParameterList")`.

**(b) `publish(event)`** ([:220-250](../../../../userpilot-android-sdk/userpilot/src/main/java/com/userpilot/analytics/AnalyticsPublisher.kt#L220-L250)):

```kotlin
// null for non-identify events
val refreshDecision = if (event.isIdentifyEvent) handleIdentifyEvent(event) else null

// Nothing new for the backend, and this screen already refreshed the user
if (refreshDecision == IdentifyRefreshDecision.SUPPRESS) return

// … existing isShutdownState / isJoiningSocket / isSocketOpened guards unchanged …

processEvent(event, isIdentifyRefresh = refreshDecision == IdentifyRefreshDecision.REFRESH)
```

**(c) Replace `handleIdentifyEvent`** ([:258-269](../../../../userpilot-android-sdk/userpilot/src/main/java/com/userpilot/analytics/AnalyticsPublisher.kt#L258-L269)):

```kotlin
private fun identifyRefreshRequest(event: Event) = IdentifyRefreshRequest(
    carriesNoNewData = storage.user.isNotEmpty() && storage.user.toUser().isSameIdentifyEvent(event),
    isAnonymousUser = storage.anonymousUserId.isNotEmpty() && event.userId == storage.anonymousUserId,
    // A pending identify has not reached the backend yet, so this is `onSocketClosed`
    // replaying it, not a fresh host-app call.
    isPendingReplay = cachedIdentifyEvent != null && !socketManager.isSocketOpened
)

private fun handleIdentifyEvent(event: Event): IdentifyRefreshDecision {
    val decision = identifyRefreshStateMachine.transition(identifyRefreshRequest(event))
    if (decision == IdentifyRefreshDecision.SUPPRESS) return decision

    // Update cached user
    storage.temporaryUser = event.toUser().toJson()
    cachedIdentifyEvent = event

    return decision
}
```

**(d) `processEvent` / `identify`** ([:309-315](../../../../userpilot-android-sdk/userpilot/src/main/java/com/userpilot/analytics/AnalyticsPublisher.kt#L309-L315),
[:340-352](../../../../userpilot-android-sdk/userpilot/src/main/java/com/userpilot/analytics/AnalyticsPublisher.kt#L340-L352)):

```kotlin
private fun processEvent(event: Event, isIdentifyRefresh: Boolean = false) {
    when (event.type) {
        is EventType.Identify -> identify(event, isIdentifyRefresh)
        …
    }
}

private fun identify(event: Event, isIdentifyRefresh: Boolean = false) {
    tryCatch {
        val userId = event.userId ?: return@tryCatch

        if (storage.userId.isNotEmpty() && userId != storage.userId) {
            userpilot.clean()
            logout(SocketState.SWITCHING_USER)
            return@tryCatch
        }

        if (isIdentifyRefresh) {
            // Nothing about the user changed, so the backend has nothing to re-evaluate:
            // send the identify alone and skip the fake-reload screen event.
            flushPriorityEvents(canRequestScreenEvent = false)
            syncPushTokenIfNeeded()
            return@tryCatch
        }

        flushPriorityEvents(fakeReloadScreenEvent = true)
    }
}
```

Note the existing `identify` uses `return` inside `tryCatch`; keep whichever form the file's
`tryCatch` signature already accepts (it is `return` today because the lambda is inline).

**(e) New helper:**

```kotlin
/**
 * Re-publishes the FCM token owed by a forwarded identify refresh.
 *
 * [PushNotificationHandler.sendFCMToken] is value-guarded, so a returning user whose token is
 * unchanged would otherwise never re-pair token ↔ user on the backend.
 */
private fun syncPushTokenIfNeeded() {
    // Check the socket first: an obligation must not be consumed while it cannot be fulfilled.
    if (!canRequestEvent()) return
    if (!identifyRefreshStateMachine.consumePushTokenSync()) return
    pushNotificationHandlerProvider().resyncPushToken()
}
```

**(f) `onSocketOpened()`** ([:662-666](../../../../userpilot-android-sdk/userpilot/src/main/java/com/userpilot/analytics/AnalyticsPublisher.kt#L662-L666)) —
append `syncPushTokenIfNeeded()` after `flushPriorityEvents(...)` and before/after
`permissionsHandler.requestPermissions()` (order is irrelevant; put it right after the flush).

**(g) `updateScreenViewState(event)`** ([:451](../../../../userpilot-android-sdk/userpilot/src/main/java/com/userpilot/analytics/AnalyticsPublisher.kt#L451)) —
this returns `isSameScreenAsPrevious`, the **inverse** of iOS's `setupScreenEvent`:

```kotlin
if (!isSameScreenAsPrevious) {
    // A genuinely new screen re-opens the refresh allowance.
    identifyRefreshStateMachine.onScreenChanged()
}
return isSameScreenAsPrevious
```

**(h) `logout(...)`** ([:171-172](../../../../userpilot-android-sdk/userpilot/src/main/java/com/userpilot/analytics/AnalyticsPublisher.kt#L171-L172)) —
next to `startSession = true`:

```kotlin
// A new user starts with a fresh allowance and owes no token sync.
identifyRefreshStateMachine.onUserChanged()
```

### 6.4 `userpilot/src/main/java/com/userpilot/pushNotifications/PushNotificationHandler.kt`

```kotlin
/**
 * Re-publishes the current FCM token even when its value has not changed.
 *
 * [sendFCMToken] is value-guarded and is therefore a no-op for a returning user whose token is
 * unchanged. This re-asserts the token ↔ user pairing on the backend.
 */
fun resyncPushToken() {
    tryCatch {
        if (!analyticsPublisher.canRequestEvent()) return@tryCatch
        val token = cachedFCMToken ?: storage.pushNotificationToken
        if (token.isNullOrEmpty()) return@tryCatch
        // `onSocketEventSent` persists `cachedFCMToken` when `user_token` is acked, so seed it
        // here — otherwise a resync sourced from storage would null the stored token out.
        cachedFCMToken = token
        analyticsPublisher.publishInternalSDKEvent(
            PushNotificationTokenEvent(config.token, storage.userId, token)
        )
    }
}
```

That `cachedFCMToken = token` line is load-bearing: `onSocketEventSent` does
`storage.pushNotificationToken = cachedFCMToken`, so re-syncing a storage-sourced token while
`cachedFCMToken == null` would wipe the persisted token on ack.

`checkFCMToken()` and `sendFCMToken()` are otherwise untouched.

### 6.5 Android test doubles

`AnalyticsPublisherTest` constructs the publisher directly; add
`identifyRefreshStateMachine = IdentifyRefreshStateMachine()` and
`pushNotificationHandlerProvider = { fakeHandler }` (or a relaxed mock) to every construction site.

---

## 7. Cross-platform parity checklist

| Concern | iOS | Android |
|---|---|---|
| State machine class | `IdentifyRefreshStateMachine.swift` | `IdentifyRefreshStateMachine.kt` |
| Thread safety | `NSLock` | `@Synchronized` |
| Wiring | owned `private let` (like `EventThrottle`) | Koin `scoped` + ctor (like `ScreenSessionStateMachine`) |
| Redundancy check | `User.isSameIdentifyEvent(event:)` | `User.isSameIdentifyEvent(event)` |
| Anonymous check | `storage.anonymousUserId` | `storage.anonymousUserId` |
| Screen-change hook | `setupScreenEvent` → `isScreenTitleChanged == true` | `updateScreenViewState` → `isSameScreenAsPrevious == false` |
| Screen suppression | `flushPriorityEvents(canRequestScreenEvent: false)` | `flushPriorityEvents(canRequestScreenEvent = false)` |
| Token re-assert | `PushNotificationMonitor.resyncPushToken()` | `PushNotificationHandler.resyncPushToken()` |
| Token source order | `cachedToken` → `storage.pushToken` | `cachedFCMToken` → `storage.pushNotificationToken` |
| Token event name | `user_token` | `user_token` |

The **wire protocol is byte-identical on both platforms**: one extra `identify` frame with no
accompanying screen frame, followed by one `user_token` frame. No backend change is required.

---

## 8. Regression matrix (applies to both platforms)

| Scenario | Before | After |
|---|---|---|
| First `identify` ever (`storage.user` empty) | `identify` + screen(`fake_reload: true`) | **unchanged** |
| `identify` with new/changed properties, same `userId` | `identify` + screen(`fake_reload: true`) | **unchanged** |
| `identify` with a different `userId` | `clean()` + `logout(switching user)` | **unchanged** (`isSameIdentifyEvent` fails on `userId`) |
| **`anonymous()` repeated** | dropped | **unchanged — dropped**, and the screen allowance is not consumed |
| `anonymous()` then `identify(realUser)` | normal path | **unchanged** |
| Refresh, socket open, first on this screen | dropped | `identify` published; **no** screen frame; `user_token` published |
| Refresh, socket open, 2nd+ on same screen | dropped | dropped |
| Refresh after navigating to a different screen | dropped | forwarded again (once) |
| Refresh after the *same* screen is re-emitted | dropped | still suppressed |
| Refresh, socket closed (cold/warm start) | dropped; socket not opened by it | cached + connect; on open → `identify` + screen(`fake_reload: false`) + `user_token` |
| Refresh, socket joining | dropped | cached; flushed on open + `user_token` |
| Refresh while app backgrounded | cached (policy never runs) | **unchanged** |
| Refresh while socket shutting down | dropped | dropped; obligation stays owed and is fulfilled on the next socket open |
| Screen changes while a token sync is still owed | n/a | allowance stays closed until the sync settles, then the next screen re-opens it |
| `onSocketClosed` replay of a pending refresh | n/a (never cached) | bypasses the allowance — reconnect keeps the user |
| `logout()` then `identify` same user | `storage.user` cleared → carries new data | **unchanged** |
| Background → foreground on the same screen, `identify` again | dropped | dropped (decision #2) |
| Multi-instance | per-instance state | **unchanged** — one machine per SDK instance |

### Behaviour changes worth telling the team about

1. **The analytics listener now fires for refreshes.** iOS `UserpilotAnalyticsDelegate.didTrack` /
   Android `UserpilotAnalyticsListener` see an `identify` they previously never saw, because the
   refresh reaches `onSocketEventSent` → broadcast.
2. **Traffic ceiling.** Worst case for an app that identifies on every screen: one extra `identify`
   + one extra `user_token` per *screen change*. If that proves too chatty the lever is the
   existing `EventThrottle`; not implemented now, the per-screen allowance is the primary bound.
3. **`temporaryUser` is now written for refreshes** and cleared on successful send. If the process
   dies in that window, `AnalyticsPublisher.init` restores it and publishes on the next socket
   open — same user, harmless.

---

## 9. Test plan

### 9.1 State machine — new file, both platforms

`Tests/UserpilotTests/Analytics/IdentifyRefreshStateMachineTests.swift` /
`userpilot/src/test/java/com/userpilot/analytics/IdentifyRefreshStateMachineTest.kt`

One test per row of the §4.4 transition table, plus:

- initial state is `refreshAllowed`
- `carriesNewData` never mutates state (assert state before/after)
- anonymous suppression never mutates state
- `onScreenChanged` is a no-op while awaiting a token sync, and effective once settled
- `consumePushTokenSync` returns `true` exactly once, `false` on the second call
- `onUserChanged` resets from every state
- a replay re-arms the obligation from `refreshSettled`

### 9.2 iOS `AnalyticsPublisherTests`

Replace `testPublish_withSameIdentifyEvent_shouldNotReprocess`
([:734-753](../../../Tests/UserpilotTests/Analytics/AnalyticsPublisherTests.swift#L734-L753)) — it
currently passes for the wrong reason, since `isSocketOpened` defaults to `false` so nothing
publishes either way. Every new test must set `userpilot.socketManager.isSocketOpened = true` where
it means "socket open".

| Test | Asserts |
|---|---|
| `testPublish_identifyRefresh_socketOpen_shouldPublishIdentifyWithoutScreenEvent` | one publish, name `EventType.identifyEvent`, no screen frame |
| `testPublish_identifyRefresh_twiceOnSameScreen_shouldPublishOnce` | second call publishes nothing |
| `testPublish_identifyRefresh_afterNewScreen_shouldPublishAgain` | screen A → identify → screen B → identify ⇒ two identify frames |
| `testPublish_identifyRefresh_afterSameScreenTitleRepeated_shouldStaySuppressed` | re-emitting the title does not re-open the allowance |
| `testPublish_identifyRefresh_shouldResyncPushToken` | `onResyncPushToken` fires once, **after** the identify publish |
| `testPublish_identifyRefresh_secondOnSameScreen_shouldNotResyncPushToken` | obligation is consumed once |
| `testPublish_anonymousIdentify_shouldStayDropped` | no publish, no token event, and a following real-user refresh still gets its allowance |
| `testPublish_identifyRefresh_whenSocketClosed_shouldCacheAndConnect` | `cachedIdentifyEvent != nil`, `connect()` called, nothing published |
| `testOnSocketOpened_afterCachedIdentifyRefresh_shouldResyncPushToken` | flush publishes identify, then one token sync |
| `testOnSocketClosed_replayOfPendingRefresh_shouldNotBeSuppressed` | allowance already consumed + pending event ⇒ replay accepted |
| `testPublish_identifyWithNewProperties_shouldStillPublishFakeReloadScreenEvent` | **regression**: screen frame with `fake_reload == true` |
| `testPublish_identifyRefresh_afterLogout_shouldPublishAgain` | `logout` resets the machine |
| `testPublish_identifyRefresh_whenShutdownState_shouldNotPublishOrResync` | no publish, no token event |

`MockUserpilot.container` already registers `MockPushNotificationMonitor` for
`PushNotificationMonitoring`, so no harness wiring beyond §5.4.

### 9.3 iOS `PushNotificationMonitorTests`

| Test | Asserts |
|---|---|
| `testResyncPushToken_withCachedToken_shouldPublishTokenEvent` | `user_token` with the hex of `setCachedToken` |
| `testResyncPushToken_withStoredTokenOnly_shouldPublishTokenEvent` | falls back to `storage.pushToken` |
| `testResyncPushToken_withNoToken_shouldNotPublish` | both sources empty ⇒ nothing |
| `testResyncPushToken_whenSocketClosed_shouldNotPublish` | `canRequestEvent == false` ⇒ nothing |
| `testSetPushToken_withUnchangedToken_shouldStillNotPublish` | **regression**: the value guard survives the refactor |

### 9.4 Android `AnalyticsPublisherTest` / `PushNotificationHandlerTest`

Same matrix as §9.2 / §9.3, plus one Android-specific case:

- `resyncPushToken seeds cachedFCMToken so ack does not wipe stored token` — resync with
  `cachedFCMToken == null`, ack `user_token`, assert `storage.pushNotificationToken` is unchanged
  rather than null.

### 9.5 Verification commands

**iOS**
```bash
swiftlint
xcodebuild build -scheme Userpilot -destination 'generic/platform=iOS Simulator'
xcodebuild test -scheme Userpilot -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:UserpilotTests/IdentifyRefreshStateMachineTests \
  -only-testing:UserpilotTests/AnalyticsPublisherTests \
  -only-testing:UserpilotTests/PushNotificationMonitorTests
xcodebuild test -scheme Userpilot -destination 'platform=iOS Simulator,name=iPhone 16'
```
Pick a live simulator with `xcrun simctl list devices available`.

**Android**
```bash
./gradlew detekt
./gradlew :userpilot:testDebugUnitTest --tests '*IdentifyRefreshStateMachineTest'
./gradlew :userpilot:testDebugUnitTest
./gradlew build
```

### 9.6 Manual check (both sample apps, logging enabled)

1. Launch, `identify` the same user twice on screen A → exactly one `identify` frame, **no** screen
   frame between them, one `user_token` frame.
2. Navigate to screen B, `identify` again → a second `identify` frame.
3. Return to A, `identify` again → a third.
4. Background → foreground on B, `identify` again → **no** new frame (decision #2).
5. `anonymous()` twice → **no** frames after the first identify (decision #4).
6. `identify` with a changed property → `identify` **plus** screen frame with `fake_reload: true`.
7. Kill and relaunch, `identify` the same user → `identify` reaches the backend on socket open
   (previously it did not) plus `user_token`.
8. Switch user → clean + reconnect, token registered for the new user (unchanged behaviour).

Android extras: exercise both an Activity→Activity change and an Activity→Fragment change on the
same host, since `ScreenSessionStateMachine` treats the latter as the **same** logical surface —
so the fragment case must **not** re-open the refresh allowance.

---

## 10. Shipping

- **Lint.** iOS: `AnalyticsPublisher.swift` already has `// swiftlint:disable file_length`;
  `publish(_:)` grows ~4 lines and stays far under the 50-line `function_body_length` warning.
  Android: `AnalyticsPublisher` already carries `@Suppress("TooManyFunctions", "LongParameterList")`;
  detekt runs with `maxIssues: 0`, so run `./gradlew detekt` before pushing.
- **No public surface change** on either platform ⇒ no `Userpilot.docc` / README update required.
  Optional: one line in the `identify` doc comment on each platform noting that a repeated
  identical `identify` is forwarded at most once per screen and that `anonymous()` is exempt.
- **Versions** are owned by CI (`bump-version.yml` on both repos) — do not hand-edit
  `Version.swift` or the Android version constant. iOS releases via `release/release-*`;
  Android via `maven-publish-release.yml`.
- **Commits.** iOS uses emoji prefixes matched by the CI changelog filter; framed as a fix for
  "an identical identify never reaches the backend" ⇒ `🐛`. Ship the two platforms as separate PRs
  that reference each other, and land them together so behaviour does not diverge between SDKs.

## 11. Risks

| Risk | Mitigation |
|---|---|
| Extra backend traffic for apps that identify on every screen | per-screen allowance bounds it to one `identify` + one `user_token` per screen change; `EventThrottle` is the follow-up lever |
| Reconnect loses the user because the replay is suppressed | explicit `isPendingReplay` bypass (§4.4) + dedicated test on both platforms |
| Token obligation silently dropped on navigation | encoded as a state transition, not a flag: `onScreenChanged` is a no-op while `awaitingPushTokenSync` |
| iOS `DIContainer.resolve` `fatalError` during SDK init | `pushNotificationMonitor` is resolved on demand, never from `init` (§5.2a) |
| Android socket-listener registration order changes | `pushNotificationHandlerProvider` defers construction to first use (§6.2) |
| Android stored token wiped on ack | `resyncPushToken` seeds `cachedFCMToken` before publishing (§6.4) |
| iOS/Android drift after this change | §7 parity checklist; both state machines carry a "keep in sync" doc comment |
| `weak` on an iOS computed property | mirrors the existing `experiencesPublisher` / `sessionMonitorer` declarations in the same file; drop the keyword if the compiler objects |
