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
    func updateScreen(_ screenName: String)

    /// Manually end experience
    func endExperience(isInternalEvent: Bool, component: UPExperience?)

    /// Determine if can requst screen event
    func canRequestScreenEvent() -> Bool

    /// Try to handle the deep link internally
    func triggerDeepLink(url: URL)

    /// logout event and reset state
    func resetState()

    var getCurrentScreen: String { get }

    /// Show thank you message
    func showThankYouMessage(
        _ surveyContent: SurveyContent,
        _ surveyTheme: SurveyTheme,
        _ submissionId: Int64
    )
}

/// ExperiencesPublisher manages the lifecycle and display of user experiences (flows, surveys, NPS).
///
/// This class is responsible for:
/// - Receiving and processing experience content from socket events
/// - Managing experience queuing and display timing
/// - Handling theme caching and fetching
/// - Coordinating with analytics for proper event tracking
/// - Managing experience state and lifecycle
/// - Handling deep links and navigation
///
/// The publisher ensures experiences are shown at appropriate times by validating screen context,
/// managing delays, and handling concurrent experience scenarios.
internal class ExperiencesPublisher: ExperiencesPublishing {
    // MARK: - Properties

    /// The dependency injection container used for resolving services and configurations.
    private weak var container: DIContainer?

    /// Reference to the `Userpilot` instance that owns this manager.
    private weak var userpilot: Userpilot?

    /// Manages socket connections and listens for socket events.
    private let socketManager: SocketManaging

    /// Analytics publisher to manage events triggering.
    private let analyticsPublisher: AnalyticsPublishing

    /// Analytics publisher to manage events triggering.
    private let userpilotRemoteSource: UserpilotRemoteSourcing

    /// Handles themes for the experiences, managing theme data and styles.
    private let themeHandler: ThemeHandling

    /// Handles local data storage operations.
    private let storage: DataStoring

    /// The configuration settings for the `Userpilot` SDK.
    private let config: Userpilot.Config

    /// Logger used for internal logging of operations and errors.
    private let linkOpener: LinkOpening

    /// The Expereince state manager.
    private let experienceStateManager: ExperienceStateManaging

    /// Logger used for internal logging of operations and errors.
    private let logger: Logging

    /// ---- Logic Variables ---- ///

    /// The current screen title being tracked
    private lazy var currentScreen: String = ""

    /// The current screen title being tracked
    private lazy var npsTrackedScreen: String = ""

    /// Queue to track pending experience content waiting to be displayed
    private var pendingExperiences: [ExperienceContent] = []

    /// Utility for managing display delays for surveys and NPS experiences
    private lazy var delayUtils = DelayUtils()

    /// Thread-safe lock for managing experience content operations
    private let experienceQueue = DispatchQueue(
        label: Constants.DispatchQueues.experience,
        qos: .userInteractive
    )

    /// Date when a fake screen reload event was last requested
    private var requestFakeScreenReloadEventDate: Date?

    /// Helper method to get top view controller
    var topViewControllerProvider: () -> UIViewController? = {
        let topControllerGetting: TopControllerGetting = UIApplication.shared
        return topControllerGetting.topViewController()
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
        self.linkOpener = container.resolve(LinkOpening.self)
        self.experienceStateManager = container.resolve(ExperienceStateManaging.self)
        self.logger = container.resolve(Userpilot.Config.self).logger

        socketManager.registerCallback(self)
    }

