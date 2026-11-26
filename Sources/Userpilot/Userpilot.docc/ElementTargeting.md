# Element targeting and Builder strategies

Configure custom element discovery for a wrapper while keeping native host ownership and Builder capture.

## SwiftUI targeting identity

```swift
Button("Save") { save() }
    .userpilotTarget("profile_save")
```

``SwiftUI/View/userpilotTarget(_:)`` gives a view a stable identity for tooltip selectors. Builder
capture records it as `userpilot_id`, even with screen and interaction autocapture disabled, and a
tooltip whose selector has that `userpilot_id` matches the view first. It sends no analytics text
and is not affected by text privacy settings. Use a stable, non-personal identifier that is unique
on the screen; an empty or whitespace-only value attaches nothing.

``SwiftUI/View/userpilotLabel(_:)`` is the analytics counterpart and keeps its 1.4.1 behaviour: it
names the view in interaction events as `target_text` (with the logical view type) and never sets
`userpilot_id`. See *Identifying Custom or Composite SwiftUI Views* in <doc:Autocapture>.
Neither API enables autocapture or adds click detection. These are native SwiftUI APIs, not new
wrapper bridge methods.

## Builder JSON

Each saved capture uploads one `capture.json` document next to its screenshot. The document uses
`schema_version: 1`. Selector scoring has its own version, `selector_version: 1`, which is not part
of the document.

| Field | Value |
| --- | --- |
| `capture_id` | The `capture_id` from the Builder's QR link, also sent as the upload's `capture_id` part. |
| `captured_at` | When the capture was taken, ISO 8601 in UTC. |
| `display_name` | The name typed on the confirmation sheet, trimmed and cut at 255 Unicode code points. The sheet suggests the screen title; a blank name keeps the title. |
| `app`, `sdk`, `device`, `viewport` | Nested objects. `sdk.name` is a path, not a dotted key. |
| `screen` | The last `screen` event's `title` and `metadata`, exactly as the SDK sent them, plus `name`: the title cut at 255 code points. Analytics-only flags and seen content are not added. |
| `screenshot` | `file_name` is `screenshot.png`, the file name of the upload's screenshot part. `format`, `width_px` and `height_px` describe the image. |
| `element_tree` | The root node and every node with a selector. |

Each node has `node_id`, `target_class` (the native type), `target_text` (the displayed text, when
there is any), `bounds`, `visible_bounds`, `selector` and `children`. `visible_bounds` is left out
for a node that is not visible on screen, and the SDK writes no `null` fields.

The native selector keys are `userpilot_id` (from `userpilotTarget` or `data-userpilot-id`;
never from `userpilotLabel`), `accessibility_identifier`,
`auto_tag` (an SDK tag such as `tab[2]` for a view without an identity), `tag` (a nonzero
`UIView.tag`, or `#id` for a web element) and `accessibility_label`. Custom strategy maps keep
their own keys; no key in them or in the screen metadata is rewritten.

## Configuration

```swift
let config = Userpilot.Config(token: "<APP_TOKEN>")
    .elementTargetingStrategy(wrapperStrategy)
let userpilot = Userpilot(config: config)
```

`wrapperStrategy` implements `UserpilotElementTargetingStrategy`. Omitting the option or passing
`nil` uses native UIKit/SwiftUI targeting. Configure it before initialization; the SDK retains it
for that instance. The protocols and the logical-node initializer are Objective-C bridgeable.

The strategy receives the admitted window as the layout root. Element bounds use window-coordinate
points. `captureLayout(in:completion:)` completes exactly once on main, either inline for native
views or asynchronously for web/wrapper reads. Do not block the main thread waiting for a bridge.

`isScrolledToEnd(in:completion:)` is optional. Complete with whether the screen is at its end:
its main vertical scroll area cannot scroll further down, or nothing visible scrolls vertically.
Implement it when the native views cannot see the scroll position, for example a UI drawn into one
native view. Completing with `nil` uses native detection. A tooltip whose target is not found
reports `not_found` only at the end of the screen.

`captureScreenshot(in:)` is optional; nil uses native rendering. Return `UserpilotScreenshot`
with an image, logical `size` in points and `insets` relative to that image. Builder normalizes the
image to one pixel per point and writes the supplied size/insets to `capture.json`.
The image can have a different pixel density or exclude a system bar. Its origin and logical
coordinates must agree with the element tree; set an excluded bar's inset to zero. Invalid
sizes/insets fail capture. Existing native screenshot behavior is unchanged.

## Strategy and selector contract

The SDK reads selector properties as a string map. It preserves framework-specific keys until the
requesting instance's `UserpilotElementTargetingStrategy.inflateSelector` creates a
`UserpilotElementSelector`. No process-wide strategy selects behavior for other instances.
The native default uses the selector keys above, with empty-string normalization and score weights.

