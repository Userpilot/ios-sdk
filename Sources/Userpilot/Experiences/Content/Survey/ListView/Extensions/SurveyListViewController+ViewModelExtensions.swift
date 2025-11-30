//
//  SurveyListViewController+ViewModelExtensions.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This extension provides methods to handle the setup and interactions for
//  the survey experience, including configuring view styles, managing
//  action button bindings, and binding the view model
//  to update the UI based on the view model state.
//

import UIKit

extension SurveyListViewController {

    /// Binds the view model to update the UI based on the view model state.
    /// Sets up closures for data binding and dismiss actions.
    func bindViewModel() {
        // Bind data from the view model and update the view accordingly.
        surveyViewModel.bindData = { [weak self] canBindData in
            if !canBindData {
                self?.dismiss(animated: false, completion: nil)
                return
            }
            // Set up the general style and reload data when view model data changes.
            self?.setupGeneralStyle()
            self?.bindSurveyViews()
        }

        // Trigger any initial actions or setup needed when the view model starts.
        surveyViewModel.onStart()
    }
}
