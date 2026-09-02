//
//  Userpilot.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The `Userpilot` class is the primary interface for integrating Userpilot SDK into an application.
//  It manages user tracking, event publishing, experience rendering, and various analytics functions,
//  allowing you to deliver personalized, context-aware content based on user actions and data.
//

import ObjectiveC
import UIKit

// swiftlint:disable file_length

/// `Userpilot` manages the lifecycle of the Userpilot SDK and tracks user activity, enabling
/// personalized content delivery.
@objc(Userpilot)
public class Userpilot: NSObject {

    // MARK: - Shared Instance

    /// Returns the default `Userpilot` instance — the one that opted in via
    /// `Config.defaultInstance(true)` — or `nil` when no instance currently holds
    /// the default role.
    ///
    /// In single-instance integrations (the common case) this is the only
    /// instance the host app created via `Userpilot(config:)`; `isDefault`
    /// defaults to `true`, so no extra configuration is needed. In multi-instance
    /// integrations (e.g. an app that uses Userpilot directly while also depending
    /// on a vendor SDK that embeds Userpilot) this returns whichever instance
    /// claimed the default role — normally the host, with the vendor opting out
    /// via `defaultInstance(false)`. Selection is claim-based, so it is independent
    /// of init order.
    ///
    /// SDK-internal call sites use this as the fallback for unattributed
    /// autocapture and screen-tracking work.
    internal static var shared: Userpilot? {
        return Registry.shared.default
    }

    /// Returns `true` if the SDK has been initialized and the default instance is available.
    internal static var isInitialized: Bool {
        return Registry.shared.default != nil
    }

    /// Look up a registered `Userpilot` instance by its configured token.
    ///
    /// Returns `nil` when no instance has been created with that token, or when the only
    /// instance for that token has been deallocated.
    ///
    /// Useful for code paths that need to reach a specific tenant from outside the
    /// callsite that created it (e.g. callbacks from a vendor SDK back into Userpilot).
    internal static func instance(forToken token: String) -> Userpilot? {
        return Registry.shared.instance(forToken: token)
    }

    // MARK: - Properties

    /// A dependency injection container that stores and provides necessary services like analytics,
    /// storage, and networking.
    ///
    /// `var` rather than `let` so the idempotent initializer can adopt an already-registered
    /// instance's container when `Userpilot(config:)` is called twice with the same token —
    /// see the explanatory comment in `init(config:)`. External callers never see this
    /// property; it remains module-internal.
    var container = DIContainer()

    /// Configuration object that holds initialization parameters for the SDK.
    let config: Config

    /// Lazy loading of the `AnalyticsPublishing` instance responsible for publishing user tracking events.
    private lazy var analyticsPublisher = container.resolve(AnalyticsPublishing.self)

    /// Lazy loading of the `DataStoring` instance that manages persistent storage (e.g., user data, preferences).
    private lazy var storage = container.resolve(DataStoring.self)

    /// Lazy loading of the `SocketEvents` instance that manages WebSocket connections and event-driven communication.
    private lazy var socketManager = container.resolve(SocketEvents.self)

    /// Lazy loading of the `SessionMonitoring` instance that manages app lifecycle.
    private lazy var sessionMonitor = container.resolve(SessionMonitoring.self)

    /// Lazy loading of the `ExperiencesPublishing` instance that manages app lifecycle.
    private lazy var experiencesPublisher = container.resolve(ExperiencesPublishing.self)

    /// Lazy loading AutoPropertyDecoratoring
    private lazy var autoPropertyDecorator = container.resolve(AutoPropertyDecoratoring.self)

    /// Lazy loading pushNotificationMonitoring
    private lazy var pushNotificationMonitor = container.resolve(PushNotificationMonitoring.self)

    /// Lazy loading SDK logger
    private lazy var logger = container.resolve(Userpilot.Config.self).logger

    /// Lazy-instantiated overlay window used to present experiences for this instance.
    ///
    /// Each `Userpilot` instance owns one. The window is created on first
    /// access (i.e. only when this instance actually presents an experience),
    /// uses passthrough hit-testing so non-experience touches fall through, and
    /// sits at a deterministic `UIWindow.Level` derived from the instance's
    /// registration order. See `ExperienceOverlayWindow` for the full rationale.
    ///
    /// Marked `internal` so `ExperiencesPublisher` can route presentations
    /// through it; never exposed to host apps directly.
    internal lazy var experienceOverlayWindow: ExperienceOverlayWindow = {
        ExperienceOverlayWindow(owningInstance: self)
    }()

