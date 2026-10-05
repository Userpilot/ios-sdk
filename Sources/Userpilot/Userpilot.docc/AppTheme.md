# App Theme

Render every flow and survey with one mobile theme chosen by your app, for example a light and a dark theme that follow your app's appearance.

## Overview

By default each experience uses the theme it was built with. Call `setTheme(name:)` with the title of a mobile theme defined in Userpilot, and the SDK fetches that theme once and applies it to every flow and survey that follows.

```swift
userpilot.setTheme(name: "Brand Dark")
```

Pass `nil` to go back to each experience's own theme.

### Following light and dark mode

The SDK does not read the system appearance, so your app stays in control. Call `setTheme(name:)` wherever your app decides its appearance:

```swift
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    let isDark = traitCollection.userInterfaceStyle == .dark
    userpilot.setTheme(name: isDark ? "Brand Dark" : "Brand Light")
}
```

## Behavior

- The title must match one mobile theme exactly, including case. If no theme or more than one theme has that title, experiences keep their own themes.
- While an app theme is in use, it replaces each experience's whole theme: colors, buttons, fonts, progress, backdrop, dismiss button and placement (a slideout's alignment and a survey's position), including per-step styling from the builder.
- NPS surveys keep their own theme.
- A new theme applies from the next experience; an experience already on screen keeps its look.
- Once fetched, each theme is reused, so switching back and forth is instant. Themes are fetched again after the SDK reconnects, so changes made in Userpilot reach the next experience.
