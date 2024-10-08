//
//  File.swift
//  
//
//  Created by Motasem Hamed on 29/09/2024.
//

import Foundation
import UIKit
import SwiftPhoenixClient

internal protocol ExperiencesPublishing: AnyObject {
    func start()
    func getActiveCarousel() -> CarouselContent?
    func sendSocketRequest(_ sdkEvent: SDKEvent)
}

/**
 The `AnalyticsPublisher` class implements the `AnalyticsPublishing` protocol
 to process events and send them to the backend.
 
 It handles socket connections, event caching, and ensures events are sent
 reliably. The class supports tracking user identification, screen views, and
 custom events, with event queuing and debouncing to optimize network traffic.
 */
internal class ExperiencesPublisher: ExperiencesPublishing {

    private let container: DIContainer
    private weak var userPilot: UserPilot?
    private let socketManager: SocketEvents
    private let themeHandler: ThemeHandling
    private var storage: DataStoring
    private let config: UserPilot.Config
    private let logger: Logging

    // Properties
    private var appScreen: String = ""
    private var carouselScreen: String = ""
    private var carousels: [CarouselContent] = []

    init(container: DIContainer) {
        self.container = container
        self.userPilot = container.owner
        self.storage = container.resolve(DataStoring.self)
        self.config = container.resolve(UserPilot.Config.self)
        self.socketManager = container.resolve(SocketEvents.self)
        self.themeHandler = container.resolve(ThemeHandling.self)
        self.logger = container.resolve(UserPilot.Config.self).logger
    }

    func start() {
        socketManager.registerCallback(self)
    }

    func getActiveCarousel() -> CarouselContent? {
        return carousels.first
    }

    /**
     * Starts the experience.
     *
     * - Parameter experienceId: The ID of the experience to start.
     */
    func startExperience(experienceId: String) {
        // Implementation for starting an experience
    }

    /**
     * Checks for cached themes to determine if the theme is available.
     *
     * - Parameter themeId: A theme ID to check against the cached themes.
     */
    private func checkCachedThemes(themeId: Int) {
        if themeHandler.getThemeById(themeId) != nil {
            openCarouselScreen()
        } else {
            fetchThemeData(themeId: 1)
        }
    }

    /**
     * Opens the carousel screen to display carousel content.
     */
    private func openCarouselScreen() {
        let carouselExperienceViewModel = CarouselExperienceViewModel(container: container)
        let carouselExperienceViewController = CarouselExperienceViewController(
            carouselExperienceViewModel: carouselExperienceViewModel)
        carouselExperienceViewController.modalPresentationStyle = .fullScreen
        if let topViewController = UIApplication.shared.topViewController(),
           !topViewController.isKind(of: CarouselExperienceViewController.self) {
            topViewController.present(carouselExperienceViewController, animated: true)
        }
    }

    /**
     * Fetches theme data for themes that are not cached.
     *
     * - Parameter themeId: A list of theme IDs that need to be fetched.
     */
    private func fetchThemeData(themeId: Int) {
        // Uncomment and modify as needed
        /*
        if carouselScreen != appScreen || !socketManager.isSocketOpened {
            carousels.removeAll()
            return
        }
        */
        sendSocketRequest(ThemeContentEvent(themeID: themeId, token: config.token))
    }

    /**
     * Sends a socket request based on the provided event interface.
     *
     * - Parameter sdkEvent: The event interface containing the event name and payload.
     */
    func sendSocketRequest(_ sdkEvent: SDKEvent) {
        // Implementation to publish socket event.
        // socketManager.publish(sdkEvent.eventName, payload: sdkEvent.eventPayload, socketSubscription: self)
    }

    /**
     * Validates whether the carousel can be shown based on the current application state.
     *
     * - Returns: True if the carousel can be shown; otherwise, false.
     */
    private func isValidToShowCarousel() -> Bool {
        return !carousels.isEmpty &&
               carousels[0].configuration.targeting.screens.contains(appScreen)
    }

}

extension ExperiencesPublisher: SocketSubscription {

    /**
     * Handles the socket event when a message is sent.
     * It processes the incoming message to check carousel data and themes.
     *
     * - Parameters:
     *   - eventName: The name of the event sent over the socket.
     *   - message: The message payload received.
     *   - eventSent: Indicates whether the event was successfully sent.
     */
    func onSocketEventSent(_ eventName: String, _ message: Message, _ eventSent: Bool) {
        // Temporarily using mock data for demonstration.
        if let carouselData = MockManager.carouselData.toCarouselList() {
            carousels.append(contentsOf: carouselData)
        }

        if let baseTheme = MockManager.BaseTheme.toMobileTheme() {
            themeHandler.saveTheme(baseTheme)
        }

        performOn(.main) { [weak self] in
            // self?.openCarouselScreen()
        }
    }
}
