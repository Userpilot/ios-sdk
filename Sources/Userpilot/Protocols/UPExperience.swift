//
//  UPExperience.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/12/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  This protocol defines the behavior for handling the closure of Userpilot experiences.
//

import Foundation

/// A protocol representing an experience in the Userpilot SDK.
/// Conforming types can handle experience closure events.
internal protocol UPExperience: AnyObject {

    /// Triggers the closure of the current experience.
    func triggerCloseExperience(
        manualClose: Bool,
        completion: (() -> Void)?
    )
}
