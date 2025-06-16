//
//  SurveyContainerViewDelegate.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 30/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This protocol defines the delegate methods for handling user interactions
//  within the `SurveyContainerView`. It allows the implementing class to
//  respond to events such as dismissing the view or handling button actions.
//

import Foundation

internal protocol SurveyContainerViewDelegate: AnyObject {

    /// Called when the dismiss button is clicked to close the survey view.
    func onClose()

    /// Called when the action button is clicked, triggering the specified action.
    func onAction(_ answer: Any?, _ answerPayload: Payload)

}
