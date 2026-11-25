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
- **Successful screen ACK:** the backend successfully acknowledges the current screen request. It settles pending identification context and releases that request's queue slot, without changing `is_session_start`.

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
| ID-005 | Same-user identify after the initial screen's successful ACK, followed by a generated refresh | Preserve the current value: `true` on the first screen, `false` after live navigation | `true` |

Same-user identify and screen ACKs never change session-start. During an uninterrupted live session, only a change to the current screen ends session-start. First identification, logout, and a different user start a new identity session; background/foreground expiry keeps its separate lifecycle rule.

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

**ID-002 cold-launch variant: logout, terminate, reopen, identify**

1. Logout, terminate the app, then launch with the stored user ID empty and fresh runtime services.
2. Report the current screen before identify, manually or through enabled screen autocapture. Keep its screen context; do not send, queue, or persist unidentified analytics events.
3. Identify A or B. Wait for the identify ACK.
4. If a track or autocapture event is queued behind identify, let it finish before the generated screen. Its successful ACK must still be able to resolve the known screen.
5. If a real screen is queued, send that screen and do not generate another. Otherwise enqueue one request for the known screen with `is_session_start=true, fake_reload=false`.
6. Acknowledge that screen. No duplicate screen is generated; session-start stays true until a session transition or live navigation changes it.

