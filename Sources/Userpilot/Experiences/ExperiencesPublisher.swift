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
import SwiftPhoenixClient

/*
 The `ExperiencesPublishing` protocol defines the required methods for managing experiences,
 such as starting the service, retrieving active carousel content, and sending socket requests.
 */
internal protocol ExperiencesPublishing: AnyObject {

    /// Get current experience
    func getActiveMobileContent() -> ExperienceContent?

    /// Send experience event to backend
    func publishExperienceEvent(_ sdkEvent: SDKEvent)

    /// Manually trigger experience
    func triggerExperience(_ experienceID: String)

    /// Manually end experience
    func endExperience(manualClose: Bool)

    /// Determine if can requst screen event
    func canRequestScreenEvent() -> Bool

    /// Try to handle the deep link internally
    func triggerDeepLink(url: URL)

    /// cancel pending/processing experience
    func cancelPendingSurveyContent()

    /// Show thank you message
    func showThankYouMessage(_ surveyContent: SurveyContent, _ surveyTheme: SurveyTheme)
}

internal class ExperiencesPublisher: ExperiencesPublishing, BootUp {

    // MARK: - Properties

    /// The dependency injection container used for resolving services and configurations.
    private let container: DIContainer

    /// Reference to the `Userpilot` instance that owns this manager.
    private weak var userpilot: Userpilot?

    /// Manages socket connections and listens for socket events.
    private let socketManager: SocketEvents

    /// Analytics publisher to manage events triggering.
    private let analyticsPublisher: AnalyticsPublishing

    /// Handles themes for the experiences, managing theme data and styles.
    private let themeHandler: ThemeHandling

    /// Handles local data storage operations.
    private var storage: DataStoring

    /// The configuration settings for the `Userpilot` SDK.
    private let config: Userpilot.Config

    /// Logger used for internal logging of operations and errors.
    private let logger: Logging

    /// ---- Logic Variables ---- ///

    /// The current screen name in the application, used to track active screens.
    private var currentScreen: String = ""

    /// Debouncer to request fake reload in safe time
    private lazy var debounce = Debouncer(delay: 0.5)

    /// Holds the active carousel content, if any, that is being displayed.
    private var experienceContent: ExperienceContent?

    /// To manage thread safety for experienceContent.
    private lazy var readWriteLock = ReadWriteLockSerial(label: DispatchQueueConstants.EXPERIENCE_QUEUE)

    /// To manage delay for show experience or delay logic for survey & NPS.
    private lazy var delayUtils = DelayUtils()

    /// A special flag to prevent screen event after manual triggering content.
    private lazy var oneSecondFlag = OneSecondFlag()

    /// Manual experience not check screen.
    private var isTriggerManualExperience = false

    /// A flag to indicate triggering thank you message for survey list view.
    private var isTriggeringThankYouMessage = false

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
    }

    // MARK: - Public Methods

    /**
     Starts the experience publisher by registering itself as a socket callback listener.
     */
    func start() {
        socketManager.registerCallback(self)
    }

    // MARK: - SDK APIs

    /// Determine if can requst screen event
    func canRequestScreenEvent() -> Bool {
        return !oneSecondFlag.isActive && !hasActiveExperience() && !isTriggeringThankYouMessage
    }

    /**
     Starts the experience for a given experience ID. This method can be used to
     initiate a specific experience based on the provided ID.

     - Parameter experienceId: The ID of the experience to start.
     */
    func triggerExperience(_ experienceID: String) {
        readWriteLock.read { [weak self] in
            guard self?.experienceContent == nil else { return }
            self?.publishExperienceEvent(ExperienceContentEvent(experienceID: experienceID))
        }
    }

    /*
     End experience manually
     */
    func endExperience(manualClose: Bool) {
        guard let experience = UIApplication.shared.fetchTopViewController() else { return }
        (experience as? UPExperience)?.triggerCloseExpereince(manualClose: manualClose)
    }

    /*
     Show Thank you module
     */
    func showThankYouMessage(_ surveyContent: SurveyContent, _ surveyTheme: SurveyTheme) {
        triggerThankYouMessageView(surveyContent, surveyTheme)
    }

    // MARK: - helper methods

    /// Return the current active carousel content.
    /// Returns the current active carousel content and clears it safely.
    func getActiveMobileContent() -> ExperienceContent? {
        var content: ExperienceContent?

        // Safely read the experience content
        readWriteLock.read { [weak self] in
            content = self?.experienceContent
        }

        // Safely clear the experience content
        resetExperienceContent()
        return content
    }

    /// Try to handle the deep link internally
    func triggerDeepLink(url: URL) {
        delay(ThemeHandler.DefaultValues.delayTimeForDeepLink) { [weak self] in
            if let navigationDelegate = self?.userpilot?.navigationDelegate {
                navigationDelegate.navigate(to: url) { _ in }
            } else {
                if url.isHttpOrHttps,
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        }
    }

}

