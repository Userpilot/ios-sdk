//
//  SlideOutBottomSheetViewController.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A specialized view controller that displays a slide-out bottom sheet experience,
//  controlled by an `ExperienceViewModel`. It allows dynamic content rendering,
//  user actions (like closing or triggering deep links), and customizable themes.
//  The view controller handles the user interface of the bottom sheet and binds the
//  experience state from the view model to update content and handle actions.
//

import Foundation
import UIKit

internal class SlideOutBottomSheetViewController: BottomSheetViewController {

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

    /// Handle screen rotation
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.slideOutContainerView.resetContentHeight(size)
        }, completion: nil)
    }
}

// MARK: - ViewModel Binding
internal extension SlideOutBottomSheetViewController {

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
                self?.dismissBottomSheet()
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

    /// Dismisses the bottom sheet when the close action is triggered.
    func onClose() {
        dismissBottomSheet { [weak self] in
            self?.experienceViewModel.onDismissStep()
        }
    }

    /// Handles actions triggered from buttons within the slide-out experience.
    ///
    /// - Parameter action: A `ButtonAction` that defines the type of action triggered (e.g., deep-linking).
    func onAction(_ action: ButtonAction?) {
        guard let action else { return }
        dismissBottomSheet { [weak self] in
            self?.experienceViewModel.onExperienceCompleted()
            if action.deepLink != nil {
                self?.experienceViewModel.onDeepLinkTriggered()
            }
        }
    }
}

// MARK: - UPExperience

extension SlideOutBottomSheetViewController: UPExperience {
    func triggerCloseExpereince() {
        dismissBottomSheet()
    }
}
