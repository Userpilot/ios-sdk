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
    func start()
    func getActiveCarousel() -> MobileContent?
    func sendSocketRequest(_ sdkEvent: SDKEvent)
}

internal class ExperiencesPublisher: ExperiencesPublishing {

    // MARK: - Properties

    /// The dependency injection container used for resolving services and configurations.
    private let container: DIContainer

    /// Reference to the `UserPilot` instance that owns this manager.
    private weak var userPilot: UserPilot?

    /// Manages socket connections and listens for socket events.
    private let socketManager: SocketEvents

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

    /**
     Return the current active carousel content.

     - Returns: The current `MobileContent`, or `nil` if no active carousel is present.
     */
    func getActiveCarousel() -> MobileContent? {
        let currentContent = mobileContent
        mobileContent = nil
        return currentContent
    }

    /**
     Sends a socket request based on the provided event interface.

     - Parameter sdkEvent: The event interface containing the event name and payload to be sent.
     */
    func sendSocketRequest(_ sdkEvent: SDKEvent) {
        socketManager.publish(sdkEvent.eventName, payload: sdkEvent.eventPayload, socketSubscription: self)
    }

    // MARK: - Private Methods

    /**
     Starts the experience for a given experience ID. This method can be used to
     initiate a specific experience based on the provided ID.

     - Parameter experienceId: The ID of the experience to start.
     */
    private func startExperience(experienceId: String) {
        // Implementation for starting an experience
    }

    /**
     Checks for cached themes to determine if the theme is available locally.

     - Parameter themeID: A theme ID to check against the cached themes.
     */
    private func checkCachedThemes(_ themeID: Int) {
        if themeHandler.getThemeById(themeID) != nil {
            openCarouselScreen()
        } else {
            fetchThemeData(themeID)
        }
    }

    /**
     Opens the carousel screen to display carousel content.

     Presents the `CarouselExperienceViewController` with the active carousel content
     if the conditions for displaying the carousel are met.
     */
    private func openCarouselScreen() {
        performOn(.main) { [weak self] in
            guard let self = self else { return }
            // if !canShowCarousel() { return }
            let carouselExperienceViewModel = CarouselExperienceViewModel(container: self.container)
            let carouselExperienceViewController = CarouselExperienceViewController(
                carouselExperienceViewModel: carouselExperienceViewModel)
            carouselExperienceViewController.modalPresentationStyle = .fullScreen
            if let topViewController = UIApplication.shared.topViewController() {
                topViewController.present(carouselExperienceViewController, animated: true)
            }
        }
    }

    /**
     Fetches theme data for themes that are not cached.

     - Parameter themeID: A theme ID for which data needs to be fetched.
     */
    private func fetchThemeData(_ themeID: Int) {
        guard socketManager.isSocketOpened else {
            mobileContent = nil
            return
        }
        sendSocketRequest(ThemeContentEvent(themeID: themeID, token: config.token))
    }

    /**
     Validates whether the carousel can be shown based on the current application state.

     - Returns: `true` if the carousel can be shown; otherwise, `false`.
     */
    private func canShowCarousel() -> Bool {
        if let topViewController = UIApplication.shared.topViewController(),
           !topViewController.isKind(of: CarouselExperienceViewController.self),
           mobileContent?.carouselScreen.contains(currentScreen) == true,
           mobileContent?.type == .carousel {
            return true
        }
        return false
    }
}

// MARK: - SocketSubscription

extension ExperiencesPublisher: SocketSubscription {

    /**
     Handles the socket event when a message is sent.

     Processes the incoming message to check carousel data and themes.

     - Parameters:
       - eventName: The name of the event sent over the socket.
       - payload: The message payload, if any, received.
       - message: The message object containing additional data.
       - eventSent: Indicates whether the event was successfully sent.
     */
    func onSocketEventSent(_ eventName: String, _ payload: Payload, _ message: Message, _ eventSent: Bool) {
        if eventName == EventType.screenEvent {
            currentScreen = payload?[AnalyticsPublisher.identifyScreenProperty] as? String ?? ""
        }

        guard
            !message.payload.isEmpty,
            let response = message.payload.toJSONString()
        else { return }

        if let mobileContentData = response.toMobileContent() {
            mobileContent = mobileContentData.mobileContent
        }
        if let themeData = response.toMobileTheme() {
            themeHandler.saveTheme(themeData)
        }

        if let mobileContent = mobileContent {
            checkCachedThemes(mobileContent.baseThemeID)
        }
    }

    /*
     Handles new messages received over the socket, Processes the message to extract carousel and theme data.

     - Parameter message: The message object containing payload data.
     */
//    func onNewMessage(_ message: Message) {
//        guard let response = message.payload.toJSONString() else { return }
//
//        if let mobileContentData = response.toMobileContent() {
//            mobileContent = mobileContentData.mobileContent
//        }
//        if let themeData = response.toMobileTheme() {
//            themeHandler.saveTheme(themeData)
//        }
//
//        if let mobileContent = mobileContent {
//            checkCachedThemes(mobileContent.baseThemeID)
//        }
//
//    }
}
