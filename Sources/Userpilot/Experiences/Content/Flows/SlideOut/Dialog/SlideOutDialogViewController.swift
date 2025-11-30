//
//  SlideOutDialogViewController.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 20/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A view controller that presents a dialog with a slide-out container view.
//  It is designed to display content related to the user experience and allows for
//  dynamic updates via a provided view model.
//

import Foundation
import UIKit

internal class SlideOutDialogViewController: DialogViewController {

    // MARK: - UI Elements
    /// Container view that holds the slide-out content
    internal lazy var slideOutContainerView: SlideOutContainerView = {
        let slideOutContainerView = SlideOutContainerView()
        slideOutContainerView.translatesAutoresizingMaskIntoConstraints = false
        return slideOutContainerView
    }()

    // MARK: - Properties

    /// View model managing the carousel experience state and actions
    internal let experienceViewModel: ExperienceViewModel

    // MARK: - Initializers

    /// Initializes the view controller with the given view model.
    /// - Parameter experienceViewModel: The view model to bind with the dialog.
    init(experienceViewModel: ExperienceViewModel) {
        self.experienceViewModel = experienceViewModel
        super.init(nibName: nil, bundle: nil)
    }

    /// Required initializer with a coder, not implemented for programmatic instantiation.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        setContent(content: slideOutContainerView)
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
            self.resetWidth(size)
        }, completion: nil)
    }
}

// MARK: - View Model Binding
extension SlideOutDialogViewController {

    /// Binds the view model data to the view.
    func bindViewModel() {
        // Bind data from the view model and update the view accordingly.
        experienceViewModel.bindData = { [weak self] canBindData in
            guard
                let self = self,
                canBindData,
                let slideOutContent = self.experienceViewModel.slideOutContent
            else {
                self?.dismissDialog()
                return
            }
            self.setupGeneralStyle()
            self.slideOutContainerView.bindStep(
                slideOutContent,
                withTheme: self.experienceViewModel.slideOutTheme,
                andSlideOutContainerViewDelegate: self,
                andImageLoader: self.experienceViewModel.imageLoader,
                withLocal: experienceViewModel.isRTL)
        }

        // Trigger any initial actions or setup needed when the view model starts.
        experienceViewModel.onStart()
    }

    /// Sets up the general style for the dialog, including background color.
    func setupGeneralStyle() {
        // Set the background color for the view based on the theme.
        setBackgroundColor(experienceViewModel.slideOutTheme)
    }
}

// MARK: - SlideOutContainerViewDelegate
extension SlideOutDialogViewController: SlideOutContainerViewDelegate {

    /// Handles the close action from the slide-out container.
    func onClose() {
        dismissDialog { [weak self] in
            self?.experienceViewModel.onDismissStep()
        }
    }

    /// Handles actions triggered by buttons in the slide-out container.
    /// - Parameter action: The action triggered by the button.
    func onAction(_ action: ButtonAction?) {
        guard let action else { return }
        dismissDialog { [weak self] in
            self?.experienceViewModel.onExperienceCompleted()
            if action.deepLink != nil {
                self?.experienceViewModel.onDeepLinkTriggered()
            }
        }
    }
}

// MARK: - UPExperience

extension SlideOutDialogViewController: UPExperience {
    func triggerCloseExperience(isInternalEvent: Bool) {
        dismissDialog()
    }
}