The screen must be reported again after relaunch; screen context is not persisted across process termination. With no known screen, identify alone does not invent one. Verify this case with screen autocapture both off and on, and with and without a queued interaction. The same case applies to a first installation with no stored identity.

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
generated refresh -> is_session_start=true, fake_reload=true
```

Repeating identify any number of times, including with different properties, preserves the flag. This sequence stays on the first screen without an intervening logout, different user, or lifecycle transition. After live navigation sets session-start to `false`, repeating identify preserves `false` instead; its generated refresh still has `fake_reload=true`.

### ACK ownership and ordering

- A successful current screen ACK settles pending identification context without changing session-start. It does not rewrite the payload already sent.
- Success, error, and timeout all preserve session-start. Errors/timeouts do not settle pending identification context or imply automatic retry; normal queue failure handling still applies.
- An identify queued while a screen is in flight waits for that screen to resolve. If the screen succeeds, the later identify observes the completed initial-screen phase.
- Elapsed milliseconds do not decide these identity rules. Identity changes and screen navigation control session-start; matching ACKs control delivery and pending identification context.
- Generated screens are normal queue entries and retain their own request flags and ACK ownership. They must not overtake earlier analytics or release another request's queue position.

### Boundaries of this section

Screen navigation and experience-dismissal refreshes are covered below. On a real background/foreground return, the existing expiry rule sets session-start to the expiry result: `true` after more than **30 minutes** in the background, otherwise `false`; a pending new identity still takes precedence when preparing its first screen. Both SDKs use the same 30-minute timeout and a strict greater-than comparison, including when returning to the same screen. This is separate from content dismissal or host view/activity callbacks. Offline replay and screen eligibility have their own rules. This identity table does not make every screen after identify a fake reload, or prevent a lifecycle transition from starting another session.

Both platforms enforce the same identity outcomes while retaining native queue/threading behavior. Their sources for a known screen differ: iOS can use the experience publisher's current title; Android uses the current analytics screen session or its screen tracker. Include the relevant known-screen precondition when comparing generated-screen tests.

### Implementation and regression pointers

- `AnalyticsPublisher`: identity admission and cleanup, event queueing, screen construction, matched successful ACK handling, and lifecycle notifications. It reports transitions and uses the returned screen configuration; it does not own a writable session-start flag.
- `UserSessionStateMachine`: the single owner of session-start and identification/background context. `beginSession`, `acknowledgeScreen`, `markScreenChanged`, `resumeSession`, and `resetSessionStart` apply transitions. `getPostIdentificationScreenConfig` chooses generated reload intent at enqueue; `prepareScreen` resolves session-start at send while preserving that queued intent.
- `ScreenSessionStateMachine`: current screen context and seen-content metadata.
- iOS `AnalyticsPublisherTests` and Android `AnalyticsPublisherTest`: fresh identity, unidentified offline events, generated/manual first screens, logout, different-user switch, repeated identify before the first screen, and repeated identify after its successful ACK.
- `UserSessionStateMachineTests` / `UserSessionStateMachineTest`: transition rules and existing diagnostic formats.

These pointers describe current responsibilities. A future internal refactor may move ownership while preserving the business cases above.

## Screen navigation and session-start

During an uninterrupted live session, changing the current screen ends session-start. A screen ACK, same-user identify, or experience dismissal/completion does not change it. Both platforms apply this existing rule when an analytics screen already exists, its title changes, and the socket channel is joined and ready.

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
6. Deliver the refresh through the normal analytics queue and resolve it through its own ACK/error/timeout. Its ACK settles pending identification context and releases its queue slot while preserving session-start.

If content appeared on the first screen and that screen has not changed, dismissal/completion produces `is_session_start=true, fake_reload=true`, even after the first screen ACK and any subsequent refresh ACKs. After live navigation sets the current value to `false`, dismissal/completion produces `is_session_start=false, fake_reload=true`. "Preserve" refers to the current session value, not to copying the flags from the older screen request that originally returned the experience.

This also applies when identify generates the first request from a screen tracked before identification. Android Compose/wrapper screens retain their title-only identity; Activity/Fragment screens retain their native surface identity. A generated request must use the same identity as ordinary navigation, so reloading that screen preserves both session-start and its seen flow/survey IDs. Android native screens include the configured `ui_framework` in both ordinary and identify-generated requests; wrapper screen events omit this native metadata. The field does not participate in screen identity or session transitions.

### EXP-001: dismissal on the first screen, then after navigation

1. Identify A and send `Home`: `is_session_start=true, fake_reload=false`.
2. Receive the successful screen ACK and display its content. Stay on `Home` with no screen queued.
3. Dismiss or complete the content and wait for actual UI removal.
4. The queued `Home` refresh sends `is_session_start=true, fake_reload=true`.
5. Acknowledge the refresh and repeat with the next content: the flags remain `true / true`.
6. Navigate to `Checkout`: its ordinary live screen sends `false / false`.
7. Dismiss content there with no screen queued: the refresh sends `false / true`.

Screen and refresh ACKs preserve the flag throughout. `AnalyticsPublisherTests` / `AnalyticsPublisherTest` exercise repeated content-refresh requests after successful and failed replies, and the separate navigation case. EXP-002 still skips a refresh whenever a screen is queued, including the in-flight screen.

## Preview presentation host

| Case | Scenario | Required behavior |
| --- | --- | --- |
| PREV-001 | Preview content and theme are loaded, but no usable presentation host exists | Keep that preview operation in `WaitingForHost` / `waitingForHost`. Do not fetch it again or report it as seen. Normal experiences still release admission when they cannot present. |
| PREV-002 | A host becomes available | Retry through the existing display-delay/presentation path. Repeated lifecycle signals schedule at most one retry for the same waiting operation. |
| PREV-003 | Logout, explicit closure or a newer preview arrives while waiting | Cancel the old operation. Later host notifications cannot display it or request its fake reload. A newer preview owns its own fetch and presentation. |
| PREV-004 | Screen navigation or socket closure occurs while waiting | Preserve the HTTP preview. Ordinary experience requests arriving during the wait remain dropped. |
| PREV-005 | Preview content is invalid, renderer construction fails, or a tooltip cannot admit its target host | Finish through the existing failure path; do not convert content or targeting failures into indefinite host waiting. |

Android retries on its Activity-monitor callback. iOS uses the shared lifecycle monitor's app-active,
scene-active and key-window callbacks, inspects UIKit on main, and claims the retry on the experience
queue. An immediate readiness probe after entering the wait closes the queue-handoff gap. Scene-based
overlays need an active scene; legacy UIKit apps can use their visible non-scene app window. Normal
controller navigation does not require rehosting the iOS overlay. Existing tooltip target ownership
and native dismissal completion remain unchanged.

## Experience completion links

Completion navigation belongs to the accepted experience operation. Record the selected action's link before closing, wait for the final renderer to be removed, release the operation, then wait **250 milliseconds** before handing the link to the host navigation handler or normal URL opener. The delay starts after UI removal; it is not proof that dismissal completed. This applies to carousel, slideout, tooltip, survey completion, survey thank-you and NPS completion actions.

| Case | Scenario | Expected result |
| --- | --- | --- |
| LINK-001 | Completion action has a link | No navigation while content is visible or dismissing; open once, 250 ms after final removal. Suppress the completion fake reload. |
| LINK-002 | Renderer reports dismissal more than once | Consume its completion link once; no duplicate navigation. |
| LINK-003 | Logout or user switch before removal or during the delay | Discard the outgoing user's link. |
| LINK-004 | Screen change, manual SDK closure or preview replacement interrupts dismissal | Clear the operation's pending completion link. |
| LINK-005 | Survey continues to a thank-you presentation | Keep the same operation; wait for the thank-you renderer's final removal. An old survey callback cannot finish it. |
| LINK-006 | Tooltip target is tapped while its action button has a link | The target tap does not inherit the button's link; its completion event has `hasDeepLink=false` and normal refresh eligibility applies. |
| LINK-007 | A removed renderer reports a link after another experience starts | Reject the stale renderer; never attach its link to the replacement. |

Ordinary inline text hyperlinks retain their existing behavior. This contract does not change flow progression, event names, payload structure or native dismissal animations.

## Tooltip card layout

These cases describe the current tooltip UI. The existing theme payload and shared components
remain authoritative; this does not expand flow admission or change engagement analytics.

| Case | Input | Expected result |
| --- | --- | --- |
| TIP-UI-001 | Title and paragraph text with a CTA | Render title, body and one CTA in that order using shared text/action controls. |
| TIP-UI-002 | Body text without a title | Render the body without an empty heading or extra heading gap; CTA remains optional. |
| TIP-UI-003 | Extra titles, buttons, image or icon-list lines | Keep the first title/CTA and all paragraph lines; omit unsupported rows without modifying decoded content. |
| TIP-UI-004 | Theme enables/disables dismissal | Use the shared close control and existing dismissContent styling; reserve space only when enabled. |
| TIP-UI-005 | Theme enables progress | Show a bar for the `bar` style and dots for every other style, only when `steps_count` exceeds one. A one-step Flow has no progress. |
| TIP-UI-006 | Long body or RTL content | Body/action remain scrollable above the pinned progress; the close control stays inside the card and outside text. |
| TIP-UI-007 | CTA exists with no button action | Deliver the tap once to the existing renderer completion path; do not invent a link. |

## Tooltip targeting and Builder capture

These cases apply to tooltip steps in a Flow and to Builder capture. The Flow walk, step events and fallbacks are in [Mobile Flows](#mobile-flows) (FLOW cases); the tooltip card contract is defined above.

| Case | Scenario | Required behavior |
| --- | --- | --- |
| TIP-001 | Target resolution retries after the foreground window or Activity changes | Resolve only inside the admitted host. Do not fall back to another instance or a new global current host. A removed owner or replaced native root invalidates that work. |
| TIP-002 | The same identifier exists under different SDK owners | Score only eligible candidates belonging to the requesting instance, including an explicitly owned child under another instance's root. Never guess across owners. |
| TIP-003 | A tooltip step's `target` or `settings` fails native decoding | Reject the whole Flow through the logged decode failure (FLOW-003, FLOW-004); survey and NPS siblings are kept. Missing/null optional settings keep their defaults: a missing or null `settings.position` lets layout choose a side, and an unknown name rejects the Flow. The SDK builds the tooltip's targeting and presentation from `target` and `settings`; it reads no `targeting` or `presentation` block from the payload. |
| TIP-004 | A target is missing | The retry ladder is fixed in the SDK: lookups wait 300, 600, 900 and 1,200 ms in turn. The payload carries no retry intervals. Nothing runs while the user scrolls: a scroll cancels the pending retry and any lookup in flight, the next lookup runs once the screen has been quiet for 1 s (TIP-009), and the ladder then resumes. iOS counts user scrolling of the host window's scroll views (SwiftUI included); Android counts any View scroll, not Compose scrolling. A found target shows only once two lookups 100 ms apart agree within 0.5 pt/dp; one still moving after 2 s shows at its latest position, and one that leaves meanwhile is a failed lookup. A visible tooltip re-matches without this wait. Just before a hidden tooltip shows, a drag still in progress on the host ends: Android cancels the window's touch gesture, iOS the host scroll views' drag. |
| TIP-005 | Screen/interaction autocapture is disabled or stopped | Explicit tooltip targeting and Builder capture still work. Autocapture enablement, suppression, ignore and redaction settings must not change Builder screenshots or target inventory. |
| TIP-006 | Native tooltip teardown or recreation occurs | Stop recovery work at teardown; stale callbacks cannot reveal or release another renderer. Android reattaches only to the original host's recreated successor and settles failed reattachment. Backgrounding (Home, app switch, screen lock, another app's screen such as an opened link) keeps the tooltip on its target after return, with no second seen event; Android resolves the target again when the same host resumes. Navigation to another host screen closes it; on Android, another instance of the same Activity class does not (FLOW-036). |
| TIP-007 | Keyboard is open when a tooltip is about to present | The publisher requests keyboard dismissal on main immediately before opening the tooltip. iOS ends editing in the admitted target window; Android uses the presenting Activity's existing `hideKeyboard()`. Presentation does not wait for the keyboard animation, and this does not add keyboard-aware layout or prevent later keyboard reopening. |
| TIP-008 | A Flow has consecutive tooltip steps | They page in `order` (payload position breaks ties) inside one presentation. The button or a target tap advances; on the Flow's last step it completes the Flow, and only that step follows its link (FLOW-012). A second advance within 300 ms is ignored, and taps on the outgoing card do nothing until the next step shows. If the next target does not resolve on its first attempt, the overlay fades out so the host can scroll and fades back in when it resolves. Once it resolves, the card glides and the keyhole moves from the previous step over 300 ms, linear (Android scales this by the system animation setting). Content, theme and tap actions switch to the new step at once. Progress follows TIP-UI-005. Screen readers announce each step: VoiceOver moves to the new card, and TalkBack reads the card's pane title (its title, or first body line). Each move reports the step completed at the tap and the next step seen at its reveal, never a Flow-level event. Only the close button, the button and a target tap end a step; a backdrop tap and Back do not (FLOW-025). A later step whose target never resolves follows its fallback (FLOW-016, FLOW-017). |
| TIP-009 | A tooltip target cannot be used | Only the visible screen is searched. A match counts when it has a size and its middle is on the visible screen, even with its edges cut off; a hidden, zero-size or off-screen element is not found yet. Searches follow the retry ladder (TIP-004), then run again once the host window has been quiet for 1 s: no scrolling and no layout change. Scrolling keeps its own timer, so a screen that never stops animating still recovers after a scroll. Android also counts drawing; iOS compares the window's layer geometry (views added, removed, moved, resized, shown, hidden or faded), so content redrawn inside an unchanged frame does not count. Once the ladder is spent, a failed search sends `mobile_content_error` with its `issue`: `ambiguous` for a tie at the top score, `not_visible` for a fully transparent target (on a web page, `opacity: 0`; `display: none` and `visibility: hidden` hide it), `overlapped` for an opaque colour view drawn over its middle, and `not_found` only when the screen is at its end (its main vertical scroll area cannot scroll further down, or nothing visible scrolls vertically). `not_in_view` is never sent. A screen left before its end sends nothing. Each step sends at most one error, then follows its fallback (FLOW-016, FLOW-017); the SDK log line for it carries the issue and `match_count`. A target that appears in time shows the tooltip with its normal seen event. After the reveal, the target is matched again when the window size changes and once the host screen settles as above; a moved target re-places the card. One failed re-match is tolerated and checked again after 1 s; a second in a row loses the target and closes the step silently (FLOW-026). |
| BLD-001 | Capture requested while an experience is visible or dismissing | Reserve one capture request and wait for the publisher's actual-removal completion before taking the screenshot and element tree. Repeated taps do not start another capture. |
| BLD-002 | Capture continues after session replacement, stop or host invalidation | Discard the stale result and release its own resources. It cannot update the replacement session or keep its capture slot busy. |
| BLD-003 | Screenshot and element tree are assembled | Use the same admitted native host for screenshot and geometry. Use the screen event frozen when Capture was tapped, as defined by BLD-010; do not fabricate it from the host. Preserve full-host output and nested geometry; instance filtering for tooltip matching does not crop Builder output. |
| BLD-004 | A confirmed capture outlives capture UI | The encoder keeps its image and document until encoding finishes. Android hands the bitmap to IO before UI cleanup can recycle it and recycles it after encoding. Encoding happens in memory: nothing is written to disk, and the prepared bytes are released when the upload ends. |
| BLD-005 | Capture mode starts from the Builder QR link | Only `userpilot-{app_token}://sdk/capture?capture_id=…&platform=…&token=…` starts capture mode; there is no public capture API. Query values are URL-decoded and a `+` stays `+`. `platform` must name the receiving SDK's platform, `android` or `ios` in any letter case (BLD-016). Other query items, such as an upload_url from an older QR code, are ignored; the SDK holds the upload URL (BLD-013). The token stays in memory for the session only. It is never logged or stored, and it is sent only as the upload's bearer header (BLD-013). Opening the same QR code again refreshes it. A different capture_id on the same instance replaces the session and cancels its upload without spending the old capture_id. One capture session runs per process: a link for another SDK instance first stops the active session through the process-wide owner, which spends its capture_id. Link logs redact the whole query. The capture button appears on the next active scene (iOS) or resumed Activity (Android). |
| BLD-006 | Builder navigation and recreation | While capture mode is active, the floating control remains available on eligible app screens. Android reattaches to the resumed Activity window and removes obsolete UI; iOS retains its scene window across controller navigation, and closing that scene ends capture mode without spending its capture_id. Stop removes controls and pending attachment work. The floating container is transparent regardless of host theme defaults. |
| BLD-007 | Logout during capture dismissal wait | A queued completion-bearing close still completes after its operation releases UI, even if logout invalidates experience work. The Builder continuation must still validate its originating session and host. |
| BLD-008 | Builder capture controls, confirmation and operator messages | Ship English text only. Keep strings in native SDK resources; do not translate Builder controls from the identified user's locale or experience content. This does not change localization of backend-authored experiences. |
| BLD-009 | Serialize capture metadata | capture.json uses schema version 1 and keeps app, SDK, device, viewport, screenshot and element tree nested. Only literal dots in fixed SDK-owned keys are replaced with underscores; custom keys and metadata are not rewritten. capture_id is the QR link's capture_id, the same value as the upload's capture_id part. display_name is the confirmation sheet's name, trimmed and cut at 255 Unicode code points; the sheet suggests the screen title, and a blank name keeps it. screenshot.file_name is screenshot.png. Element nodes use shared target_class and target_text keys; target_text contains displayed component text, not selector identifiers or accessibility descriptions. Omit unavailable text, password fields and typed input. Analytics text redaction does not apply to Builder text, and the screenshot is not masked; in web content, text under a `data-userpilot-redact` attribute other than `false` is omitted. Write no null fields, no token and no URL. |
| BLD-010 | Read screen metadata for capture | When Capture is tapped, freeze the last screen event before asynchronous layout discovery and write it as `screen: { name, title, metadata }`. title and metadata are exactly what the event sent; name is the title cut at 255 code points. Do not prepare analytics, add session/seen flags, enable autocapture or keep a new latest-screen cache. Without a tracked screen there is no capture (BLD-015). |
| BLD-011 | Use native returned selectors | Android uses target_resource_id, accessibility_label and view_tag end to end with no legacy-key fallback. Live View/Compose provenance preserves respective tag weights once; DOM tag and iOS selector meanings stay unchanged. Custom strategy maps remain untouched. |
| BLD-012 | A component has an analytics label and a targeting identity | userpilotLabel and userpilotTarget are independent and take a non-optional String; a blank or whitespace-only value attaches nothing. userpilotLabel is analytics-only: enabled autocapture sends it as target_text through the label metadata path, applying the text policy once (normalized and truncated, omitted when interaction text capture is off, redacted under userpilotRedactText) without falling through to visible text on suppression; it never yields userpilot_id or a tooltip selector. userpilotTarget is targeting-only: Builder records it as userpilot_id independently of autocapture, a tooltip selector with that userpilot_id matches it first, and it sends no analytics text and ignores text privacy settings. One component may carry both; each keeps its own effect and neither overrides the other. Neither changes hierarchy construction. iOS userpilotLabel keeps its LabelCarrierView, background placement, host resolution and logical type, is not deprecated and never yields userpilot_id. |
| BLD-013 | Upload a confirmed capture | Save shows a progress dialog without Cancel that asks the operator to keep the app open. The PNG and capture.json are encoded in memory off main. A PNG over 5,000,000 bytes or a capture.json over 2,000,000 bytes is not sent and shows "Capture failed"; a file exactly at its limit is sent. One multipart POST goes to the SDK's Appex capture URL for its environment, `https://appex.userpilot.io/api/v1/public/mobile_screen_captures` (appex-dev.userpilot.io in development), with `Authorization: Bearer {token}` and three parts: capture_id, screenshot (screenshot.png, image/png) and document (capture.json, application/json). Each attempt has 30 s in total and reads the session's token when it is sent. A 2xx is saved (BLD-019). A 413, or a 4xx other than 401, 408 and 429, shows "Capture failed" with OK, discards the capture and keeps capture mode on. A 422's message is its errors[0].details sentence, which the backend writes for the operator; any other status, or a 422 without details, shows "This screen couldn't be saved (error N)". Retries follow BLD-018. Logs carry only the category, the HTTP status and errors[0].details. Android keeps the upload running through Activity teardown and shows its progress or result on the next resumed Activity. iOS holds one background task for the whole run; when background time runs out, the run ends as a connection failure. Stop, a new session or logout cancels the upload. |
| BLD-014 | Capture mode is on | Starting capture mode closes the current experience of every SDK instance, visible or still preparing, silently (FLOW-030). While it is on, no instance admits or presents an experience: socket replies, triggerExperience and previews are dropped, not cached. Work that was preparing or in its display delay is never shown and sends no seen event. Screen and track events keep flowing, including repeat screen events. When capture mode ends, nothing is replayed; the next screen event admits content as usual. |
| BLD-015 | Capture is tapped without an identified user or a tracked screen | Take no screenshot. Show "Can't capture yet", which asks the operator to sign in and open a screen Userpilot tracks, with OK; capture mode stays on. A capture needs a non-empty user id and a last screen event with a title. |
| BLD-016 | A QR code is invalid, already used or replayed | One QR code is one capture. A missing link value, or a `platform` that names neither platform, starts nothing, shows "Invalid QR code" and cancels the receiving instance's capture session without spending its capture_id; the log names only the failing field. A link whose `platform` names the other platform, in any letter case, is refused the same way before any other check. Android shows "QR code for iOS": "This QR code was created for iOS. Scan it with an iOS device, or create an Android QR code in the builder." iOS shows "QR code for Android" with the platforms swapped. A capture_id whose session ended in this process (Saved or 401, Close, logout) shows "QR code already used" and starts nothing. Android ignores a recreated launch intent for the capture link, so rotation never restarts capture. Spent capture_ids are kept in memory only. |
| BLD-017 | Logout during capture mode | Logout of the instance that owns the capture session ends capture mode like Close: it cancels the upload run and its wait, removes the capture controls and dialogs, and spends the capture_id. Instance teardown ends capture mode the same way. |
| BLD-018 | An upload attempt fails | One run makes at most 4 attempts with the same bytes and capture_id. A 5xx, 408, timeout or network failure waits 2, 4 or 8 s before the next attempt. The first 429 in a run waits 10 s; a second 429 ends the run. 401, 413 and other 4xx responses are not retried. The progress dialog stays up across attempts. When the run ends on one of these retried failures, "Upload failed" shows with Retry, which starts a new run with the same bytes, and Cancel, which discards the capture and keeps capture mode on. Stop, logout or a new session during a wait sends nothing more. |
| BLD-019 | The upload is saved or its token is refused | A 2xx or a 401 ends capture mode as the result arrives and spends the capture_id, so that QR code cannot start capture mode again. Then a 2xx shows "Saved", and a 401 shows "Invalid QR code" when errors[0].details is invalid_token, otherwise "Session ended". Each has an OK that only closes it. An alert that arrives in the background shows on the next resumed screen. |