    // MARK: - Delegates

    /// The delegate object that handles application screen navigation during experience presentation.
    @objc public weak var navigationDelegate: UserpilotNavigationDelegate?

    /// The delegate object that broadcast analytics events.
    @objc public weak var analyticsDelegate: UserpilotAnalyticsDelegate?

    /// The delegate object that manages and observes experience presentations.
    @objc public weak var experienceDelegate: UserpilotExperienceDelegate?

    // MARK: - Initialization

    /**
     Initializes the `Userpilot` SDK with the provided configuration.

     Idempotent ("get-or-create"): if a `Userpilot` for `config.token` is already
     registered, this initializer adopts that instance's services by pointing the
     new wrapper at the existing dependency container. The supplied `config` is
     discarded in that case — the first call wins. This prevents accidental
     socket / observer churn from duplicate `Userpilot(config:)` calls.

     On the fresh-init path it sets up analytics, storage, networking, push
     auto-config, and autocapture as before.

     - Parameter config: A `Config` object that contains various initialization settings like logging,
     API keys, and anonymous user tracking settings.
     */

    @objc
    public init(config: Config) {
        self.config = config
        super.init()

        // One-shot legacy storage migration. Idempotent, runs at most once per
        // (token, install). The first-token-wins claim inside `StorageMigrator`
        // ensures only one tenant ever absorbs the legacy v1 suite.
        StorageMigrator.runIfNeeded(forToken: config.token)

        // Idempotent: if a Userpilot for this token already exists, adopt its
        // container and return. The new wrapper still resolves the same
        // services (analytics, socket, storage, etc.) as the original — the
        // existing instance and this returned facade publish through the same
        // underlying machinery. Callers that hold the original reference and
        // the one returned here both observe the same state.
        if let existing = Registry.shared.instance(forToken: config.token) {
            self.container = existing.container
            config.logger.error(
                // swiftlint:disable:next line_length
                "⚠️ Userpilot already initialized for token %{public}@; returning the existing instance. The supplied config was discarded.",
                config.token
            )
            return
        }

        // Default-instance resolution: if `Config.defaultInstance(true)` was set
        // (the default), this instance claims the default role (first claim wins).
        // When the role is already held, the claim is rejected. See
        // `Registry.register(_:)`.
        // The registry is a pure data structure, so when it rejects a second
        // `isDefault` claim it returns the existing claimant's token and the
        // warning is emitted here at the call site.
        if let existingDefaultToken = Registry.shared.register(self) {
            config.logger.error(
                // swiftlint:disable:next line_length
                "⚠️ isDefault is already claimed by token %{public}@; ignoring isDefault=true on token %{public}@. Only one Userpilot instance per process can be the default; unattributed events will continue to route to %{public}@.",
                existingDefaultToken,
                config.token,
                existingDefaultToken
            )
        }

        // Set up the dependency container and register required services
        initializeContainer()

        // Register pushNotificationMonitoring for push notification auto config
        PushNotificationAutoConfig.register(observer: pushNotificationMonitor)

        // Start Auto capture
        checkAutoCapture()

        // Log the initialization of the SDK with the current version.
        config.logger.info("🌏 Userpilot SDK initialized, version: %{public}@", version())
    }

    deinit {
        Registry.shared.unregister(self)
    }

    // MARK: - Setup Methods

