//
//  CarouselExperienceViewController.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  This extension provides methods to handle the setup and interactions for
//  the carousel experience, including configuring view styles, managing
//  action button bindings, handling step transitions, and binding the view model
//  to update the UI based on the view model state.
//

import Foundation

internal extension CarouselExperienceViewController {

    /// Binds the view model to update the UI based on the view model state.
    /// Sets up closures for data binding and dismiss actions.
    func bindViewModel() {
        // Bind data from the view model and update the view accordingly.
        experienceViewModel.bindData = { [weak self] canBindData in
            if !canBindData {
                self?.dismiss(animated: false, completion: nil)
                return
            }
            // Set up the general style and reload data when view model data changes.
            self?.setupGeneralStyle()
            self?.collectionView.reloadData()
            // Bind the action button for the first step.
            self?.bindActionButton(0)
        }

        // Trigger any initial actions or setup needed when the view model starts.
        experienceViewModel.onStart()
    }
}
