//
//  CarouselExperienceViewController+ViewExtensions.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  This extension provides methods to handle the setup and interactions for
//  the carousel experience, including configuring the view themes, managing
//  action button bindings, and handling step transitions. It defines helper
//  functions for updating the step progress view and closing the experience.
//

import Foundation
import UIKit

extension CarouselExperienceViewController {

    /// Configures general views constraints.
    func setupViews() {
        isModalInPresentation = true

        // The counter shares the dots' row; the bar lies along the top of the safe area.
        view.addSubview(viewStepsCounter)
        view.addSubview(viewStepsBarProgress)
        NSLayoutConstraint.activate([
            viewStepsCounter.leadingAnchor.constraint(equalTo: viewStepsProgress.leadingAnchor),
            viewStepsCounter.trailingAnchor.constraint(equalTo: viewStepsProgress.trailingAnchor),
            viewStepsCounter.centerYAnchor.constraint(equalTo: viewStepsProgress.centerYAnchor),
            viewStepsCounter.heightAnchor.constraint(equalToConstant: Constants.Theme.stepsProgressDotsHeight),

            viewStepsBarProgress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewStepsBarProgress.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            viewStepsBarProgress.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            viewStepsBarProgress.heightAnchor.constraint(equalToConstant: Constants.Theme.stepsProgressBarHeight)
        ])
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
        } else {
            buttonDismissContainerView.semanticContentAttribute = .forceLeftToRight
            collectionView.semanticContentAttribute = .forceLeftToRight
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
            let page = experienceViewModel.currentStep
            // A one-step or bad-count Flow hides progress; standalone content (nil) keeps showing it.
            guard experienceViewModel.flowStepsProgress(page)?.isShown != false else {
                viewStepsProgress.isHidden = true
                viewStepsCounter.isHidden = true
                viewStepsBarProgress.isHidden = true
                return
            }
            let stepIndex = experienceViewModel.progressStepIndex(page)
            let stepsCount = experienceViewModel.progressStepsCount
            // A Flow step whose theme draws a bar or a counter shows it instead of the dots; each step's theme
            // decides again.
            let showsBar = experienceViewModel.isFlowSegment && theme.isStepsProgressBar
            let showsCounter = experienceViewModel.isFlowSegment && theme.isStepsProgressCounter
            viewStepsProgress.isHidden = showsBar || showsCounter
            viewStepsCounter.isHidden = !showsCounter
            viewStepsBarProgress.isHidden = !showsBar
            if showsBar {
                viewStepsBarProgress.setupView(
                    stepsCount: stepsCount,
                    theme: theme,
                    isRTL: experienceViewModel.isRTL
                )
                viewStepsBarProgress.setCurrentStep(stepIndex)
            } else if showsCounter {
                viewStepsCounter.setupView(
                    stepsCount: stepsCount,
                    theme: theme,
                    isRTL: experienceViewModel.isRTL
                )
                viewStepsCounter.setCurrentStep(stepIndex)
            } else {
                viewStepsProgress.setupView(
                    stepsCount: stepsCount,
                    theme: theme,
                    isRTL: experienceViewModel.isRTL
                )
                viewStepsProgress.setCurrentStep(stepIndex)
            }
        }
    }

    /// Process action button -> action: earlier steps page forward; the last step's first action reports and
    /// dismisses. A closing carousel ignores the tap: it neither reports nor pages.
    func onActionButtonClicked(_ action: ButtonAction?) {
        guard let action, !isClosing else { return }
        guard isLastStep(), claimCloseReport() else { return }
        experienceViewModel.onExperienceCompleted(action)
        dismiss(animated: true, completion: { [weak self] in
            self?.experienceViewModel.onExperienceDismissalCompleted()
        })
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
        viewStepsProgress.setCurrentStep(experienceViewModel.progressStepIndex(step))
    }

    /// Reports the dismissal unless a tap or manual close already did, then closes the carousel.
    func closeExperience(completion: (() -> Void)? = nil) {
        if claimCloseReport() {
            experienceViewModel.onDismissStep()
        }
        dismiss(animated: true) { [weak self] in
            if let completion {
                completion()
            } else {
                self?.experienceViewModel.onExperienceDismissalCompleted()
            }
        }
    }
}
