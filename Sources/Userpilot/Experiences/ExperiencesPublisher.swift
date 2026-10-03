//
//  ExperiencesPublisher.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The `ExperiencesPublisher` class is responsible for managing and publishing in-app experiences,
//  such as carousels, using socket connections. It handles socket events, updates themes, and
//  manages the lifecycle of the experiences displayed within the application.
//

// swiftlint:disable file_length
import Foundation
import UIKit

/*
 The `ExperiencesPublishing` protocol defines the required methods for managing experiences,
 such as starting the service, retrieving active carousel content, and sending socket requests.
 */
internal protocol ExperiencesPublishing: AnyObject {

    /// Whether the publisher is currently processing a preview experience.

    /// Get current experience
    func getActiveMobileContent() -> ExperienceContent?

    /// Send experience event to backend
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent)

    /// Manually trigger experience
    func triggerExperience(_ experienceId: String)

    /// Preview experience
    func triggerPreviewExperience(_ experienceId: String, _ queryItems: [URLQueryItem])

    /// Updates the current screen used for experience targeting
    func updateScreen(_ screenName: String)

    /// The current screen used for experience targeting
    var getCurrentScreen: String { get }

    /// Manually end experience
    func endExperience(manualClose: Bool)

    /// Notify that an experience view finished dismissing
    func experienceDidFinishDismissing()

    /// Determine if can requst screen event
    func canRequestScreenEvent() -> Bool

    /// Try to handle the deep link internally
    func triggerDeepLink(url: URL)

    /// logout event
    func logout()

    /// Show thank you message
    func showThankYouMessage(_ surveyContent: SurveyContent, _ surveyTheme: SurveyTheme, _ submissionId: Int64)

    /// True while the running flow still owes a step, so its experience is not finished.
    func hasNextFlowStep() -> Bool
}

/**
 * ExperiencesPublisher manages the lifecycle and display of user experiences (flows, surveys, NPS).
 *
 * This class is responsible for:
 * - Receiving and processing experience content from socket events
 * - Managing experience queuing and display timing
 * - Handling theme caching and fetching
 * - Coordinating with analytics for proper event tracking
 * - Managing experience state and lifecycle
 * - Handling deep links and navigation
 *
 * The publisher ensures experiences are shown at appropriate times by validating screen context,
 * managing delays, and handling concurrent experience scenarios.
 */
internal class ExperiencesPublisher: ExperiencesPublishing {

    // MARK: - Dependencies

    // Services are resolved in init; the container and owner stay weak to avoid retain cycles.
    private weak var container: DIContainer?
    private weak var userpilot: Userpilot?
    private let socketManager: SocketManaging
    private let analyticsPublisher: AnalyticsPublishing
    private let userpilotRemoteSource: UserpilotRemoteSourcing
    private let themeHandler: ThemeHandling
    private let storage: DataStoring
    private let config: Userpilot.Config
    private let linkOpener: LinkOpening
    private let experienceStateMachine: ExperienceStateManaging
    private let logger: Logging

    // MARK: - Properties

    /// The current screen title being tracked
    private lazy var currentScreen: String = ""

    /// Set when NPS is presented so it shows at most once per screen visit, matching Android.
    /// Cleared when the screen changes or the user logs out, but preserved across QR previews.
    /// Atomic because presentation writes on main while socket and reset paths use other queues.
    private let npsShownOnCurrentScreen = AtomicReference(false)

    /// Keeps trigger provenance with content across theme fetching and display delays.
    private struct PendingExperience {
        let experienceContent: ExperienceContent
        let triggerType: TriggerType
    }

    /// Queue to track pending experience content waiting to be displayed.
    private var pendingExperiences: [PendingExperience] = []

    /// Rejects preview responses that were overtaken by a newer preview or a lifecycle reset.

    /// Utility for managing display delays for surveys and NPS experiences
    private lazy var delayUtils = DelayUtils()

    /// Thread-safe lock for managing experience content operations
    private let experienceQueue = DispatchQueue(
        label: Constants.DispatchQueues.experienceQueue,
        qos: .userInteractive
    )

    /// Date when a fake screen reload event was last requested.
    /// Armed on every experience close, online or offline. Closing an experience makes the host
    /// surface re-emit its screen event, and that repeat is an artifact of the dismissal rather
    /// than real navigation whether or not a socket is there to carry the fake reload — offline it
    /// would otherwise be persisted and replayed to the backend as a genuine screen view.
    private var requestFakeScreenReloadEventDate: Date?

    /// Determines if there are currently active experiences being displayed.
    ///
    /// The state machine's component is the only record of what is on screen. A second, weaker
    /// `activeExperience` reference used to sit beside it, for a renderer that did not conform to
    /// `UPExperience` — but every view controller `showExperience` can present does conform, so it
    /// only ever held the same object twice. Android has always had the one reference.
    private var hasActiveExperience: Bool {
        return experienceStateMachine.getActiveComponent() != nil
            || experienceStateMachine.isActivelyRendered()
    }

    /// Expereinces presentation style.
    private enum PresentationStyle {
        case fullScreen
        case dialog
        case bottomSheet
        case normal
    }

    // MARK: - Initialization

    /**
     * Initializes the ExperiencesPublisher by setting up socket subscription
     * and activity tracker listeners.
     *
     * - Parameter container: A `DIContainer` instance that provides dependencies.
     */
    init(container: DIContainer) {
        self.container = container
        self.userpilot = container.owner
        self.storage = container.resolve(DataStoring.self)
        self.config = container.resolve(Userpilot.Config.self)
        self.socketManager = container.resolve(SocketManaging.self)
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.userpilotRemoteSource = container.resolve(UserpilotRemoteSourcing.self)
        self.themeHandler = container.resolve(ThemeHandling.self)
        self.logger = container.resolve(Userpilot.Config.self).logger
        self.linkOpener = container.resolve(LinkOpening.self)
        self.experienceStateMachine = container.resolve(ExperienceStateManaging.self)

        socketManager.registerCallback(self)
    }

