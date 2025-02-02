//
//  SurveyContainerViewDelegate.swift
//  Userpilot
//
//  Created by Motasem Hamed on 30/01/2025.
//

import Foundation

internal protocol SurveyContainerViewDelegate: AnyObject {
    /// Called when the dismiss button is clicked to close the slide-out view.
    func onClose()

    /// Called when the action button is clicked, triggering the specified action.
    func onAction(_ answer: Any?, _ answerPayload: Payload)

    func onOpenLink()
}
