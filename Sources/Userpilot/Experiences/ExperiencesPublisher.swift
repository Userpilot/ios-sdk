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

    /// Get current experience
    func getActiveMobileContent() -> ExperienceContent?

    /// Send experience event to backend
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent)

    /// Manually trigger experience
    func triggerExperience(_ experienceId: String)

    /// Manually trigger experience
    func updateSceen(_ screenName: String)

    /// Manually end experience
    func endExperience(manualClose: Bool)

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

    /// Handles themes for the experiences, managing theme data and styles.
    private let themeHandler: ThemeHandling

    /// Handles local data storage operations.
    private let storage: DataStoring

    /// The configuration settings for the `Userpilot` SDK.
    private let config: Userpilot.Config

    /// Logger used for internal logging of operations and errors.
    private let logger: Logging

    /// ---- Logic Variables ---- ///

    /// The current screen title being tracked
    private lazy var currentScreen: String = ""

    /// Flag indicating if a manual experience trigger is in progress
    private var isTriggerManualExperience = false

    /// Flag indicating if a thank you message is currently being triggered
    private var isTriggeringThankYouMessage = false

    /// Queue to track pending experience content waiting to be displayed
    private var pendingExperiences: [ExperienceContent] = []

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

    /// Determines if there are currently active experiences being displayed
    private var hasActiveExperience: Bool {
        return activeExperience != nil
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
        self.themeHandler = container.resolve(ThemeHandling.self)
        self.logger = container.resolve(Userpilot.Config.self).logger

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
        return requestFakeScreenReloadEventDate?.isMoreThanOneSecond(from: Date()) ?? true &&
        !hasActiveExperience &&
        !isTriggeringThankYouMessage
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
            if self.pendingExperiences.isEmpty {
                self.publishInternalSDKEvent(ExperienceContentEvent(experienceId: experienceId))
            } else {
                logger.info("‼️ There is a currently active experience being processed")
            }
        }
    }

    /// Helper method to get top view controller
    internal var topViewControllerProvider: () -> UIViewController? = {
        return UIApplication.shared.resolveTopViewController()
    }

    /**
     * Ends all active experience views.
     *
     * - Parameter manualClose: true if the user manually closed the experience, false for automatic closure
     */
    func endExperience(manualClose: Bool) {
        performOn(.main) { [weak self] in
            if let topVC = self?.activeExperience,
               let experience = topVC as? UPExperience {
                experience.triggerCloseExpereince(manualClose: manualClose)
            }
            self?.activeExperience = nil
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
        let content = pendingExperiences.first
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
            if let navigationDelegate = self?.userpilot?.navigationDelegate {
                navigationDelegate.navigate(to: url)
            } else {
                if url.isHttpOrHttps, UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
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
                return
            }

            // Trigger fake reload when closing experience that wasn't manually triggered
            if sdkEvent.isEventForCloseExperience() && !isTriggerManualExperience {
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
    func updateSceen(_ screenName: String) {
        tryCatch {
            currentScreen = screenName
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
                  // If there's an active experience, ignore new content
                  !hasActiveExperience,
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

            // Process content from screen events and fetch experience content events
            if eventName == EventType.screenEvent ||
                eventName == SDKEventsName.fetchExperienceContent.rawValue {

                // Determine the new experience based on response
                let experience: ExperienceContent? = {
                    if let flowContent = response.toFlowContent()?.flowContent {
                        return .flow(content: flowContent)
                    } else if let surveyContent = response.toSurveyContent()?.surveyContent {
                        return .survey(content: surveyContent)
                    } else if let npsContent = response.toNPSContent()?.npsContent {
                        return .nps(content: npsContent)
                    }
                    return nil
                }()

                if let experience {
                    self.isTriggerManualExperience = eventName == SDKEventsName.fetchExperienceContent.rawValue
                    self.pendingExperiences.append(experience)
                }
            }

            // Process the first pending experience
            if let experience = self.pendingExperiences.first {
                if experience.asNPSContent() != nil {
                    self.openNPSBottomSheetExperience()
                } else {
                    self.checkCachedThemes(experience.experienceThemeId())
                }
            }
        }
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
                      !hasActiveExperience,
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
                    self.pendingExperiences.append(experience)
                    self.isTriggerManualExperience = true
                    self.checkCachedThemes(experience.experienceThemeId())
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
        if let experienceContent = pendingExperiences.first {
            switch experienceContent {
            case .flow(let content):
                switch content.type {
                case .carousel:
                    self.openCarouselExperience()
                case .slideout:
                    if self.isBottomSheetContent(content) {
                        self.openSlideOutBottomSheetExperience()
                    } else {
                        self.openSlideOutDialogExperience()
                    }
                }

            case .survey(let content):
                switch content.type {
                case .list:
                    self.openSurveyListExperience()
                case .step:
                    if self.isBottomSheetSurveyContent(content) {
                        self.openSurveyBottomSheetExperience()
                    } else {
                        self.openSurveyDialogExperience()
                    }
                }

            case .nps:
                openNPSBottomSheetExperience()
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
    private func openCarouselExperience() {
        showExperience(
            makeViewModel: ExperienceViewModel.init,
            makeViewController: CarouselExperienceViewController.init,
            presentation: .fullScreen
        )
    }

    /** Opens a slide-out experience as a dialog fragment */
    private func openSlideOutDialogExperience() {
        showExperience(
            makeViewModel: ExperienceViewModel.init,
            makeViewController: SlideOutDialogViewController.init,
            presentation: .dialog
        )
    }

    /** Opens a slide-out experience as a bottom sheet fragment */
    private func openSlideOutBottomSheetExperience() {
        showExperience(
            makeViewModel: ExperienceViewModel.init,
            makeViewController: SlideOutBottomSheetViewController.init,
            presentation: .bottomSheet
        )
    }

    /** Opens a survey experience in a full-screen activity with list view */
    private func openSurveyListExperience() {
        showExperience(
            makeViewModel: SurveyViewModel.init,
            makeViewController: SurveyListViewController.init,
            presentation: .fullScreen
        )
    }

    /** Opens a survey experience as a dialog fragment */
    private func openSurveyDialogExperience() {
        showExperience(
            makeViewModel: SurveyViewModel.init,
            makeViewController: SurveyDialogViewController.init,
            presentation: .dialog
        )
    }

    /** Opens a survey experience as a bottom sheet fragment */
    private func openSurveyBottomSheetExperience() {
        showExperience(
            makeViewModel: SurveyViewModel.init,
            makeViewController: SurveyBottomSheetViewController.init,
            presentation: .bottomSheet
        )
    }

    /** Opens an NPS experience as a bottom sheet fragment */
    private func openNPSBottomSheetExperience() {
        showExperience(
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
        isTriggeringThankYouMessage = true
        performOn(.main) { [weak self] in
            guard
                let self = self,
                let topViewController = self.topViewControllerProvider()
            else {
                self?.isTriggeringThankYouMessage = false
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
                    self?.isTriggeringThankYouMessage = false
                }
                topViewController.presentBottomSheet(viewController: thankYouBottomSheetViewController)
            }
        }
    }

}

// MARK: - Experience Validation and Display Logic

internal extension ExperiencesPublisher {

    /**
     * Resolves the display delay for an experience.
     * Surveys and NPS have configurable delays, with a default fallback.
     *
     * - Returns: The delay duration in seconds
     */
    func resolvedDelay() -> TimeInterval {
        if let surveyDelay = pendingExperiences.first?.asSurveyContent()?.delayDuration, surveyDelay > 0 {
            return surveyDelay
        }
        if let npsDelay = pendingExperiences.first?.asNPSContent()?.delayDuration, npsDelay > 0 {
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
        makeViewModel: @escaping (DIContainer) -> VM,
        makeViewController: @escaping (VM) -> VC,
        presentation: PresentationStyle
    ) {
        tryCatch {
            delayUtils.delayAction(delayTime: resolvedDelay()) { [weak self] in
                guard
                    let self,
                    self.canShowExperience(),
                    let container = self.container
                else {
                    // Delay was cancelled through resetState, stop processing this experience
                    // If not valid to show the content, move to next one
                    self?.processNextPendingExperiences()
                    return
                }

                performOn(.main) {
                    guard let topViewController = self.topViewControllerProvider() else {
                        self.processNextPendingExperiences()
                        return
                    }
                    let viewModel = makeViewModel(container)
                    let viewController = makeViewController(viewModel)
                    if presentation == .fullScreen {
                        viewController.modalPresentationStyle = .fullScreen
                    }
                    self.activeExperience = viewController
                    switch presentation {
                    case .fullScreen, .normal:
                        topViewController.present(viewController, animated: true)
                    case .dialog:
                        topViewController.presentDialog(viewController: viewController)
                    case .bottomSheet:
                        topViewController.presentBottomSheet(viewController: viewController)
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
    private func canShowExperience() -> Bool {
        guard
            // No pending content to show (removed for some reason)
            let experienceContent = pendingExperiences.first,
            // Already have an active rendered experience
            !hasActiveExperience
        else { return false }

        let isForAllScreens: Bool
        let screens: [String]

        // Extract properties based on the enum case
        switch experienceContent {
        case .flow(let content):
            isForAllScreens = content.isForAllScreens
            screens = content.screens
        case .survey(let content):
            isForAllScreens = content.isForAllScreens
            screens = content.screens
        case .nps(let content):
            isForAllScreens = content.isForAllScreens
            screens = content.screens
        }

        return isTriggerManualExperience ||
        analyticsPublisher.isStartSession ||
        isForAllScreens ||
        screens.contains(currentScreen)
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
                if pendingExperiences.count == 1 {
                    pendingExperiences.removeAll()
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
        tryCatch {
            delayUtils.cancelDelay()
            clearPendingExperiences()
            isTriggeringThankYouMessage = false
        }
    }
}

#if DEBUG
internal extension ExperiencesPublisher {
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
