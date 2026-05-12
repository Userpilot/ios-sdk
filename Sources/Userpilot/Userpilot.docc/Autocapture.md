# UIKit & SwiftUI Autocapture

The Userpilot iOS SDK can automatically capture **screen views** and **user interactions** in both UIKit and SwiftUI apps. For a technical overview of how the UIKit AutoCapture classes relate and call each other, see [UIKit AutoCapture Architecture](UIKitAutoCaptureArchitecture.md). Once enabled via configuration, the SDK records which screens users see and which controls they tap—without requiring manual ``Userpilot/screen(_:)`` or ``Userpilot/track(_:properties:)`` calls for every screen or button.

This guide covers configuration for both UIKit and SwiftUI, customizing screen capture behavior, hiding sensitive data, and handling custom clickable views.

---

## Enabling Autocapture

Autocapture is **off by default**. Enable it when building your ``Userpilot/Config`` and initializing Userpilot.

```swift
Userpilot(config: Userpilot.Config(token: "<APP_TOKEN>")
    .logging(enabled: true)
    .appFramework(.uiKit)  // Specify UIKit framework
    .enableScreenAutoCapture(true)   // Capture screen views automatically
    .enableInteractionAutoCapture(true) // Capture taps and interactions automatically
)
```

| Config option | Description | Default |
|---------------|-------------|--------|
| ``enableScreenAutoCapture`` | Automatically capture screen events when view controllers appear. | `false` |
| ``enableInteractionAutoCapture`` | Automatically capture user interactions (button taps, table/collection selections, text input, etc.). | `false` |

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
| ``enableScreenAutoCapture`` | ``enableScreenAutoCapture(_:)`` | Turn automatic screen capture on or off. | `false` |
| ``enableScreenTitleCapture`` | ``enableScreenTitleCapture(_:)`` | When enabled, screen titles (e.g. navigation title, tab title) may be captured. Set to `false` to disable title capture globally. | `true` |
| ``appFramework`` | ``appFramework(_:)`` | Specify whether your app uses UIKit or SwiftUI (affects autocapture behavior). | `.uiKit` |

### Interaction options

| Property | Method | Description | Default |
|----------|--------|-------------|--------|
| ``enableInteractionAutoCapture`` | ``enableInteractionAutoCapture(_:)`` | Turn automatic interaction capture on or off. | `false` |
| ``enableInteractionTextCapture`` | ``enableInteractionTextCapture(_:)`` | When enabled, user-visible text (labels, button titles, etc.) may be captured. Set to `false` to disable globally. | `true` |
| ``enableInteractionAccessibilityLabelCapture`` | ``enableInteractionAccessibilityLabelCapture(_:)`` | When enabled, accessibility labels may be captured. Set to `false` to disable globally. Use with `enableInteractionTextCapture(false)` when accessibility may mirror on-screen text. | `true` |
| ``enableInteractionValueCapture`` | ``enableInteractionValueCapture(_:)`` | When enabled, captures values from controls like switches, sliders, and pickers. | `true` |
| ``ignoreTapForTextInputEditingActions`` | ``ignoreTapForTextInputEditingActions(_:)`` | When true, prevents duplicate events by not sending tap events for text input editing actions. | `true` |
| ``preferUIKitOverSwiftUIForNavigationBar`` | ``preferUIKitOverSwiftUIForNavigationBar(_:)`` | When true, prefers UIKit events over SwiftUI for navigation bar interactions to avoid duplicates. | `true` |

Example: disable all text and accessibility label capture for maximum privacy:

```swift
Userpilot(config: Userpilot.Config(token: "<APP_TOKEN>")
    .appFramework(.uiKit)  // Specify UIKit framework
    .enableScreenAutoCapture(true)
    .enableInteractionAutoCapture(true)
    .enableInteractionTextCapture(false)
    .enableInteractionAccessibilityLabelCapture(false)
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

- ``enableInteractionTextCapture(false)`` — no user-visible text stored or uploaded  
- ``enableInteractionAccessibilityLabelCapture(false)`` — no accessibility labels stored or uploaded  
- ``enableScreenTitleCapture(false)`` — no screen titles (navigation/tab titles) stored or uploaded  

Because accessibility labels can mirror on-screen text when accessibility features are on, it’s good practice to set `enableInteractionAccessibilityLabelCapture(false)` when using `enableInteractionTextCapture(false)`.

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

### Hiding inner view hierarchy

`userpilotIgnoreInnerHierarchy` lets you hide the structure *inside* a container while still recording that an interaction happened. When set, all touches inside the view are attributed to the container itself — the element path and text from any child views are suppressed and replaced with `****`. Use this for complex widgets (e.g. a PIN pad) where you want to know the pad was tapped but not which individual key.

```swift
pinPadView.userpilotIgnoreInnerHierarchy = true
```

Unlike `userpilotIgnoreInteractions` (which records nothing), `userpilotIgnoreInnerHierarchy` still sends a tap event — it just omits inner details.

### Stopping and resuming all autocapture

To halt all screen and interaction capture temporarily (e.g. during onboarding flows or sensitive transactions):

```swift
Userpilot.stopAutoCapture()

// ... sensitive flow ...

Userpilot.resumeAutoCapture()
```

While stopped, **no** screen or interaction events are recorded regardless of any other configuration. This is a global toggle — it overrides per-view settings.

---

## Programmatic API

Use responder properties directly for ignore/redact behavior:

| Property | Effect |
|----------|--------|
| `userpilotIgnoreInteractions` | Skip interaction capture for this responder subtree |
| `userpilotIgnoreInnerHierarchy` | Attribute child taps to parent container and hide inner details |
| `userpilotRedactText` | Replace captured text with `****` |
| `userpilotRedactAccessibilityLabel` | Replace captured accessibility labels with `****` |

Class-level defaults are available via overridable class vars:

```swift
class PaymentCellView: UIView {
    override class var userpilotIgnoreInteractionsDefault: Bool { true }
}

