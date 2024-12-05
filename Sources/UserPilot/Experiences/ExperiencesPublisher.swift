//
//  ExperiencesPublisher.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  The `ExperiencesPublisher` class is responsible for managing and publishing in-app experiences,
//  such as carousels, using socket connections. It handles socket events, updates themes, and
//  manages the lifecycle of the experiences displayed within the application.
//

import Foundation
import UIKit
import SwiftPhoenixClient

/**
 The `ExperiencesPublishing` protocol defines the required methods for managing experiences,
 such as starting the service, retrieving active carousel content, and sending socket requests.
 */
internal protocol ExperiencesPublishing: AnyObject {
    /// Start new experience
    func start()

    /// Get current experience
    func getActiveMobileContent() -> MobileContent?

    /// check active experience
    func fetchAndResetCarouselContentState() -> Bool

    /// Send experience event to backend
    func publishExperienceEvent(_ sdkEvent: SDKEvent)

    /// Manually trigger experience
    func triggerExperience(_ experienceID: String)

    /// manually end experience
    func endExperience()
}

internal class ExperiencesPublisher: ExperiencesPublishing {

    // MARK: - Properties

    /// The dependency injection container used for resolving services and configurations.
    private let container: DIContainer

    /// Reference to the `UserPilot` instance that owns this manager.
    private weak var userPilot: UserPilot?

    /// Manages socket connections and listens for socket events.
    private let socketManager: SocketEvents

    /// Analytics publisher to manage events triggering.
    private let analyticsPublisher: AnalyticsPublishing

    /// Handles themes for the experiences, managing theme data and styles.
    private let themeHandler: ThemeHandling

    /// Handles local data storage operations.
    private var storage: DataStoring

    /// The configuration settings for the `UserPilot` SDK.
    private let config: UserPilot.Config

    /// Logger used for internal logging of operations and errors.
    private let logger: Logging

    /// The current screen name in the application, used to track active screens.
    private var currentScreen: String = ""

