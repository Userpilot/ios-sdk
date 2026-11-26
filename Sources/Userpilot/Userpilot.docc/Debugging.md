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

A circular Userpilot logo button appears above the host UI and any in-app experiences. Drag it to either edge. Tap it to open or close the panel. Closing the panel keeps collection active. There is no public `stop()` API; `logout()` clears event buffers but leaves the overlay in place.

Tap the top-right bug icon on each sample home screen. The samples expose the same one-liner: UIKit and SwiftUI call `UserpilotManager.shared.debug()`, and the Objective-C sample calls `[[Userpilot shared] debug]` on its host singleton.

## Tabs

| Tab | Contents |
|-----|----------|
| **Config** | SDK version and token, socket URL, push token, autocapture flags, deep-link scheme, and installed fonts |
| **User** | Stored user ID, anonymous ID, and session dates |
| **Manual** | Events from `identify`, `track`, and manual `screen` |
| **Auto** | Autocaptured screens and interactions |
| **SDK** | Internal experience lifecycle events |
| **Flow** | The 50 most recent flow runs, their status, and the steps reported by the SDK |

Event tabs keep the 50 newest events. Tap a row for flattened properties. Tap a config or user value to copy it.

Open **Flow** while running a flow to see each step’s position, type, ID and state. A revealed step shows the tracked host screen when available. A tooltip that fails before appearing shows the issue and the screen where the lookup failed. A run can complete with a failed step when the flow’s fallback ends the run.

When a flow pauses between screens, later checkpoints for the same user update the same run. A new first step or a new preview gets its own run number. Preview runs are labeled. Recording starts when you call `debug()`. The floating exit button and logout both clear this history.

## Notes

- Events are shown when submitted to the publisher, before queue admission or network delivery. A debugger row does not confirm a socket acknowledgment.
- User and company properties are visible on identify events in the Manual tab; the SDK does not cache a merged profile.
- The overlay sits in its own non-key window so it does not steal the keyboard or status-bar style.
- The debugger stays active after logout and starts a fresh history.

Each SDK instance owns its debugger store and buffers. Debugger windows are excluded from native autocapture.