    // MARK: - SDK API Methods

    /**
     * Resets state and cancels pending content on user logout.
     * This prevents experiences from being shown to the wrong user.
     */
    func logout() {
        npsShownOnCurrentScreen.value = false
        // The sole external exit from the preview latch: a preview must not outlive the user who
        // scanned it, or it would follow the next user in.
        exitPreviewMode()
        resetState()
    }

    /**
     * Determines if screen tracking events are allowed to be triggered.
     *
     * Screen events can be tracked when:
     * - Close full screen content flag is not active (more than 1 second has passed)
     * - No active experience is currently displayed
     * - No thank you survey message is currently active
     *
     * - Returns: true if screen events can be triggered, false otherwise
     */
    func canRequestScreenEvent() -> Bool {
        return requestFakeScreenReloadEventDate?.isMoreThanOneSecond(from: Date()) ?? true
            && !hasActiveExperience
            && !experienceStateMachine.isActive()
            // A preview being set up is not yet "active", but requesting screen events during it
            // would drive normal content on top of the draft being previewed.
            && !experienceStateMachine.isPreviewMode()
            && !experienceStateMachine.hasCachedExperience()
    }

    /// True while the running flow still owes a step, so its experience is not finished.
    func hasNextFlowStep() -> Bool {
        experienceStateMachine.hasNextFlowStep()
    }

    /**
     * Triggers an experience manually by its ID.
     * Only allows triggering if no other experiences are currently pending or active.
     *
     * - Parameter experienceId: The ID of the experience to be triggered
     */
    func triggerExperience(_ experienceId: String) {
        experienceQueue.async { [weak self] in
            self?.triggerExperienceIfIdle(experienceId)
        }
    }

    /// Runs on `experienceQueue` for both host requests and cached manual replay.
    private func triggerExperienceIfIdle(_ experienceId: String) {
        guard case .idle = experienceStateMachine.getCurrentState(),
              !hasActiveExperience,
              !experienceStateMachine.hasCachedExperience(),
              pendingExperiences.isEmpty else {
            experienceStateMachine.markCachedManual(experienceId)
            logger.info("Experience cached - active experience in progress")
            return
        }

        delayUtils.cancelDelay()
        experienceStateMachine.markManualTrigger(experienceId)
        publishInternalSDKEvent(ExperienceContentEvent(experienceId: experienceId))
    }

    /// Helper method to get top view controller
    internal var topViewControllerProvider: () -> UIViewController? = {
        return UIApplication.shared.topViewController()
    }

    /// Resolves the host view controller that experiences should be presented on.
    ///
    /// Multi-instance: returns this instance's overlay window root VC so two
    /// instances may render experiences concurrently without competing for the
    /// host app's `keyWindow`. The overlay uses passthrough hit-testing so
    /// non-experience touches still reach the underlying app UI.
    ///
    /// Single-instance: behaves identically — the overlay is a single full-screen
    /// window at `windowLevel.normal + 1` that fully passes touches through when
    /// no experience is being presented.
    ///
    /// The overlay window surfaces itself synchronously in `init`, so by the
    /// time we return the rootVC it is already in the scene's window hierarchy
    /// and safe to present on. `refreshWindowLevel()` re-resolves the level on
    /// every present so newly-registered tenants don't disturb the z-order of
    /// in-flight presentations.
    ///
    /// Falls back to the legacy `topViewControllerProvider()` only when the
    /// owning instance has been deallocated (defensive — should not happen
    /// under normal lifecycle).
    internal func experiencePresentationHost() -> UIViewController? {
        if let overlay = userpilot?.experienceOverlayWindow {
            overlay.prepareForPresentation()
            return overlay.rootViewController
        }
        return topViewControllerProvider()
    }

    /// Hides the overlay window when no experience is currently presented on it.
    /// Called from dismissal paths so the overlay window doesn't sit visible
    /// (and consume input focus) while idle.
    ///
    /// Reached from `resetState`, which runs on the caller's queue — `logout()` and
    /// `updateScreen(_:)` are public API and wrappers call them from their own
    /// queues (Capacitor from its `bridge` queue). Hiding a window is UIKit work,
    /// so marshal it onto the main queue; the `Thread.isMainThread` fast path keeps
    /// the already-on-main callers (`endExperience`, `experienceDidFinishDismissing`)
    /// synchronous so their hide still lands before their completion handler.
    ///
    /// Uses the non-creating accessor: an instance that never presented an
    /// experience has no overlay to collapse, and building one here would construct
    /// (and briefly surface) a window purely in order to hide it.
    internal func hideExperienceOverlayIfIdle() {
        if Thread.isMainThread {
            userpilot?.existingExperienceOverlayWindow?.hideIfIdle()
        } else {
            performOn(.main) { [weak self] in
                self?.userpilot?.existingExperienceOverlayWindow?.hideIfIdle()
            }
        }
    }

    /**
     * Ends all active experience views.
     *
     * - Parameter manualClose: true if the user manually closed the experience, false for automatic closure
     */
    func endExperience(manualClose: Bool) {
        endExperience(manualClose: manualClose, completion: nil)
    }

    private func endExperience(manualClose: Bool, completion: (() -> Void)?) {
        performOn(.main) { [weak self] in
            guard let self else {
                completion?()
                return
            }
            guard let experience = self.experienceStateMachine.getActiveComponent() else {
                if !self.experienceStateMachine.hasCachedExperience() {
                    self.experienceStateMachine.markIdle()
                }
                self.hideExperienceOverlayIfIdle()
                completion?()
                return
            }

            experience.triggerCloseExperience(manualClose: manualClose) { [weak self] in
                guard let self else {
                    completion?()
                    return
                }
                if !self.experienceStateMachine.hasCachedExperience() {
                    self.experienceStateMachine.markIdle()
                }
                self.experienceDidFinishDismissing()
                completion?()
            }
        }
    }

