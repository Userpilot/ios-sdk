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

For SwiftUI, the equivalent API is ``userpilotLabel(_:)`` — it tags any SwiftUI view (including composite ones using `.onTapGesture`) with a stable analytics label and view type. See *Labeling custom or composite SwiftUI views* under [SwiftUI Autocapture](#swiftui-autocapture).


---

## SwiftUI Autocapture

The Userpilot SDK supports automatic capture in SwiftUI apps. SwiftUI autocapture bridges to UIKit through the hosting controller, so the same configuration options and privacy controls apply. SwiftUI exposes a small set of view modifiers that mirror the UIKit autocapture surface; nothing else is required for the common cases.

| SwiftUI modifier | Purpose |
|---|---|
| ``userpilotScreenName(_:)`` | Override the screen name reported for the autocaptured screen this view belongs to. |
| ``userpilotScreen(_:)`` | Emit a manual screen event when this view appears (for apps with automatic screen capture **disabled**). |
| ``userpilotLabel(_:)`` | Attach a stable analytics label and logical view type to a view (recommended for custom or composite tappable views). |
| ``userpilotRedactText(_:)`` | Mark text content as sensitive — captured text becomes `****`. |
| ``userpilotIgnoreInteractions(_:)`` | Suppress all interaction events for this view and its descendants. |

### Configuration

For SwiftUI apps, set the app framework in your configuration:

```swift
Userpilot(config: Userpilot.Config(token: "<APP_TOKEN>")
    .appFramework(.swiftUI)
    .enableScreenAutoCapture(true)
    .enableInteractionAutoCapture(true)
)
```

All UIKit configuration options — including ``enableInteractionTextCapture(_:)``, ``enableInteractionAccessibilityLabelCapture(_:)``, ``enableInteractionValueCapture(_:)``, and ``enableScreenTitleCapture(_:)`` — apply unchanged to SwiftUI apps.

### Screen Tracking in SwiftUI

#### Automatic Screen Capture

With ``enableScreenAutoCapture(true)``, the SDK records a screen event whenever a SwiftUI view becomes visible inside its `UIHostingController`. By default the screen name is derived from the SwiftUI type.

#### Custom Screen Names — ``userpilotScreenName(_:)``

Use ``userpilotScreenName(_:)`` to override the **autocaptured** screen name with a stable, human-readable string. The modifier propagates the name to the underlying hosting controller, so it takes effect on the next automatic screen event for that screen.

```swift
struct ProfileView: View {
    var body: some View {
        VStack {
            Text("Profile")
            // ...
        }
        .userpilotScreenName("User Profile")
    }
}
```

This is the right choice when **screen autocapture is enabled** and you want a better label than the synthesized SwiftUI type name.

#### Manual Screen Events — ``userpilotScreen(_:)``

Use ``userpilotScreen(_:)`` when **screen autocapture is disabled** (or when you need to emit an additional screen event for a non-routing view such as a tab). It calls ``Userpilot/screen(_:)`` from `.onAppear`. If `name` is omitted the SwiftUI type name is used.

```swift
struct CheckoutView: View {
    var body: some View {
        VStack {
            Text("Checkout")
            // ...
        }
        .userpilotScreen("Purchase Checkout")
    }
}
```

> Tip: If `enableScreenAutoCapture` is `true`, manual ``Userpilot/screen(_:)`` calls (and therefore `userpilotScreen(_:)`) are intentionally suppressed to avoid double-tracking. Pick **one** of the two modifiers per screen.

### Interaction Tracking in SwiftUI

#### What Gets Captured Automatically

When interaction autocapture is enabled, the SDK captures:

- SwiftUI `Button` taps
- `NavigationLink` activations
- `Toggle`, `Slider`, `Stepper`, `Picker` value changes (via their underlying UIKit controls)
- `List` row selections and `.pickerStyle(.inline)` / `.pickerStyle(.wheel)` selections
- Most views with `.onTapGesture` — the gesture recognizer is observed through the same `UIWindow` swizzle the SDK uses for UIKit, so no accessibility traits are required

#### Labeling Custom or Composite SwiftUI Views — ``userpilotLabel(_:)``

The recommended way to make a custom or composite SwiftUI view identifiable in analytics is ``userpilotLabel(_:)``. The modifier sets a stable label and a logical view type (`Button`, `Text`, `Toggle`, `NavigationLink`, or the SwiftUI type name) on the resolved underlying UIKit view. The autocapture pipeline reads those values and reports them as `element_text` and `element_type` on every interaction event the view emits.

```swift
// Composite tappable card — the entire VStack is one logical "Favorite row"
HStack {
    Image(systemName: "star")
    Text("Favorite")
}
.onTapGesture { toggleFavorite() }
.userpilotLabel("Favorite row")

// Make a Button report a friendlier name
Button("Submit") { send() }
    .userpilotLabel("Submit order")

// Override what an isolated Text reports when it participates in tap events
Text("Balance")
    .userpilotLabel("Account balance label")
```

Resolution rules:

- The modifier first looks for a **taggable sibling** under the same UIKit parent (covers the common `.background` placement). Taggable kinds are `UIControl`, `UILabel`, `UIImageView`, and `UITextView`.
- If no sibling matches, it walks up to the nearest **taggable ancestor**.
- If neither is found, the parent UIKit view is used as a fallback.

Pass `nil` to clear a previously applied label when the content becomes conditional. Logical view types are best-effort from `String(reflecting: Self.self)`; unknown types fall back to the bare `Self` name.

If you cannot use ``userpilotLabel(_:)`` for some reason (e.g. you can't reach the view to attach a modifier), Apple's native accessibility modifiers still help a screen reader and may improve hit-target resolution for some custom hierarchies — but they do **not** replace the analytics label that ``userpilotLabel(_:)`` provides:

```swift
.accessibilityElement(children: .combine)
.accessibilityAddTraits(.isButton)
```

### Hiding Sensitive Data in SwiftUI

#### Redacting Text — ``userpilotRedactText(_:)``

Marks text content under this view as sensitive. Captured `element_text` becomes `****`; the on-screen text is unchanged. The flag propagates down the responder chain, so applying it to a container redacts every descendant.

```swift
// One field
Text("Account: \(accountNumber)")
    .userpilotRedactText(true)

// An entire group
VStack {
    Text("Balance: $\(balance)")
    Text("Account: \(accountNumber)")
}
.userpilotRedactText(true)
```

> SwiftUI does not currently expose a dedicated modifier for redacting accessibility labels. Use the global ``enableInteractionAccessibilityLabelCapture(_:)`` config to disable accessibility-label capture process-wide, or attach `userpilotRedactAccessibilityLabel = true` to the underlying UIKit view via a `UIViewRepresentable` if you need per-view control.

#### Ignoring Interactions — ``userpilotIgnoreInteractions(_:)``

Stops the SDK from emitting any interaction events for this view and its descendants. The view itself stays fully functional.

```swift
Button("Debug Action", action: debugAction)
    .userpilotIgnoreInteractions(true)

Section {
    Toggle("Debug Mode", isOn: $debugMode)
    Button("Clear Cache") { clearCache() }
}
.userpilotIgnoreInteractions(true)
```

This applies to the underlying SwiftUI subtree only. Interactions in pushed/presented hosting controllers are not affected.

---

## Summary

### Configuration

| Goal | Approach |
|------|----------|
| Turn on screen + interaction capture | ``enableScreenAutoCapture(_:)``, ``enableInteractionAutoCapture(_:)`` |
| No text/labels in events (global) | ``enableInteractionTextCapture(false)``, ``enableInteractionAccessibilityLabelCapture(false)`` |
| Pause all capture temporarily | `Userpilot.stopAutoCapture()` / `Userpilot.resumeAutoCapture()` |

### UIKit

| Goal | Approach |
|------|----------|
| Custom screen name | Override `userpilotScreenName` on `UIViewController` |
| Custom container for screens | Override `isUserpilotContainerClass` on your container class |
| Don’t record a screen | Override `userpilotIgnoreScreen` on `UIViewController` |
| Redact text/labels for one view or subtree | Set `userpilotRedactText` / `userpilotRedactAccessibilityLabel` on the responder |
| Don’t record any taps in a region | Set `userpilotIgnoreInteractions = true` on the container view |
| Hide inner structure of a container | Set `userpilotIgnoreInnerHierarchy = true` on the container view |
| Set ignore/redact on a responder from Swift | Set `userpilotIgnore*` / `userpilotRedact*` properties directly |
| Apply a default to every instance of a type | Override `userpilotIgnoreInteractionsDefault` / `userpilotIgnoreInnerHierarchyDefault` |
| Make a custom UIKit view tappable for autocapture | Call `userpilotRecognizeClickAnalytics()` on the `UIView` |

### SwiftUI

| Goal | Modifier |
|------|----------|
| Override the autocaptured screen name | ``userpilotScreenName(_:)`` |
| Emit a manual screen event (autocapture disabled) | ``userpilotScreen(_:)`` |
| Label a custom or composite tappable view | ``userpilotLabel(_:)`` |
| Redact text for a view or subtree | ``userpilotRedactText(_:)`` |
| Suppress interaction events for a view or subtree | ``userpilotIgnoreInteractions(_:)`` |

For manual tracking (e.g. custom events or screens), continue to use ``Userpilot/track(_:properties:)`` and ``Userpilot/screen(_:)`` as described in the [iOS SDK installation](https://userpilot-feature-mobile-revamped.mintlify.app/developer/installation/mobile/ios/installation) guide.