// MARK: - SocketSubscription

extension ExperiencesPublisher: SocketSubscription {

    /*
     Handles the socket event when a message is sent.
     
     - Parameters:
     - eventName: The name of the event sent over the socket.
     - payload: The message payload, if any, received.
     - message: The message object containing additional data.
     - eventSent: Indicates whether the event was successfully sent.
     */
    // swiftlint:disable:next cyclomatic_complexity, superfluous_disable_command
    func onSocketEventSent(_ eventName: String,
                           _ payload: Payload,
                           _ message: Message,
                           _ eventSent: Bool) {
        readWriteLock.write { [weak self] in
            guard let self, !hasActiveExperience(), !message.payload.isEmpty,
                  let response = message.payload.toJSONString() else { return }

            // Update current screen if it's a screen event
            if eventName == EventType.screenEvent {
                currentScreen = payload?[AnalyticsPublisher.screenTitleProperty] as? String ?? ""
            }

            // Handle theme fetching separately
            if eventName == SDKEventsName.fetchExperienceTheme.rawValue,
               let themeData = response.toMobileTheme(), themeData.id != nil {
                themeHandler.saveTheme(themeData)
            }

            // Process experience content
            if eventName == EventType.screenEvent || eventName == SDKEventsName.fetchExperienceContent.rawValue {
                isTriggerManualExperience = (eventName == SDKEventsName.fetchExperienceContent.rawValue)

                if let flowContent = response.toFlowContent()?.flowContent {
                    experienceContent = ExperienceContent.flow(content: flowContent)
                } else if let surveyContent = response.toSurveyContent()?.surveyContent {
                    experienceContent = ExperienceContent.survey(content: surveyContent)
                } else if let npsContent = response.toNPSContent()?.npsContent {
                    experienceContent = ExperienceContent.nps(content: npsContent)
                }
            }

            // Handle experience content
            if let experienceContent = experienceContent {
                if experienceContent.asNPSContent() != nil {
                    openExperienceFlow()
                } else {
                    checkCachedThemes(experienceContent.experienceThemeId())
                }
            }
        }
    }

