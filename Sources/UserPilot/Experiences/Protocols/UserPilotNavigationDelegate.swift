//
//  UserPilotNavigationDelegate.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 03/10/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  This protocol allows the application to control navigation between screens
//  when triggered by a UserPilot experience.
//

import Foundation

@objc
public protocol UserPilotNavigationDelegate: AnyObject {
    /// Requests the delegate navigate to the given destination, and report completion.
    /// - Parameters:
    ///   - url: The URL of the destination to navigate.
    ///   - completion: Closure to invoke when navigation is completed,
    ///    passing `true` if successfully navigated, `false` if not.
    func navigate(to url: URL, completion: @escaping (Bool) -> Void)
}
