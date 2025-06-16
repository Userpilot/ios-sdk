//
//  UserpilotNavigationDelegate.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 03/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This protocol allows the application to control navigation between screens
//  when triggered by a Userpilot experience.
//

import Foundation

@objc
public protocol UserpilotNavigationDelegate: AnyObject {
    /// Requests the delegate navigate to the given destination, and report completion.
    /// - Parameters:
    ///   - url: The URL of the destination to navigate.
    func navigate(to url: URL)
}