    /**
     Initializes the DI (Dependency Injection) container and registers required services.
    
     This method sets up lazy initialization for essential SDK services like `DataStoring`,
     `Networking`, `SocketEvents`, and more.
     By using lazy registration, the services are only created when they are first used, improving performance.
     */
    internal func initializeContainer() {
        container.owner = self
        container.register(Config.self, value: config)
        // Inject the process-wide registry as an abstraction so consumers
        // (e.g. `AutoCaptureCoordinater`) resolve it instead of reaching for
        // `Registry.shared` directly. The value is the shared singleton, so
        // every instance's container hands back the same registry.
        container.register(InstanceRegistering.self, value: Registry.shared)
        container.registerLazy(
            AutoPropertyDecoratoring.self, initializer: AutoPropertyDecorator.init)
        container.registerLazy(SocketEvents.self, initializer: SocketManager.init)
        container.registerLazy(UserpilotRemoteSourcing.self, initializer: UserpilotRemoteSource.init)
        container.registerLazy(ThemeHandling.self, initializer: ThemeHandler.init)
        container.registerLazy(ImageLoading.self, initializer: ImageLoader.init)
        container.registerLazy(ScreenNameTracking.self, initializer: ScreenNameTracker.init)
        container.registerLazy(AutoCaptureCoordinating.self, initializer: AutoCaptureCoordinater.init)
        container.registerLazy(DeepLinkHandling.self, initializer: DeepLinkHandler.init)
        container.registerLazy(LinkOpening.self, initializer: LinkOpener.init)
        container.registerLazy(ExperienceStateManaging.self, initializer: ExperienceStateManager.init)
        container.registerEager(DataStoring.self, initializer: Storage.init)
        container.registerEager(AnalyticsPublishing.self, initializer: AnalyticsPublisher.init)
        container.registerEager(
            PushNotificationMonitoring.self, initializer: PushNotificationMonitor.init)
        container.registerEager(ExperiencesPublishing.self, initializer: ExperiencesPublisher.init)
        container.registerEager(SessionMonitoring.self, initializer: SessionMonitor.init)

        // Only spin up the auto-detector when the host app didn't set the
        // framework explicitly via `Config.appFramework(_:)`.
        if config.appFramework == nil {
            container.registerEager(
                AppFrameworkDetector.self, initializer: AppFrameworkDetector.init)
        }
    }
}

// MARK: - Public Methods

extension Userpilot {

    /**
     Retrieves the current version of the Userpilot SDK as a string.
    
     This method provides the static version of the SDK, useful for logging or debugging purposes.
    
     - Returns: A string representing the current version of the Userpilot SDK.
     */
    @objc(sdkVersion)
    public static func version() -> String {
        return userpilotVersion
    }

    /// Retrieves the current version of the SDK for this instance.
    @objc
    public func version() -> String {
        return Userpilot.version()
    }

}

// MARK: - Tracking APIs

extension Userpilot {

    /**
     Identifies a user to the SDK, enabling personalized content and behavior tracking.
    
     This method allows the SDK to associate analytics and content with a known user by passing their unique `userId`.
     Additional properties and company details can be provided for more context.
    
     - Parameters:
       - userId: A unique identifier for the user, which is used to track their behavior across sessions.
       - properties: An optional dictionary containing user-specific properties like email, role, or age.
       - company: An optional dictionary containing company-specific properties for users associated with company.
     */
    @objc
    public func identify(
        userId: String,
        properties: Payload = nil,
        company: Payload = nil
    ) {
        guard userId.trim().isNotEmpty else {
            config.logger.error("Invalid user id - empty string")
            return
        }
        analyticsPublisher.publish(
            Event(
                type: .identify(userId.trim()),
                properties: properties,
                company: company
            )
        )
    }

    /**
     Tracks an anonymous user session.
    
     This method generates a unique anonymous ID - cache it, allowing the SDK to track behavior and trigger
     relevant content even when the user has not explicitly signed in or identified themselves.
     */
    @objc
    public func anonymous() {
        if storage.anonymousUserId.isEmpty {
            storage.anonymousUserId = "\(config.token)_\(anonymousFactory())"
        }
        identify(userId: storage.anonymousUserId)
    }

    /**
     Tracks a screen view event when a user navigates to a specific screen in the app.
    
     This method records the screen title and sends it to the analytics service for tracking
     user activity and triggering content.
    
     - Parameter title: The title of the screen that the user has viewed.
     */
    @objc
    public func screen(_ title: String) {
        guard !config.enableScreenAutoCapture else {
            config.logger.error(
                "Manual screen tracking is disabled when enableScreenAutocapture is enabled")
            return
        }
        guard title.trim().isNotEmpty else {
            config.logger.error("Invalid screen title - empty string")
            return
        }
        // Interaction autocapture debounces text-field / text-view changes, so a change the user made
        // right before navigating would otherwise be published after this screen event and attributed
        // to the new screen. Screen autocapture never reaches here (guarded above), so this covers the
        // interaction-autocapture-with-manual-screens setup.
        if config.enableInteractionAutoCapture {
            InteractionEventCache.flushPendingInteractions()
        }
        let event = Event(
            type: .screen(title),
            properties: [AutoCaptureConstants.source: AutoCaptureConstants.manualCaptureSourceValue]
        )
        analyticsPublisher.publish(event)
    }

