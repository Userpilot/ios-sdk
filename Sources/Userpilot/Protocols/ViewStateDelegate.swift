//
//  ViewStateDelegate.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 9/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A protocol that defines a delegate for observing view state changes.
//

internal protocol ViewStateDelegate: AnyObject {

    /// Called when the view state changes.
    /// - Parameter isValid: A `Bool` indicating whether the current state of the view is valid.
    func onViewStateChanged(isValid: Bool)
}