    /// Cleans up the overlay after the actual UIKit dismissal completion fires.
    ///
    /// This is the one hook every renderer reaches — through `onExperienceDismissalCompleted()`
    /// when the user closes it, and through `endExperience`'s completion when an incoming scan
    /// replaces it — so it is where the preview session is settled, mirroring Android's
    /// `completeExperienceDismissal`.
    func experienceDidFinishDismissing() {
        // Settle the preview that just went away. Its session is ended only while the preview that
        // rendered under it still owns it: a scan that arrived while this experience was closing
        // has already begun the next session, and that one must outlive this close — otherwise the
        // scan would dismiss the content on screen and show nothing.
        if experienceStateMachine.isPreviewMode() {
            exitPreviewMode()
        } else if experienceStateMachine.isActivelyRendered() {
            experienceStateMachine.markIdle()
        }
        // A cached request belongs to the next experience. Start it only after the current
        // renderer has finished dismissing, and never while a replacement preview owns the flow.
        processCachedExperience()
        performOn(.main) { [weak self] in
            self?.hideExperienceOverlayIfIdle()
        }
    }

    /**
     * Opens the survey thank you bottom sheet after survey completion.
     * Manages the thank you message display timing and deep link handling.
     *
     * - Parameter surveyContent: The survey content that was completed
     * - Parameter surveyTheme: The theme to apply to the thank you message
     */
    func showThankYouMessage(
        _ surveyContent: SurveyContent,
        _ surveyTheme: SurveyTheme,
        _ submissionId: Int64
    ) {
        presentThankYouMessage(surveyContent, surveyTheme, submissionId)
    }

    // MARK: - Helper Methods

    /**
     * Retrieves the currently active mobile content and clears the pending queue.
     * Used by experience activities to get their content data.
     *
     * - Returns: The first pending experience content, or null if none available
     */
    func getActiveMobileContent() -> ExperienceContent? {
        guard !pendingExperiences.isEmpty else { return nil }
        let content = pendingExperiences.first?.experienceContent
        clearPendingExperiences()
        return content
    }

    // MARK: - Deep Link Handling

    /**
     * Triggers deep link navigation, passing control to the client app.
     * Uses the app's navigation handler if available, otherwise opens with system.
     *
     * - Parameter url: The deep link URL to navigate to
     */
    func triggerDeepLink(url: URL) {
        delay(ThemeHandler.DefaultValues.delayTimeForDeepLink) { [weak self] in
            self?.linkOpener.handleURL(url)
        }
    }

    // MARK: - SDK Event Management

    /**
     * Sends a socket request based on the provided SDK event.
     * Handles experience tracking, content caching, and fake reload triggering.
     *
     * - Parameter sdkEvent: The SDK event containing the event name and payload
     */
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent) {
        tryCatch {
            // Deliberately the state machine's own check, not the wider latch: a QR deep link
            // claims its preview session before the experience it replaces has finished closing, so
            // the wider check would route that experience's own close into this branch and let it
            // cancel the session belonging to the preview that replaced it.
            if experienceStateMachine.isPreviewMode() {
                if sdkEvent.isEventForCloseExperience() || sdkEvent.isEventForCloseNPSExperience() {
                    requestFakeScreenReloadEventDate = Date()
                    // Same exclusions as the non-preview path below, and as Android's
                    // `handlePreviewCloseEvent`: NPS is the last content shown, and a deep link
                    // opens a new screen that will ask for content on its own.
                    if !sdkEvent.isEventForCloseNPSExperience(), !sdkEvent.hasDeepLink {
                        analyticsPublisher.publishFakeReloadScreenEvent(
                            sdkEvent.getContentType(),
                            sdkEvent.getContentId()
                        )
                    }
                }
                return
            }

            // Process the event through analytics publisher; the response comes
            // back through the multicast subscription as `message.resolvedEvent`
            analyticsPublisher.publishInternalSDKEvent(sdkEvent)

            // Update seen content for ScreenSessionStateMachine tracking
            if sdkEvent.isSeenContentEvent(), let contentId = sdkEvent.getContentId() {
                analyticsPublisher.experiencePublished(sdkEvent.getContentType(), contentId)
            }

            // On close content events, remove all cached experiences
            // Cache date is used because if app goes to background and returns,
            // closing the experience directly won't trigger screen content
            if sdkEvent.isEventForCloseExperience() || sdkEvent.isEventForCloseNPSExperience() {
                requestFakeScreenReloadEventDate = Date()
            }

            // Don't trigger fake reload for NPS experiences or experiences with deep links
            // NPS is the last content, and deep links will open new screen
            if sdkEvent.isEventForCloseNPSExperience() || sdkEvent.hasDeepLink {
                if !experienceStateMachine.hasCachedExperience() {
                    experienceStateMachine.markIdle()
                }
                return
            }

            // Trigger fake reload when closing experience that wasn't manually triggered
            if sdkEvent.isEventForCloseExperience() && !experienceStateMachine.hasCachedExperience() {
                experienceStateMachine.markIdle()
                analyticsPublisher.publishFakeReloadScreenEvent(
                    sdkEvent.getContentType(), sdkEvent.getContentId()
                )
            }
        }
    }
}

// MARK: - SocketSubscription

extension ExperiencesPublisher: SocketSubscription {

    // MARK: - Screen Management

    /**
     * Updates screen from AnalyticsPublisher directly without waiting for response.
     * This is a high priority operation that processes immediately to avoid showing
     * content on old screens while moving to new screens.
     *
     * - Parameter screenName: The new screen title being navigated to
     */
    func updateScreen(_ screenName: String) {
        tryCatch {
            if currentScreen == screenName { return }
            currentScreen = screenName
            npsShownOnCurrentScreen.value = false
            // A preview renders on whatever screen the deep link landed on, so the screen change
            // that reveals it must resume it instead of resetting it away.
            if experienceStateMachine.isPreviewMode() {
                resumePendingPreviewExperience()
                return
            }
            resetState()
        }
    }