Completion-link behavior remains defined by LINK-001–LINK-007. Eligible fake reloads still use the existing analytics queue and session rules; tooltip code does not own either screen flag.

## Mobile Flows

A Flow is `mobile_contents` with `type: "flow"`: one object with `steps_count` (every step of the Flow) and the steps for the current screen. Each step adds `position` (1-based among all steps), `step_type` (`modal`, `slideout` or `tooltip`), `settings` (`position`, `advance_on`, `fallback`, `dismiss_action`, `backdrop`) and, for a tooltip, `target`. The server owns progress and sends the Flow-level events; the SDK walks the received steps in one operation and sends step events. Host callbacks (`onExperienceStateChanged` for the Flow, `onExperienceStepStateChanged` for a step) number a step by its `position` out of `steps_count`. FLOW-030 to FLOW-034 apply to every content type.

| Case | Scenario | Required behavior |
| --- | --- | --- |
| FLOW-001 | A screen reply carries `type: "flow"` | Decode it as one Flow. A tooltip is a one-step Flow; a raw `type: "tooltip"` payload is rejected. Survey and NPS siblings in the same reply stay candidates (PAR-007). The same Flow id can be accepted again, and the Flow's `screens` never filter its steps. |
| FLOW-002 | A step's `position` is missing, below 1 or above `steps_count` | Reject the whole Flow and log the decode failure. Without `steps_count`, any position from 1 up is accepted. A reply can start mid-Flow, for example with positions 3–4 of 4; positions are never compared with the number of steps received. |
| FLOW-003 | A step carries an unknown `step_type` or settings value | Reject the whole Flow and log the decode failure (PAR-008). Missing optional settings keep their defaults: advance on the button, `fallback: skip_step` and `dismiss_action: end_flow`. |
| FLOW-004 | A step's `target` | A tooltip step needs a selector holding at least one string, number or boolean value; numbers and booleans match as their text. A tooltip step with no target, or with a selector that is missing, `null`, empty or holds only null or nested values, rejects the whole Flow. Modal and slideout steps never read the target: `target: null` and an explicit `"selector": null` decode. |
| FLOW-005 | A QR preview of a Flow | The position and tooltip-selector rules of FLOW-002 and FLOW-004 are skipped. |
| FLOW-006 | A screen reply arrives while a newer screen event is queued | Ignore the reply, whatever its content, before decoding it. Otherwise the normal one-experience admission applies. |
| FLOW-007 | The SDK walks a Flow's received steps | Consecutive tooltip steps form one segment shown in one overlay; each modal or slideout step is a segment of its own. A modal step uses the carousel presenter. A slideout step uses the bottom sheet for `settings.position: bottom` and the dialog for `center`; otherwise its theme decides. Segments show in payload order in one operation, 500 ms apart. |
| FLOW-008 | Every received step has ended | Send one fake reload after the last segment's removal, unless a completion link opens (FLOW-012). Its reply carries the Flow's next steps. |
| FLOW-009 | A step is shown | Send `seen_mobile_content_step {mobile_content_id, step_id}` once per step, when it shows; a tooltip step shows when its card is revealed on a resolved target. A skipped step sends none. Seen always comes before that step's outcome. The step callback reports Started; FLOW-018 decides whether Flow Started comes first. |
| FLOW-010 | Next or a target tap, `position < steps_count` | Send `completed_mobile_content_step {mobile_content_id, step_id}` at the tap; the step callback reports Completed. The next step in the segment shows, otherwise the next segment. |
| FLOW-011 | Next or a target tap, `position == steps_count` | Send `completed_mobile_content_step`; the step callback reports Completed, then Flow Completed. The run ends: received steps after it never show, and a tooltip overlay closes even with steps left in its segment. One fake reload follows removal. |
| FLOW-012 | A `link` button | On the Flow's last step: send `completed_mobile_content_step`, end the run, and open the link once, 250 ms after removal, with no fake reload (LINK-001). On an earlier step it acts as Next and opens nothing. |
| FLOW-013 | Close with `dismiss_action: end_flow`, or none | Send `dismissed_mobile_content {mobile_content_id, step_id}` with no `state`; the step callback reports Dismissed, then Flow Dismissed. The run ends and one fake reload follows removal. There is no step-dismissed event. |
| FLOW-014 | Close with `dismiss_action: dismiss_flow_show_next_session` | As FLOW-013, with `state: "session"`. |
| FLOW-015 | Close with `dismiss_action: dismiss_flow_never_show_again` | As FLOW-013, with `state: "never_show_again"`. |
| FLOW-016 | A tooltip target cannot be used, `fallback: skip_step` or none | Send `mobile_content_error {mobile_content_id, step_id, issue, screen}` once (TIP-009); the step id joins `error_steps` (FLOW-020). No step callback and no completed event. The next received step shows; when none is left, one fake reload follows. Skipping the step at `position == steps_count` ends the run with Flow Completed. |
| FLOW-017 | A tooltip target cannot be used, `fallback: end_flow` | Send `mobile_content_error` only. The run ends at once on any step: later steps never show, Flow Completed fires once, the overlay closes and one fake reload follows. No dismissed event. |
| FLOW-018 | Flow Started and Flow Completed | Flow Started fires once per run, before the step callback, on the step at position 1, or on the first step shown after the position-1 step ended by error in the same run. A run whose first received step is past position 1 never reports Flow Started. Flow Completed fires once per run. |
| FLOW-019 | Event and callback order | Every step event goes out before the step's UI starts closing; the fake reload goes out after removal. The SDK records each outcome before the host callbacks fire, so a host reacting inside a callback sees the run already updated. After the run ends, no further step event or callback fires for it, including from a late tap. |
| FLOW-020 | Screen events during a Flow | Every live screen event carries `error_steps`: the step ids that failed in runs still open, empty when none. A run end drops its ids; they also clear on a new session, an expired resume, logout and user switch. Shown step ids merge into the existing `seen_contents` with no new key. Offline batch entries carry neither. There is no Flow-level seen event. |
| FLOW-021 | App relaunch or a new screen mid-Flow | The SDK keeps no Flow progress on disk. The server owns progress and sends the current step with the next screen reply. |
| FLOW-022 | Tooltip step layout | Fixed in the SDK: gap 8, edge margin 16, highlight padding 4 and corner radius 4, card corner radius 12. No pointer shows. `settings.position` `above` or `below` sets the side; `auto` or none lets layout choose. |
| FLOW-023 | A tooltip segment's overlay and the Flow run | One overlay stays up across consecutive tooltip steps (TIP-008). Closing the overlay at a segment's end does not end the run, and ending the run closes the overlay even with steps left. Rotation and recreation keep the step, the run and its seen state, with no second seen event. |
| FLOW-024 | `advance_on: target_tap` | A tap on the target advances like Next (FLOW-010, FLOW-011). The step shows no button even when the payload has a button line, and a target tap never opens a link (LINK-006). |
| FLOW-025 | Back press or backdrop tap on a tooltip step | A backdrop tap does nothing. On Android, Back is not intercepted and reaches the host app; if the host navigates, FLOW-030 applies. iOS has no Back on the overlay. There is no Back between steps. Modal and slideout steps keep their presenters' Back and outside-tap behavior. |
| FLOW-026 | A revealed tooltip's target moves or disappears | The SDK re-matches the target as layout changes. One failed re-match is tolerated; a second in a row loses the target. A lost target, or a layout that cannot be computed, closes the step silently: no Flow event, no callback and no reload. The run stays open, and the server sends the step again on the next real screen event. |
| FLOW-027 | The app goes to the background with a tooltip step showing | Keep the step (Home, app switch, screen lock, another app's screen such as an opened link) on its target after return, with no second seen event (TIP-006). Navigation to another host screen closes it silently (FLOW-030). |
| FLOW-028 | Flow step theme | A step's look merges from its own theme, then the Flow's custom theme, then the base theme's `flow` entry (or, when the theme has none, that step type's `carousel`, `slideout` or `tooltip` entry), then SDK defaults; the step's `settings.backdrop` (`enabled`, `color`, `opacity` 0–100) applies on top. An app theme replaces the merged theme but keeps `settings.backdrop`. |
| FLOW-029 | Step progress | Each step's theme picks a bar (`bar`) or dots (every other style, including `counter`). Progress shows `position` of `steps_count`, counted across the whole Flow, and is hidden when `steps_count` is 1 or less or the theme disables it. |
| FLOW-030 | The SDK closes content itself: navigation to another screen, logout, a QR preview or the start of Builder capture | Every content type (carousel, slideout, NPS, survey and Flow steps) closes through one silent path: no dismissed event, no callback and no fake reload. The SDK waits 500 ms before closing and skips the close if the content changed meanwhile, so a Builder capture screenshot can come up to 500 ms later. An open Flow run pauses; the server sends its step again on the next real screen event. |
| FLOW-031 | The host app calls `endExperience()` | Same as the user's own close for every content type: a dismissed event (with a Flow step's `state`), the callbacks and one fake reload (FLOW-013 to FLOW-015). A tooltip step that was never revealed closes silently. |
| FLOW-032 | A second tap while a carousel or slideout is closing | The first tap reports once; later taps do nothing. This holds for modal and slideout Flow steps too. |
| FLOW-033 | A server push arrives while content shows | Hold it in one slot: the latest valid push wins, and content that fails to decode never takes the slot. It shows after the current content ends. If that content owed a fake reload, the held push takes the reload over, and the reload goes out when the held push ends. Navigation, logout, a QR preview, Builder capture and a completion link drop the held push. Other automatic content that arrives while content shows is dropped. |
| FLOW-034 | A socket message's `payload.request_id` | The SDK treats a message as a server push only when `request_id` is missing or `null`; a present, non-null `request_id` marks a reply to an SDK request, which the push path ignores. |
| FLOW-036 | Android only: another instance of the same Activity class opens while a tooltip step shows, with no new screen event | Known limit: the tooltip stays parked, out of view, on the first instance. A start of the same Activity class counts as a recreation, not navigation, so nothing closes it. It comes back when the first instance resumes; the next screen change closes it silently (FLOW-030), and destroying the first instance releases it with no dismissal event. iOS has no Activity host, so this row does not apply there. |

