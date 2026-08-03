# Liquid Glass

From iOS 26, Userpilot experiences can render with Apple's **Liquid Glass** material. The SDK keeps its previous appearance everywhere else — on earlier iOS versions, when built with an Xcode that predates the iOS 26 SDK, and whenever you opt out. No source changes are required either way.

Glass is applied deliberately rather than everywhere, following Apple's guidance: *"Avoid overusing Liquid Glass effects. […] Limit these effects to the most important functional elements in your app."* So the SDK glasses **chrome** — the dismiss button, the action button, popup menus, the date picker — by default, and treats **card backgrounds** as opt-in.

This guide covers requirements, the configuration options, what glass supersedes from your theme, and the behaviour changes worth knowing about before you enable it.

---

## Requirements

| | |
|---|---|
| Deployment target | Unchanged — iOS 13 |
| Glass rendering | iOS 26 or later |
| Build requirement | Xcode 26 or later |

The SDK builds with Xcode 15 and later. Liquid Glass visuals require building with Xcode 26 or later **and** running on iOS 26 or later. Glass is also suppressed entirely when your app sets `UIDesignRequiresCompatibility` in its Info.plist, so an app that opts out of the iOS 26 design system system-wide gets a matching SDK.

---

## Enabling Liquid Glass

Chrome glass is **on by default**. Card backgrounds are **off by default** and are enabled per group when building your ``Userpilot/Config``.

```swift
Userpilot(config: Userpilot.Config(token: "<APP_TOKEN>")
    .liquidGlass(true)                      // global switch, default ON
    .liquidGlassSheetsAndDialogs(true)      // sheets + dialogs, default OFF
    .liquidGlassFullScreen(true)            // carousel + full-screen survey, default OFF
)
```

### Which experiences each option covers

Card backgrounds are split by how much of the screen they cover, because that is what decides the legibility risk. **Neither opt-in enables the other.**

| Experience | Opt-in |
|---|---|
| Bottom sheets — survey, NPS, thank-you, slide-out | ``Userpilot/Config/liquidGlassSheetsAndDialogs(_:)`` |
| Centre dialogs — survey, slide-out | ``Userpilot/Config/liquidGlassSheetsAndDialogs(_:)`` |
| Carousel steps | ``Userpilot/Config/liquidGlassFullScreen(_:)`` |
| Full-screen survey list | ``Userpilot/Config/liquidGlassFullScreen(_:)`` |
| Dismiss button, action button, popup menus, date picker, scroll edge effect | ``Userpilot/Config/liquidGlass(_:)`` only — on by default |

---

## Configuration Options (Config)

| Property | Method | Description | Default |
|----------|--------|-------------|--------|
| `liquidGlassEnabled` | ``Userpilot/Config/liquidGlass(_:)`` | Global switch. When `false`, the SDK renders its pre-iOS 26 appearance everywhere, including chrome, and every option below is ignored. | `true` |
| `liquidGlassSheetsAndDialogsEnabled` | ``Userpilot/Config/liquidGlassSheetsAndDialogs(_:)`` | Glass on bottom sheets and centre dialogs. | *unset* — defers to the theme, which is solid |
| `liquidGlassFullScreenEnabled` | ``Userpilot/Config/liquidGlassFullScreen(_:)`` | Glass on carousel steps and the full-screen survey. | `false` |
| `liquidGlassDefaultBackgroundEnabled` | ``Userpilot/Config/liquidGlassDefaultBackground(_:)`` | Fill glass cards with Apple's material instead of tinting them with your `background_color`. | `true` |
| `liquidGlassDefaultBackdropEnabled` | ``Userpilot/Config/liquidGlassDefaultBackdrop(_:)`` | Dim behind glass cards with Apple's value instead of your `backdrop_color`. | `true` |
| `liquidGlassMaskedBackdropEnabled` | ``Userpilot/Config/liquidGlassMaskedBackdrop(_:)`` | Cut the card's own shape out of the dimming backdrop, so the glass refracts your app rather than the scrim. | `true` |
| `liquidGlassTintAlphaLight` / `liquidGlassTintAlphaDark` | ``Userpilot/Config/liquidGlassTintAlpha(light:dark:)``, ``Userpilot/Config/liquidGlassTintAlpha(_:)`` | Strength of your `background_color` when it tints glass. Only consulted when `liquidGlassDefaultBackground(false)`. | `0.28` / `0.40` |
| `dialogAnimationType` | ``Userpilot/Config/dialogAnimation(_:)`` | How a centred dialog enters and leaves. | `.fade` |
| `liquidGlassAccessibilityAdaptationEnabled` | ``Userpilot/Config/liquidGlassAccessibilityAdaptation(_:)`` | Whether a presented experience honours Reduce Motion and re-resolves its appearance on live accessibility/appearance changes. | `true` |