    /// Re-opens a preview that was waiting for the screen it was triggered from.
    private func resumePendingPreviewExperience() {
        experienceQueue.async { [weak self] in
            guard
                let self,
                case .pendingPreview = self.experienceStateMachine.getCurrentState(),
                !self.pendingExperiences.isEmpty
            else { return }
            self.openExperienceFlow()
        }
    }

    /// The current screen used for experience targeting.
    var getCurrentScreen: String {
        currentScreen
    }

    // MARK: - Socket Event Handling

    /*
     * Handles socket events when an event is sent and processes experience content responses.
     *
     * - Parameter eventName: The name of the event that was sent
     * - Parameter payload: The event payload that was sent
     * - Parameter message: The response message object from the server
     * - Parameter eventSent: Whether the event was successfully sent
     */
    func onSocketEventSent(
        _ eventName: String,
        _ payload: Payload,
        _ message: Message,
        _ eventSent: Bool
    ) {
        experienceQueue.async { [weak self] in
            guard let self else { return }
            defer { self.finishManualRequestIfEmpty(eventName, payload) }
            // Before the payload is read: a preview owns the SDK, so everything arriving for
            // another experience is dropped whatever it turns out to be. Same guard, same
            // position as Android.
            //
            // An *active* experience is deliberately not part of this guard: that content is
            // cached below and replayed when the experience closes, rather than lost. Only a
            // preview drops it.
            guard !experienceStateMachine.isPreviewMode(),
                  !message.payload.isEmpty,
                  let response = message.payload.toJSONString() else { return }
            if eventName == SDKEventsName.fetchExperienceContent.rawValue, !eventSent { return }

            // Cache theme data if this is a fetch theme event
            if eventName == SDKEventsName.fetchExperienceTheme.rawValue,
               let themeData = response.toMobileTheme(), themeData.id != nil {
                self.themeHandler.saveTheme(themeData)
            }

            self.processExperienceContentResponse(eventName, response)

            // Process the first pending experience
            if let pendingExperience = self.pendingExperiences.first {
                if pendingExperience.experienceContent.asNPSContent() != nil {
                    self.openNPSBottomSheetExperience(pendingExperience)
                } else {
                    self.checkCachedThemes(pendingExperience.experienceContent.experienceThemeId())
                }
            }
        }
    }

    /// Empty or failed manual replies end preparation even when there is no renderer to dismiss.
    private func finishManualRequestIfEmpty(_ eventName: String, _ payload: Payload) {
        guard eventName == SDKEventsName.fetchExperienceContent.rawValue,
              case .pendingManual(let experienceId) = experienceStateMachine.getCurrentState(),
              pendingExperiences.isEmpty,
              !hasActiveExperience,
              !experienceStateMachine.isPreviewMode() else { return }
        if let requestedId = payload?["mobile_content_token"] as? String, requestedId != experienceId { return }
        experienceStateMachine.markIdle()
        processCachedExperience()
    }

    /**
     * Handles new messages received from the socket.
     * This is triggered from manual experience events.
     *
     * - Parameter message: The message object containing the data received through the socket
     */
    func onNewMessage(_ message: Message) {
        if let payload = message.payload["payload"] as? [String: Any] {
            experienceQueue.async { [weak self] in
                guard let self,
                      !experienceStateMachine.isPreviewMode(),
                      payload.keys.contains("request_id"),
                      payload["request_id"] as? Int == nil else { return }

                // Determine the new content based on payload
                let experience: ExperienceContent? = {
                    if let mobileContents = payload["mobile_contents"] as? [String: Any],
                       !mobileContents.isEmpty,
                       let flowContentData = payload.toJSONString()?.toFlowContent() {
                        return ExperienceContent.flow(content: flowContentData.flowContent)
                    } else if let mobileContents = payload["surveys"] as? [String: Any],
                              !mobileContents.isEmpty,
                              let surveyContentData = payload.toJSONString()?.toSurveyContent() {
                        return ExperienceContent.survey(content: surveyContentData.surveyContent)
                    } else if let mobileContents = payload["nps"] as? [String: Any],
                              !mobileContents.isEmpty,
                              let npsContentData = payload.toJSONString()?.toNPSContent() {
                        return ExperienceContent.nps(content: npsContentData.npsContent)
                    }
                    return nil
                }()

                if let experience {
                    if self.hasActiveExperience || self.experienceStateMachine.isActive() {
                        self.experienceStateMachine.markCachedAutomatic(experience)
                        self.logger.info("Active experience in progress, caching incoming experience")
                    } else {
                        self.delayUtils.cancelDelay()
                        self.experienceStateMachine.markManualTrigger(
                            experience.experienceId().toString()
                        )
                        self.pendingExperiences.append(
                            PendingExperience(experienceContent: experience, triggerType: .manual)
                        )
                        self.checkCachedThemes(experience.experienceThemeId())
                    }
                }
            }
        }
    }
}

// MARK: - Theme Management

extension ExperiencesPublisher {

    /**
     * Checks whether a theme is cached and fetches it if necessary.
     * If the theme is available, immediately opens the experience flow.
     * Otherwise, fetches the theme data first.
     *
     * - Parameter themeId: The ID of the theme to check and potentially fetch
     */
    private func checkCachedThemes(_ themeId: Int) {
        tryCatch {
            if themeHandler.getThemeById(themeId) != nil {
                openExperienceFlow()
            } else {
                fetchThemeData(themeId)
            }
        }
    }

    /**
     * Fetches theme data for uncached themes.
     * Clears pending experiences if socket is not available.
     *
     * - Parameter themeId: The ID of the theme to fetch
     */
    private func fetchThemeData(_ themeId: Int) {
        guard analyticsPublisher.canRequestEvent else {
            // Theme preparation is abandoned on this queue; leave the flow ready for cached work.
            pendingExperiences.removeAll()
            experienceStateMachine.markIdle()
            processCachedExperience()
            return
        }

        publishInternalSDKEvent(ThemeContentEvent(themeId: themeId, token: config.token))
    }

}