    /**
     Tracks a custom event based on a user action.
    
     This method allows developers to track any arbitrary action taken by the user, such as button clicks,
     form submissions, or purchases.
     The event is recorded and sent to the analytics service for further analysis or content triggering.
    
     - Parameters:
       - name: The name of the custom event (e.g., "purchase", "button_click").
       - properties: An optional dictionary containing additional context or metadata related to the event.
     */
    @objc
    public func track(
        eventName: String,
        properties: Payload = nil
    ) {
        guard eventName.trim().isNotEmpty else {
            config.logger.error("Invalid event name - empty string")
            return
        }
        analyticsPublisher.publish(
            Event(
                type: .event(eventName),
                properties: properties
            )
        )
    }

    /**
     Logs the user out and clears their session data.
    
     This method should be called when the user logs out of the application.
     It calls clean method and close user socket.
     */
    @objc
    public func logout() {
        storage.temporaryUser = nil
        storage.user = ""
        analyticsPublisher.logout(socketState: .shuttingDown, shouldClearCachedIdentifyEvent: true)
        clean()
    }

    /**
     This function gathers application settings (such as the SDK version and user data) into a dictionary,
     converts it into a JSON string, and logs it for debugging purposes.
     */
    @objc
    public func settings() -> [String: Any] {
        var autoPropertiesDict: [String: Any]?
        var appPropertiesDict: [String: Any]?
        var user: [String: Any]?

        // Convert the JSON strings to dictionaries
        if let autoPropertiesData = autoPropertyDecorator.autoProperties.toJSONString()?.data(
            using: .utf8) {
            autoPropertiesDict =
                (try? JSONSerialization.jsonObject(
                    with: autoPropertiesData, options: [])) as? [String: Any]
        }

        if let appPropertiesData = autoPropertyDecorator.appProperties.toJSONString()?.data(
            using: .utf8) {
            appPropertiesDict =
                (try? JSONSerialization.jsonObject(
                    with: appPropertiesData, options: [])) as? [String: Any]
        }

        if let userData = storage.user.data(using: .utf8) {
            user =
                (try? JSONSerialization.jsonObject(with: userData, options: [])) as? [String: Any]
        }

        // Create the dictionary for settings
        let settings: [String: Any] = [
            "SDK version": version(),
            "Token": config.token,
            "User": user ?? [:],
            "Auto properties": autoPropertiesDict ?? [:],
            "App properties": appPropertiesDict ?? [:]
        ]

        if let jsonData = try? JSONSerialization.data(
            withJSONObject: settings, options: .withoutEscapingSlashes) {
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                logger.debug("⚙️ Settings -> %{public}@", jsonString)
            }
        }

        return settings
    }

    // MARK: - SDK APIs

    /**
     Clear user session data.
    
     This method should be called when the user logs out or when identify called with new userId.
     It resets the session state, clears user-related data, and ensures no further tracking occurs for
     the logged-out user.
     */
    internal func clean() {
        storage.pushToken = nil
        storage.userId = ""
        storage.user = ""
    }
}

// MARK: - Experiences

extension Userpilot {

    /**
     Manually starts an experience within the client application using the provided experience token.
    
     - Parameters:
       - experienceId: unique identifier for the experience to be launched, this ID should be provided
        by the backend or obtained during experience configuration.
     */
    @objc
    public func triggerExperience(_ experienceId: String) {
        guard experienceId.trim().isNotEmpty else {
            config.logger.error("Invalid experience id - empty string")
            return
        }
        experiencesPublisher.triggerExperience(experienceId)
    }

    /**
     Manually ends an experience within from the client application.
     */
    @objc
    public func endExperience() {
        experiencesPublisher.endExperience(manualClose: true)
    }
}

// MARK: - Push notifications

extension Userpilot {

    /// Enables automatic configuration of push notifications for Userpilot.
    /// This method sets up the push notification settings automatically.
    @objc
    public static func enableAutomaticPushConfig() {
        PushNotificationAutoConfig.configureAutomatically()
    }

    /// Provides the APNs device token to Userpilot for push notification tracking.
    ///
    /// - Parameter deviceToken: The device token received from Apple's Push Notification Service (APNs).
    ///   This token is used for registering the device with Userpilot to receive push notifications.
    @objc
    public func setPushToken(_ deviceToken: Data?) {
        pushNotificationMonitor.setPushToken(deviceToken)
    }

