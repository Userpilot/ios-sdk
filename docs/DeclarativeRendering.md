# Declarative experience rendering

This is an **unreleased migration branch**, based on `refactor/core-classes-v2` at `e6b71e0` in the
`ios-sdk copy` checkout. The production publisher now selects SwiftUI content for every experience
family present at that base: carousel, slideout (dialog/bottom sheet), step/list surveys, thank-you and NPS.
The base contains no tooltip implementation; tooltip work from other branches was not imported.

## Architecture

Existing decoded content and theme → existing concrete ViewModel → `ExperienceRenderState` →
`UPExperienceRootView` → reusable SwiftUI components → contained `UIHostingController` → native
`UPExperienceHostingController` → existing SDK overlay window.

This uses a model/component/native-host separation without coupling to external payload schemas or
business engines. Fullscreen carousels use `UPExperienceCarouselController` (`UIPageViewController`)
to page complete SwiftUI screens, including their close control, action and dots. Each page has an
independent vertical body scroll. Other experiences keep header/action SwiftUI hosts around a native
body scroll area. The native host
owns safe-area sizing, keyboard avoidance, accessibility modal scope and completed dismissal.

Shared components render flow sections, text, images, buttons, close controls, progress, ratings,
choice groups, input fields and thank-you content. `SurveyAnswerState` retains answers independently
of SwiftUI body evaluation, size changes or question-view identity; each question observes only its
own `SurveyAnswerModel`, so typing redraws one question.

Each component has **one SwiftUI implementation on every iOS version** (a UIKit shell around SwiftUI
content). UIKit appears inside the content only as a plain Apple view, in exactly three places,
chosen by content and never by iOS version:

- a flow line that contains a link draws in a plain `UITextView` (`UPExperienceLinkText`), because iOS 13
  SwiftUI can't tap one word of a `Text`; touches away from link glyphs fall through to the carousel;
- multiline input is a plain `UITextView` (iOS 13 has no multiline SwiftUI input);
- an animated image plays in a plain `UIImageView` (SwiftUI can't animate an image on any version).

Plain flow text is SwiftUI `Text` built from the same `Line.textRuns(theme:)` as the link text view, and
static images are SwiftUI `Image`. The legacy UIKit widgets, containers and screens, their xibs and the
helpers only they used have been deleted; `Experiences/Content/` now holds only the three ViewModels.

Public customer initialization, content payloads, theme precedence and wrapper APIs are unchanged.
The engine still owns eligibility, once-per-screen NPS, preview suppression, stale renderer rejection,
survey branching, event sequencing and thank-you continuation. Redrawing never emits engagement.
A dismissal request completes only after UIKit removes the native renderer.

## Review entry points

| File or directory | Responsibility |
| --- | --- |
| `Sources/Userpilot/Experiences/ExperiencesPublisher.swift` | Routes every existing family and survey continuation to the new renderer |
| `Sources/Userpilot/Experiences/Views/State/ExperienceRenderState.swift` | Observes existing ViewModels, retains presentation state and preserves callback ordering |
| `Sources/Userpilot/Experiences/Views/State/ExperienceRenderState+NPS.swift` | NPS stage transitions, category mapping and submit/close behavior |
| `Sources/Userpilot/Experiences/Views/State/SurveyAnswerState.swift` | Answer retention, validation, branching values and submission payloads |
| `Sources/Userpilot/Experiences/Views/State/ExperienceRenderState+Appearance.swift`, `UPImageModel.swift` | Theme-derived colors, direction and progress; per-image pixels that survive redraws |
| `Sources/Userpilot/Experiences/Views/Containers/UPExperienceRootView.swift` | Selects SwiftUI family content and maps themes into header/content/footer regions |
| `Sources/Userpilot/Experiences/Views/Containers/UPExperienceCarouselController.swift` | Pages complete SwiftUI carousel screens with native horizontal gestures and a vertical scroll per page |
| `Sources/Userpilot/Experiences/Views/Containers/UPExperienceHostingController.swift` | Contains SwiftUI hosts and manages scrolling, sizing, keyboard, animation and actual dismissal |
| `Sources/Userpilot/Experiences/Views/Containers/ExperienceOverlayWindow.swift` | The scene-attached overlay window that holds the hosts above the app |
| `Sources/Userpilot/Experiences/Views/Widgets/` | SwiftUI components, one per file: `General/` (text, text area, image, button, dismiss, progress), `Flows/` (flow step, sections, rich text, link text), `Feedback/` (rating, question, survey, thank-you, NPS) |
| `Sources/Userpilot/Experiences/Views/Style/` | `UPExperienceStyle` (one font resolver for SwiftUI and the UIKit text views, the opt-in text-size rule and cap), `UPExperienceButtonStyle`, `UPExperienceLayout` || `Sources/Userpilot/Extensions/Line+Rendering.swift`, `SurveyStep+Rating.swift` | Pure receiver helpers: flow text runs, the shared image size rule, rating cells |
| `Sources/Userpilot/Extensions/UIImage+Extensions.swift` | Decoding that keeps each image's aspect ratio and downscales large images and GIF frames |
| `Tests/UserpilotTests/Experiences/` | Rendering, answer, text-run, image-size, rating, style, host, resize, accessibility and VoiceOver tests, a keystroke probe, plus a native animation recorder and two updated publisher test files |
| `scripts/test-declarative-rendering.sh`, `scripts/rendering-fixtures/` | Reproducible app-hosted screenshot, native lifecycle, gesture and VoiceOver harness |

The renderer is 27 source files under `Experiences/Views/`, one main type per file. Existing engine and model files remain the
source of eligibility, payload decoding and business behavior.

## Design corrections

- Carousel swipes use the whole screen, including the action/footer and blank areas. The page's
  theme and content travel together; button actions from an adjacent page cannot act on the current step.
- Flow sections/lines, survey elements and body-to-action spacing use one 16-point rhythm. Existing
  20-point content insets remain; bottom sheets additionally inset their card 16 points on each side.
- Dots restore the legacy iOS 6-point circles and 6-point gaps, cumulative active state and 20% inactive
  color. Survey/NPS bar progress is a continuous 5-point fill at the top edge, with its original theme
  colors and a clear track. Ball progress remains below the action.
- Images load/decode at the authored size independently of an initial narrow display proposal, so a
  temporary 1-point layout can't create a tiny image cached for that URL. The size rule is the one
  Android uses (both `auto` → natural size; both numeric → that size; wider than the space → the width
  at the natural aspect; anything else → 300 × 300), applied to the width the parent passes in rather
  than the screen. Decoding keeps the image's own aspect ratio (it covers the box, so `fit` letterboxes
  and nothing stretches unless authored as `fill`) and downscales large images and GIF frames with ImageIO.
  The render state owns one `UPImageModel` per image, so SwiftUI re-evaluation never restarts a download.
