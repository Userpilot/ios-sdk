# SDK business cases

This is the shared product and QA reference for the iOS and Android SDKs. It records agreed business behavior independently of queues, threads, coroutines, and implementation details. Keep the two repositories' copies consistent when a business rule changes.

The first section records the identity and screen-session rules agreed on 7 October 2026 for `refactor/core-classes-v2`, including the first-identification correction currently under review. This is a working-branch contract, not a statement that these changes are in a published release. Add future SDK/product cases as separate feature sections using the format at the end of this document.

## Identity and screen sessions

### Terms

- **First identification:** selecting a user when the SDK has no stored user ID. Calling identify for the first time in a particular app launch is not necessarily first identification if an identity was retained.
- **Same-user identification:** identifying the currently selected user again. Changing properties or company data does not make that ID a different user. Identify calls are still sent to the backend.
- **User switch:** selecting a different user while another ID is selected.
- **Initial screen:** the first screen request for a new identity session. It can be a host screen event or a generated request for a known current screen.
- **Generated refresh:** the SDK requests content again for a known screen. Its flags depend on whether the initial screen is still pending or the session is already established.
- **Successful screen ACK:** the backend successfully acknowledges the current screen request. Identify ACKs, unrelated SDK replies, stale replies, errors, and timeouts do not complete that screen's session-start phase.

`is_session_start` and `fake_reload` are screen payload fields. Logout and identify establish the context for a following screen; they do not themselves carry these two screen flags.

`is_session_start` describes session-start status. `fake_reload` describes the particular screen request. Do not treat `fake_reload` as one persistent flag shared by all queued screens.

### Agreed case table

The table describes the screen that follows the stated actions. A generated screen requires a known surface and must wait for earlier analytics events; identify does not guarantee a separate screen request after every call.

| Case | Scenario | `is_session_start` | `fake_reload` |
| --- | --- | --- | --- |
| ID-001 | First identification with no previous user, then the first screen | `true` | `false` |
| ID-002 | Logout, identify the same or a different user, then the first screen | `true` | `false` |
| ID-003 | Identify a different user without logout, then that user's first screen | `true` | `false` |
| ID-004 | Several identifies for that same selected user before its initial screen is sent | Preserve the initial session: `true` | The initial screen remains `false` |
| ID-005 | Same-user identify after the initial screen's successful ACK, followed by a generated refresh | Preserve the current value; `false` after that ACK unless another lifecycle transition starts a session | `true` |

Same-user identify never resets or consumes session-start. A successful screen ACK consumes it. First identification, logout, and a different user establish an initial-screen session.

### Reproduction sequences

The following sequences describe ordered SDK actions and replies, not timed delays. Use a valid identity and make the current screen known when expecting a generated request.

**ID-001: fresh identity and a screen reported before identify**

1. Start with no stored user ID.
2. Report screen `Home` before identifying.
3. The unidentified analytics event must not enter the live queue, initial network-readiness buffer, or offline storage. Screen navigation can still update the SDK's knowledge of the visible surface.
4. Identify user A. The identify request must precede any screen request for A.
5. After identify ACK, a generated request for a known current screen uses `true / false`. If no surface is known, wait for a valid screen event; do not invent a screen.
6. First identification establishes session context without old-user cleanup or an unnecessary socket teardown.

The same admission rule applies to unidentified track and autocapture analytics. An explicit anonymous identification supplies an identity and follows normal identified delivery.

**ID-002: logout and identify again**

1. Establish user A and acknowledge a screen.
2. Logout. Clear the previous user's pending analytics and reset session state.
3. Identify A again, or identify B.
4. The next initial screen uses `true / false`, whether its title matches the retained screen or differs.

**ID-003: switch directly to another user**

1. Establish user A and acknowledge a screen.
2. Identify user B without logout.
3. Clear A's pending work and establish B's initial-screen session.
4. B's first screen uses `true / false`.

**ID-004: repeated identification before the first screen**

```text
logout
identify(A)
identify(A)
identify ACK
identify ACK
first screen -> is_session_start=true, fake_reload=false
```

Queue both identifies before the first screen is sent. Repeating the selected identity must not discard its pending initial-screen context. A real screen already waiting behind those identifies supplies the first screen instead of a generated request; it also uses `true / false`.

**ID-005: repeated identification after the first screen ACK**

```text
identify(A)
identify ACK
first screen -> is_session_start=true, fake_reload=false
successful screen ACK
identify(A)
identify ACK
generated refresh -> is_session_start=false, fake_reload=true
```

Repeating identify any number of times, including with different properties, must not reset the established session. This sequence assumes no intervening logout, different user, or lifecycle session reset.

### ACK ownership and ordering

- A successful current screen ACK changes session-start to `false` for later screen requests. It does not rewrite the payload already sent.
- An error or timeout does not consume session-start. This does not imply automatic retry; normal queue failure handling still applies.
- An identify queued while a screen is in flight waits for that screen to resolve. If the screen succeeds, the later identify observes the completed initial-screen phase.
- Elapsed milliseconds do not decide these identity rules. The order of identity changes, screen delivery, and successful ACKs does.
- Generated screens are normal queue entries and retain their own request flags and ACK ownership. They must not overtake earlier analytics or release another request's queue position.

