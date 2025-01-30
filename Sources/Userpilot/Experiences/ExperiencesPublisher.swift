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

import Foundation
import UIKit
import SwiftPhoenixClient

/*
 The `ExperiencesPublishing` protocol defines the required methods for managing experiences,
 such as starting the service, retrieving active carousel content, and sending socket requests.
 */
// swiftlint:disable file_length
internal protocol ExperiencesPublishing: AnyObject {
    /// Start new experience
    func start()

    /// Get current experience
    func getActiveMobileContent() -> ExperienceContent?

    /// check active experience
    func fetchAndResetCarouselContentState() -> Bool

    /// Send experience event to backend
    func publishExperienceEvent(_ sdkEvent: SDKEvent)

    /// Manually trigger experience
    func triggerExperience(_ experienceID: String)

    /// Manually end experience
    func endExperience()

    /// Try to handle the deep link internally
    func triggerDeepLink(url: URL)

    /// Show thank you message
    func showThankYouMessage(_ surveyContent: SurveyContent, _ surveyTheme: SurveyTheme)
}

internal class ExperiencesPublisher: ExperiencesPublishing {

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

    /// The current screen name in the application, used to track active screens.
    private var currentScreen: String = ""

    /// Holds the active carousel content, if any, that is being displayed.
    private var experienceContent: ExperienceContent?

    /// Holds last experience triggered by SDK
    private var carouselContent = false

    /// Manual experience not check screen
    private var isTriggerManualExperience = false

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

    /**
     Starts the experience for a given experience ID. This method can be used to
     initiate a specific experience based on the provided ID.

     - Parameter experienceId: The ID of the experience to start.
     */
    func triggerExperience(_ experienceID: String) {
        guard experienceContent == nil else { return }
        publishExperienceEvent(ExperienceContentEvent(experienceID: experienceID))
    }

    /*
     End experience manually
     */
    func endExperience() {
        guard let experience = UIApplication.shared.fetchTopViewController() else { return }
        (experience as? UPExperience)?.triggerCloseExpereince()
    }

    /*
     Show Thank you module
     */
    func showThankYouMessage(_ surveyContent: SurveyContent, _ surveyTheme: SurveyTheme) {
        triggerThankYouMessageView(surveyContent, surveyTheme)
    }

    // MARK: - helper methods

    /// Return the current active carousel content.
    func getActiveMobileContent() -> ExperienceContent? {
        defer { experienceContent = nil }
        return experienceContent
    }

    /// Check experiences state, in case the screen events comes from on resume state after
    /// carousel expereince end
    func fetchAndResetCarouselContentState() -> Bool {
        guard carouselContent else { return false }
        carouselContent = false
        return true
    }

    /// Try to handle the deep link internally
    func triggerDeepLink(url: URL) {
        if let navigationDelegate = userpilot?.navigationDelegate {
            navigationDelegate.navigate(to: url) { _ in }
        } else {
            if url.isHttpOrHttps,
                UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }

}

// MARK: - SocketSubscription

extension ExperiencesPublisher: SocketSubscription {

    /**
     Handles the socket event when a message is sent.
     
     - Parameters:
     - eventName: The name of the event sent over the socket.
     - payload: The message payload, if any, received.
     - message: The message object containing additional data.
     - eventSent: Indicates whether the event was successfully sent.
     */
    func onSocketEventSent(_ eventName: String, _ payload: Payload, _ message: Message, _ eventSent: Bool) {
        if eventName == EventType.screenEvent {
            currentScreen = payload?[AnalyticsPublisher.screenTitleProperty] as? String ?? ""
        }

        guard
            !hasActiveExperience(),
            !message.payload.isEmpty,
            let response = message.payload.toJSONString()
        else { return }

        // Process experience content or screen events
        if eventName == EventType.screenEvent || eventName == SDKEventsName.fetchExperienceContent.rawValue {
            if let contentPayload = message.payload["mobile_contents"] as? [String: Any],
               !contentPayload.isEmpty, let flowContentData = response.toFlowContent() {
                experienceContent =  ExperienceContent.flow(content: flowContentData.flowContent)
            } else if let contentPayload = message.payload["surveys"] as? [String: Any],
                !contentPayload.isEmpty, let surveyContentData = response.toSurveyContent() {
                experienceContent =  ExperienceContent.survey(content: surveyContentData.surveyContent)
            }
            isTriggerManualExperience = (eventName == SDKEventsName.fetchExperienceContent.rawValue)
        }

        if eventName == SDKEventsName.fetchExperienceTheme.rawValue {
            if let themeData = response.toMobileTheme(), themeData.id != nil {
                themeHandler.saveTheme(themeData)
            }
        }

        if let mobileContent = experienceContent {
            checkCachedThemes(mobileContent.experienceThemeId())
        }
    }

