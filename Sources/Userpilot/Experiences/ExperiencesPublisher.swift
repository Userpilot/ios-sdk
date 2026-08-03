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
    func isPreviewExperienceMode() -> Bool

    /// Get current experience
    func getActiveMobileContent() -> ExperienceContent?

    /// Send experience event to backend
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent)

    /// Manually trigger experience
    func triggerExperience(_ experienceId: String)

    /// Preview experience
    func triggerPreviewExperience(_ experienceId: String, _ queryItems: [URLQueryItem])

    /// Manually trigger experience
    func updateSceen(_ screenName: String)

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

    // MARK: - Properties

    /// The dependency injection container used for resolving services and configurations.
    private weak var container: DIContainer?

    /// Reference to the `Userpilot` instance that owns this manager.
    private weak var userpilot: Userpilot?

    /// Manages socket connections and listens for socket events.
    private let socketManager: SocketEvents

    /// Analytics publisher to manage events triggering.
    private let analyticsPublisher: AnalyticsPublishing

    /// Remote source used for fetching preview experience content.
    private let userpilotRemoteSource: UserpilotRemoteSourcing

    /// Handles themes for the experiences, managing theme data and styles.
    private let themeHandler: ThemeHandling

    /// Handles local data storage operations.
    private let storage: DataStoring

    /// The configuration settings for the `Userpilot` SDK.
    private let config: Userpilot.Config

    /// Logger used for internal logging of operations and errors.
    private let linkOpener: LinkOpening

    /// Manages experience flow state transitions.
    private let experienceStateManager: ExperienceStateManaging

    /// Logger used for internal logging of operations and errors.
    private let logger: Logging

    /// ---- Logic Variables ---- ///

    /// The current screen title being tracked
    private lazy var currentScreen: String = ""

    /// The last screen on which NPS was shown, preventing repeated NPS on same screen.
    private lazy var npsTrackedScreen: String = ""

    /// Queue to track pending experience content waiting to be displayed.
    private var pendingExperiences: [PendingExperience] = []

    /// Utility for managing display delays for surveys and NPS experiences
    private lazy var delayUtils = DelayUtils()

    /// Thread-safe lock for managing experience content operations
    private let experienceQueue = DispatchQueue(
        label: DispatchQueueConstants.EXPERIENCE_QUEUE,
        qos: .userInteractive
    )

    /// Date when a fake screen reload event was last requested
    private var requestFakeScreenReloadEventDate: Date?

    /// Track last active experience
    private weak var activeExperience: UIViewController?

    /// Guards preview request identity across lifecycle and network callbacks.
    private let previewSessionTracker = PreviewSessionTracker()

    /// Content waiting to be shown together with immutable trigger provenance.
    private struct PendingExperience {
        let content: ExperienceContent
        let triggerType: TriggerType
    }

    /// Determines if there are currently active experiences being displayed
    private var hasActiveExperience: Bool {
        return activeExperience != nil || experienceStateManager.isActivelyRendered()
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
        self.socketManager = container.resolve(SocketEvents.self)
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.userpilotRemoteSource = container.resolve(UserpilotRemoteSourcing.self)
        self.themeHandler = container.resolve(ThemeHandling.self)
        self.logger = container.resolve(Userpilot.Config.self).logger
        self.linkOpener = container.resolve(LinkOpening.self)
        self.experienceStateManager = container.resolve(ExperienceStateManaging.self)

        socketManager.registerCallback(self)
    }

    // MARK: - SDK API Methods

    /**
     * Resets state and cancels pending content on user logout.
     * This prevents experiences from being shown to the wrong user.
     */
    func logout() {
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
            && !experienceStateManager.isActive()
            && !isPreviewExperienceMode()
            && !experienceStateManager.hasCachedExperience()
    }

    /**
     * Triggers an experience manually by its ID.
     * Only allows triggering if no other experiences are currently pending or active.
     *
     * - Parameter experienceId: The ID of the experience to be triggered
     */
    func triggerExperience(_ experienceId: String) {
        experienceQueue.async { [weak self] in
            guard let self else { return }
            if self.hasActiveExperience
                || self.experienceStateManager.isActive()
                || self.experienceStateManager.hasCachedExperience()
                || !self.pendingExperiences.isEmpty {
                self.experienceStateManager.markCachedManual(experienceId)
                self.logger.info("Experience cached - active experience in progress")
                return
            }

            self.delayUtils.cancelDelay()
            self.experienceStateManager.markManualTrigger(experienceId)
            self.publishInternalSDKEvent(ExperienceContentEvent(experienceId: experienceId))
        }
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
    internal func hideExperienceOverlayIfIdle() {
        userpilot?.experienceOverlayWindow.hideIfIdle()
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
            let activeViewController = self.activeExperience
            let activeComponent = self.experienceStateManager.getActiveComponent()
            self.activeExperience = nil

            guard let experience = (activeViewController as? UPExperience) ?? activeComponent else {
                if !self.experienceStateManager.hasCachedExperience() {
                    self.experienceStateManager.markIdle()
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
                if !self.experienceStateManager.hasCachedExperience() {
                    self.experienceStateManager.markIdle()
                }
                self.experienceDidFinishDismissing()
                completion?()
            }
        }
    }

    /// Cleans up the overlay after the actual UIKit dismissal completion fires.
    func experienceDidFinishDismissing() {
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
        triggerThankYouMessageView(surveyContent, surveyTheme, submissionId)
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
        let content = pendingExperiences.first?.content
        clearPendingExperiences()
        return content
    }

    /// Preview mode suppresses normal analytics while draft content is being rendered.
    func isPreviewExperienceMode() -> Bool {
        experienceStateManager.isPreviewMode() || previewSessionTracker.isActive()
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
            if isPreviewExperienceMode() {
                if sdkEvent.isEventForCloseExperience() || sdkEvent.isEventForCloseNPSExperience() {
                    activeExperience = nil
                    if socketManager.isSocketOpened {
                        requestFakeScreenReloadEventDate = Date()
                    }
                    analyticsPublisher.publishFakeReloadScreenEvent(
                        sdkEvent.getContentType(),
                        sdkEvent.getContentId(),
                        false
                    )
                    resetProcessingPreviewExperienceStatus()
                }
                return
            }

            // Process the event through analytics publisher
            analyticsPublisher.publishInternalSDKEvent(sdkEvent, socketSubscription: self)

            // Update seen content for ScreenViewEntity tracking
            if sdkEvent.isSeenContentEvent(), let contentId = sdkEvent.getContentId() {
                analyticsPublisher.experiencePublished(sdkEvent.getContentType(), contentId)
            }

            // On close content events, remove all cached experiences
            // Cache date is used because if app goes to background and returns,
            // closing the experience directly won't trigger screen content
            if sdkEvent.isEventForCloseExperience() || sdkEvent.isEventForCloseNPSExperience() {
                activeExperience = nil
                if socketManager.isSocketOpened {
                    requestFakeScreenReloadEventDate = Date()
                }
            }

            // Don't trigger fake reload for NPS experiences or experiences with deep links
            // NPS is the last content, and deep links will open new screen
            if sdkEvent.isEventForCloseNPSExperience() || sdkEvent.hasDeepLink {
                if !experienceStateManager.hasCachedExperience() {
                    experienceStateManager.markIdle()
                }
                return
            }

            // Trigger fake reload when closing experience that wasn't manually triggered
            if sdkEvent.isEventForCloseExperience() && !experienceStateManager.hasCachedExperience() {
                experienceStateManager.markIdle()
                analyticsPublisher.publishFakeReloadScreenEvent(
                    sdkEvent.getContentType(),
                    sdkEvent.getContentId(),
                    true
                )
            } else if sdkEvent.isEventForCloseExperience() {
                processCachedExperienceAfterClose()
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
    func updateSceen(_ screenName: String) {
        tryCatch {
            if currentScreen == screenName { return }
            currentScreen = screenName
            if isPreviewExperienceMode() {
                resumePendingPreviewExperience()
                return
            }
            resetState()
        }
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
    // swiftlint:disable:next cyclomatic_complexity, superfluous_disable_command
    func onSocketEventSent(
        _ eventName: String,
        _ payload: Payload,
        _ message: Message,
        _ eventSent: Bool
    ) {
        experienceQueue.async { [weak self] in
            guard let self,
                  !experienceStateManager.isPreviewMode(),
                  !message.payload.isEmpty,
                  let response = message.payload.toJSONString()
            else {
                return
            }

            // Cache theme data if this is a fetch theme event
            if eventName == SDKEventsName.fetchExperienceTheme.rawValue,
               let themeData = response.toMobileTheme(), themeData.id != nil {
                self.themeHandler.saveTheme(themeData)
            }

            self.processExperienceContentResponse(eventName, response)

            // Process the first pending experience
            if let pendingExperience = self.pendingExperiences.first {
                if pendingExperience.content.asNPSContent() != nil {
                    self.openNPSBottomSheetExperience(pendingExperience)
                } else {
                    self.checkCachedThemes(pendingExperience.content.experienceThemeId())
                }
            }
        }
    }

    /**
     * Selects and queues one eligible experience from a screen or manual-content response.
     *
     * Responses are parsed in priority order: Flow, Survey, then NPS. Automatic screen responses
     * select the first candidate that is not in the current screen entity's seen sets, allowing an
     * unseen Survey or NPS to fall back when a Flow was already shown. Manual fetch responses select
     * the first candidate without filtering by seen state.
     *
     * Preview responses and active/pending/cached duplicates are ignored. A distinct candidate is
     * cached when another experience is active; otherwise the appropriate trigger state is set and
     * the candidate is appended to `pendingExperiences`. Other socket event types and responses
     * without valid candidates are ignored.
     */
    private func processExperienceContentResponse(_ eventName: String, _ response: String) {
        guard eventName == EventType.screenEvent ||
                eventName == SDKEventsName.fetchExperienceContent.rawValue
        else { return }

        let triggerType = triggerTypeForEvent(eventName)
        let candidates = experienceCandidates(response)
        let experience: ExperienceContent?
        if triggerType == .automatic {
            experience = candidates.first { !analyticsPublisher.isExperienceSeen($0) }
        } else {
            experience = candidates.first
        }

        guard let experience, !experienceStateManager.isPreviewMode() else { return }
        if isDuplicateExperience(experience) {
            logger.info("Ignoring duplicate experience: %@", experience.experienceId().toString())
            return
        }
        if hasActiveExperience || experienceStateManager.isActive() {
            experienceStateManager.markCachedAutomatic(experience)
            logger.info("Experience cached - active experience in progress")
            return
        }

        if triggerType == .manual {
            experienceStateManager.markManualTrigger(experience.experienceId().toString())
        } else {
            experienceStateManager.markAutomaticTrigger(experience)
        }
        pendingExperiences.append(
            PendingExperience(content: experience, triggerType: triggerType)
        )
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
                      !experienceStateManager.isPreviewMode(),
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
                    if self.hasActiveExperience || self.experienceStateManager.isActive() {
                        self.experienceStateManager.markCachedAutomatic(experience)
                        self.logger.info("Active experience in progress, caching incoming experience")
                    } else {
                        self.delayUtils.cancelDelay()
                        self.experienceStateManager.markManualTrigger(
                            experience.experienceId().toString()
                        )
                        self.pendingExperiences.append(
                            PendingExperience(content: experience, triggerType: .manual)
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
            clearPendingExperiences()
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
            let experienceContent = pendingExperience.content
            switch experienceContent {
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

    /** Opens an NPS experience as a bottom sheet fragment */
    private func openNPSBottomSheetExperience(_ pendingExperience: PendingExperience) {
        if currentScreen == npsTrackedScreen {
            resetProcessingExperienceStatus()
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
    private func triggerThankYouMessageView(
        _ surveyContent: SurveyContent,
        _ surveyTheme: SurveyTheme,
        _ submissionId: Int64
    ) {
        experienceStateManager.markShowingThankYou()
        performOn(.main) { [weak self] in
            guard
                let self = self,
                let host = self.experiencePresentationHost()
            else {
                self?.resetProcessingExperienceStatus()
                self?.experienceDidFinishDismissing()
                return
            }
            delayUtils.delayAction { [weak self] in
                let thankYouBottomSheetViewController = ThankYouBottomSheetViewController(
                    surveyContent: surveyContent, surveyTheme: surveyTheme)
                thankYouBottomSheetViewController.glassResolver =
                    self?.container?.resolve(GlassCapabilityResolving.self)
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
                    self?.resetProcessingExperienceStatus()
                    self?.experienceDidFinishDismissing()
                }
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
            let experienceContent = pendingExperience.content
            experienceStateManager.markWaitingDelay(pendingExperience.triggerType)

            delayUtils.delayAction(delayTime: resolvedDelay(experienceContent)) { [weak self] in
                guard
                    let self,
                    self.canShowExperience(experienceContent),
                    let container = self.container
                else {
                    // Delay was cancelled through resetState, stop processing this experience
                    // If not valid to show the content, move to next one
                    self?.processNextPendingExperiences()
                    return
                }

                performOn(.main) {
                    guard let host = self.experiencePresentationHost() else {
                        self.processNextPendingExperiences()
                        return
                    }
                    let viewModel = makeViewModel(container)
                    let viewController = makeViewController(viewModel)
                    if presentation == .fullScreen {
                        viewController.modalPresentationStyle = .fullScreen
                    }
                    self.activeExperience = viewController
                    self.experienceStateManager.markActiveFromCurrentState(content: experienceContent)
                    if let upExperience = viewController as? UPExperience {
                        self.experienceStateManager.setActiveComponent(upExperience)
                    }
                    if viewController.isKind(of: NPSBottomSheetViewController.self) {
                        self.npsTrackedScreen = self.currentScreen
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
     * @param experienceContent The experience content to validate.
     * @return `true` if the experience can be shown, `false` otherwise.
     */
    private func canShowExperience(_ experienceContent: ExperienceContent) -> Bool {
        guard !pendingExperiences.isEmpty else {
            logger.info("Cannot show experience: pending experiences is empty")
            return false
        }

        guard !hasActiveExperience else {
            logger.info("Cannot show experience: there is an active experience already")
            return false
        }

        if experienceStateManager.shouldBypassScreenValidation() {
            logger.info("Can show experience: bypassing screen validation")
            return true
        }

        if analyticsPublisher.isStartSession {
            logger.info("Can show experience: start session is true")
            return true
        }

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
                if self.pendingExperiences.first?.triggerType == .preview,
                   self.previewSessionTracker.isActive() {
                    self.experienceStateManager.markPreviewMode()
                    return
                }
                self.resetProcessingExperienceStatus()
                if self.pendingExperiences.count == 1 {
                    self.pendingExperiences.removeAll()
                } else {
                    if let lastPending = self.pendingExperiences.last, self.pendingExperiences.count > 1 {
                        self.pendingExperiences = [lastPending]
                        self.experienceStateManager.markAutomaticTrigger(lastPending.content)
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
        previewSessionTracker.cancel()
        resetState(completion: nil)
    }

    private func resetState(completion: (() -> Void)?) {
        tryCatch {
            delayUtils.cancelDelay()
            clearPendingExperiences()
            npsTrackedScreen = ""

            if hasActiveExperience || experienceStateManager.getActiveComponent() != nil {
                endExperience(manualClose: false, completion: completion)
            } else {
                resetProcessingExperienceStatus()
                hideExperienceOverlayIfIdle()
                completion?()
            }
        }
    }

    private func resetProcessingExperienceStatus() {
        activeExperience = nil
        experienceStateManager.markIdle()
    }

    private func resetProcessingPreviewExperienceStatus(previewSessionId: UInt64? = nil) {
        if let previewSessionId {
            guard previewSessionTracker.finish(previewSessionId) else { return }
        } else {
            previewSessionTracker.cancel()
        }
        resetProcessingExperienceStatus()
    }

    /**
     * Processes the experience, if any, that was cached while another experience was active.
     *
     * An automatic cached experience is discarded if it became seen before replay; otherwise it is
     * queued and resumes automatic processing. A cached manual id is retriggered through the public
     * manual path. If the state contains neither cached case, processing returns to idle.
     */
    private func processCachedExperienceAfterClose() {
        let state = experienceStateManager.getCurrentState()
        switch state {
        case .cachedPendingAutomatic(let experience):
            activeExperience = nil
            if analyticsPublisher.isExperienceSeen(experience) {
                logger.info(
                    "Ignoring cached experience already seen: %@",
                    experience.experienceId().toString()
                )
                resetProcessingExperienceStatus()
                return
            }
            pendingExperiences.append(
                PendingExperience(content: experience, triggerType: .automatic)
            )
            experienceStateManager.markAutomaticTrigger(experience)
            checkCachedThemes(experience.experienceThemeId())

        case .cachedPendingManual(let experienceId):
            activeExperience = nil
            experienceStateManager.markIdle()
            triggerExperience(experienceId)

        default:
            resetProcessingExperienceStatus()
        }
    }

    /**
     * Parses every available response type in backend priority order: Flow, Survey, then NPS.
     *
     * Each decoder contributes only when its content exists and is valid. Returning all candidates,
     * instead of stopping at the first decoded type, lets automatic selection continue past a seen
     * higher-priority candidate.
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

    /**
     * Maps the response event to its trigger provenance.
     *
     * `fetchExperienceContent` is a manual API response and bypasses seen-screen filtering. Screen
     * and any other accepted response events are automatic and must select an unseen candidate.
     */
    private func triggerTypeForEvent(_ eventName: String) -> TriggerType {
        eventName == SDKEventsName.fetchExperienceContent.rawValue ? .manual : .automatic
    }

    /**
     * Returns whether the same content is already active, pending, or cached.
     *
     * This differs from a seen check: seen content was already displayed on the current screen,
     * while duplicate content is another copy currently moving through the rendering lifecycle.
     * Checking all three locations prevents repeated responses from replacing or requeuing work.
     */
    private func isDuplicateExperience(_ experience: ExperienceContent) -> Bool {
        if sameExperience(experienceStateManager.getActiveContent(), experience) {
            return true
        }
        if pendingExperiences.contains(where: { sameExperience($0.content, experience) }) {
            return true
        }
        return sameExperience(experienceStateManager.getCachedExperienceContent(), experience)
    }

    /**
     * Compares two experiences by type and that type's stable identifier.
     *
     * Flow and Survey compare numeric ids. NPS compares the survey key because its `experienceId()`
     * is currently zero for every NPS. Different content types and a nil first value never match.
     */
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
}

// MARK: - Preview Experience

extension ExperiencesPublisher {

    func triggerPreviewExperience(_ experienceId: String, _ queryItems: [URLQueryItem]) {
        let previewSessionId = previewSessionTracker.begin()
        resetState { [weak self] in
            guard let self, self.previewSessionTracker.isCurrent(previewSessionId) else { return }
            self.experienceStateManager.markPreviewMode()
            self.userpilotRemoteSource.fetchPreviewExperience(
                params: PreviewExperienceQueryParams(
                    baseUrl: RemoteSource.experienceBaseURL,
                    appToken: self.config.token,
                    contentType: queryItems.first(where: { $0.name == "type" })?.value ?? "",
                    contentId: experienceId
                ),
                completion: { [weak self] result in
                    guard let self, self.previewSessionTracker.isCurrent(previewSessionId) else { return }
                    switch result {
                    case .success(let previewExperience):
                        self.processPreviewExperience(
                            previewExperience,
                            previewSessionId: previewSessionId
                        )
                    case .failure(let error):
                        self.showExperienceTriggeringDebugMessage(
                            error.localizedDescription,
                            previewSessionId: previewSessionId
                        )
                    }
                }
            )
        }
    }

    private func processPreviewExperience(
        _ previewExperience: PreviewExperience,
        previewSessionId: UInt64
    ) {
        tryCatch {
            guard previewSessionTracker.isCurrent(previewSessionId) else { return }
            guard let theme = previewExperience.theme,
                  previewExperience.flow != nil || previewExperience.survey != nil
            else {
                resetProcessingPreviewExperienceStatus(previewSessionId: previewSessionId)
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
                resetProcessingPreviewExperienceStatus(previewSessionId: previewSessionId)
                return
            }

            experienceQueue.async { [weak self] in
                guard let self, self.previewSessionTracker.isCurrent(previewSessionId) else { return }
                self.pendingExperiences.append(
                    PendingExperience(content: experience, triggerType: .preview)
                )
                self.themeHandler.saveTheme(theme)
                self.openExperienceFlow()
            }
        }
    }

    private func showExperienceTriggeringDebugMessage(
        _ message: String,
        previewSessionId: UInt64
    ) {
        guard previewSessionTracker.isCurrent(previewSessionId) else { return }
        resetProcessingPreviewExperienceStatus(previewSessionId: previewSessionId)
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

    private func resumePendingPreviewExperience() {
        experienceQueue.async { [weak self] in
            guard
                let self,
                case .pendingPreview = self.experienceStateManager.getCurrentState(),
                self.pendingExperiences.first?.triggerType == .preview
            else { return }
            self.openExperienceFlow()
        }
    }
}

#if DEBUG
extension ExperiencesPublisher {
    func mockSetCurrentScreen(title: String) {
        currentScreen = title
    }

    func mockGetCurrentScreen() -> String {
        return currentScreen
    }

    func mockActiveExperience(experience: UIViewController) {
        self.activeExperience = experience
    }
}
#endif

// swiftlint:enable file_length
