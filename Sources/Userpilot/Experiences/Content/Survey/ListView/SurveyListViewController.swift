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
//  The view hierarchy is built in code, in `SurveyListViewController+Layout`. It used to come from
//  a XIB, at the cost of a `Userpilot.resourceBundle` lookup on a nib name no compiler checks, its
//  own copies of sizes the SDK already names, and a scroll content width that was wrong. Authoring
//  it in code is also what let the floating action button ship: that layout has two shapes
//  depending on whether Liquid Glass is in play, which a XIB cannot express.
//

import UIKit

internal class SurveyListViewController: UIViewController {

    // MARK: - Views

    /// Row the dismiss button sits in. It also sets where the scrolling content starts.
    internal let buttonDismissContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Close button to dismiss the survey.
    internal let buttonDismiss: UPDismissButton = {
        let button = UPDismissButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// The survey's submit button.
    internal let actionButton = UPButtonView()

    /// Scrolls the questions when they outgrow the screen.
    ///
    /// `contentInsetAdjustmentBehavior` is pinned to `.always` rather than left at `.automatic`,
    /// whose adjustment depends on whether the axis is currently scrollable. When the action button
    /// floats, this scroll view reaches the display's bottom edge, and the home indicator's inset
    /// has to be added to the button's clearance for the content to clear both.
    internal let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.clipsToBounds = true
        view.contentInsetAdjustmentBehavior = .always
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Stacks the survey's questions.
    internal let containerView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.spacing = ThemeHandler.DefaultValues.surveyListQuestionSpacing
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Properties

    /// View model managing the carousel experience state and actions.
    internal let surveyViewModel: SurveyViewModel
    private var appSemanticContentAttribute: UIUserInterfaceLayoutDirection?

    /// Glass background behind the survey, when the surface renders as glass. Held so it can be
    /// replaced if the theme is re-applied.
    internal var glassBackground: UPGlassEffectView?

    // MARK: - Initializers

    /// Initializes the view controller with the given view model.
    init(surveyViewModel: SurveyViewModel) {
        self.surveyViewModel = surveyViewModel
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        surveyViewModel.onExperienceSeen()
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
        ExternalKeyboardManagerCompat.disableIQKeyboardManager(for: [SurveyListViewController.self])

        appSemanticContentAttribute = UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute)

        // This flag tells automatic screen tracking to ignore screens that the SDK is presenting
        objc_setAssociatedObject(
            self,
            &ScreenNameTracker.untrackedScreenKey,
            true,
            .OBJC_ASSOCIATION_RETAIN
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if surveyViewModel.isRTL {
            UIView.appearance().semanticContentAttribute = .forceRightToLeft
        } else {
            UIView.appearance().semanticContentAttribute = .forceLeftToRight
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let appSemanticContentAttribute {
            UIView.appearance().semanticContentAttribute = appSemanticContentAttribute == .leftToRight
            ? .forceLeftToRight : .forceRightToLeft
        }
    }

    deinit {
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
    @objc func onCloseButtonClicked(_ sender: UIButton) {
        closeExperience()
    }
}

// MARK: - UPExperience

extension SurveyListViewController: UPExperience {
    func triggerCloseExperience(
        manualClose: Bool,
        completion: (() -> Void)?
    ) {
        if manualClose {
            closeExperience(completion: completion)
        } else {
            dismiss(animated: true) { [weak self] in
                if let completion {
                    completion()
                } else {
                    self?.surveyViewModel.onExperienceDismissalCompleted()
                }
            }
        }
    }
}
