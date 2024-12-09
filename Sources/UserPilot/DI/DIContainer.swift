//
//  DIContainer.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The `DIContainer` class provides a dependency injection container for managing component instances
//  and their initializers. It supports lazy initialization and singleton resolution for components.
//

import Foundation

/**
 The `DIContainer` class is responsible for handling dependency injection within the application.
 It manages the registration and resolution of components, supporting both lazy and immediate initialization.
 */
internal class DIContainer {

    // MARK: - Properties

    /// A queue used for concurrent reads and synchronized writes to the container's components.
    private let componentQueue = DispatchQueue(
        label: DispatchQueueConstants.DI_CONTAINER_QUEUE,
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// A dictionary of initializers for lazy component creation.
    private var initializers: [String: (DIContainer) -> Any] = [:]

    /// A dictionary of registered component instances.
    private var components: [String: Any] = [:]

    /// A weak reference to the owning instance (e.g., `Userpilot`).
    weak var owner: Userpilot?

    // MARK: - Register Methods

    /**
     Registers a lazy initializer for a component type.
     
     - Parameter type: The type of the component to register.
     - Parameter initializer: A closure that initializes the component when resolved.
     */
    func registerLazy<Component>(_ type: Component.Type, initializer: @escaping (DIContainer) -> Component) {
        initializers[String(describing: Component.self)] = initializer
    }

    /**
     Registers a lazy initializer for a component type with a default initializer.
     
     - Parameter type: The type of the component to register.
     - Parameter initializer: A closure that initializes the component when resolved.
     */
    func registerLazy<Component>(_ type: Component.Type, initializer: @escaping () -> Component) {
        initializers[String(describing: Component.self)] = { _ in initializer() }
    }

    /**
     Registers a component instance for a specific type.
     
     - Parameter type: The type of the component to register.
     - Parameter value: The instance of the component to register.
     */
    func register<Component>(_ type: Component.Type, value: Component) {
        // Use a barrier to ensure exclusive access during writes.
        componentQueue.async(flags: .barrier) {
            self.components[String(describing: Component.self)] = value
        }
    }

    // MARK: - Resolve Methods

    /**
     Resolves a component instance of the specified type.
     
     - Parameter type: The type of the component to resolve.
     - Returns: An instance of the component.
     - Throws: A fatal error if the component type is not registered.
     */
    @discardableResult
    func resolve<Component>(_ type: Component.Type) -> Component {
        let key = String(describing: Component.self)

        // Check if the component is already registered.
        if let component = componentQueue.sync(execute: { components[key] as? Component }) {
            return component
        }

        // If not, use the initializer to create the component.
        if let initializer = initializers[key] {
            // swiftlint:disable:next force_cast
            let component = initializer(self) as! Component
            // Store the component in the container.
            componentQueue.sync(flags: .barrier) {
                components[key] = component
            }
            return component
        }

        // Throw an error if the component type is not registered.
        fatalError("Unable to resolve type \(key)")
    }
}