// MARK: - Experience Launch Management

extension ExperiencesPublisher {

    /**
     * Starts the experience flow by determining the type and opening the appropriate UI.
     * Handles flows (carousel, slide-out), surveys (list, step), and NPS experiences.
     */
    private func openExperienceFlow() {
        if let pendingExperience = pendingExperiences.first {
            switch pendingExperience.experienceContent {
            case .flow(let content):
                switch content.type {
                case .carousel:
                    self.openCarouselExperience(pendingExperience)
                case .slideout:
                    if self.isBottomSheetContent(content) {
                        self.openSlideOutBottomSheetExperience(pendingExperience)
                    } else {
                        self.openSlideOutDialogExperience(pendingExperience)
                    }
                }

            case .survey(let content):
                switch content.type {
                case .list:
                    self.openSurveyListExperience(pendingExperience)
                case .step:
                    if self.isBottomSheetSurveyContent(content) {
                        self.openSurveyBottomSheetExperience(pendingExperience)
                    } else {
                        self.openSurveyDialogExperience(pendingExperience)
                    }
                }

            case .nps:
                openNPSBottomSheetExperience(pendingExperience)
            }
        }
    }

    /**
     * Determines whether the flow content should be displayed as a bottom sheet.
     * Checks theme data first, then falls back to cached theme information.
     *
     * - Parameter mobileContent: The flow content object to evaluate
     * - Returns: true if content should be displayed as bottom sheet, false for dialog
     */
    private func isBottomSheetContent(_ mobileContent: FlowContent) -> Bool {
        if let themeData = mobileContent.mobileTheme.themeData {
            return themeData.general?.contentAlignment == ContentAlignmentType.bottom
        } else {
            return themeHandler.getThemeById(mobileContent.mobileTheme.id)?.isDialogExperience == false
        }
    }

    /**
     * Determines whether the survey content should be displayed as a bottom sheet.
     * Checks theme data first, then falls back to cached theme information.
     *
     * - Parameter surveyContent: The survey content to evaluate
     * - Returns: true if content should be displayed as bottom sheet, false for dialog
     */
    private func isBottomSheetSurveyContent(_ surveyContent: SurveyContent) -> Bool {
        if let themeData = surveyContent.surveyTheme.themeData, let position = themeData.general?.position {
            return position == .bottom
        } else {
            return themeHandler.getThemeById(surveyContent.surveyTheme.id)?.isDialogSurvey == false
        }
    }

}

// MARK: - Experience Opening Methods

extension ExperiencesPublisher {

    /**
     * Opens a carousel experience in a full-screen activity.
     * Content is passed to prevent issues if pending experiences are cleared during screen transitions.
     */
    private func openCarouselExperience(_ pendingExperience: PendingExperience) {
        showExperience(
            pendingExperience,
            makeViewModel: ExperienceViewModel.init,
            makeViewController: CarouselExperienceViewController.init,
            presentation: .fullScreen
        )
    }

    /** Opens a slide-out experience as a dialog fragment */
    private func openSlideOutDialogExperience(_ pendingExperience: PendingExperience) {
        showExperience(
            pendingExperience,
            makeViewModel: ExperienceViewModel.init,
            makeViewController: SlideOutDialogViewController.init,
            presentation: .dialog
        )
    }

    /** Opens a slide-out experience as a bottom sheet fragment */
    private func openSlideOutBottomSheetExperience(_ pendingExperience: PendingExperience) {
        showExperience(
            pendingExperience,
            makeViewModel: ExperienceViewModel.init,
            makeViewController: SlideOutBottomSheetViewController.init,
            presentation: .bottomSheet
        )
    }

    /** Opens a survey experience in a full-screen activity with list view */
    private func openSurveyListExperience(_ pendingExperience: PendingExperience) {
        // Begun before the renderer starts, so a dismissal arriving at any point can be told
        // apart from the end of the experience.
        experienceStateMachine.beginFlow(pendingExperience.experienceContent)
        showExperience(
            pendingExperience,
            makeViewModel: SurveyViewModel.init,
            makeViewController: SurveyListViewController.init,
            presentation: .fullScreen
        )
    }

    /** Opens a survey experience as a dialog fragment */
    private func openSurveyDialogExperience(_ pendingExperience: PendingExperience) {
        showExperience(
            pendingExperience,
            makeViewModel: SurveyViewModel.init,
            makeViewController: SurveyDialogViewController.init,
            presentation: .dialog
        )
    }

    /** Opens a survey experience as a bottom sheet fragment */
    private func openSurveyBottomSheetExperience(_ pendingExperience: PendingExperience) {
        showExperience(
            pendingExperience,
            makeViewModel: SurveyViewModel.init,
            makeViewController: SurveyBottomSheetViewController.init,
            presentation: .bottomSheet
        )
    }

    /** Opens an NPS experience as a bottom sheet, at most once per screen visit. */
    private func openNPSBottomSheetExperience(_ pendingExperience: PendingExperience) {
        if npsShownOnCurrentScreen.value {
            logger.info("🎯 NPS suppressed - already shown on the current screen")
            // Drain the queue rather than only resetting the state: every launch path reads
            // `pendingExperiences.first`, so an NPS left at the head after being refused blocks
            // each experience that arrives behind it until the screen changes.
            processNextPendingExperiences()
            return
        }
        showExperience(
            pendingExperience,
            makeViewModel: NPSViewModel.init,
            makeViewController: NPSBottomSheetViewController.init,
            presentation: .bottomSheet
        )
    }