class SensitiveContainerView: UIView {
    override class var userpilotIgnoreInnerHierarchyDefault: Bool { true }
}
```

A per-instance value always takes precedence over the class default.

---

## Custom clickable views (UIKit)

Standard controls (`UIButton`, `UIControl` subclasses, table/collection cells) and tappable views that participate in the normal touch chain are captured automatically. For **custom UIKit views** that act as buttons but are not recognized (e.g. plain `UIView` with a gesture or custom hit-testing), call:

```swift
customButtonView.userpilotRecognizeClickAnalytics()
```

This enables user interaction, adds a tap gesture if needed, sets button-like accessibility traits, and marks the view so the SDK’s touch handling can record taps. Call it after configuring the view and before or after adding it to the hierarchy.

You do **not** need to use this for:

- `UIButton` or other `UIControl` subclasses  
- Views that already receive touches and are in the responder chain  

For SwiftUI, this API is **not** provided — use Apple's native `.accessibilityElement(children: .combine)` + `.accessibilityAddTraits(.isButton)` instead (see *SwiftUI Autocapture* below).


---

## SwiftUI Autocapture

The Userpilot SDK also supports automatic capture in SwiftUI apps. SwiftUI autocapture works by bridging to UIKit through the hosting controller, allowing the same configuration options and privacy controls to apply.

### Configuration

For SwiftUI apps, set the app framework in your configuration:

```swift
Userpilot(config: Userpilot.Config(token: "<APP_TOKEN>")
    .appFramework(.swiftUI)  // Specify SwiftUI framework
    .enableScreenAutoCapture(true)
    .enableInteractionAutoCapture(true)
)
```

All the same configuration options from UIKit apply to SwiftUI apps, including privacy settings and capture toggles.

### Screen Tracking in SwiftUI

#### Automatic Screen Capture

When screen autocapture is enabled, the SDK automatically tracks SwiftUI views when they appear. Screen names are derived from the view's type by default.

#### Custom Screen Names

Use the ``userpilotScreenName(_:)`` modifier to set meaningful screen names:

```swift
struct ProfileView: View {
    var body: some View {
        VStack {
            Text("Profile")
            // ...
        }
        .userpilotScreenName("User Profile")  // Custom screen name
    }
}
```

#### Manual Screen Tracking

For more control, use the ``trackScreen(_:)`` modifier to manually track screen events:

```swift
struct CheckoutView: View {
    var body: some View {
        VStack {
            Text("Checkout")
            // ...
        }
        .trackScreen("Purchase Checkout")  // Manual screen tracking
    }
}
```

### Interaction Tracking in SwiftUI

#### Automatic Interaction Capture

When interaction autocapture is enabled, the SDK automatically captures:
- SwiftUI `Button` taps
- `NavigationLink` activations
- `Toggle`, `Slider`, `Stepper`, `Picker` value changes (via their underlying UIKit controls)
- `List` row and `.pickerStyle(.inline)` / `.pickerStyle(.wheel)` selections
- Custom views with tap gestures (when SwiftUI exposes them as accessibility elements — most container views with `.onTapGesture` already qualify)

#### Custom Clickable Views

If a custom SwiftUI view with `.onTapGesture` is not picked up, apply Apple's native accessibility modifiers so the view is exposed as a single clickable element:

```swift
VStack {
    Text("Custom Button")
    Image(systemName: "star")
}
.onTapGesture {
    performAction()
}
.accessibilityElement(children: .combine)
.accessibilityAddTraits(.isButton)
```

For attaching analytics text and a logical view type to any SwiftUI view, use ``userpilotLabel(_:)`` (see *View+UserpilotLabel*).

### Hiding Sensitive Data in SwiftUI

#### Redacting Text

Use the ``userpilotRedactText(_:)`` modifier to redact sensitive text content:

```swift
Text("Account: \(accountNumber)")
    .userpilotRedactText(true)  // Text becomes "****" in events
```

#### Ignoring Interactions

Use the ``userpilotIgnoreInteractions(_:)`` modifier to prevent interaction capture:

```swift
Button("Debug Action", action: debugAction)
    .userpilotIgnoreInteractions(true)  // No interaction events captured
```

---

## Summary

| Goal | Approach |
|------|----------|
| Turn on screen + interaction capture | ``enableScreenAutoCapture(_:)``, ``enableInteractionAutoCapture(_:)`` |
| No text/labels in events (global) | ``enableInteractionTextCapture(false)``, ``enableInteractionAccessibilityLabelCapture(false)`` |
| Custom screen name | Override `userpilotScreenName` on `UIViewController` |
| Custom container for screens | Override `isUserpilotContainerClass` on your container class |
| Don’t record a screen | Override `userpilotIgnoreScreen` on `UIViewController` |
| Redact text/labels for one view or subtree | Set `userpilotRedactText` / `userpilotRedactAccessibilityLabel` on the responder |
| Don’t record any taps in a region | Set `userpilotIgnoreInteractions = true` on the container view |
| Hide inner structure of a container | Set `userpilotIgnoreInnerHierarchy = true` on the container view |
| Pause all capture temporarily | `Userpilot.stopAutoCapture()` / `Userpilot.resumeAutoCapture()` |
| Set ignore/redact on a responder from Swift | Set `userpilotIgnore*` / `userpilotRedact*` properties directly |
| Apply a default to every instance of a type | Override `userpilotIgnoreInteractionsDefault` / `userpilotIgnoreInnerHierarchyDefault` |
| Make a custom UIKit view tappable for autocapture | Call `userpilotRecognizeClickAnalytics()` on the `UIView` (UIKit only) |

For manual tracking (e.g. custom events or screens), continue to use ``Userpilot/track(_:properties:)`` and ``Userpilot/screen(_:)`` as described in the [iOS SDK installation](https://userpilot-feature-mobile-revamped.mintlify.app/developer/installation/mobile/ios/installation) guide.