- Sheets start hidden until their final layout is measured, then animate upward from below the screen.
  Dialogs fade/scale in place. One property animator owns each transition; closing stops any entrance
  at its current position and freezes keyboard-driven card layout until native removal.
- Step surveys animate container height changes over 0.2 seconds with ease-in/ease-out, matching the
  legacy native transition. Sheets keep their bottom edge fixed; dialogs stay centered. The header
  and action keep their natural heights while the scroll viewport changes, so text is never scaled.
  Rapid changes retarget from the rendered frame, and dismissal freezes that frame before exit.
  Initial presentation, keyboard/width changes, fullscreen content and Reduce Motion do not start
  this survey resize animation. The host refreshes its root value only when the survey step changes
  and observes child preferred-size changes, ensuring measurement uses the new SwiftUI content
  without rebuilding the renderer or resetting answer state on each keystroke.

## Text scaling and accessibility

- **Text scaling is opt-in**: `Config.enableTextScaling(true)`. Off (the default), both
  SwiftUI roots pin `\.sizeCategory` to `.large`, so every surface keeps its authored size. On, they cap it
  at `.accessibilityLarge` (about 2×). Every size scales by the body text style, so headings stay larger
  than body text at every setting. `UPExperienceStyle.font` resolves one `UIFont` that SwiftUI wraps in
  `Font(_:)` and the UIKit text views use as-is, so nothing scales twice; the host re-measures on
  `UIContentSizeCategory.didChangeNotification`.
- **VoiceOver**: h1–h3 lines carry the header trait (including a heading drawn by the link text view);
  links are reachable in the link text view; the chosen survey option and the chosen rating carry the
  selected trait (a filled star is not selected); images with alt text are images, without it they are
  hidden; the multiline placeholder and the checkbox symbols are hidden; the Close control is a
  44-point target. A page, survey step or NPS stage change moves focus to the new content.
- **Escape**: VoiceOver's two-finger Z calls `state.userClose()`, the same path as the visible close
  control, so the same dismissal events are reported. It does nothing when the experience shows no
  close control (a flow with its dismiss button disabled).