    /// Holds the active carousel content, if any, that is being displayed.
    private var mobileContent: MobileContent?

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
        self.userPilot = container.owner
        self.storage = container.resolve(DataStoring.self)
        self.config = container.resolve(UserPilot.Config.self)
        self.socketManager = container.resolve(SocketEvents.self)
        self.analyticsPublisher = container.resolve(AnalyticsPublishing.self)
        self.themeHandler = container.resolve(ThemeHandling.self)
        self.logger = container.resolve(UserPilot.Config.self).logger
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
        if mobileContent != nil { return }
        publishExperienceEvent(ExperienceContentEvent(experienceID: experienceID))
    }

    /*
     End experience manually
     */
    func endExperience() {
        guard let experience = UIApplication.shared.fetchTopViewController() else { return }
        (experience as? CarouselExperienceViewController)?.closeExperience()
        (experience as? SlideOutBottomSheetViewController)?.dismissBottomSheet()
        (experience as? SlideOutDialogViewController)?.dismissDialog()
    }

    // MARK: - helper methods

    /// Return the current active carousel content.
    func getActiveMobileContent() -> MobileContent? {
        let currentContent = mobileContent
        mobileContent = nil
        return currentContent
    }

    // Check experiences state
    func fetchAndResetCarouselContentState() -> Bool {
        if carouselContent {
            carouselContent = false
            return true
        }
        return false
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
            guard
                let contentPayload = message.payload["mobile_contents"] as? [String: Any],
                !contentPayload.isEmpty,
                let mobileContentData = response.toMobileContent()
            else { return }
            isTriggerManualExperience = (eventName == SDKEventsName.fetchExperienceContent.rawValue)
            mobileContent = mobileContentData.mobileContent
        }

        if eventName == SDKEventsName.fetchExperienceTheme.rawValue {
            if let themeData = response.toMobileTheme(), themeData.id != nil {
                themeHandler.saveTheme(themeData)
            }
        }

        if let mobileContent = mobileContent {
            checkCachedThemes(mobileContent.baseThemeID)
        }
    }

    /*
     Handles new messages received over the socket, Processes the message to extract carousel and theme data.
     - Parameter message: The message object containing payload data.
     */
    func onNewMessage(_ message: Message) {
        if let payload = message.payload["payload"] as? [String: Any] {
            guard
                !hasActiveExperience(),
                payload.keys.contains("request_id"),
                payload["request_id"] as? Int == nil,
                let mobileContents = payload["mobile_contents"] as? [String: Any],
                !mobileContents.isEmpty,
                let mobileContentData = payload.toJSONString()?.toMobileContent()
            else {
                return
            }
            isTriggerManualExperience = true
            mobileContent = mobileContentData.mobileContent
            checkCachedThemes(mobileContentData.mobileContent.baseThemeID)
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
        guard
            analyticsPublisher.canRequestExperienceEvent
        else {
            mobileContent = nil
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

        if sdkEvent.eventName == SDKEventsName.experienceDismissed.rawValue ||
            sdkEvent.eventName == SDKEventsName.experienceCompleted.rawValue {

            if sdkEvent.hasDeepLink {
                mobileContent = nil
                return
            }

            if let mobileContent {
                checkCachedThemes(mobileContent.baseThemeID)
            } else {
                carouselContent = wasCarouselExperience()
                analyticsPublisher.publishFakeReloadScreenEvent()
            }
        }
    }

    /**
     Opens the carousel screen to display carousel content.

     Presents the `CarouselExperienceViewController` with the active carousel content
     if the conditions for displaying the carousel are met.
     */
    private func openExperienceFlow() {
        performOn(.main) { [weak self] in
            guard
                let self,
                let topViewController = UIApplication.shared.fetchTopViewController(),
                self.canShowExperience()
            else {
                self?.isTriggerManualExperience = false
                self?.mobileContent = nil
                return
            }
            self.isTriggerManualExperience = false
            if let mobileContent {
                let experienceViewModel = ExperienceViewModel(container: self.container)
                self.analyticsPublisher.experiencePublished(mobileContent.id)
                switch mobileContent.type {
                case .carousel:
                    self.openCarouselExperience(topViewController, experienceViewModel)
                case .slideout:
                    if self.isBottomSheetContent(mobileContent) {
                        self.openSlideOutBottomSheetExperience(topViewController, experienceViewModel)
                    } else {
                        self.openSlideOutDialogExperience(topViewController, experienceViewModel)
                    }
                }
            }
        }
    }

    /// Fetch content type based on custom mobile content theme, then from base theme
    private func isBottomSheetContent(_ mobileContent: MobileContent) -> Bool {
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
            let mobileContent
        else { return false }

        return isTriggerManualExperience ||
                mobileContent.isForAllScreens ||
                mobileContent.screens.contains(currentScreen)
    }

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

    /// Open dialog
    private func openSlideOutDialogExperience(_ viewController: UIViewController,
                                              _ experienceViewModel: ExperienceViewModel) {
        let slideOutDialogViewController = SlideOutDialogViewController(experienceViewModel: experienceViewModel)
        delay(0.5) {
            viewController.presentDialog(viewController: slideOutDialogViewController)
        }
    }

    /// Open bottom sheet
    private func openSlideOutBottomSheetExperience(_ viewController: UIViewController,
                                                   _ experienceViewModel: ExperienceViewModel) {
        let slideOutBottomSheetViewController = SlideOutBottomSheetViewController(
            experienceViewModel: experienceViewModel)
        delay(0.5) {
            viewController.presentBottomSheet(viewController: slideOutBottomSheetViewController)
        }
    }

    private func hasActiveExperience() -> Bool {
        guard let topViewController = UIApplication.shared.fetchTopViewController() else {
            return false
        }
        return topViewController.isKind(of: CarouselExperienceViewController.self) ||
        topViewController.isKind(of: SlideOutDialogViewController.self) ||
        topViewController.isKind(of: BottomSheetViewController.self)
    }

    private func wasCarouselExperience() -> Bool {
        guard let topViewController = UIApplication.shared.fetchTopViewController() else {
            return false
        }
        return topViewController.isKind(of: CarouselExperienceViewController.self)
    }
}