    /*
     Handles new messages received over the socket, Processes the message to extract carousel and theme data.
     - Parameter message: The message object containing payload data.
     */
    func onNewMessage(_ message: Message) {
        if let payload = message.payload["payload"] as? [String: Any] {
            readWriteLock.write { [weak self] in
                // Ensure experienceContent is nil and there is no active experience before processing
                guard
                    let self,
                    experienceContent == nil,
                    !hasActiveExperience(),
                    payload.keys.contains("request_id"),
                    payload["request_id"] as? Int == nil
                else { return }

                // Determine the new content based on payload
                let newExperienceContent: ExperienceContent? = {
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

                // Only set the experienceContent if it is still nil (double-check within the lock)
                if experienceContent == nil, let newExperienceContent {
                    experienceContent = newExperienceContent
                    isTriggerManualExperience = true

                    if newExperienceContent.asNPSContent() != nil {
                        openExperienceFlow()
                    } else {
                        checkCachedThemes(newExperienceContent.experienceThemeId())
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

     - Parameter themeID: A theme ID to check against the cached themes.
     */
    private func checkCachedThemes(_ themeID: Int) {
        if themeHandler.getThemeById(themeID) != nil {
            openExperienceFlow()
        } else {
            fetchThemeData(themeID)
        }
    }

    /**
     Fetches theme data for themes that are not cached.

     - Parameter themeID: A theme ID for which data needs to be fetched.
     */
    private func fetchThemeData(_ themeID: Int) {
        guard analyticsPublisher.canRequestEvent else {
            resetExperienceContent()
            return
        }

        publishExperienceEvent(ThemeContentEvent(themeID: themeID, token: config.token))
    }

}

// MARK: - Launch experiences

extension ExperiencesPublisher {

    /**
     Sends a socket request based on the provided event interface.
     
     - Parameter sdkEvent: The event interface containing the event name and payload to be sent.
     */
    func publishExperienceEvent(_ sdkEvent: SDKEvent) {
        analyticsPublisher.publishExperienceEvent(sdkEvent, isExpereinceEvent: true, socketSubscription: self)

        if sdkEvent.isEventForCloseNPSExperience() {
            resetExperienceContent()
            return
        }

        if sdkEvent.isEventForCloseExperience() {

            if sdkEvent.hasDeepLink {
                resetExperienceContent()
                return
            }

            if let experienceContent {
                checkCachedThemes(experienceContent.experienceThemeId())
            } else {
                oneSecondFlag.activate()
                if !isTriggerManualExperience {
                    debounce.debounce {
                        if self.analyticsPublisher.screenEntity?.event.screenTitle == self.currentScreen {
                            self.analyticsPublisher.publishFakeReloadScreenEvent()
                        }
                    }
                }
            }
        }
    }

    /**
     Opens the triggered flow.
     */
    private func openExperienceFlow() {
        performOn(.main) { [weak self] in
            guard
                let self,
                let topViewController = UIApplication.shared.fetchTopViewController(),
                self.canShowExperience()
            else {
                self?.isTriggerManualExperience = false
                self?.resetExperienceContent()
                return
            }

            if let experienceContent {
                switch experienceContent {
                case .flow(let content):
                    let experienceViewModel = ExperienceViewModel(container: self.container)
                    self.analyticsPublisher.experiencePublished(.flow, content.id)
                    switch content.type {
                    case .carousel:
                        self.openCarouselExperience(topViewController, experienceViewModel)
                    case .slideout:
                        if self.isBottomSheetContent(content) {
                            self.openSlideOutBottomSheetExperience(topViewController, experienceViewModel)
                        } else {
                            self.openSlideOutDialogExperience(topViewController, experienceViewModel)
                        }
                    }

                case .survey(let content):
                    self.checkSurveyDelayConfiguration(content)

                case .nps(let content):
                    self.checkNPSDelayConfiguration(content)
                }
            }
        }
    }

    /**
     Check nps delay, in case we have a delay, so start a delay timer
     */
    private func checkNPSDelayConfiguration(_ content: NPSContent) {
        if content.timeDelay != 0 {
            delayUtils.delayAction(delayTime: Double(content.timeDelay)) { [weak self] in
                self?.handleNPSExperience()
            }
        } else {
            handleNPSExperience()
        }
    }

    /**
    Publish survey experience
    */
    private func handleNPSExperience() {
        performOn(.main) { [weak self] in
            guard
                let self,
                let topViewController = UIApplication.shared.fetchTopViewController(),
                self.canShowExperience()
            else {
                self?.isTriggerManualExperience = false
                self?.resetExperienceContent()
                return
            }
            let npsViewModel = NPSViewModel(container: self.container)
            self.openNPSBottomSheetExperience(topViewController, npsViewModel)
        }
    }

    /**
     Check survey delay, in case we have a delay, so start a delay timer
     */
    private func checkSurveyDelayConfiguration(_ content: SurveyContent) {
        if content.timeDelay != 0 {
            delayUtils.delayAction(delayTime: Double(content.timeDelay)) { [weak self] in
                self?.handleSurveyExperience(content)
            }
        } else {
            handleSurveyExperience(content)
        }
    }

    /**
     Recheck top view controller and expereince state to show the survey expereince again
     */
    private func handleSurveyExperience(_ content: SurveyContent) {
        performOn(.main) { [weak self] in
            guard
                let self,
                let topViewController = UIApplication.shared.fetchTopViewController(),
                self.canShowExperience()
            else {
                self?.isTriggerManualExperience = false
                self?.resetExperienceContent()
                return
            }
            self.analyticsPublisher.experiencePublished(.survey, content.id)
            let surveyViewModel = SurveyViewModel(container: self.container)
            switch content.type {
            case .list:
                self.openSurveyListExperience(topViewController, surveyViewModel)
            case .step:
                if self.isBottomSheetSurveyContent(content) {
                    self.openSurveyBottomSheetExperience(topViewController, surveyViewModel)
                } else {
                    self.openSurveyDialogExperience(topViewController, surveyViewModel)
                }
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

    /// Open carousel
    private func openCarouselExperience(_ viewController: UIViewController,
                                        _ experienceViewModel: ExperienceViewModel) {
        delayUtils.delayAction { [weak self] in
            guard let self, self.canShowExperience() else { return }
            let carouselExperienceViewController = CarouselExperienceViewController(
                experienceViewModel: experienceViewModel)
            carouselExperienceViewController.modalPresentationStyle = .fullScreen
            viewController.present(carouselExperienceViewController, animated: true)
        }
    }

    /// Open slide out dialog
    private func openSlideOutDialogExperience(_ viewController: UIViewController,
                                              _ experienceViewModel: ExperienceViewModel) {
        delayUtils.delayAction { [weak self] in
            guard let self, self.canShowExperience() else { return }
            let slideOutDialogViewController = SlideOutDialogViewController(experienceViewModel: experienceViewModel)
            viewController.presentDialog(viewController: slideOutDialogViewController)
        }
    }

    /// Open slide out bottom sheet
    private func openSlideOutBottomSheetExperience(_ viewController: UIViewController,
                                                   _ experienceViewModel: ExperienceViewModel) {
        delayUtils.delayAction { [weak self] in
            guard let self, self.canShowExperience() else { return }
            let slideOutBottomSheetViewController = SlideOutBottomSheetViewController(
                experienceViewModel: experienceViewModel)
            viewController.presentBottomSheet(viewController: slideOutBottomSheetViewController)
        }
    }

    /// Open survey list view
    private func openSurveyListExperience(_ viewController: UIViewController,
                                          _ surveyViewModel: SurveyViewModel) {
        delayUtils.delayAction { [weak self] in
            guard let self, self.canShowExperience() else { return }
            let surveyListViewController = SurveyListViewController(surveyViewModel: surveyViewModel)
            surveyListViewController.modalPresentationStyle = .fullScreen
            viewController.present(surveyListViewController, animated: true)
        }
    }

    /// Open thank you view as a bottom sheet
    private func triggerThankYouMessageView(_ surveyContent: SurveyContent, _ surveyTheme: SurveyTheme) {
        isTriggeringThankYouMessage = true
        performOn(.main) { [weak self] in
            guard
                let self,
                let topViewController = UIApplication.shared.fetchTopViewController(),
                let surveyStep = surveyContent.modules.last
            else {
                self?.isTriggeringThankYouMessage = false
                return
            }
            delayUtils.delayAction { [weak self] in
                let thankYouBottomSheetViewController = ThankYouBottomSheetViewController(
                    surveyContent: surveyContent, surveyTheme: surveyTheme)
                thankYouBottomSheetViewController.actionButtonClicked = { [weak self] deepLink in
                    let eventExperienceSeen = ExperienceSurveyCompletedEvent(
                        surveyID: surveyContent.id,
                        hasDeepLinkContent: deepLink != nil
                    )
                    self?.publishExperienceEvent(eventExperienceSeen)

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

    /// Open survey dialog
    private func openSurveyDialogExperience(_ viewController: UIViewController,
                                            _ surveyViewModel: SurveyViewModel) {
        delayUtils.delayAction { [weak self] in
            guard let self, self.canShowExperience() else { return }
            let surveyDialogViewController = SurveyDialogViewController(surveyViewModel: surveyViewModel)
            viewController.presentDialog(viewController: surveyDialogViewController)
        }
    }

    /// Open survey bottom sheet
    private func openSurveyBottomSheetExperience(_ viewController: UIViewController,
                                                 _ surveyViewModel: SurveyViewModel) {
        delayUtils.delayAction { [weak self] in
            guard let self, self.canShowExperience() else { return }
            let surveyBottomSheetViewController = SurveyBottomSheetViewController(
                surveyViewModel: surveyViewModel)
            viewController.presentBottomSheet(viewController: surveyBottomSheetViewController)
        }
    }

    /// Open NPS bottom sheet
    private func openNPSBottomSheetExperience(_ viewController: UIViewController,
                                              _ npsViewModel: NPSViewModel) {
        delayUtils.delayAction { [weak self] in
            guard let self, self.canShowExperience() else { return }
            let npsBottomSheetViewController = NPSBottomSheetViewController(
                npsViewModel: npsViewModel)
            viewController.presentBottomSheet(viewController: npsBottomSheetViewController)
        }
    }

}

// MARK: - Experience content helper methods

extension ExperiencesPublisher {

    /// Validates whether the experience can be shown based on the current application state.
    private func canShowExperience() -> Bool {
        readWriteLock.read { [weak self] in
            guard
                let self,
                let experienceContent,
                !hasActiveExperience()
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
    }

    /// Check top view controller if its one of Experiences view controller
    private func hasActiveExperience() -> Bool {
        guard let topViewController = UIApplication.shared.fetchTopViewController() else {
            return false
        }
        return topViewController.isKind(of: CarouselExperienceViewController.self) ||
        topViewController.isKind(of: DialogViewController.self) ||
        topViewController.isKind(of: BottomSheetViewController.self) ||
        topViewController.isKind(of: SurveyListViewController.self)
    }

    /// A delegate method, on new screen opened cancel pending/processing content
    func cancelPendingSurveyContent() {
        delayUtils.cancelDelay()
        endExperience(manualClose: false)
        resetExperienceContent()
    }

    /// reset experience content
    private func resetExperienceContent() {
        readWriteLock.write { [weak self] in
            self?.experienceContent = nil
        }
    }

}
