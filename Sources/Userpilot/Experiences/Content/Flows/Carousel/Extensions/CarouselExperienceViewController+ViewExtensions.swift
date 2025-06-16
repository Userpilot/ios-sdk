//
//  CarouselExperienceViewController+ViewExtensions.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This extension provides methods to handle the setup and interactions for
//  the carousel experience, including configuring the view themes, managing
//  action button bindings, and handling step transitions. It defines helper
//  functions for updating the step progress view and closing the experience.
//

import Foundation
import UIKit

internal extension CarouselExperienceViewController {

    /// Configures general views constraints.
    func setupViews() {
        isModalInPresentation = true
    }

    /// Setup UI locale depending on Experience content
    func setupLocale() {
        let collectionViewLayout = UPCollectionViewLayout()
        collectionViewLayout.sectionInset = UIEdgeInsets.zero
        collectionViewLayout.minimumLineSpacing = 0
        collectionViewLayout.minimumInteritemSpacing = 0
        collectionViewLayout.scrollDirection = .horizontal
        collectionView.collectionViewLayout = collectionViewLayout
        if experienceViewModel.isRTL {
            buttonDismissContainerView.semanticContentAttribute = .forceRightToLeft
            collectionView.semanticContentAttribute = .forceRightToLeft
        }
    }

    /// Configures the general style for the carousel experience view.
    /// Sets up background color, dismiss button visibility, and step progress indicator.
    func setupGeneralStyle() {
        // Get the theme for the current step index.
        guard
            let theme = experienceViewModel.carouselTheme[safe: experienceViewModel.currentStep]
        else { return }

        // update status bar color
        setNeedsStatusBarAppearanceUpdate()

        // Configure the dismiss button based on the theme settings.
        if theme.isDismissButtonEnabled {
            buttonDismiss.setupView(theme: theme)
        } else {
            buttonDismissContainerView.isHidden = true
        }

        // Set up the step progress view with the total number of steps and the current theme.
        if theme.isStepsProgressEnabled {
            viewStepsProgress.setupView(
                stepsCount: experienceViewModel.flowContent?.steps.count ?? 0,
                theme: theme,
                isRTL: experienceViewModel.isRTL
            )
        }
    }

    /// Process action button -> action.
    func onActionButtonClicked(_ action: ButtonAction?) {
        guard let action else { return }
        if isLastStep() {
            experienceViewModel.onExperienceCompleted()
            dismiss(animated: true, completion: { [weak self] in
                if action.deepLink != nil {
                    self?.experienceViewModel.onDeepLinkTriggered()
                }
            })
        }
    }

    /// Checks if the current step is the last step in the carousel.
    /// - Returns: A boolean indicating if the current step is the last one.
    func isLastStep() -> Bool {
        let index = collectionView.currentIndex
        if index == experienceViewModel.carouselStepsCount - 1 {
            return true
        } else {
            // Scroll to the next item and trigger a new step view event.
            collectionView.scrollToNextItem()
            onNewStepViewed(index + 1)
            return false
        }
    }

    /// Handles the event when a new step is viewed.
    /// Updates the step progress indicator and binds the action button for the new step.
    /// - Parameter step: The index of the new step viewed.
    func onNewStepViewed(_ step: Int) {
        experienceViewModel.onStepChanged(step)
        setupGeneralStyle()
        viewStepsProgress.setCurrentStep(step)
    }

    /// Closes the carousel experience view and triggers the onDismiss event.
    func closeExperience() {
        experienceViewModel.onDismissStep()
        dismiss(animated: true)
    }
}
