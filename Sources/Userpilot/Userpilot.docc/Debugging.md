# In-App Debugger

The Userpilot iOS SDK includes a development overlay for inspecting configuration, stored identity, and live analytics. Use it while integrating or reproducing experience issues. Do not ship it as a customer-facing feature.

## Showing the debugger

Call ``Userpilot/debug()`` after the SDK is initialized:

```swift
userpilot.debug()
```

Objective-C:

```objc
[userpilot debug];
```

A floating **UP** button appears above the host UI and any in-app experiences. Drag it to either edge. Tap it to open or close the panel. Closing the panel keeps collection active. There is no public `stop()` API; `logout()` clears event buffers but leaves the overlay in place.

Tap the top-right bug icon on each sample home screen. The samples expose the same one-liner: UIKit and SwiftUI call `UserpilotManager.shared.debug()`, and the Objective-C sample calls `[[Userpilot shared] debug]` on its host singleton.

## Tabs

| Tab | Contents |
|-----|----------|
| **Config** | SDK version and token, socket URL, push token, autocapture flags, deep-link scheme, and installed fonts |
| **User** | Stored user ID, anonymous ID, and session dates |
| **Manual** | Events from `identify`, `track`, and manual `screen` |
| **Auto** | Autocaptured screens and interactions |
| **SDK** | Internal experience lifecycle events |

Event tabs keep the 50 newest events. Tap a row for flattened properties. Tap a config or user value to copy it.

## Notes

- Events are shown when submitted to the publisher, before queue admission or network delivery. A debugger row does not confirm a socket acknowledgment.
- User and company properties are visible on identify events in the Manual tab; the SDK does not cache a merged profile.
- The overlay sits in its own non-key window so it does not steal the keyboard or status-bar style.
- `logout()` resets debugger event buffers only.

Each SDK instance owns its debugger store and buffers. Debugger windows are excluded from native autocapture.
