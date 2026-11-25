//
//  SlideOutBottomSheetViewController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 21/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  A specialized view controller that displays a slide-out bottom sheet experience,
//  controlled by an `ExperienceViewModel`. It allows dynamic content rendering,
//  user actions (like closing or triggering deep links), and customizable themes.
//  The view controller handles the user interface of the bottom sheet and binds the
//  experience state from the view model to update content and handle actions.
//

import Foundation
import UIKit

internal final class SlideOutBottomSheetViewController: BottomSheetViewController {

    // MARK: - UI Components

    /// The container view that holds the main content of the slide-out experience.
    /// This view dynamically binds to the content provided by the view model.
    private lazy var slideOutContainerView: SlideOutContainerView = {
        let slideOutContainerView = SlideOutContainerView()
        slideOutContainerView.translatesAutoresizingMaskIntoConstraints = false
        return slideOutContainerView
    }()

    // MARK: - Properties

    /// The view model responsible for managing the state and actions related to the carousel experience.
    /// It provides the data and behavior for the slide-out view, including user actions, theme data,
    /// and content to be displayed.
    internal let experienceViewModel: ExperienceViewModel

    /// Set by the first close of any kind; only that close may report the step, and taps during the dismiss
    /// animation do nothing.
    private var isClosing = false

    // MARK: - Initializers

    /// Initializes the `SlideOutBottomSheetViewController` with a given view model.
    ///
    /// - Parameter experienceViewModel: The view model that controls the experience data and behavior.
    init(experienceViewModel: ExperienceViewModel) {
        self.experienceViewModel = experienceViewModel
        super.init(nibName: nil, bundle: nil)
    }

    /// This initializer should not be used and will throw a fatal error if called.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    /// Sets up the content view and binds the view model once the view is loaded.
    override func viewDidLoad() {
        super.viewDidLoad()
        setContent(content: slideOutContainerView)
        bindViewModel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        experienceViewModel.onExperienceSeen()
    }

    /// Handle screen rotation
    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.slideOutContainerView.resetContentHeight(size)
        }, completion: nil)
    }
}

// MARK: - ViewModel Binding
extension SlideOutBottomSheetViewController {

    /// Binds the view model's data and updates the `slideOutContainerView` accordingly.
    /// This method is responsible for responding to any changes in the view model's state and ensuring the
    /// content displayed in the bottom sheet is kept up-to-date.
    func bindViewModel() {
        // Bind data and update the slide-out container view when the view model data changes.
        experienceViewModel.bindData = { [weak self] canBindData in
            guard
                let self = self,
                canBindData,
                let slideOutContent = self.experienceViewModel.slideOutContent
            else {
                self?.dismissBottomSheet {
                    self?.experienceViewModel.onExperienceDismissalCompleted()
                }
                return
            }

            // Update the UI based on the view model's content and theme.
            self.setupGeneralStyle()
            self.slideOutContainerView.bindStep(
                slideOutContent,
                withTheme: self.experienceViewModel.slideOutTheme,
                andSlideOutContainerViewDelegate: self,
                andImageLoader: self.experienceViewModel.imageLoader,
                withLocal: self.experienceViewModel.isRTL
            )
            if self.experienceViewModel.isFlowSegment {
                self.slideOutContainerView.bindStepsProgress(
                    stepsCount: self.experienceViewModel.progressStepsCount,
                    stepIndex: self.experienceViewModel.progressStepIndex(self.experienceViewModel.currentStep),
                    theme: self.experienceViewModel.slideOutTheme,
                    isRTL: self.experienceViewModel.isRTL
                )
            }
        }

        // Start any initial view model actions.
        experienceViewModel.onStart()
    }

    /// Configures the general appearance and behavior of the slide-out experience,
    /// including the background color and step progress.
    func setupGeneralStyle() {
        // Set the background color of the bottom sheet based on the theme provided by the view model.
        setBackgroundColor(experienceViewModel.slideOutTheme)
    }
}

// MARK: - SlideOutContainerViewDelegate
extension SlideOutBottomSheetViewController: SlideOutContainerViewDelegate {

    /// Reports the dismissal at the tap, before the dismiss animation; later taps do nothing.
    func onClose() {
        guard !isClosing else { return }
        isClosing = true
        experienceViewModel.onDismissStep()
        dismissBottomSheet { [weak self] in
            self?.experienceViewModel.onExperienceDismissalCompleted()
        }
    }

    /// Reports the button's outcome at the tap, before the dismiss animation; later taps do nothing.
    ///
    /// - Parameter action: A `ButtonAction` that defines the type of action triggered (e.g., deep-linking).
    func onAction(_ action: ButtonAction?) {
        guard let action, !isClosing else { return }
        isClosing = true
        experienceViewModel.onExperienceCompleted(action)
        dismissBottomSheet { [weak self] in
            self?.experienceViewModel.onExperienceDismissalCompleted()
        }
    }
}

// MARK: - UPExperienceDelegate

extension SlideOutBottomSheetViewController: UPExperienceDelegate {
    /// The host app's close (`manualClose`) reports like the close button, or nothing when a tap already closed
    /// the sheet. An SDK-driven close sends no event and fires no host callback, and taps during its dismissal
    /// report nothing.
    func triggerCloseExperience(
        manualClose: Bool,
        completion: (() -> Void)?
    ) {
        if manualClose, !isClosing {
            experienceViewModel.onDismissStep()
        }
        isClosing = true
        dismissBottomSheet { [weak self] in
            if let completion {
                completion()
            } else {
                self?.experienceViewModel.onExperienceDismissalCompleted()
            }
        }
    }
}