### Sheets and dialogs

Renders the containers that float over a backdrop as glass rather than an opaque themed fill. Off unless you ask for it, because a card background is the largest and most legibility-sensitive element the SDK draws.

Leaving it uncalled defers to the theme's `general.material`, which itself defaults to solid — so "never set" and "explicitly set to `false`" are distinguishable, and only "never set" lets the backend decide.

The theme field is decoded on all three theme models: `general.material` for experiences and surveys, `main.material` for NPS (whose `main` block *is* its general block). Accepted values are `"solid"` and `"glass"`; anything missing or unrecognised resolves to solid, so a payload that predates the field behaves exactly as it does today.

This is the switch the two backdrop options hang off: with sheets and dialogs solid, neither has any effect.

### Full-screen experiences

Glass on the experiences that take the whole screen: carousel steps and the full-screen survey list. Separate from the sheet/dialog opt-in and off by default — these can hold dense, multi-section content and have no backdrop separating them from your app, which is where glass is most likely to hurt legibility. Check it against your own content before enabling. Unlike sheets and dialogs, this one is host-configuration only; the backend theme's material does not reach it.

Like sheets and dialogs, a full-screen surface falls back to solid while more than one Userpilot overlay window is visible — see [Multiple Userpilot instances](#Multiple-Userpilot-instances).

### Apple's material instead of your colour

Apple's sheet background is not a colour. Measured off a real presented sheet it is *translucent* — about 69% in light appearance and 77% in dark — which is a material, not a fill. So ``Userpilot/Config/liquidGlassDefaultBackground(_:)`` renders untinted glass, and the glass effect is actually visible: a brand tint at any real strength is what obscures it.

Your colour is still read for one thing: its luminance selects the light or the dark variant of the material, so a card you configured dark stays dark. Set `false` to tint the glass with your colour instead, at ``Userpilot/Config/liquidGlassTintAlpha(light:dark:)`` strength — `0` is untinted, higher values keep more of your brand colour and less of the content behind.

### Apple's dim instead of your colour

``Userpilot/Config/liquidGlassDefaultBackdrop(_:)`` dims behind glass cards with Apple's measured value: black at `0.20` in light appearance and `0.478` in dark. UIKit dims more than twice as hard in dark mode, which is why these are two different numbers.

A theme that switches the backdrop **off** still gets no backdrop. This replaces the colour; it never turns dimming on.

### Masking the backdrop

Glass refracts whatever is behind it. With a dimming scrim in the way it refracts the scrim, and the two effects cancel out — the card reads muddy grey. ``Userpilot/Config/liquidGlassMaskedBackdrop(_:)`` cuts the region the card already covers out of the scrim, so the glass reaches your app's pixels. It removes a *region*, never changes a value, so whichever backdrop colour is in effect stays exactly as configured everywhere the backdrop remains visible.

| Configuration | Appearance |
|---|---|
| `liquidGlassSheetsAndDialogs(false)` | Opaque card over the full themed backdrop. The pre-iOS 26 look. |
| `liquidGlassSheetsAndDialogs(true)` + `liquidGlassMaskedBackdrop(false)` | Glass card over the full themed backdrop. The glass refracts *the backdrop*, so it reads muddy grey. **Comparison only.** |
| `liquidGlassSheetsAndDialogs(true)` + `liquidGlassMaskedBackdrop(true)` — **default** | Glass card with its own shape cut out of the backdrop, so the glass refracts your app. |

Applies to sheets and dialogs only — full-screen experiences have no backdrop to cut.

### Dialog animation

``Userpilot/Config/dialogAnimation(_:)`` sets how a **centred dialog** enters and leaves. Bottom sheets always slide, because that is the gesture their shape implies, and full-screen experiences use the system's presentation.

| Value | Behaviour |
|---|---|
| `.fade` — **default** | Cross-fades in place. No movement at all. |
| `.slide` | Travels the full distance to the bottom of the screen, at full opacity throughout. |

Both work on a glass surface: fading the dialog's container takes the material with it.

---

## What Glass Replaces From Your Theme

Once a card renders as glass, some theme values are deliberately superseded by Apple's, because iOS 26's geometry and materials are not compatible with pre-26 values. Everything here reverts the moment `liquidGlass(false)` is set, or on any OS below 26.

| Theme value | While glass is on |
|---|---|
| `background_color` | Replaced by Apple's material, unless `liquidGlassDefaultBackground(false)`. Its **luminance is still read**, to choose the light or the dark material — and that appearance is pinned on the card, so the chrome inside it (the dismiss button especially) draws matching glass. Applies to every glass card: bottom sheets, centre dialogs, carousel steps and the survey list. |
| `backdrop_color` | Replaced by Apple's dim, unless `liquidGlassDefaultBackdrop(false)`. |
| `backdrop_enabled` | **Always honoured.** No option turns dimming on for a theme that asked for none. |
| `corner_radius` / `border_radius` | Replaced. Sheets get Apple's asymmetry — 36 pt on the top pair, the display-concentric radius on the bottom pair. Dialogs get Apple's alert radius (27 pt), uniform. |
| `button_border_radius` | Replaced by a capsule — UIKit's own default shape for a glass control. |
| `button_border_color` / `button_border_width` | Dropped on **filled** buttons — the material draws its own edge, and a solid stroke over it paints a second outline. Kept on **outline** buttons (transparent fill), where the border is the only thing drawing the control. |
| every other value — colours, fonts, text, spacing | Untouched. |

Disabled buttons never render as glass, whatever the configuration: the material signals interactivity, and it renders almost invisibly once UIKit applies its own disabled dimming on top of the theme's disabled fill.

---

## Layout Changes on iOS 26

These follow from the material and apply wherever glass is in use.

### Cards are rounder and inset

Cards are rounded more on iOS 26 — 32 pt by default, up from 12 — and a glass bottom sheet is inset 8 pt from the display's left, right and bottom edges, per Apple's half-sheet pattern. Your configured `border_radius` / `corner_radius` still wins when you set one.

A glass bottom sheet's corners are **asymmetric**, matching UIKit's own sheets: the bottom pair is concentric with your device's display — the display's curvature minus the 8 pt inset — and the top pair uses Apple's flat 36 pt, because there is no geometry up there to be concentric with. Elements *inside* the card, the action button in particular, then derive their corners concentrically from the card's radius, so everything stays visually nested.

### Content runs under the action button

Where the action button floats — full-screen carousels and the full-screen survey — the scrolling content extends to the display's bottom edge and passes *beneath* the button, with Apple's scroll edge effect fading it as it goes. This is what the effect requires: with content stopping above the button there is nothing passing underneath to fade.

The content is inset so it can still be scrolled clear of both the button and the home indicator, so nothing becomes unreachable. This is gated on chrome glass, which means it is **active by default on iOS 26** — set `liquidGlass(false)` for the previous layout, where content stops above the button.

---

## Things To Know

### Glass refracts your app's content

This is the point of the material — but it means Userpilot experiences show a distorted view of whatever is behind them.

**If your app displays sensitive content** — medical, financial, or camera views, or any screen you deliberately redact in screenshots — consider whether that content should be visible through a Userpilot experience. Use `liquidGlass(false)` to opt out entirely, or leave both `liquidGlassSheetsAndDialogs` and `liquidGlassFullScreen` off so only small chrome elements are affected.

### Multiple Userpilot instances

> Important: If your app runs more than one `Userpilot` instance — for example a host app plus an embedded vendor SDK — **glass on sheets and dialogs is automatically suppressed while more than one instance is showing an experience.**

Each instance owns its own overlay window. Two glass surfaces stacked one behind the other produce exactly the layered-glass appearance Apple warns against: *"Avoid crowding or layering Liquid Glass elements on top of each other."* Since neither instance can see the other's UI, neither could choose to avoid it, so the SDK falls back to opaque surfaces for the duration and keeps both experiences readable.

Chrome glass is unaffected — it is small enough not to stack into a full-surface problem. Full-screen experiences **are** covered by the same rule.

The suppression is live rather than decided once: a surface that was glass when it appeared turns solid when a second overlay joins it, and returns to its configured style when that one closes.

**What this means for you:** in a multi-instance app, a sheet or dialog that normally renders as glass may render solid when another instance's experience is on screen at the same time. This is intended behaviour, not a bug.

### Accessibility

Two different things happen here, and it is worth knowing which is which.

**UIKit handles the material.** A native `UIGlassEffect` adapts itself to Reduce Transparency and Increase Contrast. No SDK can switch that off, and this one does not try.

**The SDK handles what it draws itself**, controlled by ``Userpilot/Config/liquidGlassAccessibilityAdaptation(_:)`` (on by default):

| Setting | What the SDK does |
|---|---|
| Reduce Motion | Drops its own movement. A sliding dialog cross-fades in place, a sheet arrives without travelling, and the Likert selection stops pulsing — the fill still communicates the selection. Completion callbacks are unaffected. |
| Reduce Transparency, Increase Contrast | Re-resolves the tint, backdrop and colours the SDK chose, on an experience that is already on screen. |
| Light/dark switch while presented | Re-resolves the same values, so a card presented in light mode does not stay light behind a switch to dark. |

Turning the option off freezes a presented experience with the appearance it was built with. The Likert pulse is the one exception: it follows Reduce Motion regardless, because suppressing a scale animation cannot break anything and ignoring the setting outright is not defensible.

Not yet covered: large Dynamic Type sizes are laid out but not visually validated against glass surfaces.