Regression pointers (unit tests): `FlowContentDecodingTests`, `FlowContentStepsCountDecodingTests`, `FlowContentTooltipStepsTests`, `FlowWalkTests`, `FlowRunTests`, `FlowStepEventsTests`, `FlowStepsProgressTests`, `FlowThemeTests`, `FlowRendererEventOrderTests`, `ExperiencesPublisherFlowWalkTests`, `ExperiencesPublisherTooltipFlowTests`, `ExperiencesPublisherSilentCloseTests`, `ExperiencesPublisherEndExperienceTests`, `ExperiencesPublisherHeldPushTests`, `ExperiencesPublisherCaptureModeTests`, `TooltipFlowStepEventsTests`, `TooltipFlowPagingTests`, `TooltipManualCloseTests` and `FlowCheckpointFixtureTests`. Device and backend QA are separate.

## Native SwiftUI class identity (iOS opt-in)

This iOS-first implementation leaves Android unchanged. `enableScreenClassIdentity` defaults to
false. When enabled before initialization, only native SwiftUI screen events with captured class
metadata use class plus resolved name as their identity. Existing payload field names and values
are preserved; no hierarchy or local visit identifier is added to the wire schema.

| Case | Trigger | Required behavior |
| --- | --- | --- |
| SCR-CLASS-001 | Default-disabled SDK sees different classes with one title | Preserve existing throttling, visit state and wire payloads. |
| SCR-CLASS-002 | Enabled SDK sees different classes with one title | Admit the transition immediately, reset screen seen-content state and treat it as navigation. |
| SCR-CLASS-003 | Same class and name reappear | Preserve the current visit and seen state; retain repeat throttling. |
| SCR-CLASS-004 | Reply arrives after same-name navigation, including A → B → A | Reject the previous visit's content; preserve FIFO acknowledgment handling. |
| SCR-CLASS-005 | Class changes during content preparation or UI handoff | Cancel normal content and reject stale presentation; keep preview behavior. |
| SCR-CLASS-006 | Identify or content dismissal generates a screen | Retain captured class metadata and the current visit; preserve session/fake-reload policy. |
| SCR-CLASS-007 | Event is serialized for offline storage | Retain existing class metadata and omit local visit IDs. |
| SCR-CLASS-008 | Manual, wrapper, UIKit, or missing-class screen | Preserve the existing identity behavior; identical type-erased classes and names remain indistinguishable. |

