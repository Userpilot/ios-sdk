# In-App Debugger

The Userpilot iOS SDK includes a development overlay for inspecting configuration, the cached user, and live analytics. Use it while integrating or reproducing experience issues. Do not ship it as a customer-facing feature.

## Showing the debugger

Call ``Userpilot/debug()`` after the SDK is initialized:

```swift
userpilot.debug()
```

Objective-C:

```objc
[userpilot debug];
```

A floating **UP** button appears above the host UI and any in-app experiences. Drag it to either edge. Tap it to open or close the panel. There is no public `stop()` API; `logout()` clears event buffers but leaves the overlay in place.

The samples expose the same one-liner: UIKit and SwiftUI call `UserpilotManager.shared.debug()`, and the Objective-C sample calls `[[Userpilot shared] debug]` on its host singleton.

## Tabs

| Tab | Contents |
|-----|----------|
| **Config** | SDK version and token, socket URL, push token, autocapture flags, deep-link scheme, and installed fonts |
| **User** | Cached identity, user properties, and company properties |
| **Manual** | Events from `identify`, `track`, and manual `screen` |
| **Auto** | Autocaptured screens and interactions |
| **SDK** | Internal experience lifecycle events |

Event tabs keep the 50 newest events. Tap a row for flattened properties. Tap a config or user value to copy it.

## Notes

- Analytics is observed, not intercepted. Events still publish to the socket as usual.
- The overlay sits in its own non-key window so it does not steal the keyboard or status-bar style.
- `logout()` resets debugger event buffers only.