    /** Opens the survey thank you bottom sheet after survey completion */
    private func presentThankYouMessage(
        _ surveyContent: SurveyContent,
        _ surveyTheme: SurveyTheme,
        _ submissionId: Int64
    ) {
        experienceStateMachine.markShowingThankYou()
        performOn(.main) { [weak self] in
            guard
                let self = self,
                let host = self.experiencePresentationHost()
            else {
                self?.experienceDidFinishDismissing()
                return
            }
            delayUtils.delayAction { [weak self] in
                let thankYouBottomSheetViewController = ThankYouBottomSheetViewController(
                    surveyContent: surveyContent, surveyTheme: surveyTheme)
                thankYouBottomSheetViewController.actionButtonClicked = { [weak self] deepLink in
                    let eventExperienceSeen = ExperienceSurveyCompletedEvent(
                        surveyId: surveyContent.id,
                        submissionId: submissionId,
                        hasDeepLinkContent: deepLink != nil
                    )
                    self?.publishInternalSDKEvent(eventExperienceSeen)

                    delay(ThemeHandler.DefaultValues.delayTimeForExperience) { [weak self] in
                        if let deepLink, let url = URL(string: deepLink) {
                            self?.triggerDeepLink(url: url)
                        }
                    }
                }
                thankYouBottomSheetViewController.onDismissCompleted = { [weak self] in
                    self?.experienceDidFinishDismissing()
                }
                self?.experienceStateMachine.advanceFlowStep()
                host.presentBottomSheet(viewController: thankYouBottomSheetViewController)
            }
        }
    }

}

// MARK: - Experience Validation and Display Logic

extension ExperiencesPublisher {

    /**
     * Resolves the display delay for an experience.
     * Surveys and NPS have configurable delays, with a default fallback.
     *
     * - Returns: The delay duration in seconds
     */
    func resolvedDelay(_ experienceContent: ExperienceContent) -> TimeInterval {
        if let surveyDelay = experienceContent.asSurveyContent()?.delayDuration, surveyDelay > 0 {
            return surveyDelay
        }
        if let npsDelay = experienceContent.asNPSContent()?.delayDuration, npsDelay > 0 {
            return npsDelay
        }
        return ThemeHandler.DefaultValues.delayTimeForExperience
    }

    /**
     * Validates content before showing it and applies the necessary delay.
     * Delay is needed because socket responses are too fast (~200ms) which causes
     * dropped frames and interrupts opening content animations.
     */
    private func showExperience<VM, VC: UIViewController>(
        _ pendingExperience: PendingExperience,
        makeViewModel: @escaping (DIContainer) -> VM,
        makeViewController: @escaping (VM) -> VC,
        presentation: PresentationStyle
    ) {
        tryCatch {
            let experienceContent = pendingExperience.experienceContent
            experienceStateMachine.markWaitingDelay(pendingExperience.triggerType)

            delayUtils.delayAction(delayTime: resolvedDelay(experienceContent)) { [weak self] in
                guard
                    let self,
                    self.canShowExperience(pendingExperience),
                    let container = self.container
                else {
                    // Delay was cancelled through resetState, stop processing this experience
                    // If not valid to show the content, move to next one
                    self?.processNextPendingExperiences()
                    return
                }

                performOn(.main) { [weak self] in
                    guard let self, let host = self.experiencePresentationHost() else {
                        self?.processNextPendingExperiences()
                        return
                    }
                    let viewModel = makeViewModel(container)
                    let viewController = makeViewController(viewModel)
                    if presentation == .fullScreen {
                        viewController.modalPresentationStyle = .fullScreen
                    }
                    self.experienceStateMachine.markActive(pendingExperience.triggerType, experienceContent)
                    if let upExperience = viewController as? UPExperience {
                        self.experienceStateMachine.setActiveComponent(upExperience)
                    }
                    if viewController.isKind(of: NPSBottomSheetViewController.self) {
                        self.npsShownOnCurrentScreen.value = true
                    }
                    switch presentation {
                    case .fullScreen, .normal:
                        host.present(viewController, animated: true)
                    case .dialog:
                        host.presentDialog(viewController: viewController)
                    case .bottomSheet:
                        host.presentBottomSheet(viewController: viewController)
                    }
                }
            }
        }
    }

}

// MARK: - Experience content helper methods

extension ExperiencesPublisher {

    /**
     * Determines whether an experience can be shown based on current state and targeting rules.
     *
     * Validation rules:
     * - Returns `false` if there are no pending experiences to show.
     * - Returns `false` if there is already an active rendered experience.
     * - Returns `true` if the experience was manually triggered (screen validation not required).
     * - Returns `true` if the current session has just started and the experience is tied to the start session
     *   (these experiences have no screens to check, so they are shown without screen validation).
     * - Otherwise, validates screen targeting rules for Flow, Survey, or NPS content.
     *
     * @param pendingExperience The content and original trigger to validate.
     * @return `true` if the experience can be shown, `false` otherwise.
     */
    /// Selects the experience a screen or manual-fetch response carries, and queues or caches it.
    ///
    /// Mirrors Android's `processExperienceContentResponse`, including caching behind an active
    /// experience rather than dropping the content.
    private func processExperienceContentResponse(_ eventName: String, _ response: String) {
        guard eventName == Constants.Event.screenEvent ||
                eventName == SDKEventsName.fetchExperienceContent.rawValue else { return }

        // Decode every type the response carries instead of stopping at the first, so
        // automatic selection can skip past a candidate that was already seen.
        let triggerType = triggerTypeForEvent(eventName)
        let candidates = experienceCandidates(response)
        let experience: ExperienceContent? = triggerType == .automatic
            ? candidates.first { !analyticsPublisher.isExperienceSeen($0) }
            : candidates.first
        guard let experience else { return }

        if isDuplicateExperience(experience) {
            logger.info("Ignoring duplicate experience: %@", experience.experienceId().toString())
            return
        }
        if hasActiveExperience {
            experienceStateMachine.markCachedAutomatic(experience)
            logger.info("Experience cached - active experience in progress")
            return
        }
        if triggerType == .manual {
            experienceStateMachine.markManualTrigger(experience.experienceId().toString())
        } else {
            experienceStateMachine.markAutomaticTrigger(experience)
        }
        pendingExperiences.append(
            PendingExperience(experienceContent: experience, triggerType: triggerType)
        )
    }