`ScreenClassIdentityTests` covers these ownership boundaries with controlled replies. The SwiftUI
sample's DEBUG-only `--screen-class-probe` scenario captures real outgoing WebSocket payloads with
a loopback receiver; it does not establish production backend rule support.

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
| Dismissal refresh on the first screen and after navigation / an existing queued screen | Online S17 / S18 |
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

## Multi-instance ownership and lifetime

These cases describe the runtime refactor on `refactor/multi-instance-runtime`. Implementation is
available for review. Automated ownership tests and focused two-account runtime QA have run.

| Case | Scenario | Expected result on both platforms |
| --- | --- | --- |
| MI-001 | Initialize and retain one instance per app token | Each supported initialization creates and registers its own service graph. Repeated initialization with the same live token is unsupported client integration; callers reuse their stored instance. Surrounding token whitespace is removed once at the input boundary, before storage and service startup. |
| MI-002 | Initialize different tokens | Keep identity, session flags, analytics queues, transport, presentation and storage independent. |
| MI-003 | Register a default, then another instance requests the default role | Keep the first claimant, preserve the existing warning, and still register the second instance for its claimed UI. |
| MI-004 | One non-default instance owns the originating UI | Route to that owner even when there is no default. Instance count never bypasses ownership. |
| MI-005 | UI is unclaimed and no default exists | Drop the automatic event. Never choose an arbitrary registered instance. |
| MI-006 | UI has a nested explicit owner | The nearest explicit owner wins before configured platform scopes and default fallback. |
| MI-007 | The selected owner is stopped or has capture disabled | Drop through that owner's capture gates. Never redirect to another enabled/default instance. |
| MI-008 | Deferred interaction fires after the default or UI ownership changes | Preserve its original destination. Drop if that owner is gone; never redirect pending work to a new owner. |
| MI-009 | An explicit binding outlives its removed instance | Treat that binding as unavailable; do not fall through to a different tenant. Reattach/detach deliberately to change ownership. |
| MI-010 | Two instances debounce text changes at the same time | Preserve both pending events independently; one owner's scheduling or stopping cannot cancel another owner's work. |
| MI-011 | The default opts into forwarding captured events from other instances | Publish locally first, then forward one copy directly to the default publisher. Do not resolve ownership again or recursively forward. |
| MI-012 | An instance logs out or switches users | Apply the existing identity/queue/session reset inside that instance. Keep its registration and UI ownership; other instances are unaffected. |
| MI-013 | An instance is removed | Retire its registration and its own resources. Do not promote a surviving non-default or stop process-wide hooks needed by other instances. |
| MI-014 | Explicit `identify`, `screen` or `track` calls target an instance | Use that instance's publisher directly. Native ownership resolution does not change explicit API destinations. |
| MI-015 | SwiftUI scan waits after capture admission | Carry the requesting owner and window weakly; recheck its registration and capture policy at execution. A different root/default must not replace that requester. |
| MI-016 | Stop capture while an interaction is waiting or queued for main delivery | Cancel that instance's unclaimed pending interactions. Other instances keep their work. A callback already claimed to execute may finish. |
| MI-017 | Resume capture after stopping | Accept new interactions; never replay interactions cancelled by the stop. |
| MI-018 | An instance reports an automatic or manual screen with interactions pending | Flush only that instance's pending interactions. On main, delivery runs before the screen changes its context; other instances keep their debounce timing. |

