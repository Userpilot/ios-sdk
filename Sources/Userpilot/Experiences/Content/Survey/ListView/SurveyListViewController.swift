//
//  SurveyListViewController.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This class is responsible for managing and displaying the survey experience.
//  It contains UI components such as a dismiss button, action button, and questions.
//  The class integrates with the `SurveyViewModel` to handle data binding and user interactions.
//

import UIKit

internal class SurveyListViewController: UIViewController {

    // MARK: - IBOutlets

    /// UPDismissButton & UPButtonView & containerView
    @IBOutlet internal weak var scrollView: UIScrollView!
    @IBOutlet internal weak var buttonDismiss: UPDismissButton!
    @IBOutlet internal weak var actionButton: UPButtonView!
    @IBOutlet internal weak var containerView: UIStackView!

    // MARK: - Properties

    /// View model managing the carousel experience state and actions.
    internal let surveyViewModel: SurveyViewModel
    private var appSemanticContentAttribute: UIUserInterfaceLayoutDirection?

    // MARK: - Initializers

    /// Initializes the view controller with the given view model.
    init(surveyViewModel: SurveyViewModel) {
        self.surveyViewModel = surveyViewModel
        super.init(nibName: "SurveyListViewController", bundle: Userpilot.resourceBundle)
    }

    /// Required initializer with a coder, not implemented for programmatic instantiation.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    /// Called after the view has been loaded. Sets up initial UI configurations and binds the view model.
    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.clearViews()
        setupViews()
        bindViewModel()
        registerKeyboardNotifications()

        if surveyViewModel.isRTL {
            appSemanticContentAttribute = UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute)
            UIView.appearance().semanticContentAttribute = .forceRightToLeft
        }
    }

    deinit {
        if let appSemanticContentAttribute {
            UIView.appearance().semanticContentAttribute = appSemanticContentAttribute == .leftToRight
            ? .forceLeftToRight : .forceRightToLeft
        }
        removeKeyboardNotifications()
    }

    // Override the preferredStatusBarStyle based on the current style
    override var preferredStatusBarStyle: UIStatusBarStyle {
        guard
            let theme = surveyViewModel.surveyTheme
        else { return .lightContent }
        return theme.isLightTheme ? .darkContent : .lightContent
    }

    // MARK: - Actions

    /// Action handler for the close button. Dismisses the experience view.
    /// - Parameter sender: The button triggering the close action.
    @IBAction func onCloseButtonClicked(_ sender: UIButton) {
        closeExperience()
    }
}

// MARK: - UPExperience

extension SurveyListViewController: UPExperience {
    func triggerCloseExpereince() {
        closeExperience()
    }
}
