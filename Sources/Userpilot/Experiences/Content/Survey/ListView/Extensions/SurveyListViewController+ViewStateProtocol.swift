//
//  SurveyListViewController+ViewStateProtocol.swift//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This class confirm to ViewStateDelegate to listen for view updates.
//

// Extension for SurveyListViewController to conform to the ViewStateDelegate protocol.
extension SurveyListViewController: ViewStateDelegate {

    /// Called when the view state changes.
    /// - Parameter isValid: A Boolean indicating whether the current view state is valid.
    func onViewStateChanged(isValid: Bool) {
        checkActionButtonState()
    }
}
