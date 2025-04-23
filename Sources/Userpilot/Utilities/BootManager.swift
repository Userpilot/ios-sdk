//
//  BootManager.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 23/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
// [Brief Description]
// A class responsible for managing and initializing a list of components that conform to the `BootUp` protocol.
//

internal class BootManager {

    /// The list of components to be managed and initialized.
    private let components: [Any]

    /// Initializes a new `BootManager` with a list of components.
    init(components: [Any]) {
        self.components = components
    }

    /// Initializes all components by safely casting them to the `BootUp` protocol
    /// and calling their `start()` method.
    func initialize() {
        components.forEach { component in
            if let bootUpComponent = component as? BootUp {
                bootUpComponent.start()
            }
        }
    }
}

/// A protocol that defines the requirement for components that can be initialized.
///
/// Components that conform to this protocol must implement the `start()` method, which is
/// called by the `BootManager` during initialization.
internal protocol BootUp {
    /// Starts the component's initialization process.
    ///
    /// This method is called by the `BootManager` to initialize the component during the boot-up process.
    func start()
}