    private func canShowExperience(_ pendingExperience: PendingExperience) -> Bool {
        guard !pendingExperiences.isEmpty else {
            logger.info("Cannot show experience: pending experiences is empty")
            return false
        }

        guard !hasActiveExperience else {
            logger.info("Cannot show experience: there is an active experience already")
            return false
        }

        if pendingExperience.triggerType == .manual || pendingExperience.triggerType == .preview {
            logger.info("Can show experience: bypassing screen validation")
            return true
        }

        if analyticsPublisher.isStartSession {
            logger.info("Can show experience: start session is true")
            return true
        }

        let experienceContent = pendingExperience.experienceContent
        let flowContent = experienceContent.asFlowContent()
        let surveyContent = experienceContent.asSurveyContent()
        let npsContent = experienceContent.asNPSContent()

        let isFlowContentValid =
            flowContent.map { $0.isForAllScreens || $0.screens.contains(currentScreen) } ?? false
        let isSurveyContentValid =
            surveyContent.map { $0.isForAllScreens || $0.screens.contains(currentScreen) } ?? false
        let isNPSContentValid =
            npsContent.map { $0.isForAllScreens || $0.screens.contains(currentScreen) } ?? false
        let isValidScreen = isFlowContentValid || isSurveyContentValid || isNPSContentValid

        logger.info(
            """
            Screen validation result: Flow=%{public}@, Survey=%{public}@, NPS=%{public}@, \
            is valid=%{public}@, current screen='%{public}@'
            """,
            "\(isFlowContentValid)",
            "\(isSurveyContentValid)",
            "\(isNPSContentValid)",
            "\(isValidScreen)",
            currentScreen
        )

        return isValidScreen
    }

    /** Removes all cached/pending experiences from the queue */
    private func clearPendingExperiences() {
        if pendingExperiences.isEmpty { return }
        experienceQueue.async { [weak self] in
            self?.pendingExperiences.removeAll()
        }
    }

    /**
     * Moves to the next pending experience in the queue.
     * Retains only the last experience and processes it.
     */
    private func processNextPendingExperiences() {
        tryCatch {
            if pendingExperiences.isEmpty { return }
            experienceQueue.async { [weak self] in
                guard let self else { return }
                // A live preview owns the queue: re-assert preview mode instead of draining the
                // pending experience out from under it.
                if self.experienceStateMachine.isPreviewMode() {
                    self.experienceStateMachine.markPreviewMode()
                    return
                }
                self.experienceStateMachine.markIdle()
                if self.pendingExperiences.count == 1 {
                    self.pendingExperiences.removeAll()
                    self.processCachedExperience()
                } else {
                    if let lastContent = self.pendingExperiences.last, self.pendingExperiences.count > 1 {
                        self.pendingExperiences = [lastContent]
                        self.openExperienceFlow()
                    }
                }
            }
        }
    }

    /**
     * Resets the publisher state, cancelling pending content and experiences.
     * Called when logging out, updating screen, activity changes, or when content
     * becomes invalid from view models.
     */
    private func resetState() {
        // Deliberately does not touch the preview latch: a lifecycle reset must not be able to
        // abandon a preview. Only `exitPreviewMode` ends one.
        resetState(completion: nil)
    }

    private func resetState(completion: (() -> Void)?) {
        tryCatch {
            delayUtils.cancelDelay()
            clearPendingExperiences()
            experienceStateMachine.clearCachedExperience()

            if hasActiveExperience || experienceStateMachine.getActiveComponent() != nil {
                endExperience(manualClose: true, completion: completion)
            } else {
                // Going idle would clear preview mode, and a reset is exactly what must not.
                if !experienceStateMachine.isPreviewMode() { experienceStateMachine.markIdle() }
                hideExperienceOverlayIfIdle()
                completion?()
            }
        }
    }

    /**
     * Decodes every experience type present in the response, in Flow → Survey → NPS order.
     *
     * Returning all of them (rather than stopping at the first that decodes) is what lets automatic
     * selection fall through to an unseen Survey or NPS when the Flow was already shown on this
     * screen.
     */
    private func experienceCandidates(_ response: String) -> [ExperienceContent] {
        var candidates: [ExperienceContent] = []
        if let flowContent = response.toFlowContent()?.flowContent {
            candidates.append(.flow(content: flowContent))
        }
        if let surveyContent = response.toSurveyContent()?.surveyContent {
            candidates.append(.survey(content: surveyContent))
        }
        if let npsContent = response.toNPSContent()?.npsContent {
            candidates.append(.nps(content: npsContent))
        }
        return candidates
    }

    /// `fetchExperienceContent` is a manual API response and bypasses seen-screen filtering; screen
    /// events are automatic and must select an unseen candidate.
    private func triggerTypeForEvent(_ eventName: String) -> TriggerType {
        eventName == SDKEventsName.fetchExperienceContent.rawValue ? .manual : .automatic
    }

    /**
     * Whether this experience is already active, queued, or cached.
     *
     * Distinct from a seen check: seen content was already displayed on this screen, whereas a
     * duplicate is the same content arriving twice before it has been shown.
     */
    private func isDuplicateExperience(_ experience: ExperienceContent) -> Bool {
        if sameExperience(experienceStateMachine.getActiveContent(), experience) {
            return true
        }
        if pendingExperiences.contains(where: { sameExperience($0.experienceContent, experience) }) {
            return true
        }
        return sameExperience(experienceStateMachine.getCachedExperienceContent(), experience)
    }