1. The resolver admits a host belonging to the requesting instance.
2. Its configured strategy captures that host's element tree and inflates the authored selector.
3. Each candidate selector evaluates the target. Positive scores match; the existing score floor
   and unique-highest-score rule apply. Only the visible screen is searched: a match counts when
   it has a size and its middle is on the visible screen, even with its edges cut off. Hidden,
   zero-size and off-screen elements are not found. Equal highest scores remain ambiguous. The
   winner reports `not_visible` when it, an ancestor or its `ownershipView` is fully transparent,
   and `overlapped` when an opaque view drawn above covers its middle (SwiftUI markers are not
   checked for covers). The tooltip dismisses the keyboard first, so it is never a reason.
   On a web page, `display: none` and `visibility: hidden` hide an element, while `opacity: 0`
   (on the element or a parent) makes it transparent.
4. Matches must belong to the requesting instance. A logical element supplies its own bounds and
   a weak native `ownershipView`; it need not have its own native anchor view.
5. Builder uses the same strategy for its full-host tree and optional screenshot. Match ownership
   filters do not crop the Builder document or depend on autocapture settings. The saved
   `element_tree` keeps its root and only nodes with a selector; a node without one is replaced
   by its targetable descendants.
6. Builder serializes each selector's `toMap()` in the existing `selector` field. Selectors must be
   immutable values without retained native views or SDK instances; serialization runs on the
   capture encoder's background queue. Layout, inflation, matching and screenshot capture run on main.

A malformed map follows normal content-decoding failure. Missing/null properties remain accepted;
null entries are omitted before inflation. A strategy returns nil/null for an unusable identity.
No strategy-specific permissive parsing or global decoder state is installed. Incoming tooltip
payloads retain raw maps until resolution; the capture tree encodes each selector map through
its existing Encodable implementation.

## Wrapper integration boundary

A wrapper integration implements the strategy and selector contracts, builds `ElementNode` trees,
and supplies the strategy before SDK initialization. This is an extension point, not an installed
React Native or Flutter integration. Native capture remains the default.

Logical nodes retain their own geometry, even when several nodes share one hosting view. Each
logical target must provide that weak ownership source; missing or foreign sources cannot match.
Changing the bound owner or replacing the admitted host invalidates pending resolution.
Builder continues to capture the full admitted host, independently of autocapture opt-outs.

For a future React Native selector, the recommended shared scoring policy is `nativeID = 10,000`
and `testID = 1,000`, summed when both match. This policy is not installed by the native default;
the wrapper integration must implement it on both native platforms.

## Native WebView discovery

The default strategy also discovers visible elements in the WebView's main document. Use an HTML
`id` or `data-userpilot-id`, for example:

```html
<button id="buy" data-userpilot-id="checkout">Buy</button>
```

This produces the existing selector keys `tag: "#buy"` and `userpilot_id: "checkout"`. Existing
native scoring applies. The tree contains logical `HTMLNode` entries whose geometry belongs to
the DOM element and whose weak ownership source is the hosting WebView. This enables a thin
Capacitor bridge to use native targeting and Builder discovery without supplying a DOM cache.

Reads are asynchronous, with a two-second limit per WebView. Failed/timed-out reads add no DOM
targets; native nodes remain available. Moved/detached hosts or a changed page URL discard stale replies.
The SDK revalidates admitted host ownership after capture; stopped or replaced tooltip/capture
operations cannot use a late response. The host's navigation delegate/client is never replaced.
Android does not enable JavaScript if the app disabled it.

Only explicit identifiers, visible rectangles and displayed text are read. Each element's text joins
its visible text nodes, capped at 100 characters like autocapture's `target_text`. Input values,
`textarea`/`select`/`option` content, editable content and subtrees whose nearest
`data-userpilot-redact` attribute is not `"false"` never contribute text, and no URLs are read.
Hidden/offscreen targets are excluded; ancestor overflow and viewport
clipping are respected. Discovery does not traverse iframe documents or shadow roots. Autocapture
settings do not enable or disable this explicit targeting/Builder path.

## Upload and scope

Capture mode starts only from the Builder's QR link; the SDK has no public capture API. Forward
Userpilot links to the SDK as described in <doc:URLSchemeConfiguring>. While capture mode is on,
no experience shows from any SDK instance, and analytics events keep flowing.

Save sends the screenshot (`screenshot.png`) and `capture.json` in one multipart request to the
upload URL from the QR link, with the link's token as a bearer token. Encoding happens in memory;
nothing is written to disk. A strategy changes discovery and screenshots only: native matching
weights, experience teardown and analytics log formats are the same with or without one.
