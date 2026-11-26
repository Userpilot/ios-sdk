//
//  SurveyListViewController+ViewStateProtocol.swift
//  Userpilot SDK
//
//  Created by Userpilot on 21/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  SurveyListViewController+ViewStateProtocol.swift//  Userpilot SDK
//
//
//  This class confirm to UPViewStateDelegate to listen for view updates.
//
//
//  Extension for SurveyListViewController to conform to the UPViewStateDelegate protocol.
//

extension SurveyListViewController: UPViewStateDelegate {

    /// Called when the view state changes.
    /// - Parameter isValid: A Boolean indicating whether the current view state is valid.
    func onViewStateChanged(isValid: Bool) {
        checkActionButtonState()
    }
}
