//
//  AnalyticsPublishing.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// AnalyticsPublisher handle process events and push it to BE
//

import Foundation

protocol AnalyticsPublishing: AnyObject {
    func identify(_ event: Event, isAnonymous: Bool)
    func publish(_ event: Event)
    func reset()
}

class AnalyticsPublisher {

    // MARK: - properties
    // private let syncQueue = DispatchQueue(label: Constants.DispatchQueueConfig.EVENT_QUEUE)
    private var itemsToFlush: [Event] = []
    private lazy var throttle = Throttle(minimumDelay: 2.0)
    private lazy var readWriteLock = ReadWriteLock(label: DispatchQueueConstants.EVENT_QUEUE)

    private weak var userPilot: UserPilot?
    private let storage: DataStoring
    private let autoPropertyDecorator: AutoPropertyDecoratoring
    private let socketManager: SocketEvents

    private var cachedIdentifyEvent: Event?

    // MARK: - init
    init(container: DIContainer) {
        self.userPilot = container.owner
        self.storage = container.resolve(DataStoring.self)
        self.autoPropertyDecorator = container.resolve(AutoPropertyDecoratoring.self)
        self.socketManager = container.resolve(SocketEvents.self)

        self.socketManager.registerCallback(self)
    }

}

// MARK: - AnalyticsPublishing
extension AnalyticsPublisher: AnalyticsPublishing {

    /// Print event after it sent throw the socket
    func logEvent(_ event: Event) {
        guard let logger = userPilot?.config.logger else { return }
        event.logData(logger: logger)
    }

    /// reset cached events
    func reset() {
        resetCachedIndintifyEvent()
        itemsToFlush.removeAll()
    }
    
    /// Identify user properties and publish the event
    func identify(_ event: Event, isAnonymous: Bool) {
        guard let userID = event.userID else { return }

        // If a different userID is already stored, reset and close the socket
        if storage.userID.isNotEmpty && userID != storage.userID {
            userPilot?.reset()
            closeSocket(event, isAnonymous: isAnonymous)
            return
        }

        // Update storage with new userID and anonymity status
        storage.userID = userID
        storage.isAnonymous = isAnonymous
        cachedIdentifyEvent = event

        // If the socket is open, publish the cached event immediately
        if socketManager.isSocketOpened {
            if let eventToPublish = cachedIdentifyEvent {
                publish(eventToPublish)
            }
        } else {
            // If the socket is not open, connect and publish upon successful connection
            socketManager.connect { [weak self] didOpenSocket in
                if didOpenSocket, let eventToPublish = self?.cachedIdentifyEvent {
                    self?.publish(eventToPublish)
                }
            }
        }
    }

    /// Publish events
    func publish(_ event: Event) {
        if event.type.isIdentifyEvent {
            processEvent(event)
        }else {
            readWriteLock.write {
                itemsToFlush.append(event)
            }
            processEvent(event)
        }
    }
    
    /// prepare events and check status
    private func processEvent(_ event: Event){
        if event.type.isScreenEvent && !socketManager.isSocketOpened && storage.userID.isNotEmpty {
            if let identifyEvent = cachedIdentifyEvent {
                identify(identifyEvent, isAnonymous: false)
            }
        } else {
            flushQueue()
        }
    }
    
    /// Clear cached Identify event since we are connected with the socket and the channel is opened
    private func resetCachedIndintifyEvent() {
        cachedIdentifyEvent = nil
    }

    /// Close current socket since we have new userID in identify event
    private func closeSocket(_ event: Event, isAnonymous: Bool) {
        socketManager.close { [weak self] in
            self?.identify(event, isAnonymous: isAnonymous)
        }
    }

}

// MARK: - SocketSubscription
extension AnalyticsPublisher: SocketSubscription {

    func onSocketEventSent(_ event: Event, _ eventSent: Bool) {
        if event.type.caseName == EventCaseNameConstants.IDENTIFY {
            resetCachedIndintifyEvent()
        }
        readWriteLock.read {
            if itemsToFlush.isEmpty { return }
            if eventSent {
                logEvent(event)
                itemsToFlush.removeFirst()
                flushQueue()
            } else {
                itemsToFlush.removeFirst()
            }
        }
    }

    private func flushQueue() {
        readWriteLock.read {
            guard let event = itemsToFlush.first else { return }
            socketManager.publish(event)
        }
    }

}
