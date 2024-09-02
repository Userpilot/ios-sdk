//
//  DIContainer.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// DIContainer to handle dependancy injection
//

import Foundation

class DIContainer {

    // MARK: - Properties
    private let componentQueue = DispatchQueue(label: DispatchQueueConstants.DI_CONTAINER_QUEUE,
                                               qos: .userInitiated, attributes: .concurrent)

    private var initializers: [String: (DIContainer) -> Any] = [:]
    private var components: [String: Any] = [:]

    weak var owner: UserPilot?

    // MARK: - Register methods
    func registerLazy<Component>(_ type: Component.Type, initializer: @escaping (DIContainer) -> Component) {
        initializers[String(describing: Component.self)] = initializer
    }

    func registerLazy<Component>(_ type: Component.Type, initializer: @escaping () -> Component) {
        initializers[String(describing: Component.self)] = { _ in initializer() }
    }

    func register<Component>(_ type: Component.Type, value: Component) {
        // If we're writing, need to lock, but no return, so this can be async
        componentQueue.async(flags: .barrier) {
            self.components[String(describing: Component.self)] = value
        }
    }

    // MARK: - Optain singelton
    @discardableResult
    func resolve<Component>(_ type: Component.Type) -> Component {
        let key = String(describing: Component.self)

        // Concurrent reads are ok
        if let component = componentQueue.sync(execute: { components[key] as? Component }) {
            return component
        }

        if let initializer = initializers[key] {
            // swiftlint:disable:next force_cast
            let component = initializer(self) as! Component
            // If we're writing, need to lock
            componentQueue.sync(flags: .barrier) {
                components[key] = component
            }
            return component
        }

        // this is a coding error, did not register dependency
        fatalError("Unable to resolve type \(key)")
    }

}
