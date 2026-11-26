//
//  SurveyListViewController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  This class is responsible for managing and displaying the survey experience.
//  It contains UI components such as a dismiss button, action button, and questions.
//  The class integrates with the `SurveyViewModel` to handle data binding and user interactions.
//

import UIKit

internal final class SurveyListViewController: UIViewController {

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

    /// Set by the first close of any kind; only that close may report, and taps during the dismiss
    /// animation do nothing.
    private(set) var isClosing = false

    // MARK: - Initializers

    /// Initializes the view controller with the given view model.
    init(surveyViewModel: SurveyViewModel) {
        self.surveyViewModel = surveyViewModel
        super.init(nibName: "SurveyListViewController", bundle: Userpilot.resourceBundle)
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
    @IBAction func onCloseButtonClicked(_ sender: UIButton) {
        guard !isClosing else { return }
        closeExperience()
    }

    /// True only for the first close of any kind; later closes and taps report nothing.
    func claimCloseReport() -> Bool {
        guard !isClosing else { return false }
        isClosing = true
        return true
    }
}

// MARK: - UPExperienceDelegate

extension SurveyListViewController: UPExperienceDelegate {
    /// The host app's close reports like the close button, or nothing when the survey is already closing.
    /// An SDK-driven close reports nothing, and taps during its dismissal report nothing.
    func triggerCloseExperience(
        manualClose: Bool,
        completion: (() -> Void)?
    ) {
        if manualClose {
            closeExperience(completion: completion)
        } else {
            isClosing = true
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
