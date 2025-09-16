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
    func showThankYouMessage(_ surveyContent: SurveyContent, _ surveyTheme: SurveyTheme)
}

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

    /// The current screen name in the application, used to track active screens.
    private lazy var currentScreen: String = ""

    /// Queue for pending experience content - thread-safe array-based approach
    private var pendingExperiences: [ExperienceContent] = []

    /// Serial queue for managing experience operations to ensure thread safety
    private let experienceQueue = DispatchQueue(
        label: DispatchQueueConstants.EXPERIENCE_QUEUE,
        qos: .userInteractive
    )

    /// To manage delay for show experience or delay logic for survey & NPS.
    private lazy var delayUtils = DelayUtils()

    /// Manual experience not check screen.
    private var isTriggerManualExperience = false

    /// A flag to indicate triggering thank you message for survey list view.
    private var isTriggeringThankYouMessage = false

    /// Date for fake reload that has been requested.
    private var requestFakeScreenReloadEventDate: Date?

    /// Track last active experience
    private weak var activeExperience: UIViewController?
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
    // MARK: - Initializer

    /**
     Initializes the `ExperiencesPublisher` with the provided dependency container.

     - Parameter container: A `DIContainer` instance that provides dependencies.
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

    // MARK: - SDK APIs

    /// cancel pending experiences
    func logout() {
        tryCatch {
            delayUtils.cancelDelay()
            clearPendingExperiences()
        }
    }

    /// Determine if can requst screen event
    func canRequestScreenEvent() -> Bool {
        return requestFakeScreenReloadEventDate?.isMoreThanOneSecond(from: Date()) ?? true &&
        !hasActiveExperience &&
        !isTriggeringThankYouMessage
    }

    /**
     Starts the experience for a given experience ID. This method can be used to
     initiate a specific experience based on the provided ID.

     - Parameter experienceId: The Id of the experience to start.
     */
    func triggerExperience(_ experienceId: String) {
        experienceQueue.async { [weak self] in
            guard let self else { return }
            if self.pendingExperiences.isEmpty {
                self.publishInternalSDKEvent(ExperienceContentEvent(experienceId: experienceId))
            } else {
                logger.fault("‼️ There is current active experience has been processing")
            }
        }
    }

    /// Helper method to get top view controller
    internal var topViewControllerProvider: () -> UIViewController? = {
        return UIApplication.shared.resolveTopViewController()
    }

    /// End experience manually
    func endExperience(manualClose: Bool) {
        performOn(.main) { [weak self] in
            if let topVC = self?.activeExperience,
               let experience = topVC as? UPExperience {
                experience.triggerCloseExpereince(manualClose: manualClose)
            }
            self?.activeExperience = nil
        }
    }

    /*
     Show Thank you module
     */
    func showThankYouMessage(
        _ surveyContent: SurveyContent,
        _ surveyTheme: SurveyTheme
    ) {
        triggerThankYouMessageView(surveyContent, surveyTheme)
    }

    // MARK: - helper methods

    /// Return the current active carousel content.
    /// Returns the current active carousel content and clears it safely.
    func getActiveMobileContent() -> ExperienceContent? {
        guard !pendingExperiences.isEmpty else { return nil }
        let content = pendingExperiences.first
        clearPendingExperiences()
        return content
    }

    /// Try to handle the deep link internally
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
}

// MARK: - SocketSubscription

extension ExperiencesPublisher: SocketSubscription {

    // Update screen
    func updateSceen(_ screenName: String) {
        tryCatch {
            currentScreen = screenName
            delayUtils.cancelDelay()
            clearPendingExperiences()
            isTriggeringThankYouMessage = false
        }
    }

    /*
     Handles the socket event when a message is sent.
     
     - Parameters:
     - eventName: The name of the event sent over the socket.
     - payload: The message payload, if any, received.
     - message: The message object containing additional data.
     - eventSent: Indicates whether the event was successfully sent.
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
                  !hasActiveExperience,
                  !message.payload.isEmpty,
                  let response = message.payload.toJSONString()
            else {
                return
            }

            // Handle theme fetching separately
            if eventName == SDKEventsName.fetchExperienceTheme.rawValue,
               let themeData = response.toMobileTheme(), themeData.id != nil {
                self.themeHandler.saveTheme(themeData)
            }

            // Process experience content
            if eventName == EventType.screenEvent ||
                eventName == SDKEventsName.fetchExperienceContent.rawValue {

                self.isTriggerManualExperience = eventName == SDKEventsName.fetchExperienceContent.rawValue

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
                    self.pendingExperiences.append(experience)
                }
            }
            if let experience = self.pendingExperiences.first {
                if experience.asNPSContent() != nil {
                    self.openNPSBottomSheetExperience()
                } else {
                    self.checkCachedThemes(experience.experienceThemeId())
                }
            }
        }
    }

    /*
     Handles new messages received ove the socket, Processes the message to extract carousel and theme data.
     - Parameter message: The message object containing payload data.
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

                    if experience.asNPSContent() != nil {
                        self.openNPSBottomSheetExperience()
                    } else {
                        self.checkCachedThemes(experience.experienceThemeId())
                    }
                }
            }
        }
    }

}

// MARK: - Theme

extension ExperiencesPublisher {

    /**
     Checks for cached themes to determine if the theme is available locally.

     - Parameter themeId: A theme Id to check against the cached themes.
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
     Fetches theme data for themes that are not cached.

     - Parameter themeId: A theme Id for which data needs to be fetched.
     */
    private func fetchThemeData(_ themeId: Int) {
        guard analyticsPublisher.canRequestEvent else {
            clearPendingExperiences()
            return
        }

        publishInternalSDKEvent(ThemeContentEvent(themeId: themeId, token: config.token))
    }

}

// MARK: - Launch experiences

