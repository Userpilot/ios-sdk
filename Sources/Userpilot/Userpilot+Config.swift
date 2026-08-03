//
//  Config.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
// [Brief Description]
// Config A configuration object that defines behavior and policies for Userpilot.
//

import Foundation
import UIKit
import os.log

// swiftlint:disable file_length

/// Default values for tunable Liquid Glass configuration, kept together so they are
/// documented in one place rather than scattered as literals.
///
/// Declared at file scope rather than nested inside `Config`, which is itself nested in
/// `Userpilot` — a third level would breach the `nesting` lint rule.
private enum UPLiquidGlassConfigDefaults {

    /// Tint alpha in light mode. Provisional; validated against real customer themes.
    static let tintAlphaLight: CGFloat = 0.28

    /// Tint alpha in dark mode. Higher than light: dark surfaces need more tint to hold
    /// contrast against the content behind them.
    static let tintAlphaDark: CGFloat = 0.40
}

extension Userpilot {

    /// How a **centre dialog** enters and leaves the screen.
    ///
    /// Applies to centred dialogs only. Bottom sheets always slide, and full-screen experiences
    /// use the system's own presentation.
    @objc(UserpilotDialogAnimation)
    public enum DialogAnimation: Int {

        /// Cross-fade in place, with no movement at all. **The default.**
        ///
        /// Works on a Liquid Glass surface as well as a solid one — fading the dialog's container
        /// takes the material with it.
        case fade = 0

        /// Slide in from the bottom edge and back out again, at full opacity throughout.
        case slide = 1
    }

    // The app framework used by the client application.
    // Used by the SDK for autocapture and lifecycle behavior.
    public enum AppFramework: String {
        case UIKit
        // swiftlint:disable:next identifier_name
        case SwiftUI
    }

    // Note: `Config` is a class so that it can be initialized inline with the chained setters. E.g:
    // `Config(token: "TOKEN").logging(true)`. A struct would require initializing as a var first.
    @objc
    public class Config: NSObject {

        /// Customer token
        let token: String

        /// Userpilot SDK logger
        var logger: Logging = OSLog.disabled

        /// Additional SDK configuration properties used by wrapper/plugin integrations.
        ///
        /// Wrappers can pass integration-specific flags here without expanding the
        /// public config surface for every platform bridge. The core SDK reads these
        /// values to identify supported wrapper SDKs and determine whether screen or
        /// interaction autocapture is handled by the wrapper layer.
        var additionalProperties: [String: Any] = [:]

        /// The app framework (UIKit or SwiftUI).
        ///
        /// `nil` means the SDK will auto-detect the framework once the key window
        /// is attached. Set explicitly via `appFramework(_:)` to override
        /// auto-detection (recommended when you want deterministic tagging
        /// from the very first event).
        var appFramework: AppFramework?

        /// Disable request push notifications permission by SDK.
        var disableRequestPushPermission: Bool = false

        /// Open external link In-app browser using SFSafariViewController
        var useInAppBrowser: Bool = false

        // MARK: - Autocapture Configuration Options

        /// Whether or not to enable screen autocapture. Defaults to false.
        /// If set to true, the SDK will automatically capture screen events.
        var enableScreenAutoCapture: Bool = false

        /// Whether or not to enable screen title capture. Defaults to true.
        /// If false, the core SDK will prevent screen titles from being stored or uploaded
        /// and autocapture libraries will be instructed not to capture them.
        var enableScreenTitleCapture: Bool = true

        /// Whether or not to enable interaction autocapture. Defaults to false.
        /// If set to true, the SDK will automatically capture user interactions.
        var enableInteractionAutoCapture: Bool = false

        /// Whether or not to enable user interface text capture. Defaults to true.
        /// If false, the core SDK will prevent user interface text from being stored or uploaded
        /// and autocapture libraries will be instructed not to capture them.
        var enableInteractionTextCapture: Bool = true

