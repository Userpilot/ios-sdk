//
//  SocketManager.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// SocketManager handle all sockets events
//

import Foundation
import SwiftPhoenixClient

// MARK: - Protocols
protocol SocketEvents: AnyObject {
    var isSocketOpened: Bool { get }

    func connect(completion: ((Bool) -> Void)?)
    func close(completion: (() -> Void)?)

    func publish(_ event: Event)
    func registerCallback(_ socketSubscription: SocketSubscription)
}

extension SocketEvents {
    func connect() {
        connect(completion: nil)
    }

    func close() {
        close(completion: nil)
    }
}

protocol SocketSubscription: AnyObject {
    func onSocketEventSent(_ event: Event, _ status: Bool)
}

/// Socket manager to handle socket state and Events
class SocketManager {

    // MARK: - Properties
    private let socketURL = "wss://analytex-dev-nxtapp-8755.userpilot.io/mobile/v1/events/"
    private var phoenixSocket: Socket?
    private var phoenixChannel: Channel?

    private lazy var socketProperties: [String: String] = [
        SocketConstants.SOCKET_TOKEN_KEY: config.token,
        SocketConstants.SOCKET_USER_ID_KEY: storage.userID
    ]

    private lazy var socketChannelProperties = [
        SocketConstants.SOCKET_TOKEN_KEY: config.token,
        SocketConstants.SOCKET_USER_ID_KEY: storage.userID,
        SocketConstants.SOCKET_SDK_VERSION_KEY: userPilot?.version() ?? "",
        SocketConstants.SOCKET_AUTO_PROPERTIES_KEY: autoPropertyDecorator.autoProperties,
        SocketConstants.SOCKET_APP_PROPERTIES_KEY: autoPropertyDecorator.appProperties
    ] as [String: Any]

    private weak var userPilot: UserPilot?
    private let config: UserPilot.Config
    private let storage: DataStoring
    private let autoPropertyDecorator: AutoPropertyDecoratoring
    private let logger: Logging

    @Multicast var socketSubscription: SocketSubscription

    // private let multicastDelegate: MulticastDelegate<SocketSubscription> = .init()
    // private weak var socketSubscription: SocketSubscription?
    // private var event: Event?

    // MARK: - init
    init(container: DIContainer) {
        self.userPilot = container.owner
        self.config = container.resolve(UserPilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.autoPropertyDecorator = container.resolve(AutoPropertyDecoratoring.self)
        self.logger = config.logger
    }

}

// MARK: - Socket connection and callbacks
extension SocketManager {

    private func openSocket(_ completion: ((Bool) -> Void)? = nil) {

        phoenixSocket = Socket(socketURL, params: socketProperties)
        guard let phoenixSocket = phoenixSocket else { return }

        // Setup the socket to receive open/close events
        phoenixSocket.delegateOnOpen(to: self) { (self) in
            self.logger.info("🚀 SOCKET opened\n")
        }

        phoenixSocket.delegateOnClose(to: self) { (self) in
            self.logger.error("🛑 SOCKET closed\n")
        }

        phoenixSocket.delegateOnError(to: self) { (self, error) in
            let (error, _) = error
            self.logger.error("🛑 SOCKET error - details %{public}@\n", error.localizedDescription)
            self.close()
            completion?(false)
        }

        // Socket logger
        phoenixSocket.logger = { [weak self] message in
            self?.logger.debug("💡 SOCKET logger - message %{public}@\n", message)
        }

        // Setup the Channel to receive and send messages
        let channel = phoenixSocket.channel(SocketConstants.SOCKET_CHANNEL_TOPIC, params: socketChannelProperties)

        // Now connect the socket and join the channel
        phoenixChannel = channel
        phoenixChannel?.join()
            .delegateReceive(SocketConstants.SOCKET_SUCCESS_KEY, to: self, callback: { (self, _) in
                self.logger.info("🚀 SOCKET channel JOINED\n")
                completion?(true)
            })
            .delegateReceive(SocketConstants.SOCKET_ERROR_KEY, to: self, callback: { (self, message) in
                self.logger.error("⚠️ SOCKET channel join FAIL: %{public}@\n", message.payload)
                self.close()
                completion?(false)
            })

        // Connect socket
        phoenixSocket.connect()
    }

    private func closeSocket(_ completion: (() -> Void)?) {
        guard let phoenixSocket = phoenixSocket else { return }
        if let channel = self.phoenixChannel {
            channel.leave()
            phoenixSocket.remove(channel)
        }
        phoenixSocket.disconnect {
            self.logger.info("🛑 SOCKET closed\n")
            completion?()
        }
    }

}

// MARK: - SocketEvents
extension SocketManager: SocketEvents {

    var isSocketOpened: Bool {
        return phoenixSocket?.isConnected == true
    }

    func connect(completion: ((Bool) -> Void)?) {
        openSocket(completion)
    }

    func close(completion: (() -> Void)?) {
        closeSocket(completion)
    }

    func publish(_ event: Event) {
        var payload: [String: Any] = [:]
        if let properties = event.properties {
            payload["metadata"] = properties
        }
        if let company = event.company {
            payload["company"] = company
        }
        phoenixChannel?
            .push(event.type.eventName, payload: payload)
            .receive(SocketConstants.SOCKET_SUCCESS_KEY) { [weak self] (message) in
                self?.logger.info("✈️ SOCKET message sent: %{public}@", message.event)
                self?.$socketSubscription.invoke { $0.onSocketEventSent(event, true) }
            }
            .receive(SocketConstants.SOCKET_ERROR_KEY) { [weak self] (errorMessage) in
                self?.logger.error("⚠️ SOCKET message send FAIL: %{public}@", errorMessage.event)
                self?.$socketSubscription.invoke { $0.onSocketEventSent(event, false) }
            }
    }

    func registerCallback(_ socketSubscription: SocketSubscription) {
        self.socketSubscription = socketSubscription
        // multicastDelegate.add(socketSubscription)
        // self.socketSubscription = socketSubscription
    }

}