- **Reduce Motion** also shows a GIF's first frame; animated images ignore Smart Invert.
- **Pickers open inline**, so they keep the experience's text size and style: the date field opens
  Apple's inline calendar (graphical style) below it and picking a day fills it; the phone country code
  is a SwiftUI `Menu` with a checkmarked `Picker`. iOS 13 has neither, so both fall back to Apple's
  wheel below the field. These two picker styles are the only `#available` swaps in the renderer, and
  they are cosmetic; there are no sheets.
- **Light or dark follows the experience**, not the device: the host sets `overrideUserInterfaceStyle`
  from the experience background, so the calendar, the menu, the keyboard and system text-field
  backgrounds match the card.
- **Link lines** can't be selected (no first responder) or dragged, so a double-tap or long press on
  a link shows no edit menu, like the label they replace.
- **Rating cells** shrink slightly while pressed, and the chosen cell pulses once with a spring;
  Reduce Motion turns both off.
- Accessibility labels such as "Close" and "Step x of y" stay English literals.

## Official Apple API review

Checked against current Apple documentation on 2026-10-09:

- [Interfacing with UIKit](https://developer.apple.com/tutorials/swiftui/interfacing-with-uikit): Apple
  demonstrates a `UIPageViewController` carousel hosting SwiftUI pages and coordinating selection state;
  the same supported bridge preserves iOS 13 paging without raising the minimum to use newer APIs.
- [UIHostingController](https://developer.apple.com/documentation/swiftui/uihostingcontroller): supported
  UIKit integration from iOS 13. Child controllers use `addChild`, view constraints and `didMove`.
- [sizingOptions](https://developer.apple.com/documentation/swiftui/uihostingcontroller/sizingoptions):
  enabled only on iOS 16+. Explicit `sizeThatFits(in:)` measurement preserves iOS 13 support.
- [Preferred content size](https://developer.apple.com/documentation/swiftui/uihostingcontrollersizingoptions/preferredcontentsize):
  on iOS 16+, child size changes notify the native container to remeasure. The host still uses its
  own width-aware `sizeThatFits(in:)` proposal. Refreshing the same `rootView` value on a step change
  also makes measurement reliable on the supported iOS 13 path without changing the hosting identity.
- [UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable): bridges
  own create/update/teardown without replacing the complete legacy experience screen.
- [Monitoring model data](https://developer.apple.com/documentation/swiftui/monitoring-model-data-changes-in-your-app):
  Apple documents `ObservableObject` for deployments before iOS 17. It is confined to presentation state.
- [Observation migration](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro):
  `@Observable` requires iOS 17; adopting it unconditionally would break the current iOS 13 contract.

The migration avoids historical iOS 15 sizing workarounds and does not raise the OS minimum,
replace the GCD engine with Swift concurrency, or modify global `UIView.appearance` for RTL.

## Related behavior correction

The previous iOS NPS container compared its 1-based selection with 0-based category boundaries.
The new renderer keeps the existing submitted score conversion but selects detractor/passive/promoter
follow-up and completion content using the displayed score: 0–6, 7–8, 9–10. Boundary tests cover
0, 6, 7, 8, 9 and 10, including exact published score and follow-up key.

## Validation

Final validation on 2026-10-09 used Xcode 26.6:

| Check | Result |
| --- | --- |
| Full release preflight | Passed environment checks, compile/tests, strict SwiftLint and XCFramework generation |
| Package XCTest, iPhone 17 Pro Max / iOS 26.5 | 735 passed, 0 failed, 7 skipped |
| App-hosted rendering tests, iPhone 16 Pro Max / iOS 18.3 | 10 passed, 0 failed; 13 rendered fixture states captured plus ten native animation traces |
| Actual carousel gesture UI tests, iPhone 16 Pro Max / iOS 18.3 | 2 passed, 0 failed; horizontal drags from header/footer/empty space, long vertical scroll and button tap |
| Release XCFramework | Device arm64 and simulator arm64/x86_64 slices; module interfaces verified; 8.4 MB |
| Source diff whitespace | `git diff --check` passed |

The package runner has no application window scene, so native presentation and animation tests explicitly
skip there. The separate app-hosted harness runs them, including repeated dismissal requests,
completion after native removal, strictly upward/downward sheet movement, and a dialog interrupted
after three entrance frames with no center displacement. Fixture coverage includes carousel, slideout, dialog, step/list survey,
survey thank-you and the NPS score/follow-up/completion states. Layout assertions also verify all three
hosted regions, full-page carousel containment, long-page vertical extent and the full-screen background.
The real ImageLoader fixture uses a URLProtocol PNG response and verifies a temporary 1-point display
proposal does not reduce decoded pixels or change the authored 2:1 aspect ratio. These checks do not
establish pixel parity with every
dashboard configuration or live backend delivery.

Local evidence: `/tmp/ios-survey-resize-verified.xcresult`, `/tmp/ios-survey-resize-verified.log`,
`/tmp/ios-survey-resize-measurement.xcresult` and `/tmp/ios-survey-resize-measurement.log`.
The final combined harness passed all twelve tests and exported attachments in
`/tmp/ios-survey-resize-combined-final.log`. Its complete result bundle and attachments are under
`/var/folders/g3/5fd7nwfj189frfq23qdxbb4h0000gn/T/userpilot-rendering.GP5qaz/`.
The eight focused survey resize frame traces are also exported to `/tmp/ios-survey-resize-frames/`.
Both styles grow from 280 to 662 points and shrink back with 14 distinct intermediate heights and
fixed native anchors. Rapid step changes and dismissal interrupt the current resize without snapping
through its abandoned destination; header/footer heights remain constant throughout resizing.
The SDK version remains 1.4.1; this migration has not been committed, published or released.

Validation on 2026-10-26 (native components, text scaling and accessibility), Xcode 26.6:

| Check | Result |
| --- | --- |
| Package XCTest, iPhone 16 Pro Max / iOS 18.3 and iPhone 17 Pro Max / iOS 26.5 | 797 run, 12 skipped; the only failures are 22 `SocketManagerTests`/`SocketManagerStressTests` from an uncommitted development token in `SocketManager.swift`, unrelated to rendering |
| App-hosted harness, iOS 18.3 + iPad Pro 13 / iOS 26.5 | All suites passed: hosting, accessibility, VoiceOver, survey resize, gestures (including link taps, a long press with no menu and swipes that start on a link), direction, the VoiceOver fixture with an accessibility audit at the largest text size, and the multi-scene overlay |
| App-hosted harness, iPhone 17 Pro Max / iOS 26.5 | All suites passed except `testSheetEntranceMovesUpAndExitMovesDownWithoutLayoutJump`, which fails identically on the code before this change (an existing iOS 26 animation-timing issue) |
| Live Text Size change | `simctl ui content_size` on a running survey: text, rating wrap and footer resized in place |
| Keystroke probe (`SurveyTypingPerformanceTests`, run on demand) | 24 vs 4 questions: 1.61 vs 1.17 ms per key (1.38×); before: 4.12 vs 2.16 ms (1.9×) |

```bash
bash scripts/release-preflight.sh
bash scripts/test-declarative-rendering.sh
# Optionally select installed iPhone and iPad simulators by UDID:
bash scripts/test-declarative-rendering.sh 01571169-CEA4-456F-944D-E4073E19EAE5 539C1236-8075-42BB-98B7-2855FFD31C74
```

The fixture script generates a temporary UIKit host app, consumes this local SDK package, runs
`ExperienceHostingTests`, `ExperienceAccessibilityHostingTests`, `ExperienceVoiceOverHostingTests`,
`SurveyResizeHostingTests`, `CarouselGestureTests`, `CarouselDirectionTests` and `VoiceOverFixtureTests` and exports
screenshot attachments. SwiftUI builds its accessibility tree only for an assistive client, so traits are
checked through XCUITest (`VoiceOverFixtureTests`, including an accessibility audit at the largest text
size); XCUITest also lists SwiftUI elements hidden from VoiceOver, so hidden elements and the header trait
of SwiftUI headings remain part of the manual VoiceOver review. The gesture fixture uses three local pages; hosted image tests use deterministic image data. UI tests
perform actual horizontal drags from the header, action/footer and empty page area, scroll long content vertically, and tap
the action. `CarouselDirectionTests` swipes LTR and RTL content inside LTR and RTL host apps; content direction alone decides
the forward swipe. On an iPad simulator the script also runs `ExperienceOverlaySceneTests`, which opens a second scene and
checks the idle overlay follows the user to the foreground scene. It requires an installed iOS simulator
and the `xcodeproj` Ruby gem, also installed with CocoaPods. It prints the artifact directory on exit.

Required device review includes a VoiceOver pass (Headings and Links rotors, Z-gesture dismissal, focus
after a page and a step change, no escape into the host app behind the overlay window), a live Text Size
change with an experience on screen, RTL layouts beyond carousel swipe direction,
physical keyboard/date/country selection, side-by-side iPad scenes (both foreground-active), rotation while typing, long content with sticky controls, theme/fonts,
GIFs, image cache behavior, actual preview replacement and wrapper host applications. No live backend
or customer app visual parity is claimed by unit tests.