        // Whether or not to enable user interface accessibility label capture. Defaults to true.
        // If false, the core SDK will prevent user interface accessibility labels from being
        // stored or uploaded and autocapture libraries will be instructed not to capture them.
        // swiftlint:disable:next identifier_name
        var enableInteractionAccessibilityLabelCapture: Bool = true

        /// Whether or not to enable capturing control values. Defaults to true.
        /// If set to true, the SDK will capture values from controls such as:
        /// - UISwitch: captures the on/off state
        /// - UISegmentedControl: captures the selected segment value
        /// - UISlider: captures the selected value
        /// - UIStepper: captures the selected step value
        /// - UIPickerView: captures the selected value
        /// - UIDatePicker: captures the selected date/time value
        var enableInteractionValueCapture: Bool = false

        /// When true (default), a tap event is not sent for UITextField/UITextView when the action is
        /// a text-editing action (e.g. textChanged:, editingChanged:). Only the text_field_changed /
        /// text_view_changed event is sent. Use this to avoid duplicate events when
        /// typing in SwiftUI or UIKit text fields.
        var ignoreTapForTextInputEditingActions: Bool = true

        /// When true (default), SwiftUI tap events are not sent for views inside a UINavigationBar
        /// (e.g. back button), so only the UIKit sendAction event is recorded. Use this to avoid
        /// duplicate events when tapping navigation bar buttons in SwiftUI.
        var preferUIKitOverSwiftUIForNavigationBar: Bool = true

        // MARK: - Multi-instance scope (autocapture ownership)

        /// Bundle identifiers this instance has explicitly claimed as its own. The
        /// autocapture resolution uses these to attribute UI events to the owning Userpilot
        /// instance when multiple instances coexist in the same process.
        ///
        /// In single-instance integrations this stays empty and the (only) instance
        /// implicitly owns every event via the SDK default fallback.
        internal var attachedBundleIdentifiers: Set<String> = []

        /// Windows this instance has explicitly claimed. Held weakly so a window dismissal
        /// does not retain it past its natural lifetime.
        internal let attachedWindows = NSHashTable<UIWindow>.weakObjects()

        /// View-controller classes this instance has explicitly claimed. Subclasses are
        /// considered owned too.
        internal var attachedViewControllerClasses: [AnyClass] = []

        /// Marks this Userpilot instance as the global fallback for autocapture events
        /// that aren't explicitly attributed (no `userpilot:` arg) and aren't anchored to
        /// a particular UI subtree (no `attach(bundles:)` / `attach(windows:)` /
        /// `attach(viewControllerClasses:)`, no SwiftUI `userpilotOwner`).
        ///
        /// Defaults to `true` so the host application is the default instance without
        /// extra configuration. Embedded third-party / vendor SDKs that coexist in the
        /// same process MUST opt out via `defaultInstance(false)` and anchor their own
        /// UI explicitly. Any unattributed UI event then routes to the host instead of
        /// fanning out to every tenant.
        ///
        /// Conflict policy:
        /// - Only one instance can hold the default role. An instance with
        ///   `isDefault = true` claims it when the role is unclaimed. If the role is
        ///   already held, the new claim is rejected and a warning is logged; the
        ///   existing claimant keeps the role. Embedded vendors MUST call
        ///   `defaultInstance(false)` so they do not compete for the slot.
        /// - If no instance claims it, there is no default at all and un-anchored
        ///   events are dropped rather than attributed to an arbitrary tenant. Keep
        ///   the default of `true` on the host app so it owns un-anchored events.
        var isDefault: Bool = true

        /// When `true` on the **default** (client app) instance, autocapture events
        /// (screen + interaction) that originate on a non-default instance — i.e. an
        /// embedded third-party / vendor SDK — are also forwarded to this default
        /// instance, so the host app's analytics and backend become aware of them.
        ///
        /// Read only on the resolved default instance. Has no effect on non-default
        /// instances. Defaults to `false`, so existing integrations are unchanged
        /// unless the host opts in via `allowReceiveEventsFromExternalSource()`. The
        /// forwarded event is delivered unchanged through this instance's publisher
        /// (associated with the host's user/session).
        var allowReceiveEventsFromExternalSource: Bool = false