    /// Identity comparison per type — a Flow and a Survey sharing a numeric id are not the same
    /// experience, and NPS is identified by its survey key rather than an id.
    private func sameExperience(
        _ first: ExperienceContent?,
        _ second: ExperienceContent
    ) -> Bool {
        switch (first, second) {
        case (.flow(let firstContent), .flow(let secondContent)):
            return firstContent.id == secondContent.id
        case (.survey(let firstContent), .survey(let secondContent)):
            return firstContent.id == secondContent.id
        case (.nps(let firstContent), .nps(let secondContent)):
            return firstContent.content.survey.key == secondContent.content.survey.key
        default:
            return false
        }
    }

    /// The only way out of preview mode.
    ///
    /// Preview mode is a latch: resets, screen flushes and lifecycle callbacks all leave it alone,
    /// so a preview cannot be cleared by anything but the flow that started it. That makes every
    /// exit this SDK has the responsibility of this one function — a preview flow that fails to
    /// reach it leaves the SDK previewing forever, showing no content to anyone.
    ///
    /// Reached on: a failed fetch, a response with no usable content, and the user dismissing a
    /// rendered preview. `logout` is the sole deliberate exception, since a preview must not
    /// outlive the user who scanned it.
    private func exitPreviewMode() {
        if experienceStateMachine.getActiveComponent() == nil { experienceStateMachine.markIdle() }
    }

    private func processCachedExperience() {
        experienceQueue.async { [weak self] in
            guard let self,
                  case .idle = self.experienceStateMachine.getCurrentState(),
                  !self.experienceStateMachine.isPreviewMode(),
                  self.pendingExperiences.isEmpty else { return }

            switch self.experienceStateMachine.processCachedExperience() {
            case .processAutomatic(let experience):
                // Cached content may have been shown while waiting for the previous renderer.
                guard !self.analyticsPublisher.isExperienceSeen(experience) else {
                    self.logger.info(
                        "Ignoring cached experience already seen: %@",
                        experience.experienceId().toString()
                    )
                    return
                }
                let pendingExperience = PendingExperience(experienceContent: experience, triggerType: .automatic)
                self.pendingExperiences.append(pendingExperience)
                self.experienceStateMachine.markAutomaticTrigger(experience)
                if experience.asNPSContent() != nil {
                    self.openNPSBottomSheetExperience(pendingExperience)
                } else {
                    self.checkCachedThemes(experience.experienceThemeId())
                }

            case .triggerManual(let experienceId):
                self.triggerExperienceIfIdle(experienceId)

            case .none:
                break
            }
        }
    }
}

// MARK: - Preview Experience

extension ExperiencesPublisher {

    func triggerPreviewExperience(_ experienceId: String, _ queryItems: [URLQueryItem]) {
        // One fetch at a time. `pendingPreview` *is* "scanned but not yet on screen": once the
        // content renders the state moves to waitingDelay/active(.preview) and a new scan is free
        // to replace it. A scan arriving before then is dropped.
        if case .pendingPreview = experienceStateMachine.getCurrentState() {
            logger.info("Preview dropped - another preview is still loading")
            return
        }
        // Entered here, not in the continuation below: while a renderer is still closing there
        // would otherwise be no preview state for anything to see.
        experienceStateMachine.markPreviewMode()
        resetState { [weak self] in
            guard let self else { return }
            // Re-asserted: the dismissal that released the continuation marks the flow idle.
            self.experienceStateMachine.markPreviewMode()
            self.userpilotRemoteSource.fetchPreviewExperience(
                params: PreviewExperienceQueryParams(
                        baseUrl: Environment.getExperienceContentUrl(),
                    appToken: self.config.token,
                    contentType: queryItems.first(where: { $0.name == "type" })?.value ?? "",
                    contentId: experienceId
                ),
                completion: { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success(let previewExperience):
                        self.processPreviewExperience(previewExperience)
                    case .failure(let error):
                        self.showExperienceTriggeringDebugMessage(error.localizedDescription)
                    }
                }
            )
        }
    }

    private func processPreviewExperience(_ previewExperience: PreviewExperience) {
        tryCatch {
            guard let theme = previewExperience.theme,
                  previewExperience.flow != nil || previewExperience.survey != nil
            else {
                exitPreviewMode()
                return
            }

            let experience: ExperienceContent?
            if let flow = previewExperience.flow {
                experience = .flow(content: flow)
            } else if let survey = previewExperience.survey {
                experience = .survey(content: survey)
            } else {
                experience = nil
            }

            guard let experience else {
                exitPreviewMode()
                return
            }

            experienceQueue.async { [weak self] in
                    guard let self else { return }
                self.pendingExperiences.append(
                    PendingExperience(experienceContent: experience, triggerType: .preview)
                )
                self.themeHandler.saveTheme(theme)
                self.openExperienceFlow()
            }
        }
    }

    private func showExperienceTriggeringDebugMessage(_ message: String) {
        exitPreviewMode()
        performOn(.main) { [weak self] in
            guard
                let self,
                let host = self.experiencePresentationHost()
            else { return }

            let alert = UIAlertController(
                title: "Preview Experience",
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))

            if let popover = alert.popoverPresentationController {
                popover.sourceView = host.view
                popover.sourceRect = CGRect(
                    x: host.view.bounds.midX,
                    y: host.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }

            host.present(alert, animated: true, completion: nil)
        }
    }
}

#if DEBUG
extension ExperiencesPublisher {
    /// Set before delivering events so tests can control when the display delay finishes.
    func mockSetDelayUtils(_ delayUtils: DelayUtils) {
        self.delayUtils = delayUtils
    }

    func mockSetCurrentScreen(title: String) {
        currentScreen = title
    }

    func mockGetCurrentScreen() -> String {
        return currentScreen
    }

    func mockSetNPSShownOnCurrentScreen(_ shown: Bool) {
        npsShownOnCurrentScreen.value = shown
    }

    func mockActiveExperience(experience: UIViewController) {
        guard let upExperience = experience as? UPExperience else { return }
        experienceStateMachine.setActiveComponent(upExperience)
    }
}
#endif

// swiftlint:enable file_length
