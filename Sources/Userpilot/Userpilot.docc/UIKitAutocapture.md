# UIKit Autocapture

The Userpilot iOS SDK can automatically capture **screen views** and **user interactions** in UIKit apps. For a technical overview of how the UIKit AutoCapture classes relate and call each other, see [UIKit AutoCapture Architecture](UIKitAutoCaptureArchitecture.md). Once enabled via configuration, the SDK records which screens users see and which controls they tap—without requiring manual ``Userpilot/screen(_:)`` or ``Userpilot/track(_:properties:)`` calls for every screen or button.

This guide covers configuration, customizing screen capture behavior, hiding sensitive data, and handling custom clickable views.

---

## Enabling Autocapture

Autocapture is **off by default**. Enable it when building your ``Userpilot/Config`` and initializing Userpilot.

```swift
Userpilot(config: Userpilot.Config(token: "<APP_TOKEN>")
    .logging(enabled: true)
    .enableScreenAutocapture(true)   // Capture screen views automatically
    .enableInteractionAutocapture(true) // Capture taps and interactions automatically
)
```

| Config option | Description | Default |
|---------------|-------------|--------|
| ``enableScreenAutocapture`` | Automatically capture screen events when view controllers appear. | `false` |
| ``enableInteractionAutocapture`` | Automatically capture user interactions (button taps, table/collection selections, text input, etc.). | `false` |

---

## What Gets Captured

### Screen events

When **screen autocapture** is enabled, the SDK records a screen event when a `UIViewController` appears (e.g. pushed, presented, or shown in a tab). Each event includes:

- Current and previous screen names and classes  
- Screen type (e.g. ViewController), path, navigation title  
- Tab name and index when inside a `UITabBarController`  
- Root screen flag and timestamp  

Transient view controllers such as `UIAlertController` and `UIActivityViewController` are **not** treated as the current or previous screen; they are still tracked for analytics but do not update the screen stack.

### Interaction events

When **interaction autocapture** is enabled, the SDK captures:

| Interaction type | UIKit element | Notes |
|------------------|---------------|--------|
| Tap | `UIButton`, other `UIControl` subclasses | Includes target-action name when available |
| Value change | `UISwitch`, `UISlider`, `UISegmentedControl`, `UIStepper`, `UIDatePicker`, `UIPageControl` | Slider and text input are cached and sent once per screen (no flood of events) |
| Text input | `UITextField`, `UITextView` | Cached; one event per field when leaving the screen |
| Cell selection | `UITableView`, `UICollectionView` | Cell class name, index path, and text/labels when available |
| View tap | `UILabel`, `UIImageView`, custom views | Resolves deepest subview at touch point for accurate element type and text |
| Alert / sheet | `UIAlertController` | View-presented event with title and message |

All interaction events include a **screen** object with current/previous screen, path, tab info, and related context from the screen name tracker.

---

## Configuration Options (Config)

Configure global capture and privacy via ``Userpilot/Config``.

### Screen options

| Property | Method | Description | Default |
|----------|--------|-------------|--------|
| ``enableScreenAutocapture`` | ``enableScreenAutocapture(_:)`` | Turn automatic screen capture on or off. | `false` |
| ``disableScreenTitleCapture`` | ``disableScreenTitleCapture(_:)`` | When set, screen titles (e.g. navigation title, tab title) are not stored or uploaded. | `false` |

### Interaction options

| Property | Method | Description | Default |
|----------|--------|-------------|--------|
| ``enableInteractionAutocapture`` | ``enableInteractionAutocapture(_:)`` | Turn automatic interaction capture on or off. | `false` |
| ``disableInteractionTextCapture`` | ``disableInteractionTextCapture(_:)`` | When set, user-visible text (labels, button titles, etc.) is not stored or uploaded. | `false` |
| ``disableInteractionAccessibilityLabelCapture`` | ``disableInteractionAccessibilityLabelCapture(_:)`` | When set, accessibility labels are not stored or uploaded. Use with `disableInteractionTextCapture` when accessibility may mirror on-screen text. | `false` |

Example: disable all text and accessibility label capture for maximum privacy:

```swift
Userpilot(config: Userpilot.Config(token: "<APP_TOKEN>")
    .enableScreenAutocapture(true)
    .enableInteractionAutocapture(true)
    .disableInteractionTextCapture(true)
    .disableInteractionAccessibilityLabelCapture(true)
)
```

---

## Customizing Screen Capture

### Container view controllers

By default, the SDK treats only the direct children of `UINavigationController`, `UITabBarController`, `UISplitViewController`, and `UIPageViewController` as screens. If you have a custom container whose children should be treated as screens, override `isUserpilotContainerClass`:

```swift
extension SignUpFlowViewController {
    open override class var isUserpilotContainerClass: Bool {
        true
    }
}
```

### Custom screen names

Override `userpilotScreenName` to use a stable, meaningful name instead of the view controller class name:

```swift
extension MyViewController {
    open override var userpilotScreenName: String? {
        "Main Signup Flow"
    }
}
```

### Custom or disabled screen title

Override `userpilotScreenTitle` to supply a custom title or disable title capture for that screen:

```swift
extension PrivateViewController {
    open override var userpilotScreenTitle: String? {
        nil  // Disable title capture for this screen
    }
}
```

### Ignoring a screen

To prevent a view controller from being recorded as a screen at all:

```swift
extension SplashViewController {
    open override var userpilotIgnoreScreen: Bool {
        true
    }
}
```

---

## Hiding Sensitive Data

You can hide or redact sensitive data in three ways: disable capture globally, redact text or accessibility labels for specific views, or ignore all interactions for specific views.

### Disabling capture globally

Use ``Userpilot/Config`` to disable text or accessibility label capture for all autocaptured events:

- ``disableInteractionTextCapture`` — no user-visible text stored or uploaded  
- ``disableInteractionAccessibilityLabelCapture`` — no accessibility labels stored or uploaded  
- ``disableScreenTitleCapture`` — no screen titles (navigation/tab titles) stored or uploaded  

Because accessibility labels can mirror on-screen text when accessibility features are on, it’s good practice to set `disableInteractionAccessibilityLabelCapture` when using `disableInteractionTextCapture`.

### Redacting text for specific views

If you only want to redact certain views (e.g. password field, PIN pad), set `userpilotRedactText` or `userpilotRedactAccessibilityLabel` on the responder (view or view controller). Redaction is recursive: set it on a container to redact all descendants.

**In code:**

```swift
// Redact visible text (labels, button titles, etc.)
passwordTextField.userpilotRedactText = true

// Redact accessibility labels (recommended when also redacting text)
sensitiveButton.userpilotRedactAccessibilityLabel = true
```

Redacted values are replaced with `****` in event data. You can set these on `UIView`, `UIViewController`, or any `UIResponder` subclass.

**In Interface Builder:**  
Select the view, open the **Attributes Inspector**, and under **Responder** set **Userpilot Redact Text** and/or **Userpilot Redact Accessibility Label** to **On** (if your Xcode version exposes these Userpilot-added attributes).

### Ignoring all interactions for specific views

To avoid capturing any interaction events for a view and its subviews (e.g. entire PIN or payment screen), set `userpilotIgnoreInteractions`:

```swift
pinContainerView.userpilotIgnoreInteractions = true
```

This applies only to interactions **within** that view hierarchy. Interactions in pushed/presented view controllers or in system UI (e.g. `UIMenu`) are not affected.

---

## Custom clickable views

Standard controls (`UIButton`, `UIControl` subclasses, table/collection cells) and tappable views that participate in the normal touch chain are captured automatically. For **custom views** that act as buttons but are not recognized (e.g. plain `UIView` with a gesture or custom hit-testing), call:

```swift
customButtonView.userpilotRecognizeClickAnalytics()
```

This enables user interaction, adds a tap gesture if needed, sets button-like accessibility traits, and marks the view so the SDK’s touch handling can record taps. Call it after configuring the view and before or after adding it to the hierarchy.

You do **not** need to use this for:

- `UIButton` or other `UIControl` subclasses  
- Views that already receive touches and are in the responder chain  

---

## Summary

| Goal | Approach |
|------|----------|
| Turn on screen + interaction capture | ``enableScreenAutocapture(_:)``, ``enableInteractionAutocapture(_:)`` |
| No text/labels in events (global) | ``disableInteractionTextCapture(_:)``, ``disableInteractionAccessibilityLabelCapture(_:)`` |
| Custom screen name | Override `userpilotScreenName` on `UIViewController` |
| Custom container for screens | Override `isUserpilotContainerClass` on your container class |
| Don’t record a screen | Override `userpilotIgnoreScreen` on `UIViewController` |
| Redact text/labels for one view or subtree | Set `userpilotRedactText` / `userpilotRedactAccessibilityLabel` on the responder |
| Don’t record any taps in a region | Set `userpilotIgnoreInteractions = true` on the container view |
| Make a custom view tappable for autocapture | Call `userpilotRecognizeClickAnalytics()` on the view |

For manual tracking (e.g. custom events or screens), continue to use ``Userpilot/track(_:properties:)`` and ``Userpilot/screen(_:)`` as described in the [iOS SDK installation](https://userpilot-feature-mobile-revamped.mintlify.app/developer/installation/mobile/ios/installation) guide.