        // MARK: - Liquid Glass (iOS 26+)

        /// Global switch for Liquid Glass. Defaults to `true`.
        ///
        /// When `false`, the SDK renders its pre-iOS 26 appearance everywhere — including
        /// chrome — regardless of every other Liquid Glass option. Provided as an escape
        /// hatch for hosts with a strict design system, and as a kill switch for us.
        ///
        /// Has no effect below iOS 26, or when the SDK was built with an Xcode that
        /// predates the iOS 26 SDK, or when the host app sets
        /// `UIDesignRequiresCompatibility`.
        var liquidGlassEnabled: Bool = true

        /// Whether **bottom sheet and centre dialog** backgrounds render as Liquid Glass
        /// instead of an opaque themed fill.
        ///
        /// Covers the containers that float over a backdrop: surveys, NPS, thank-you and
        /// slide-outs, in either presentation. Full-screen experiences are governed by
        /// ``liquidGlassFullScreenEnabled`` instead.
        ///
        /// `nil` (never set) means "defer to the theme's `general.material`", which itself
        /// defaults to solid. A non-`nil` value is an explicit host decision and takes
        /// precedence over the theme. Stored as an optional precisely so that "not set" is
        /// distinguishable from "explicitly set to `false`".
        ///
        /// When a surface does render as glass, the theme's `background_color` is applied
        /// as the glass tint rather than being discarded — see
        /// ``liquidGlassTintAlpha(light:dark:)``.
        var liquidGlassSheetsAndDialogsEnabled: Bool?

        /// Whether **full-screen** experience backgrounds render as Liquid Glass. Defaults to off.
        ///
        /// Covers carousel step cards and the full-screen survey list. Separate from
        /// ``liquidGlassSheetsAndDialogsEnabled`` on purpose: a full-screen experience can hold
        /// dense, multi-section content and has no backdrop separating it from the host app,
        /// which is the most likely place for glass to hurt legibility. Enabling glass for
        /// sheets and dialogs does **not** enable it here — this has to be asked for by name.
        ///
        /// Non-optional, unlike ``liquidGlassSheetsAndDialogsEnabled``: there is no third state to
        /// represent. The theme cannot enable full-screen glass, so "not set" and "set to `false`"
        /// mean exactly the same thing and the type should say so.
        var liquidGlassFullScreenEnabled: Bool = false

        // Whether the SDK adapts an already-presented experience to live accessibility and trait
        // changes. Defaults to true.
        //
        // Governs only what the SDK draws itself: its own animations (dialog transitions, the
        // Likert pulse), its tint, its backdrop, and re-resolving colors when the interface style
        // changes. UIKit's own accessibility handling of a native `UIGlassEffect` is not affected
        // by this and cannot be switched off by the SDK.
        // swiftlint:disable:next identifier_name
        var liquidGlassAccessibilityAdaptationEnabled: Bool = true

        /// How centre dialogs enter and leave. Defaults to ``Userpilot/DialogAnimation/fade``.
        ///
        /// Centre dialogs only — bottom sheets always slide.
        var dialogAnimationType: DialogAnimation = .fade

        /// Whether the dimming backdrop has the card's shape cut out of it when the card
        /// renders as Liquid Glass. Defaults to `true`.
        ///
        /// Without this, glass refracts the dimming scrim rather than the host app, so the
        /// card renders muddy grey instead of glass — the two effects cancel out. Masking the
        /// card's own rect out of the backdrop resolves it by removing a *region* rather than
        /// changing a value, so whichever backdrop colour is in effect stays exactly as it is
        /// everywhere the backdrop is still visible.
        ///
        /// Set to `false` only to compare against the unmasked appearance; there is no
        /// production reason to prefer it.
        var liquidGlassMaskedBackdropEnabled: Bool = true