    /// Called when the client app receives a push notification.
    ///
    /// - Parameters:
    ///   - response: The `UNNotificationResponse` object containing information about the
    ///   notification that was received.
    ///   - completionHandler: A closure to be executed after processing the notification. This block
    ///   must be called when the app finishes processing the notification.
    ///
    /// - Returns: A `Bool` indicating whether Userpilot should automatically handle the
    /// completion block. If `true` is returned, Userpilot will call the `completionHandler` automatically.
    ///  If `false` is returned, you should call `completionHandler` after processing the user's response.
    public func didReceiveNotification(
        response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) -> Bool {
        return pushNotificationMonitor.didReceiveNotification(
            response: response,
            completionHandler: completionHandler
        )
    }

}

// MARK: - Auto capture

extension Userpilot {

    /// Internal access to the automatic capture engine (screen + interaction hooks).
    internal var autoCaptureCoordinator: AutoCaptureCoordinating {
        return container.resolve(AutoCaptureCoordinating.self)
    }

    /// The analytics publisher backing this instance, resolved from its container.
    ///
    /// Used by a non-default instance's `AutoCaptureCoordinater` to forward an
    /// autocapture event into this (default) instance's publisher when the default
    /// opted in via `Config.allowReceiveEventsFromExternalSource`. Publishing
    /// straight to the publisher (never back through routing) means it cannot
    /// re-forward.
    internal func resolveAnalyticsPublisher() -> AnalyticsPublishing {
        container.resolve(AnalyticsPublishing.self)
    }

    /// Check auto capture configuration and initialize engines if enabled.
    public func checkAutoCapture() {
        let config = container.resolve(Userpilot.Config.self)
        let screenAutocaptureEnabled = config.enableScreenAutoCapture
        let interactionEnabled = config.enableInteractionAutoCapture

        if screenAutocaptureEnabled || interactionEnabled {
            _ = autoCaptureCoordinator
        }
    }

    /// Auto capture screen events from wrappers
    @objc
    public func trackExternalAutoCaptureScreen(_ title: String) {
        autoCaptureCoordinator.trackExternalAutoCaptureScreen(title)
    }

    /// Auto capture interactions events from wrappers
    @objc
    public func trackExternalAutoCaptureEvent(eventName: String, properties: Payload) {
        autoCaptureCoordinator.trackExternalAutoCaptureEvent(eventName, properties)
    }
}

// MARK: - Autocapture Stop / Resume (per instance)

extension Userpilot {

    /// Stops automatic screen and interaction capture for **this** instance. No events are
    /// recorded for it until `resumeAutoCapture()` is called. Other Userpilot instances in the
    /// same process keep capturing, so a host app and an embedded vendor SDK can pause independently.
    @objc
    public func stopAutoCapture() {
        autoCaptureCoordinator.stopAutoCapture()
    }

    /// Resumes automatic screen and interaction capture for **this** instance after a previous
    /// `stopAutoCapture()`.
    @objc
    public func resumeAutoCapture() {
        autoCaptureCoordinator.resumeAutoCapture()
    }
}

// MARK: - Autocapture View Configuration (thin facade; implementation in AutocaptureViewConfiguration)

extension Userpilot {

    @objc
    public static func userpilotSetRedactText(_ value: Bool, for responder: UIResponder) {
        AutocaptureViewConfiguration.setRedactText(value, for: responder)
    }

    @objc
    public static func userpilotSetRedactAccessibilityLabel(_ value: Bool, for responder: UIResponder) {
        AutocaptureViewConfiguration.setRedactAccessibilityLabel(value, for: responder)
    }

}

// MARK: - Deep links

extension Userpilot {

    /// Verifies if an incoming URL is intended for the Userpilot SDK.
    /// - Parameter url: The URL being opened.
    /// - Returns: `true` if the URL matches the Userpilot URL Scheme or `false` if the URL is not
    ///  known by the Userpilot SDK.
    ///
    /// If the `url` is an Userpilot URL, this function may launch an experience or otherwise alter
    /// the UI state.
    ///
    /// This function is intended to be called added at the top of your
    /// `UIApplicationDelegate`'s `application(_:open:options:)` function:
    /// ```swift
    /// guard !userpilot.didHandleURL(url) else { return true }
    /// ```
    @discardableResult
    @objc
    public func didHandleURL(_ url: URL) -> Bool {
        return container.resolve(DeepLinkHandling.self).didHandleURL(url)
    }

}
// swiftlint:enable file_length