Native differences are deliberate:

- iOS uses `Userpilot(config:)`; Android uses the top-level `Userpilot(context, token)` factory.
  Both initialize a new instance with its own services. Callers initialize once per token and
  retain that instance. The original native initialization signatures remain available to wrappers.
- iOS registrations are weak and retire with ARC. Android registrations hold instances until the
  runtime's internal removal path closes the matching Koin scope. Logout is not disposal.
- UIKit resolves explicit responder bindings, then controller class, window and bundle scopes.
  Android Views resolve their nearest View/Activity binding. Compose uses explicit ownership or
  `UserpilotOwner`, then the native View resolver. UIKit/SwiftUI and View/Compose retain native reads.
- iOS queues an already captured interaction payload. Android preserves its existing delayed native
  text/snapshot read and drops the work if that target has moved to a different owner.
- SwiftUI scans and UIKit hooks remain process-wide. Android compiler bridges and shared gesture
  suppression remain process-wide; debounce work belongs to the destination instance.
- A complete SwiftUI screen can attach its existing `UIHostingController`. This refactor does not
  rehost SwiftUI content or introduce a subtree wrapper that could alter layout or navigation.

The entry flow is native callback → resolve owner → apply that owner's capture rules → owner
coordinator → owner analytics publisher → owner socket. Optional forwarding is a separate direct
publication after the local event. Runtime composition never builds analytics payloads or handles ACKs.

## Hybrid native autocapture

A hybrid app uses one retained SDK instance per account token. iOS selects `.appFramework(.Hybrid)` for UIKit + SwiftUI; Android selects `uiFramework = UiFramework.Hybrid` for Android Views + Compose. This option does not enable capture by itself or change ownership/forwarding.