        /// Whether a glass card dims its background with **Apple's** value instead of the theme's
        /// backdrop colour. Defaults to `true`, and only consulted while glass is actually in use.
        ///
        /// Measured from a real presented sheet and alert: black at `0.20` in light appearance and
        /// `0.478` in dark. A theme that switches the backdrop *off* still gets no backdrop — this
        /// replaces the colour, it never forces dimming on.
        var liquidGlassDefaultBackdropEnabled: Bool = true

        /// Whether a glass card uses **Apple's** sheet material instead of tinting itself with the
        /// theme's `background_color`. Defaults to `true`, and only consulted while glass is in use.
        ///
        /// Apple's sheet background is not a colour — measured, it is translucent (~69% in light,
        /// ~77% in dark), which is the signature of a material. So this renders untinted
        /// `UIGlassEffect`, and the glass effect is actually visible; a tint at any real strength
        /// is what was hiding it.
        ///
        /// The theme colour is not ignored entirely: its *luminance* still selects the light or the
        /// dark variant of the material, so a customer who configured a dark card still gets one.
        var liquidGlassDefaultBackgroundEnabled: Bool = true

        /// Alpha applied to a theme's `background_color` when it tints a glass surface in
        /// light mode. Defaults to `0.28`.
        var liquidGlassTintAlphaLight: CGFloat = UPLiquidGlassConfigDefaults.tintAlphaLight

        /// Alpha applied to a theme's `background_color` when it tints a glass surface in
        /// dark mode. Defaults to `0.40` — dark surfaces need more tint to hold contrast.
        var liquidGlassTintAlphaDark: CGFloat = UPLiquidGlassConfigDefaults.tintAlphaDark

        /// Create an Userpilot SDK configuration
        /// - Parameter token: Userpilot Account Token, copied from the Environments settings page.
        @objc
        public init(token: String) {
            self.token = token
        }

        /// Sets the logging status for the configuration.
        ///
        /// - Parameter enabled: A boolean indicating whether logging is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func logging(enabled isEnabled: Bool) -> Self {
            logger = isEnabled
                ? UPLogger(
                    category: UserpilotLogging.general,
                    token: token
                )
                : OSLog.disabled
            return self
        }

        /// Applies additional SDK configuration properties.
        ///
        /// Wrapper/plugin SDKs use this as an escape hatch for bridge-specific setup,
        /// such as `PluginType`, `WrapperEnableScreenAutoCapture`, and
        /// `WrapperEnableInteractionAutoCapture`. This function can be called
        /// multiple times; each call merges into the existing dictionary, and later
        /// values overwrite earlier values for the same key.
        ///
        /// - Parameter additionalProperties: Additional SDK configuration values.
        /// - Returns: The config object, allowing for method chaining.
        @discardableResult
        @objc
        public func additionalProperties(_ additionalProperties: [String: Any]) -> Self {
            self.additionalProperties = self.additionalProperties.merging(additionalProperties)
            return self
        }

