//
//  CarouselExperienceViewController.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
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
        buttonDismissRightMargin.constant = ThemeHandler.DefaultValues.contentMargin
        actionLeftMargin.constant = ThemeHandler.DefaultValues.contentMargin
        actionRightMargin.constant = ThemeHandler.DefaultValues.contentMargin
        contentTopMargin.constant = ThemeHandler.DefaultValues.contentMargin
        contentBottomMargin.constant = ThemeHandler.DefaultValues.contentBottomMargin
    }

    /// Setup UI locale depending on Experience content
    private func setupLocale() {
        if "".isRTL {
            UIView.appearance().semanticContentAttribute = .forceLeftToRight
        }
        let collectionViewLayout = UIView.userInterfaceLayoutDirection(
            for: self.view.semanticContentAttribute) == .rightToLeft ?
        UPCollectionViewLayout() : UICollectionViewFlowLayout()
        collectionViewLayout.sectionInset = UIEdgeInsets.zero
        collectionViewLayout.minimumLineSpacing = 0
        collectionViewLayout.minimumInteritemSpacing = 0
        collectionViewLayout.scrollDirection = .horizontal
        collectionView.collectionViewLayout = collectionViewLayout
    }

    /// Configures the general style for the carousel experience view.
    /// Sets up background color, dismiss button visibility, and step progress indicator.
    func setupGeneralStyle() {
        // Get the theme for the current step index.
        guard
            let theme = experienceViewModel.carouselTheme[safe: collectionView.currentIndex]
        else { return }

        // update status bar color
        setNeedsStatusBarAppearanceUpdate()

        // Set the background color for the view.
        self.view.backgroundColor = theme.backgroundColor

        // Configure the dismiss button based on the theme settings.
        if theme.isDismissButtonEnabled {
            buttonDismiss.setupView(theme: theme)
        } else {
            buttonDismissContainerView.isHidden = true
        }

        // Set up the step progress view with the total number of steps and the current theme.
        viewStepsProgress.setupView(
            stepsCount: experienceViewModel.mobileContent?.steps.count ?? 0,
            theme: theme
        )
    }

    /// Binds the action button for a given step index.
    /// Sets up the button with its properties and configures the action when tapped.
    /// - Parameter index: The index of the step to bind the action button for.
    func bindActionButton(_ index: Int) {
        guard
            let theme = experienceViewModel.carouselTheme[safe: index],
            let step = experienceViewModel.mobileContent?.steps[safe: index],
            let lastSection = step.sections.last,
            let button = lastSection.lines.last,
            button.type == .button
        else {
            return
        }

        // Set up the action button with the step's button configuration and theme.
        buttonAction.setupViews(
            line: button,
            action: step.buttonAction,
            theme: theme
        ) { [weak self] action in
            guard let self = self else { return }

            // If it's the last step, handle dismissal and trigger actions accordingly.
            if self.isLastStep() {
                self.dismiss(animated: true, completion: {
                    if action.deepLink != nil {
                        self.experienceViewModel.onDeepLinkTriggered()
                    }
                    self.experienceViewModel.onExperienceCompleted()
                })
            }
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
        // Update the progress view to indicate the new step.
        viewStepsProgress.setCurrentStep(step)

        // Bind the action button for the newly viewed step.
        bindActionButton(step)
    }

    /// Closes the carousel experience view and triggers the onDismiss event.
    func closeExperience() {
        dismiss(animated: true, completion: { [weak self] in
            guard let self = self else { return }
            // Notify the view model that the step was dismissed.
            self.experienceViewModel.onDismissStep(step: self.collectionView.currentIndex)
        })
    }
}