| Case | Expected behavior |
| --- | --- |
| Native imperative surface | UIKit/View capture uses its existing native hooks, identity and value rules. |
| Native declarative surface | SwiftUI/Compose capture uses its existing hosting/instrumentation path and logical screen name. |
| Event framework metadata | Report UIKit/SwiftUI or View/Compose from the originating surface; never Hybrid. Manual context without a known native source omits it. |
| Identify or content reload | Retain the tracked screen's native framework and identity. A same-screen reload preserves session-start and seen content. Queue admission and `fake_reload` rules above are unchanged. |
| Navigation between frameworks | A real screen change clears the previous screen's seen IDs and changes session-start according to the same session state machine. A framework label alone does not start a new session. |
| Privacy, stop/resume and ownership | Apply the captured owner's configuration and existing ignore/redaction gates. The mode creates no second SDK instance or duplicate capture pipeline. |
| Existing explicit modes or unset framework | Keep their previous behavior. Hybrid must be selected explicitly. |

Android still requires both View and Compose Gradle instrumentation and the existing Compose screen tracker/modifier. Ignore redundant native host screens. iOS SwiftUI button titles/tap-end capture still require the opt-in and iOS 26+; UIKit outside hosted SwiftUI retains its existing touch timing. Below iOS 26, existing capture paths remain in use.

## In-app debugger

| Case | Expected behavior on both platforms |
| --- | --- |
| SDK initialization | Do not open UI or record debugger history until `debug` is called. |
| Repeated `debug` | Reuse the active debugger and record each submission once. |
| Submitted event | Show the publisher submission; a row is not proof of queue admission, socket delivery, or ACK. |
| Preview event | A QR preview's experience events are never sent. Each shows as an SDK row labeled preview, without survey or NPS answers (`feedback`, `score`). |
| Burst recording | Keep the newest 50 events per channel, even while the UI is busy or only the floating controls are visible. |
| Logout | Clear only that instance's debugger history synchronously. An open debugger continues recording subsequent events. |
| Multiple SDK instances | Each has its own manager, event store, and snapshots. Reset/teardown of one does not clear another. |
| Dismiss panel | Panel X, outside tap, Android Back, or tapping the logo while expanded close only the panel. Keep the floating controls visible, preserve all history and continue recording. Reopening shows the retained history; only panel UI observers/collectors stop while collapsed. |
| Navigate during capture mode | Keep an active debugger attached and recording across forward/back navigation and capture-mode entry. Debugger and capture controls coexist at separate initial vertical positions; closing capture mode does not close the debugger. |
| Floating-control design | Both capture and debugger pills are 112 × 56 points/dp with two 48 × 48 touch targets. Purple is #6765E8. Close glyphs match within each platform: larger Android icons, slightly smaller 14-point iOS symbols. Keep native dragging, safe-area/inset and resize behavior. Android debugger tabs use initial capitals, without forced uppercase. |
| Builder sample group | UIKit and Android Views expose one Builder menu containing Tooltips. SwiftUI and Compose Navigation 3 have no Builder group. |
| Floating X | Stop recording, clear all three event channels and Flow history, cancel pending presentation, remove lifecycle/panel observers, and release both controls and panel. Host navigation cannot reopen it; an explicit `debug` starts empty. SDK identity, stored push token and analytics queues remain intact. |
| Full event content | Show every property and full string/nested collection value; only the 50-event history limit applies. Event types use tags and property names are bold. |
| Config inspection | Show current screen/interaction/text/accessibility/value capture flags, wrapper capture flags, and native platform options. Refresh when opening the panel or selecting Config. FCM/APNs token is the last successfully sent token from storage. |
| Rotation or host resizing | Keep the docked edge, scale/clamp vertical placement within the new bounds, resize the panel, and preserve history and expanded state. |
| Flow history | Record up to 50 runs per instance while the debugger is active. Group later checkpoints into the same paused run, start a new run on replay and label previews. |
| Flow steps | Show the known steps in position order with their ID, type and observed state. A shown step records its host screen. A failed target lookup records its issue and attempted screen even if the step never appeared. A silent close pauses an unfinished run. |
| Instance teardown | Stop recording, cancel pending presentation, remove native observation, and release UI resources. |

The same store owns activation, mapping, IDs, buffers and reset. iOS uses a short `NSLock.withLock` transition and UI invalidation callbacks; Android uses `synchronized` and StateFlow snapshots. UI updates consume the latest history, so a delayed update cannot restore events from before logout. These diagnostic operations do not change analytics session flags, payloads, logs, retries, or ACK behavior.

## Native app review

The current development branch exposes `userpilot.requestReview()` on both native SDKs. It requests the host app's native store prompt; it does not submit a review or report whether one was submitted. There is no experience-action or wrapper-bridge integration yet.

| Case | Expected behavior |
| --- | --- |
| AR-001: Call after an app interaction | Request the native App Store / Play Store prompt; identification is not required. |
| AR-002: Call from a background thread | Dispatch native work to the main thread using the platform's existing concurrency mechanism. |
| AR-003: No active app or usable presentation host | Drop the request; never replay it on a later launch or resume. |
| AR-004: Store suppresses the prompt | Continue the host app's flow. No success/failure callback claims that a prompt appeared or a review was submitted. |
| AR-005: Multiple Userpilot accounts | All requests concern the same host app listing. Do not route or forward them as captured analytics events. |
| AR-006: Repeated requests | Let the store enforce eligibility and quotas. The SDK does not promise a dialog or introduce another persistent counter. |
| AR-007: Android host changes during Play preparation | Drop the prepared request if the original Activity is no longer current, alive and not finishing, or the app is inactive. |
| AR-008: Android instance removed during preparation | Cancel pending coroutine work; a later Play response cannot present it. |
| AR-009: Native request fails | Keep the host app running; Android failures use the existing coroutine error logger. |

Native differences: StoreKit uses a foreground window scene on iOS 14+ and its process-level API on iOS 13; it has no asynchronous review-preparation result. Play first prepares a `ReviewInfo`, then launches using the original Activity if it is still usable. Both APIs leave prompt visibility and eligibility to the store. No backend event or new storage field is added.


## Persisted app theme

The current development branch stores the app-selected theme title per SDK token. Theme data remains
an in-memory cache; the existing experience preparation path fetches it when needed.

| Case | Expected behavior |
| --- | --- |
| THM-001: Set a valid theme title | Persist its exact text immediately, even before any content arrives. |
| THM-002: Relaunch without calling `theme` again | The first flow or survey reads the saved title and fetches that theme before rendering. Initialization alone does not fetch it. |
| THM-003: Set another title before the first experience | Replace the stored selection; the next experience requests the latest title. |
| THM-004: Clear the theme | Remove the stored selection and in-memory app themes. Later launches use each experience's own theme. A late reply cannot restore the cleared selection. |
| THM-005: Logout or switch user | Keep the app theme selection; it represents the app's appearance, not user identity. |
| THM-006: Multiple SDK tokens | Each token has its own saved selection; setting or clearing one does not change another. |
| THM-007: Theme unavailable | Keep the saved title but use the existing content-theme fallback. Retry after reconnect or relaunch. |
| THM-008: NPS or already visible content | NPS keeps its embedded theme. Theme changes apply to subsequent experiences; visible content keeps its current appearance. |

`ThemeHandler` owns selection, caches and merges through `DataStoring`. `Storage` owns native
persistence. `ExperiencesPublisher` continues to own theme fetching and preparation; no new request
path, restoration flag or startup task is introduced.

## Shared lifecycle observation