### Boundaries of this section

Screen navigation and experience-dismissal refreshes are covered below. Background/foreground session expiry, offline replay, and screen eligibility have their own rules. This identity table does not make every screen after identify a fake reload, or prevent a lifecycle transition from starting another session.

Both platforms enforce the same identity outcomes while retaining native queue/threading behavior. Their sources for a known screen differ: iOS can use the experience publisher's current title; Android uses the current analytics screen session or its screen tracker. Include the relevant known-screen precondition when comparing generated-screen tests.

### Implementation and regression pointers

- `AnalyticsPublisher`: identity admission and cleanup, event queueing, screen construction, matched successful ACK handling, and lifecycle notifications. It reports transitions and uses the returned screen configuration; it does not own a writable session-start flag.
- `UserSessionStateMachine`: the single owner of session-start and identification/background context. `beginSession`, `acknowledgeScreen`, `markScreenChanged`, `resumeSession`, and `resetSessionStart` apply transitions. `getPostIdentificationScreenConfig` chooses generated reload intent at enqueue; `prepareScreen` resolves session-start at send while preserving that queued intent.
- `ScreenSessionStateMachine`: current screen context and seen-content metadata.
- iOS `AnalyticsPublisherTests` and Android `AnalyticsPublisherTest`: fresh identity, unidentified offline events, generated/manual first screens, logout, different-user switch, repeated identify before the first screen, and repeated identify after its successful ACK.
- `UserSessionStateMachineTests` / `UserSessionStateMachineTest`: transition rules and existing diagnostic formats.

These pointers describe current responsibilities. A future internal refactor may move ownership while preserving the business cases above.

## Screen navigation and session-start

Changing the current screen can end session-start independently of a successful screen ACK. Both platforms apply this existing rule when an analytics screen already exists, its title changes, and the socket channel is joined and ready.

| Case | Scenario | `is_session_start` on the screen request | `fake_reload` |
| --- | --- | --- | --- |
| NAV-001 | An existing screen changes to another title while the socket is ready, with no pending initial identity screen | `false` | `false` for the ordinary navigation event |
| NAV-002 | The first screen after first identify, logout, or a user switch has a different title from the retained screen | `true`; the pending initial identity session takes precedence | `false` |
| NAV-003 | The same title is reported again without another session transition | Preserve the current value; the unchanged title itself does not end session-start | Determined by the event: ordinary screen `false`, generated fake reload `true` |

`AnalyticsPublisher.setUpScreen` reports an eligible title change through `UserSessionStateMachine.markScreenChanged`. At delivery, `prepareScreen` preserves the pending first-identity override until its successful screen ACK. Changing a title must not turn that user's first screen into a continuation.

This navigation rule does not make every screen call deliverable: normal screen eligibility and throttling still apply. It also does not make an offline title change consume session-start when the socket-readiness condition is absent. A fake reload requests the current screen again and therefore does not itself count as navigation or reset session-start.

## Screen refresh after an experience

After an experience is dismissed or completed and its UI dismissal has finished, the SDK can request the next content for the current screen. This refresh continues the current session.

| Case | Screen event already in the analytics queue? | Expected action | `is_session_start` | `fake_reload` |
| --- | --- | --- | --- | --- |
| EXP-001 | No | Append a generated refresh for the current screen to the analytics queue | Preserve the current session value | `true` |
| EXP-002 | Yes, at least one | Skip the generated refresh; the queued screen already requests content | Do not change the queued screen's flags | Do not change the queued screen's flags |

### Flow and checks

1. Wait for actual experience dismissal completion before requesting the next content.
2. Apply the existing reload eligibility checks, including an available socket and a known current screen.
3. If any screen event is already queued, skip the generated refresh. Other queued event types do not prevent it; they retain their FIFO order.
4. Otherwise, append the refresh with `fake_reload=true`. The refresh itself must not reset or consume `is_session_start`; its payload uses the current session value.
5. Record the current screen in the screen throttle so a matching host callback from `onResume` or `viewWillAppear` does not create a duplicate screen within the throttle window. An existing throttle window must not reject this generated fake reload.
6. Deliver the refresh through the normal analytics queue and resolve it through its own ACK/error/timeout. The normal successful screen-ACK rule still applies.

For example, if the current session value is `false`, dismissing an experience produces `is_session_start=false, fake_reload=true`. It must not start a new session. "Preserve" refers to the current session value, not to copying the flags from the older screen request that originally returned the experience.

## Offline replay and live-screen flag checks

Offline screens are replayed as entries inside `batch_events`. Session-start and fake-reload flags are not relevant to offline batch validation. Check storage, replay order and identity cleanup; apply the flag rules above only to live `screen` requests after reconnect.

