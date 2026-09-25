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

extension Userpilot {

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
        var enableInteractionValueCapture: Bool = true

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