Native lifecycle observation is shared across SDK instances. Each instance keeps its own session policy and feature subscriptions. This centralization does not change the identity/screen flags, 30-minute expiry rule, capture payloads, or parsing policy above.

| Case | Expected behavior |
| --- | --- |
| Several SDK instances subscribe | One native observation source broadcasts to weak subscribers; a repeated subscription does not duplicate native-event delivery. |
| SDK starts while the app is already active | Its session monitor receives current-state catch-up after construction and runs the same foreground sequence; no separate network subscription is needed. |
| App becomes active | SessionMonitor marks its instance active, starts network monitoring, then resumes analytics. Native connectivity readiness still controls when events can send. |
| App enters background | SessionMonitor marks its instance inactive, saves the session date, stops network monitoring, then flushes analytics. Storage does not observe lifecycle. |
| An instance is stopped before queued startup runs | The removed subscription cannot restart it; other live instances continue receiving callbacks. |
| Activity is recreated or another scene activates | Raw host/scene callbacks remain available to presentation and capture services; these are separate from app background/foreground and do not directly reset session flags. |
| Builder or debugger follows host navigation | Native host callbacks reattach its UI only while that feature remains active; closing it removes its own subscription. |
| Subscription is removed during notification | Remaining active subscribers continue; removed subscribers receive no later delivery from that broadcast. |

Android retains ProcessLifecycleOwner timing and unfiltered Activity callbacks. ActivityMonitor updates host state before other listeners, while keeping its filtered navigation notifications. iOS retains distinct application, scene, key-window and memory-warning notifications. Fragment/view lifecycle, keyboard notifications and actual dismissal completion remain with their native feature owners.

LifecycleMonitor owns native observation and weak callback delivery. SessionMonitor owns session
activity and the ordered network/analytics calls; no generic subscriber priority is needed.

## Experience payload field requirements

These requirements apply to both native SDKs. Survey choice IDs, NPS follow-up keys and NPS
primary colors are optional. Their absence does not reject the experience.

| Case | Input | Expected behavior |
| --- | --- | --- |
| PAR-001 | A survey choice has a missing or null `id` | Accept the survey and display the choice. Omit missing IDs from submitted answers; a required choice step needs at least one selected, identified choice. Existing string IDs are preserved. |
| PAR-002 | A present NPS follow-up question has a missing or null `key` | Accept the NPS content and display the question. Keep the model key absent; submission uses the existing empty-string fallback. An absent optional question block retains its existing meaning. |
| PAR-003 | An NPS `theme_data.main` object has a missing or null `primary` | Accept the content and use the existing black primary-color fallback (`#000000`). An explicit color remains unchanged. |
| PAR-004 | NPS `primary` is an object instead of a color string | Reject the containing content. Optional means absence is allowed, not that malformed values silently become defaults. |
| PAR-005 | An optional appearance number is missing or null | Accept the payload and retain the existing rendering default. Explicit zero, false and empty strings remain authored values. |
| PAR-006 | A field cannot be decoded into its declared type, for example `border_radius: "invalid"` | Reject the containing experience or theme response and log the decoding failure through the existing SDK logger. Do not partially render the invalid payload. |
| PAR-007 | A response contains a malformed flow and a valid survey | Reject the flow; the valid survey remains a candidate. |
| PAR-008 | An optional enum field is absent, null, valid or unknown | Absent/null remains optional; a recognized wire name decodes normally; an unknown name rejects the containing payload. Tooltip placement follows the same rule; when absent/null the native layout chooses a side. |
| PAR-009 | A tooltip step's selector value is a number, boolean, object, array or null, or its `target` or `selector` has the wrong shape | Numbers and booleans match as their text; null, object and array values carry no identity and are left out (FLOW-004). A `target` or `selector` of the wrong shape rejects the containing Flow and logs the decode failure. Empty identity strings cannot match a target. |

Payload models use native typed decoding: Swift `Codable` and Moshi-generated Kotlin adapters.
Shared fields retain the same JSON categories (number, string, boolean, array or object), while
native layout types and platform-specific link/selector keys remain platform-specific.

Native scalar coercion is not identical: Swift rejects numeric strings for numeric fields and
numbers for string fields; Moshi can convert those inputs. No strict-number adapter is installed.
Matching property declarations does not imply identical acceptance of every malformed input.
Existing survey-logic decoding keeps its current behavior. Selector properties use a string map until the owning strategy interprets them; constraints
retain their optional string fields and existing wire names. Missing/null fields are accepted;
incompatible booleans, objects or arrays reject the containing content through its normal logged
decode failure, even when another identity field is valid. Empty identity strings are normalized
before matching; they never identify a target. No per-field fallback annotations or permissive
selector adapters are installed. Native scalar coercion remains different as described above.
TIP-003 defines failures propagated by decoding.


## Element targeting strategies

| Case | Input / action | Expected behavior |
| --- | --- | --- |
| STR-001 | No custom strategy configured | Use native View/Compose or UIKit/SwiftUI traversal and the existing native identity weights. |
| STR-002 | Configure a custom strategy for one instance | Only that instance's resolver, Builder tree and screenshot services use it. Another instance keeps its own strategy. |
| STR-003 | Tooltip contains framework-specific string keys | Preserve all keys through decoding. Remove null entries, then ask the owning strategy to inflate once per resolution attempt. No global strategy participates. |
| STR-004 | Logical wrapper element has no native anchor | Match using its selector and own logical bounds. Check ownership against its weak native hosting view. Missing, foreign or detached hosting sources cannot match. |
| STR-005 | Capture a wrapper tree | Keep the full admitted host. Serialize custom selector maps without native references; match ownership filtering and autocapture enablement do not crop Builder output. |
| STR-006 | Strategy overrides screenshot | Use the admitted window, existing logical coordinate space and cleanup path. Null uses native fallback. Carry the supplied logical size and insets into capture.json, including screenshots that exclude a system bar. Reject invalid geometry. Android still refuses secure windows and cancels pending capture. |
| STR-007 | Confirm a capture with custom selectors | Upload capture.json with each custom selector map's own keys. Its screenshot.file_name is screenshot.png, the file name of the upload's screenshot part (BLD-013). |
| STR-008 | Default strategy encounters a native WebView | Asynchronously discover visible main-document elements with `id` or `data-userpilot-id`. Preserve existing native nodes; logical DOM nodes use their own rectangles and weak hosting-view ownership. No text/form values are captured. |
| STR-009 | Web read fails, times out, moves, detaches or changes URL | Add no stale DOM targets. Each WebView read is bounded to two seconds; native layout remains usable. Do not replace host delegates/clients or enable JavaScript on Android. |
| STR-010 | Dismiss, restart or retarget while layout discovery is pending | Cancel/ignore the old read. A late response cannot reveal or reposition the tooltip, start an old screenshot or replace the current capture. Revalidate admitted host ownership after asynchronous discovery. |

Selector implementations are immutable value holders; map serialization may run on the encoder's
background queue (iOS) or the IO dispatcher (Android). Native UI discovery, selector inflation, evaluation and image capture run on main.
Wrappers must supply a strategy before initialization. Existing wrapper packages are not changed
by adding these native extension points.
