//
//  NPSContainerViewDelegate.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 10/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  This protocol defines the delegate methods for handling user interactions
//  within the `NPSContainerView`. It allows the implementing class to
//  respond to events such as dismissing the survey, submitting a response,
//  or completing the NPS flow.
//

import Foundation

internal protocol NPSContainerViewDelegate: AnyObject {

    /// Called when the dismiss button is clicked to close the survey view.
    func onNPSDismissed()

    /// Called when the action button is clicked, submitting the user's response.
    ///
    /// - Parameters:
    ///   - userAnswer: The numeric rating provided by the user.
    ///   - userFollowUpKey: The key identifying the follow-up question.
    ///   - userFollowUp: The text response provided by the user.
    func onNPSSubmitted(_ userAnswer: Int, _ userFollowUpKey: String, _ userFollowUp: String)

    /// Called when the NPS survey process ends, providing the final collected data.
    ///
    /// - Parameter completedData: An optional `CompletedData` object containing
    ///   the survey results, if available.
    func onEndNPS(completedData: CompletedData?)
}
