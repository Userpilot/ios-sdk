//
//  DIContainer.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
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

    /// Owns factories, cached instances and construction as one synchronous operation. Recursion lets
    /// a factory resolve dependencies on the same thread; no owner waits for a separate GCD worker.
    private let resolutionLock = NSRecursiveLock()

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
    func registerLazy<Component>(
        _ type: Component.Type,
        initializer: @escaping (DIContainer) -> Component
    ) {
        resolutionLock.withLock {
            initializers[String(describing: Component.self)] = initializer
        }
    }

    /// Register and immediately construct the component, preserving eager startup side effects.
    func registerEager<Component>(
        _ type: Component.Type,
        initializer: @escaping (DIContainer) -> Component
    ) {
        registerLazy(type, initializer: initializer)
        _ = resolve(type) // force initialization immediately
    }

    /**
     Registers a lazy initializer for a component type with a default initializer.
     
     - Parameter type: The type of the component to register.
     - Parameter initializer: A closure that initializes the component when resolved.
     */
    func registerLazy<Component>(
        _ type: Component.Type,
        initializer: @escaping () -> Component
    ) {
        registerLazy(type) { _ in initializer() }
    }

    /**
     Registers a component instance for a specific type.
     
     - Parameter type: The type of the component to register.
     - Parameter value: The instance of the component to register.
     */
    func register<Component>(
        _ type: Component.Type,
        value: Component
    ) {
        resolutionLock.withLock {
            components[String(describing: Component.self)] = value
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
        return resolutionLock.withLock {
            let key = String(describing: Component.self)

            // Check if the component is already registered.
            if let component = components[key] as? Component {
                return component
            }

            // If not, use the initializer to create the component.
            if let initializer = initializers[key] {
                // swiftlint:disable:next force_cast
                let component = initializer(self) as! Component
                // Publish the instance before releasing construction ownership to another caller.
                components[key] = component
                return component
            }

            // Throw an error if the component type is not registered.
            fatalError("Unable to resolve type \(key)")
        }
    }
}