extension ExperiencesPublisher {

    /**
     Sends a socket request based on the provided event interface.
     
     - Parameter sdkEvent: The event interface containing the event name and payload to be sent.
     */
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent) {
        tryCatch {
            analyticsPublisher.publishInternalSDKEvent(sdkEvent, socketSubscription: self)

            if sdkEvent.isSeenContentEvent() || sdkEvent.hasDeepLink, let contentId = sdkEvent.getContentId() {
               analyticsPublisher.experiencePublished(sdkEvent.getContentType(), contentId)
            }

            if sdkEvent.isEventForCloseExperience() || sdkEvent.hasDeepLink {
                activeExperience = nil
                requestFakeScreenReloadEventDate = Date()
            }

            if sdkEvent.isEventForCloseNPSExperience() || sdkEvent.hasDeepLink {
                activeExperience = nil
                requestFakeScreenReloadEventDate = Date()
                return
            }

            if sdkEvent.isEventForCloseExperience() && !isTriggerManualExperience {
                analyticsPublisher.publishFakeReloadScreenEvent(
                    sdkEvent.getContentType(), sdkEvent.getContentId()
                )
            }
        }
    }

    /**
     Opens the triggered flow.
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

    /// Fetch content type based on custom mobile content theme, then from base theme
    private func isBottomSheetContent(_ mobileContent: FlowContent) -> Bool {
        if let themeData = mobileContent.mobileTheme.themeData {
            return themeData.general?.contentAlignment == ContentAlignmentType.bottom
        } else {
            return themeHandler.getThemeById(mobileContent.mobileTheme.id)?.isDialogExperience == false
        }
    }

    private func isBottomSheetSurveyContent(_ surveyContent: SurveyContent) -> Bool {
        if let themeData = surveyContent.surveyTheme.themeData, let position = themeData.general?.position {
            return position == .bottom
        } else {
            return themeHandler.getThemeById(surveyContent.surveyTheme.id)?.isDialogSurvey == false
        }
    }

}

// MARK: - Launch experiences Screens

extension ExperiencesPublisher {

    /// Flow Experience
    private func openCarouselExperience() {
        showExperience(
            makeViewModel: ExperienceViewModel.init,
            makeViewController: CarouselExperienceViewController.init,
            presentation: .fullScreen
        )
    }

    private func openSlideOutDialogExperience() {
        showExperience(
            makeViewModel: ExperienceViewModel.init,
            makeViewController: SlideOutDialogViewController.init,
            presentation: .dialog
        )
    }

    private func openSlideOutBottomSheetExperience() {
        showExperience(
            makeViewModel: ExperienceViewModel.init,
            makeViewController: SlideOutBottomSheetViewController.init,
            presentation: .bottomSheet
        )
    }

    /// Survey Experience
    private func openSurveyListExperience() {
        showExperience(
            makeViewModel: SurveyViewModel.init,
            makeViewController: SurveyListViewController.init,
            presentation: .fullScreen
        )
    }

    private func openSurveyDialogExperience() {
        showExperience(
            makeViewModel: SurveyViewModel.init,
            makeViewController: SurveyDialogViewController.init,
            presentation: .dialog
        )
    }

    private func openSurveyBottomSheetExperience() {
        showExperience(
            makeViewModel: SurveyViewModel.init,
            makeViewController: SurveyBottomSheetViewController.init,
            presentation: .bottomSheet
        )
    }

    /// NPS Experience
    private func openNPSBottomSheetExperience() {
        showExperience(
            makeViewModel: NPSViewModel.init,
            makeViewController: NPSBottomSheetViewController.init,
            presentation: .bottomSheet
        )
    }

    /// Open thank you view as a bottom sheet
    private func triggerThankYouMessageView(
        _ surveyContent: SurveyContent,
        _ surveyTheme: SurveyTheme
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

internal extension ExperiencesPublisher {

    /// Resolves the correct delay for the current experience (Survey or NPS)
    func resolvedDelay() -> TimeInterval {
        if let surveyDelay = pendingExperiences.first?.asSurveyContent()?.delayDuration, surveyDelay > 0 {
            return surveyDelay
        }
        if let npsDelay = pendingExperiences.first?.asNPSContent()?.delayDuration, npsDelay > 0 {
            return npsDelay
        }
        return ThemeHandler.DefaultValues.delayTimeForExperience
    }

    /// Show Experience
    private func showExperience<VM, VC: UIViewController>(
        makeViewModel: @escaping (DIContainer) -> VM,
        makeViewController: @escaping (VM) -> VC,
        presentation: PresentationStyle
    ) {
        delayUtils.delayAction(delayTime: resolvedDelay()) { [weak self] in
            guard
                let self,
                self.canShowExperience(),
                let container = self.container
            else {
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

// MARK: - Experience content helper methods

extension ExperiencesPublisher {

    /// Validates whether the experience can be shown based on the current application state.
    private func canShowExperience() -> Bool {
        guard
            let experienceContent = pendingExperiences.first,
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

        let isValidContent = isTriggerManualExperience ||
        analyticsPublisher.isStartSession ||
        isForAllScreens ||
        screens.contains(currentScreen)

        return isValidContent
    }

    /// Clear all pending experiences
    private func clearPendingExperiences() {
        if pendingExperiences.isEmpty { return }
        experienceQueue.async { [weak self] in
            self?.pendingExperiences.removeAll()
        }
    }

    private func processNextPendingExperiences() {
        if pendingExperiences.isEmpty { return }
        experienceQueue.async { [weak self] in
            guard let self else { return }
            if self.pendingExperiences.count > 1 {
                self.pendingExperiences = [self.pendingExperiences.last!]
                self.openExperienceFlow()
            } else {
                self.pendingExperiences.removeAll()
            }
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