| Case | Scenario | Expected result |
| --- | --- | --- |
| OFF-001 | Record identified screens and tracks while offline, reconnect, and trigger delivery | Verify that the stored events replay through `batch_events` in their stored order. |
| OFF-002 | Logout or switch to another user while old-user events are pending offline | Clear old-user pending events; do not replay them as the next user's events. |
| OFF-003 | After reconnect and replay, send a live screen | Evaluate that live screen against the identity, navigation, and lifecycle rules above. A successful batch reply is not a successful live-screen ACK. |

The offline sample uses supported SDK calls and manual network changes. Its reconnect steps must wait for the socket to join and replay to resolve before evaluating later live-screen flags; a fixed event delay is not proof of an ACK.

## Sample QA coverage

Both platforms' Online queue and Offline events debug screens show the scenario and expected result above each test action. Online pairs are written as `(is_session_start, fake_reload)`.

| Business rule | Sample scenarios |
| --- | --- |
| First identify, including a known or unknown current screen | Online S13 and S8 |
| Logout, then identify the same or a different user | Online S15 and S16 |
| Switch directly to another user | Online S2 and S5 |
| Repeat identify before the initial screen | Online S14 |
| Repeat identify after a successful screen ACK | Online S1 |
| Real-screen queueing and changed-screen behavior | Online S3, S4, S6, S7 and manual screen controls |
| Dismissal refresh with no queued screen / an existing queued screen | Online S17 / S18 |
| Failed screen ACK and preserved session-start | Online S9, guided |
| Same-user refresh while session-start remains true after expiry | Online S19, conditional guided case |
| Queue stress with 50 ms submission spacing | Online S11 and S12; Offline O6 |
| Offline storage, identity cleanup, rejection before identify and replay | Offline O1–O5 and O8–O11 |
| Live-screen flags after reconnect | Offline O7 |

A submitted call or elapsed delay is not proof of a successful ACK. Guided cases require the stated backend, network, lifecycle, and visible-content conditions. Sample counters report submissions, not guaranteed delivery. Passing unit tests and compiling these samples provide regression evidence; they do not replace device/backend QA of those conditions.

## Socket lifecycle stress coverage

The dedicated automated classes are iOS `SocketManagerStressTests` and Android `SocketManagerStressTest`. They call the real socket manager with controlled settings and transport replies; no live backend connection is opened.

| Case | Scenario | Expected result |
| --- | --- | --- |
| SOC-001 | Repeat connect → close → connect → close → close → close → connect for 25 cycles | Each cycle can join; the previous transport is detached before a replacement is created. |
| SOC-002 | Four background producers repeatedly connect while settings are pending | One settings attempt is admitted. Closing it prevents its delayed result from affecting the replacement. |
| SOC-003 | Four producers each submit 25 closes on one joined connection | All 100 close completions run exactly once; the transport disconnects and subscribers receive close only once. |
| SOC-004 | Four producers each submit 25 connect → close → close → connect sequences | No overlapping transports or lost close completions. After a final ordered close/connect, the surviving connection can send and acknowledge a push. |
| SOC-005 | Replace connections repeatedly, then deliver old lifecycle/join/reply callbacks | Old callbacks cannot open, fail, close, or resolve work on the replacement. |
| SOC-006 | Request reconnect inside close completion for 25 cycles | Completion observes local teardown; reconnect succeeds without reentrant transport ownership. |
| SOC-007 | Submit 100 pushes from four background producers; return mixed success/error replies in reverse order, with duplicate replies | Every request resolves once with its own payload/completion. An error followed by a late success cannot resolve twice. |
| SOC-008 | Repeat terminal failure signals and reconnect for 25 cycles | One teardown per failed connection; a replacement clears failed state and can deliver another push. |

Concurrent producers have no guaranteed global submission order. Tests wait for all producers, then establish an explicit final boundary before asserting the final connection state. They use queue barriers, coroutine scheduling and completion signals rather than sleeps. iOS Phoenix remains on main; Android uses its coroutine mailbox with a controlled test dispatcher and real background callers. These checks exercise SDK ownership and response handling, not real network reliability.

For manual QA, Online S14 reproduces the restored repeated-identify regression after logout: logout → identify A → identify A → first screen, expecting `true / false`. Publisher regression tests also cover repeating the newly selected user after a direct user switch. Online S11/S12 stress public API delivery and identity cleanup with 50 ms spacing; direct socket connect/close coverage belongs to the automated classes above.

## Adding future business cases

Add a feature section with stable case IDs and the following information:

1. **Purpose and terms:** what the feature means to the host app, user, or backend.
2. **Preconditions:** identity, screen, lifecycle, or connectivity state needed for the case.
3. **Trigger and ordered actions:** include relevant replies or completion callbacks; avoid arbitrary sleeps.
4. **Expected result:** payload flags, publication, rendering, persistence, or cleanup that must occur.
5. **Failure behavior:** only the errors/cancellations relevant to that feature's agreed contract.
6. **Regression pointers:** corresponding tests and any device/backend QA evidence, clearly distinguished.

Update both platform copies together. Document an intentional platform difference explicitly rather than silently changing the shared business rule.
