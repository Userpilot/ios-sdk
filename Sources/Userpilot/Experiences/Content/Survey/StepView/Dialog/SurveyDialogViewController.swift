//
//  SurveyDialogViewController.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 30/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A specialized view controller that displays a survey dialog experience,
//  controlled by an `SurveyViewModel`. It allows dynamic content rendering,
//  user actions (like closing or triggering deep links), and customizable themes.
//  The view controller handles the user interface of the bottom sheet and binds the
//  experience state from the view model to update content and handle actions.
//

import Foundation
import UIKit

internal class SurveyDialogViewController: DialogViewController {

    // MARK: - UI Elements
    /// Container view that holds the slide-out content
    internal lazy var surveyContainerView: SurveyContainerView = {
        let surveyContainerView = SurveyContainerView()
        surveyContainerView.translatesAutoresizingMaskIntoConstraints = false
        return surveyContainerView
    }()

    // MARK: - Properties

    /// View model managing the carousel experience state and actions
    internal let surveyViewModel: SurveyViewModel

    // MARK: - Initializers

    /// Initializes the view controller with the given view model.
    /// - Parameter experienceViewModel: The view model to bind with the dialog.
    init(surveyViewModel: SurveyViewModel) {
        self.surveyViewModel = surveyViewModel
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
        setContent(content: surveyContainerView, withMargin: CGFloat(-40))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        surveyViewModel.onExperienceSeen()
    }

    /// Handle screen rotation
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.surveyContainerView.resetContentHeight(size)
            self.resetWidth(size)
        }, completion: nil)
    }

}

// MARK: - View Model Binding
extension SurveyDialogViewController {

    /// Binds the view model data to the view.
    func bindViewModel() {
        // Bind data from the view model and update the view accordingly.
        surveyViewModel.bindData = { [weak self] canBindData in
            guard
                let self = self,
                canBindData,
                let surveyContent = self.surveyViewModel.surveyContent,
                let surveyTheme = self.surveyViewModel.surveyTheme
            else {
                self?.dismissDialog {
                    self?.surveyViewModel.onExperienceDismissalCompleted()
                }
                return
            }
            self.setupGeneralStyle()
            self.surveyContainerView.bindStep(
                withTheme: surveyTheme,
                andContent: surveyContent,
                withLocal: self.surveyViewModel.isRTL,
                isDialogContent: true,
                andParentViewController: self,
                withSurveyContainerViewDelegate: self
            )
        }

        // trigger bind next survey step
        surveyViewModel.bindNextSurveyStep = { [weak self] in
            guard let self else { return }
            self.surveyContainerView.bindStep(currentStep: self.surveyViewModel.currentStep)
        }

        // triger close survey
        surveyViewModel.closeSurvey = { [weak self] in
            self?.dismissDialog {
                self?.surveyViewModel.onExperienceDismissalCompleted()
            }
        }

        // Trigger any initial actions or setup needed when the view model starts.
        surveyViewModel.onStart()
    }

    /// Sets up the general style for the dialog, including background color.
    func setupGeneralStyle() {
        guard let theme = surveyViewModel.surveyTheme else { return }
        setBackgroundColor(theme)
    }
}

// MARK: - UPExperience

extension SurveyDialogViewController: UPExperience {
    func triggerCloseExperience(
        manualClose: Bool,
        completion: (() -> Void)?
    ) {
        dismissDialog { [weak self] in
            if let completion {
                completion()
            } else {
                self?.surveyViewModel.onExperienceDismissalCompleted()
            }
        }
    }
}

// MARK: - SurveyContainerViewDelegate

extension SurveyDialogViewController: SurveyContainerViewDelegate {

    func onClose() {
        surveyViewModel.onSurveyDismissed()
        dismissDialog { [weak self] in
            self?.surveyViewModel.onExperienceDismissalCompleted()
        }
    }

    func onAction(
        _ answer: Any?,
        _ answerPayload: Payload
    ) {
        surveyViewModel.moveToNextSurveyStep(answer, answerPayload)
    }

}