    // MARK: - SDK API Methods

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
            && !experienceStateManager.isActive()
    }

    /**
     * Triggers an experience manually by its ID.
     * Only allows triggering if no other experiences are currently pending or active.
     *
     * In case there is active experience available, cache experienceId to trigger it
     * when dismiss current active experience
     *
     * - Parameter experienceId: The ID of the experience to be triggered
     */
    func triggerExperience(_ experienceId: String) {
        experienceQueue.async { [weak self] in
            guard let self else { return }
            if experienceStateManager.isActive() || experienceStateManager.hasCachedExperience() {
                self.experienceStateManager.markCachedManual(experienceId)
                self.logger.info("‼️ Experience cached - active experience in progress")
            } else {
                self.delayUtils.cancelDelay()
                self.experienceStateManager.markManualTrigger(experienceId)
                self.publishInternalSDKEvent(ExperienceContentEvent(experienceId: experienceId))
            }
        }
    }

    /**
     * Ends all active experience views.
     *
     * - Parameter isInternalEvent: true if the user manually closed the experience, false for automatic closure
     * - Parameter component: Optional component to close. If nil, will retrieve from state manager
     */
    func endExperience(isInternalEvent: Bool, component: UPExperience? = nil) {
        endExperience(isInternalEvent: isInternalEvent, component: component, completion: nil)
    }

    /**
     * Ends all active experience views with a completion callback.
     *
     * - Parameter isInternalEvent: true if the user manually closed the experience, false for automatic closure
     * - Parameter component: Optional component to close. If nil, will retrieve from state manager
     * - Parameter completion: Optional callback executed after experience is closed and state is reset
     */
    private func endExperience(
        isInternalEvent: Bool, component: UPExperience? = nil, completion: (() -> Void)?
    ) {
        performOn(.main) { [weak self] in
            guard let self else {
                completion?()
                return
            }
            let experience = component ?? self.experienceStateManager.getActiveComponent()
            if let experience {
                experience.triggerCloseExperience(isInternalEvent: isInternalEvent)
            }
            self.resetProcessingPreviewExperienceStatus()
            completion?()
        }
    }

    /// Logic to check if the socket is currently open
    var getCurrentScreen: String {
        currentScreen
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
        guard !pendingExperiences.isEmpty else {
            resetState()
            return nil
        }
        let content = pendingExperiences.first
        clearPendingExperiences()
        return content
    }

    /// On preview mode - scan QR code or deeplink preview mode don't send evaluation events for
    /// experience contents.
    ///
    /// Resets the `previewExperienceId` once we are sure the content is being displayed.
    func isPreviewExperienceMode() -> Bool {
        return experienceStateManager.isPreviewMode()
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

    /*
     * Sends a socket request based on the provided SDK event.
     * Handles experience tracking, content caching, and fake reload triggering.
     *
     * - Parameter sdkEvent: The SDK event containing the event name and payload
     */
    // swiftlint:disable:next cyclomatic_complexity
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent) {
        tryCatch {
            // if case .pendingPreview = experienceStateManager.getCurrentState() { return }
            if isPreviewExperienceMode() {
                if sdkEvent.isEventForCloseExperience() || sdkEvent.isEventForCloseNPSExperience() {
                    resetProcessingPreviewExperienceStatus()
                    if socketManager.isSocketOpened { requestFakeScreenReloadEventDate = Date() }
                    analyticsPublisher.publishFakeReloadScreenEvent(nil, nil, isFakeReload: true)
                }
                return
            }

            // Process the event through analytics publisher
            analyticsPublisher.publishInternalSDKEvent(sdkEvent)

            // Update seen content for ScreenViewEntity tracking
            if sdkEvent.isSeenContentEvent(), let contentId = sdkEvent.getContentId() {
                analyticsPublisher.experiencePublished(sdkEvent.getContentType(), contentId)
            }

            // On close content events, remove all cached experiences
            // Cache date is used because if app goes to background and returns,
            // closing the experience directly won't trigger screen content
            if sdkEvent.isEventForCloseExperience() || sdkEvent.isEventForCloseNPSExperience() {
                resetProcessingPreviewExperienceStatus()
                if socketManager.isSocketOpened { requestFakeScreenReloadEventDate = Date() }
            }

            // Don't trigger fake reload for NPS experiences or experiences with deep links
            // NPS is the last content, and deep links will open new screen
            if sdkEvent.isEventForCloseNPSExperience() || sdkEvent.hasDeepLink {
                return
            }

            // Trigger fake reload when closing experience that wasn't manually triggered
            if sdkEvent.isEventForCloseExperience() && !experienceStateManager.hasCachedExperience() {
                analyticsPublisher.publishFakeReloadScreenEvent(
                    sdkEvent.getContentType(), sdkEvent.getContentId(), isFakeReload: true
                )
            } else {
                // Process cached experiences
                let state = experienceStateManager.getCurrentState()
                switch state {
                case .cachedPendingAutomatic(let experience):
                    pendingExperiences.append(experience)
                    experienceStateManager.markManualTrigger(experience.experienceId().toString())
                    checkCachedThemes(experience.experienceThemeId())
                case .cachedPendingManual(let experienceId):
                    triggerExperience(experienceId)
                default:
                    break
                }
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
    // swiftlint:disable:next cyclomatic_complexity superfluous_disable_command
    func onSocketEventSent(
        _ eventName: String, _ payload: Payload, _ message: Message, _ eventSent: Bool
    ) {
        experienceQueue.async { [weak self] in
            guard let self,
                !experienceStateManager.isActive(),
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

            // Process content from screen events and fetch experience content events
            if eventName == Constants.Event.screenEvent
                || eventName == SDKEventsName.fetchExperienceContent.rawValue {
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
                    if eventName == SDKEventsName.fetchExperienceContent.rawValue {
                        self.experienceStateManager.markManualTrigger(
                            experience.experienceId().toString())
                    } else {
                        self.experienceStateManager.markAutomaticTrigger(experience)
                    }
                    self.pendingExperiences.append(experience)
                }
            }

            // Process the first pending experience
            if let experience = self.pendingExperiences.first {
                if experience.asNPSContent() != nil {
                    self.openNPSBottomSheetExperience(experience)
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
                    !experienceStateManager.isActive(),
                    !experienceStateManager.isPreviewMode(),
                    self.pendingExperiences.isEmpty,
                    payload.keys.contains("request_id"),
                    payload["request_id"] as? Int == nil
                else { return }

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
                    if experienceStateManager.isActive() {
                        experienceStateManager.markCachedAutomatic(experience)
                        logger.info("‼️ There is a currently active experience being processed")
                    } else {
                        self.delayUtils.cancelDelay()
                        self.experienceStateManager.markManualTrigger(
                            experience.experienceId().toString())
                        self.pendingExperiences.append(experience)
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
            resetProcessingPreviewExperienceStatus()
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
                    self.openCarouselExperience(experienceContent)
                case .slideout:
                    if self.isBottomSheetContent(content) {
                        self.openSlideOutBottomSheetExperience(experienceContent)
                    } else {
                        self.openSlideOutDialogExperience(experienceContent)
                    }
                }

            case .survey(let content):
                switch content.type {
                case .list:
                    self.openSurveyListExperience(experienceContent)
                case .step:
                    if self.isBottomSheetSurveyContent(content) {
                        self.openSurveyBottomSheetExperience(experienceContent)
                    } else {
                        self.openSurveyDialogExperience(experienceContent)
                    }
                }

            case .nps:
                openNPSBottomSheetExperience(experienceContent)
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
            return themeHandler.getThemeById(mobileContent.mobileTheme.id)?.isDialogExperience
                == false
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
        if let themeData = surveyContent.surveyTheme.themeData,
            let position = themeData.general?.position {
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
    private func openCarouselExperience(_ experienceContent: ExperienceContent) {
        showExperience(
            experienceContent,
            makeViewModel: ExperienceViewModel.init,
            makeViewController: CarouselExperienceViewController.init,
            presentation: .fullScreen
        )
    }

    /** Opens a slide-out experience as a dialog fragment */
    private func openSlideOutDialogExperience(_ experienceContent: ExperienceContent) {
        showExperience(
            experienceContent,
            makeViewModel: ExperienceViewModel.init,
            makeViewController: SlideOutDialogViewController.init,
            presentation: .dialog
        )
    }

    /** Opens a slide-out experience as a bottom sheet fragment */
    private func openSlideOutBottomSheetExperience(_ experienceContent: ExperienceContent) {
        showExperience(
            experienceContent,
            makeViewModel: ExperienceViewModel.init,
            makeViewController: SlideOutBottomSheetViewController.init,
            presentation: .bottomSheet
        )
    }

    /** Opens a survey experience in a full-screen activity with list view */
    private func openSurveyListExperience(_ experienceContent: ExperienceContent) {
        showExperience(
            experienceContent,
            makeViewModel: SurveyViewModel.init,
            makeViewController: SurveyListViewController.init,
            presentation: .fullScreen
        )
    }

    /** Opens a survey experience as a dialog fragment */
    private func openSurveyDialogExperience(_ experienceContent: ExperienceContent) {
        showExperience(
            experienceContent,
            makeViewModel: SurveyViewModel.init,
            makeViewController: SurveyDialogViewController.init,
            presentation: .dialog
        )
    }

    /** Opens a survey experience as a bottom sheet fragment */
    private func openSurveyBottomSheetExperience(_ experienceContent: ExperienceContent) {
        showExperience(
            experienceContent,
            makeViewModel: SurveyViewModel.init,
            makeViewController: SurveyBottomSheetViewController.init,
            presentation: .bottomSheet
        )
    }

    /** Opens an NPS experience as a bottom sheet fragment */
    private func openNPSBottomSheetExperience(_ experienceContent: ExperienceContent) {
        if currentScreen == npsTrackedScreen {
            resetProcessingPreviewExperienceStatus()
            return
        }
        showExperience(
            experienceContent,
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
        delayUtils.delayAction { [weak self] in
            guard let self else {
                self?.resetProcessingPreviewExperienceStatus()
                return
            }

            performOn(.main) { [weak self] in
                guard
                    let self,
                    let topViewController = self.topViewControllerProvider()
                else {
                    self?.processNextPendingExperiences()
                    return
                }

                let thankYouVC = ThankYouBottomSheetViewController(
                    surveyContent: surveyContent,
                    surveyTheme: surveyTheme
                )

                thankYouVC.actionButtonClicked = { [weak self] deepLink in
                    self?.publishInternalSDKEvent(
                        ExperienceSurveyCompletedEvent(
                            surveyId: surveyContent.id,
                            submissionId: submissionId,
                            hasDeepLinkContent: deepLink != nil
                        )
                    )

                    if let deepLink, let url = URL(string: deepLink) {
                        self?.triggerDeepLink(url: url)
                    }

                    self?.resetProcessingPreviewExperienceStatus()
                }

                topViewController.presentBottomSheet(viewController: thankYouVC)
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

    /*
     * Validates content before showing it and applies the necessary delay.
     * Delay is needed because socket responses are too fast (~200ms) which causes
     * dropped frames and interrupts opening content animations.
     */
    // swiftlint:disable:next cyclomatic_complexity superfluous_disable_command function_body_length
    private func showExperience<VM, VC: UIViewController>(
        _ experienceContent: ExperienceContent,
        makeViewModel: @escaping (DIContainer) -> VM,
        makeViewController: @escaping (VM) -> VC,
        presentation: PresentationStyle
    ) {
        tryCatch {
            if !experienceStateManager.isPreviewMode() {
                let triggerType: TriggerType
                if experienceStateManager.isManualTrigger() {
                    triggerType = .manual
                } else if experienceStateManager.isPreviewMode() {
                    triggerType = .preview
                } else {
                    triggerType = .automatic
                }
                experienceStateManager.markWaitingDelay(triggerType)
            }

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
                    guard let topViewController = self.topViewControllerProvider() else {
                        self.processNextPendingExperiences()
                        return
                    }
                    let viewModel = makeViewModel(container)
                    let viewController = makeViewController(viewModel)
                    if presentation == .fullScreen {
                        viewController.modalPresentationStyle = .fullScreen
                        viewController.modalPresentationStyle = .overFullScreen  // or .overCurrentContext
                        // viewController.modalTransitionStyle = .crossDissolve // optional, for fade animation
                    }

                    if !self.experienceStateManager.isPreviewMode() {
                        // Mark as active and set component reference
                        self.experienceStateManager.markActiveFromCurrentState(
                            content: experienceContent)
                        if let upExperience = viewController as? UPExperience {
                            self.experienceStateManager.setActiveComponent(upExperience)
                        }
                    }

                    if viewController.isKind(of: NPSBottomSheetViewController.self) {
                        self.npsTrackedScreen = self.currentScreen
                    }
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

    /*
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
    // swiftlint:disable:next function_body_length superfluous_disable_command
    private func canShowExperience(_ experienceContent: ExperienceContent) -> Bool {
        // Check if there are pending experiences
        guard !pendingExperiences.isEmpty else {
            logger.info("🌠 Cannot show experience: pendingExperiences is empty")
            return false
        }

        // Block if there's an actively rendered experience (not including WaitingDelay which is just us)
        guard !experienceStateManager.isActivelyRendered() else {
            logger.info("🌠 Cannot show experience: there is an active experience already")
            return false
        }

        // Bypass screen validation for manual triggers or preview mode
        if experienceStateManager.shouldBypassScreenValidation() {
            logger.info("🌠 Can show experience: bypassing screen validation (manual/preview)")
            return true
        }

        // Start session
        if analyticsPublisher.isStartSession {
            logger.info("🌠 Can show experience: startSession is true")
            return true
        }

        // Screen validation for automatic experiences
        let mobileContent = experienceContent.asFlowContent()
        let surveyContent = experienceContent.asSurveyContent()
        let npsContent = experienceContent.asNPSContent()

        let isMobileContentValid =
            mobileContent.map { $0.isForAllScreens || $0.screens.contains(currentScreen) } ?? false
        let isSurveyContentValid =
            surveyContent.map { $0.isForAllScreens || $0.screens.contains(currentScreen) } ?? false
        let isNPSContentValid =
            npsContent.map { $0.isForAllScreens || $0.screens.contains(currentScreen) } ?? false
        let isValidScreen = isMobileContentValid || isSurveyContentValid || isNPSContentValid

        logger.info(
            """
            🌠 Screen validation result →
            Flow=%{public}@,
            Survey=%{public}@,
            NPS=%{public}@,
            is valid=%{public}@,
            for current screen='%{public}@'
            """,
            "\(isMobileContentValid)",
            "\(isSurveyContentValid)",
            "\(isNPSContentValid)",
            "\(isValidScreen)",
            currentScreen
        )

        return isValidScreen
    }

    /**
     * Resets the publisher state, cancelling pending content and experiences.
     * Called when logging out, updating screen, activity changes, or when content
     * becomes invalid from view models.
     */
    func resetState() {
        resetState(completion: nil)
    }

    /**
     * Resets the publisher state with a completion callback.
     * Ensures proper ordering when state changes need to happen after reset completes.
     *
     * - Parameter completion: Optional callback executed after reset operations complete
     */
    private func resetState(completion: (() -> Void)?) {
        tryCatch {
            // Cancel delays and clear pending experiences first (synchronous operations)
            delayUtils.cancelDelay()
            clearPendingExperiences()
            npsTrackedScreen = ""

            // End experience with completion to ensure proper ordering
            // The completion will be called on main thread after endExperience finishes
            endExperience(
                isInternalEvent: true,
                component: experienceStateManager.getActiveComponent(),
                completion: { [weak self] in
                    // After endExperience completes (which calls markIdle), execute the callback
                    completion?()
                }
            )
        }
    }

    /**
     * Moves to the next pending experience in the queue.
     * Retains only the last experience and processes it.
     */
    private func processNextPendingExperiences() {
        tryCatch {
            resetProcessingPreviewExperienceStatus()
            if pendingExperiences.isEmpty { return }
            experienceQueue.async { [weak self] in
                guard let self else { return }
                if pendingExperiences.count == 1 {
                    pendingExperiences.removeAll()
                } else {
                    if let lastContent = self.pendingExperiences.last,
                        self.pendingExperiences.count > 1 {
                        self.pendingExperiences = [lastContent]
                        self.openExperienceFlow()
                    }
                }
            }
        }
    }

    /** Removes all cached/pending experiences from the queue */
    private func clearPendingExperiences() {
        if pendingExperiences.isEmpty { return }
        experienceQueue.async { [weak self] in
            self?.pendingExperiences.removeAll()
        }
    }

}

extension ExperiencesPublisher {

    func triggerPreviewExperience(_ experienceId: String, _ queryItems: [URLQueryItem]) {
        // Reset state first, then mark preview mode after reset completes
        resetState { [weak self] in
            guard let self else { return }
            self.experienceStateManager.markPreviewMode()
            self.userpilotRemoteSource.fetchPreviewExperience(
                params: PreviewExperienceQueryParams(
                    baseUrl: Constants.RemoteSource.experienceBaseURL,
                    appToken: self.config.token,
                    contentType: queryItems.first(where: { $0.name == "type" })?.value ?? "",
                    contentId: experienceId),
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

    func processPreviewExperience(_ previewExperience: PreviewExperience) {
        tryCatch {
            // If neither theme nor experience content is available, exit preview mode
            guard let theme = previewExperience.theme,
                previewExperience.flow != nil || previewExperience.survey != nil
            else {
                resetProcessingPreviewExperienceStatus()
                return
            }

            // Determine which type of experience to create
            let experience: ExperienceContent?
            if let flow = previewExperience.flow {
                experience = .flow(content: flow)
            } else if let survey = previewExperience.survey {
                experience = .survey(content: survey)
            } else {
                experience = nil
            }

            // Add the experience to the pending queue if available
            if let experience {
                pendingExperiences.append(experience)
                themeHandler.saveTheme(theme)
                openExperienceFlow()
            } else {
                resetProcessingPreviewExperienceStatus()
            }
        }
    }

    private func showExperienceTriggeringDebugMessage(_ message: String) {
        resetProcessingPreviewExperienceStatus()
        performOn(.main) { [weak self] in
            guard
                let self,
                let topViewController = self.topViewControllerProvider()
            else { return }

            let alert = UIAlertController(
                title: "Preview Experience",
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))

            // iPad-specific: prevent crash if alert is presented as popover
            if let popover = alert.popoverPresentationController {
                popover.sourceView = topViewController.view
                popover.sourceRect = CGRect(
                    x: topViewController.view.bounds.midX,
                    y: topViewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }

            topViewController.present(alert, animated: true, completion: nil)
        }
    }

    private func resetProcessingPreviewExperienceStatus() {
        experienceStateManager.markIdle()
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
    }
#endif

// swiftlint:enable file_length