        /// Sets the app framework (UIKit or SwiftUI).
        ///
        /// When set explicitly, this disables runtime auto-detection.
        /// Use this to guarantee correct framework tagging from the first
        /// event, especially in apps that send events before the key window
        /// is attached (e.g. from `application:didFinishLaunchingWithOptions:`).
        ///
        /// - Parameter framework: The framework used by the client app.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        public func appFramework(_ framework: AppFramework) -> Self {
            appFramework = framework
            return self
        }

        /// Disables or enables the automatic request for push notifications permission.
        ///
        /// By default, the SDK may prompt the user to grant push notifications permission.
        /// Set to true to prevent the SDK from showing that prompt automatically.
        /// - Parameter disabled: A boolean indicating whether request permission is disabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func disableRequestPushNotificationsPermission(_ disabled: Bool = true) -> Self {
            self.disableRequestPushPermission = disabled
            return self
        }

        /// Sets the In-App browser status for the configuration.
        ///
        /// - Parameter enabled: A boolean to Open external link In-app browser using SFSafariViewController.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableUseInAppBrowser(_ enabled: Bool = true) -> Self {
            useInAppBrowser = enabled
            return self
        }

        // MARK: - Autocapture Configuration Options

        /// Enables or disables automatic screen capture.
        /// If enabled, the SDK will automatically capture screen view events.
        /// - Parameter enabled: A boolean indicating whether screen autocapture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableScreenAutoCapture(_ enabled: Bool = true) -> Self {
            enableScreenAutoCapture = enabled
            return self
        }

        /// Enables or disables screen title capture.
        /// Set to false to prevent screen titles from being stored or uploaded.
        /// - Parameter enabled: A boolean indicating whether screen title capture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableScreenTitleCapture(_ enabled: Bool = true) -> Self {
            enableScreenTitleCapture = enabled
            return self
        }

        /// Deprecated alias for `enableScreenTitleCapture(_:)`.
        @available(*, deprecated, renamed: "enableScreenTitleCapture(_:)")
        @discardableResult
        @objc(disableScreenTitleCapture:)
        public func disableScreenTitleCapture(_ disabled: Bool = true) -> Self {
            enableScreenTitleCapture(!disabled)
        }

        /// Enables or disables automatic interaction (click) capture.
        /// If enabled, the SDK will automatically capture user interaction events.
        /// - Parameter enabled: A boolean indicating whether interaction autocapture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableInteractionAutoCapture(_ enabled: Bool = true) -> Self {
            enableInteractionAutoCapture = enabled
            return self
        }

        /// Enables or disables user interface text capture.
        /// Set to false to prevent user interface text from being stored or uploaded.
        /// - Parameter enabled: A boolean indicating whether text capture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableInteractionTextCapture(_ enabled: Bool = true) -> Self {
            enableInteractionTextCapture = enabled
            return self
        }

        /// Deprecated alias for `enableInteractionTextCapture(_:)`.
        @available(*, deprecated, renamed: "enableInteractionTextCapture(_:)")
        @discardableResult
        @objc(disableInteractionTextCapture:)
        public func disableInteractionTextCapture(_ disabled: Bool = true) -> Self {
            enableInteractionTextCapture(!disabled)
        }

        /// Enables or disables user interface accessibility label capture.
        /// Set to false to prevent accessibility labels from being stored or uploaded.
        /// - Parameter enabled: A boolean indicating whether accessibility label capture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableInteractionAccessibilityLabelCapture(_ enabled: Bool = true) -> Self {
            enableInteractionAccessibilityLabelCapture = enabled
            return self
        }

        /// Deprecated alias for `enableInteractionAccessibilityLabelCapture(_:)`.
        @available(*, deprecated, renamed: "enableInteractionAccessibilityLabelCapture(_:)")
        @discardableResult
        @objc(disableInteractionAccessibilityLabelCapture:)
        public func disableInteractionAccessibilityLabelCapture(_ disabled: Bool = true) -> Self {
            enableInteractionAccessibilityLabelCapture(!disabled)
        }

        /// Enables or disables capturing control values during interaction tracking.
        /// When enabled (default), the SDK will capture values from controls such as:
        /// - UISwitch: on/off state
        /// - UISegmentedControl: selected segment value
        /// - UISlider: selected value
        /// - UIStepper: selected step value
        /// - UIPickerView: selected value
        /// - UIDatePicker: selected date/time value
        /// - Parameter enabled: A boolean indicating whether control value capture is enabled.
        /// - Returns: The `Configuration` object, allowing for method chaining.
        @discardableResult
        @objc
        public func enableInteractionValueCapture(_ enabled: Bool = true) -> Self {
            enableInteractionValueCapture = enabled
            return self
        }

        /// When true (default), tap is not sent for text field/text view editing actions;
        /// only text_field_changed / text_view_changed is sent.
        @discardableResult
        @objc
        public func ignoreTapForTextInputEditingActions(_ ignore: Bool = true) -> Self {
            ignoreTapForTextInputEditingActions = ignore
            return self
        }

        /// When true (default), SwiftUI tap is not sent for navigation bar (e.g. back button);
        /// only the UIKit event is sent.
        @discardableResult
        @objc
        public func preferUIKitOverSwiftUIForNavigationBar(_ prefer: Bool = true) -> Self {
            preferUIKitOverSwiftUIForNavigationBar = prefer
            return self
        }

        // MARK: - Liquid Glass setters

        /// Enables or disables Liquid Glass for this instance. Enabled by default.
        ///
        /// Disabling is absolute: the SDK renders its pre-iOS 26 appearance everywhere,
        /// and every other Liquid Glass option is ignored.
        ///
        /// - Parameter enabled: `false` to opt out of Liquid Glass entirely.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func liquidGlass(_ enabled: Bool = true) -> Self {
            liquidGlassEnabled = enabled
            return self
        }

        /// Renders **bottom sheets and centre dialogs** as Liquid Glass instead of an opaque
        /// themed fill, on iOS 26 and later.
        ///
        /// These are the containers that float over a backdrop: surveys, NPS, thank-you and
        /// slide-outs. Full-screen experiences are not affected — see
        /// ``liquidGlassFullScreen(_:)``.
        ///
        /// Calling this is an explicit host decision and overrides the theme's
        /// `general.material`. Leave it uncalled to let the theme decide (which defaults to
        /// the current opaque appearance).
        ///
        /// The theme's `background_color` is not discarded when glass is used — it becomes
        /// the glass tint. Adjust its strength with ``liquidGlassTintAlpha(light:dark:)``.
        ///
        /// - Parameter enabled: `true` to render sheets and dialogs as glass.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func liquidGlassSheetsAndDialogs(_ enabled: Bool = true) -> Self {
            liquidGlassSheetsAndDialogsEnabled = enabled
            return self
        }

        /// Renders **full-screen experiences** as Liquid Glass, on iOS 26 and later. Off by
        /// default.
        ///
        /// Covers carousel step cards and the full-screen survey list. Kept separate from
        /// ``liquidGlassSheetsAndDialogs(_:)`` because a full-screen experience can hold dense,
        /// multi-section content and has no backdrop separating it from the host app, which is
        /// where glass is most likely to hurt legibility. Enabling glass for sheets and dialogs
        /// does not enable it here. Check it against your own content before shipping.
        ///
        /// - Parameter enabled: `true` to render full-screen experiences as glass.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func liquidGlassFullScreen(_ enabled: Bool = true) -> Self {
            liquidGlassFullScreenEnabled = enabled
            return self
        }

        /// Adapts an already-presented experience to live accessibility and trait changes, on iOS 26
        /// and later. On by default.
        ///
        /// With this on, the SDK honours Reduce Motion for its own animations, and re-resolves its
        /// own tint, backdrop and colours when the interface style, Reduce Transparency or Increase
        /// Contrast changes while an experience is on screen.
        ///
        /// Turning it off freezes a presented experience with the appearance it was built with. It
        /// does **not** disable UIKit's own accessibility handling of the native glass material —
        /// no SDK can switch that off, and this API does not claim to.
        ///
        /// - Parameter enabled: `false` to stop the SDK adapting a presented experience.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func liquidGlassAccessibilityAdaptation(_ enabled: Bool = true) -> Self {
            liquidGlassAccessibilityAdaptationEnabled = enabled
            return self
        }

        /// Sets how centre dialogs enter and leave the screen.
        ///
        /// Affects **centred dialogs only**. Bottom sheets always slide, and full-screen
        /// experiences use the system's presentation.
        ///
        /// Both transitions are safe on a Liquid Glass surface: fading the dialog's container
        /// removes the material with it.
        ///
        /// - Parameter animation: The transition to use.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func dialogAnimation(_ animation: DialogAnimation) -> Self {
            dialogAnimationType = animation
            return self
        }

        /// Controls whether the dimming backdrop is cut away behind a glass card.
        ///
        /// With glass surfaces enabled there are three resulting appearances:
        /// - `liquidGlassSheetsAndDialogs(false)` — opaque card over the full themed backdrop
        ///   (the pre-iOS 26 appearance).
        /// - `liquidGlassSheetsAndDialogs(true)` + `liquidGlassMaskedBackdrop(false)` — glass card
        ///   over the full themed backdrop. The glass refracts the backdrop, so it reads as
        ///   muddy grey. Provided for comparison only.
        /// - `liquidGlassSheetsAndDialogs(true)` + `liquidGlassMaskedBackdrop(true)` — **default** —
        ///   glass card with its own shape cut out of the backdrop, so the glass refracts the
        ///   host app. The backdrop keeps the customer's exact colour and opacity everywhere
        ///   it remains visible.
        ///
        /// - Parameter enabled: `false` to leave the backdrop uncut behind glass cards.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func liquidGlassMaskedBackdrop(_ enabled: Bool = true) -> Self {
            liquidGlassMaskedBackdropEnabled = enabled
            return self
        }

        /// Dims behind bottom sheets and centre dialogs with **Apple's** value rather than the
        /// theme's `backdrop_color`. On by default; ignored unless the card renders as glass.
        ///
        /// Apple's dim was measured from a real presented sheet and alert — black at `0.20` in
        /// light appearance, `0.478` in dark. UIKit dims noticeably harder in dark mode, which is
        /// why the two are not the same number.
        ///
        /// A theme that turns the backdrop off still gets no backdrop: this replaces the colour,
        /// it does not force dimming on. Pass `false` to keep the theme's colour instead.
        ///
        /// - Parameter enabled: `false` to keep the theme's configured backdrop colour.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func liquidGlassDefaultBackdrop(_ enabled: Bool = true) -> Self {
            liquidGlassDefaultBackdropEnabled = enabled
            return self
        }

        /// Fills bottom sheets and centre dialogs with **Apple's** sheet material rather than
        /// tinting them with the theme's `background_color`. On by default; ignored unless the card
        /// renders as glass.
        ///
        /// Apple's sheet background is not a colour. Measured over a known backdrop it is
        /// translucent — roughly 69% in light appearance and 77% in dark — which is a material, not
        /// a fill. So this renders untinted `UIGlassEffect`, and the glass is actually visible: a
        /// brand tint at any real strength is what obscures it.
        ///
        /// The theme colour is still read, for one thing: its luminance selects the light or the
        /// dark variant of the material, so a card configured dark stays dark.
        ///
        /// Pass `false` to tint the glass with the theme's colour instead — see
        /// ``liquidGlassTintAlpha(light:dark:)`` for the strength.
        ///
        /// - Parameter enabled: `false` to tint the surface with the theme's colour.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func liquidGlassDefaultBackground(_ enabled: Bool = true) -> Self {
            liquidGlassDefaultBackgroundEnabled = enabled
            return self
        }

        /// Sets the alpha applied to a theme's `background_color` when it tints a glass
        /// surface, for both interface styles.
        ///
        /// - Parameter alpha: Tint alpha, clamped to `0...1`.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func liquidGlassTintAlpha(_ alpha: CGFloat) -> Self {
            liquidGlassTintAlpha(light: alpha, dark: alpha)
        }

        /// Sets the alpha applied to a theme's `background_color` when it tints a glass
        /// surface, per interface style.
        ///
        /// Defaults are `0.28` light / `0.40` dark. A higher value keeps more of the brand
        /// colour and less of the underlying content; `0` is untinted glass.
        ///
        /// - Parameters:
        ///   - light: Tint alpha in light mode, clamped to `0...1`.
        ///   - dark: Tint alpha in dark mode, clamped to `0...1`.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func liquidGlassTintAlpha(light: CGFloat, dark: CGFloat) -> Self {
            liquidGlassTintAlphaLight = min(max(light, 0), 1)
            liquidGlassTintAlphaDark = min(max(dark, 0), 1)
            return self
        }

        // MARK: - Multi-instance scope setters

        /// Claim every UI rooted in any of the given `bundles` for this Userpilot instance.
        ///
        /// Use this when an SDK that embeds Userpilot wants its own UI (e.g. a settings screen
        /// shipped inside the SDK's framework) attributed to its own tenant rather than the
        /// host app's. Autocapture resolves ownership by walking the responder
        /// chain to the nearest view controller, then comparing `Bundle(for: vc.class)`'s
        /// `bundleIdentifier` against every registered instance's claimed bundles.
        ///
        /// Calls are additive: each invocation merges `bundles` into the existing claims, so
        /// attaching extra bundles later does not overwrite earlier ones. Bundles without a
        /// `bundleIdentifier` are ignored, and duplicate identifiers are de-duplicated.
        ///
        /// - Parameter bundles: The bundles whose UI this Userpilot instance should own.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func attach(bundles: [Bundle]) -> Self {
            for bundle in bundles {
                if let identifier = bundle.bundleIdentifier, !identifier.isEmpty {
                    attachedBundleIdentifiers.insert(identifier)
                }
            }
            return self
        }

        /// Claim every UI hosted by any of the given `windows` for this Userpilot instance.
        ///
        /// Useful when an SDK presents its own dedicated `UIWindow`s (e.g. an overlay window
        /// for an embedded experience) that don't live inside their own framework bundle.
        /// Windows are held weakly.
        ///
        /// Calls are additive: each invocation merges `windows` into the existing claims.
        ///
        /// - Parameter windows: The windows whose UI this Userpilot instance should own.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func attach(windows: [UIWindow]) -> Self {
            for window in windows {
                attachedWindows.add(window)
            }
            return self
        }

        /// Claim every view controller of any class in `viewControllerClasses` (or any
        /// subclass of those classes) for this Userpilot instance.
        ///
        /// Escape hatch for unusual hosting setups where neither bundle nor window
        /// resolution is sufficient. Subclasses are considered owned.
        ///
        /// Calls are additive: each invocation appends to the existing claims, so passing
        /// extra classes later does not overwrite earlier ones.
        ///
        /// - Parameter viewControllerClasses: The view controller classes this instance
        ///   should own.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func attach(viewControllerClasses: [AnyClass]) -> Self {
            attachedViewControllerClasses.append(contentsOf: viewControllerClasses)
            return self
        }

        /// Marks this Userpilot instance as the global fallback for autocapture
        /// events that have no other owner (no explicit `userpilot:` argument and
        /// no `attach(bundles:)` / `attach(windows:)` / `attach(viewControllerClasses:)`
        /// hit and no SwiftUI `userpilotOwner` env value).
        ///
        /// Typical usage: the host application leaves this at `true` (the default);
        /// embedded third-party SDKs call `.defaultInstance(false)`. Default resolution
        /// is claim-based — when the vendor opts out, the host holds the role
        /// regardless of init order. See `isDefault` for the conflict policy.
        ///
        /// - Parameter enabled: A boolean indicating whether this instance should
        ///   be the explicit default. Defaults to `true`.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func defaultInstance(_ enabled: Bool = true) -> Self {
            isDefault = enabled
            return self
        }

        /// Allows this (default) instance to also receive autocapture events that
        /// originate on a non-default instance (an embedded third-party / vendor SDK),
        /// so the host app becomes aware of them.
        ///
        /// Only effective on the resolved default instance. See
        /// `allowReceiveEventsFromExternalSource` for the full policy.
        ///
        /// - Parameter enabled: Whether to receive forwarded external-source events.
        ///   Defaults to `true`.
        /// - Returns: The configuration object, allowing for method chaining.
        @discardableResult
        @objc
        public func allowReceiveEventsFromExternalSource(_ enabled: Bool = true) -> Self {
            allowReceiveEventsFromExternalSource = enabled
            return self
        }

    }

}