    /*
     Handles new messages received over the socket, Processes the message to extract carousel and theme data.
     - Parameter message: The message object containing payload data.
     */
    func onNewMessage(_ message: Message) {
        if let payload = message.payload["payload"] as? [String: Any] {
            guard
                DelayUtils.hasPendingContent() && (experienceContent == nil || !hasActiveExperience()),
                payload.keys.contains("request_id"),
                payload["request_id"] as? Int == nil
            else { return }

            if let mobileContents = payload["mobile_contents"] as? [String: Any],
               !mobileContents.isEmpty, let flowContentData = payload.toJSONString()?.toFlowContent() {
                experienceContent =  ExperienceContent.flow(content: flowContentData.flowContent)
            } else if let mobileContents = payload["surveys"] as? [String: Any],
                !mobileContents.isEmpty, let surveyContentData = payload.toJSONString()?.toSurveyContent() {
                experienceContent =  ExperienceContent.survey(content: surveyContentData.surveyContent)
            }
            if let experienceContent {
                isTriggerManualExperience = true
                checkCachedThemes(experienceContent.experienceThemeId())
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
        guard analyticsPublisher.canRequestExperienceEvent else {
            experienceContent = nil
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
        analyticsPublisher.publishExperienceEvent(sdkEvent, socketSubscription: self)

        if sdkEvent.isEventForCloseExperience() {

            if sdkEvent.hasDeepLink {
                experienceContent = nil
                return
            }

            if let experienceContent {
                checkCachedThemes(experienceContent.experienceThemeId())
            } else {
                carouselContent = wasFullScreenExperience()
                analyticsPublisher.publishFakeReloadScreenEvent()
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
                self?.experienceContent = nil
                return
            }
            self.isTriggerManualExperience = false

            if let experienceContent {
                switch experienceContent {
                case .flow(let content):
                    let experienceViewModel = ExperienceViewModel(container: self.container)
                    self.analyticsPublisher.experiencePublished(content.id)
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
                }
            }
        }
    }

    /**
     Check survey delay, in case we have a delay, so start a delay timer
     */
    private func checkSurveyDelayConfiguration(_ content: SurveyContent) {
        if content.timeDelay != 0 {
            delay(Double(content.timeDelay)) { [weak self] in
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
                self?.experienceContent = nil
                return
            }
            self.checkSurveyDelayConfiguration(content)
            self.analyticsPublisher.experiencePublished(content.id)
            switch content.type {
            case .list:
                let surveyViewModel = SurveyViewModel(container: self.container)
                self.openSurveyListExperience(topViewController, surveyViewModel)
            case .stepView:
                break
                //                        if self.isBottomSheetContent(content) {
                //     self.openSlideOutBottomSheetExperience(topViewController, experienceViewModel)
                //                        } else {
                //                            self.openSlideOutDialogExperience(topViewController, experienceViewModel)
                //                        }
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

    /// Validates whether the experience can be shown based on the current application state.
    private func canShowExperience() -> Bool {
        guard
            !hasActiveExperience(),
            let experienceContent
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
        }

        return isTriggerManualExperience ||
           analyticsPublisher.isStartSession ||
           isForAllScreens ||
           screens.contains(currentScreen)
    }

    /// Check top view controller if its one of Experiences view controller
    private func hasActiveExperience() -> Bool {
        guard let topViewController = UIApplication.shared.fetchTopViewController() else {
            return false
        }
        return topViewController.isKind(of: CarouselExperienceViewController.self) ||
        topViewController.isKind(of: SlideOutDialogViewController.self) ||
        topViewController.isKind(of: BottomSheetViewController.self) ||
        topViewController.isKind(of: SurveyListViewController.self)
    }

    /// check if expereince was Carousel one
    private func wasFullScreenExperience() -> Bool {
        guard let topViewController = UIApplication.shared.fetchTopViewController() else {
            return false
        }
        return topViewController.isKind(of: CarouselExperienceViewController.self) || topViewController.isKind(of: SurveyListViewController.self)
    }
}

// MARK: - Launch experiences Screens

extension ExperiencesPublisher {

    /// Open carousel
    private func openCarouselExperience(_ viewController: UIViewController,
                                        _ experienceViewModel: ExperienceViewModel) {
        let carouselExperienceViewController = CarouselExperienceViewController(
            experienceViewModel: experienceViewModel)
        carouselExperienceViewController.modalPresentationStyle = .fullScreen
        delay(0.5) {
            viewController.present(carouselExperienceViewController, animated: true)
        }
    }

    /// Open slide out dialog
    private func openSlideOutDialogExperience(_ viewController: UIViewController,
                                              _ experienceViewModel: ExperienceViewModel) {
        let slideOutDialogViewController = SlideOutDialogViewController(experienceViewModel: experienceViewModel)
        delay(0.5) {
            viewController.presentDialog(viewController: slideOutDialogViewController)
        }
    }

    /// Open slide out bottom sheet
    private func openSlideOutBottomSheetExperience(_ viewController: UIViewController,
                                                   _ experienceViewModel: ExperienceViewModel) {
        let slideOutBottomSheetViewController = SlideOutBottomSheetViewController(
            experienceViewModel: experienceViewModel)
        delay(0.5) {
            viewController.presentBottomSheet(viewController: slideOutBottomSheetViewController)
        }
    }

    private func checkSurveyDelayConfiguration(_ viewController: UIViewController,
                                               _ surveyViewModel: SurveyViewModel) {
        if true {
            DelayUtils.delayAction(delayInSeconds: 4, action: { [weak self] in
                self?.openSurveyListExperience(viewController, surveyViewModel)
            })
        } else {
            openSurveyListExperience(viewController, surveyViewModel)
        }
    }
    /// Open survey list view
    private func openSurveyListExperience(_ viewController: UIViewController,
                                          _ surveyViewModel: SurveyViewModel) {
        let surveyListViewController = SurveyListViewController(surveyViewModel: surveyViewModel)
        surveyListViewController.modalPresentationStyle = .fullScreen
        delay(0.5) {
            viewController.present(surveyListViewController, animated: true)
        }
    }

    /// Open thank you view as a bottom sheet
    private func triggerThankYouMessageView(_ surveyContent: SurveyContent, _ surveyTheme: SurveyTheme) {
        performOn(.main) { [weak self] in
            guard
                let self,
                let topViewController = UIApplication.shared.fetchTopViewController(),
                let surveyStep = surveyContent.modules.last
            else { return }

            delay(0.5) {
                let thankYouBottomSheetViewController = ThankYouBottomSheetViewController(
                    surveyStep: surveyStep, surveyTheme: surveyTheme)
                thankYouBottomSheetViewController.actionButtonClicked = { [weak self] deepLink in
                    let eventExperienceSeen = ExperienceSurveyCompletedEvent(
                        surveyID: surveyContent.id,
                        hasDeepLinkContent: deepLink != nil
                    )
                    self?.publishExperienceEvent(eventExperienceSeen)

                    if let deepLink, let url = URL(string: deepLink) {
                        self?.triggerDeepLink(url: url)
                    }
                }
                topViewController.presentBottomSheet(viewController: thankYouBottomSheetViewController)
            }
        }
    }

    /// Region pending content
    private func cancelPendingSurveyContent() {
        DelayUtils.cancelDelay()
        experienceContent = nil
    }
}

// swiftlint:enable file_length
