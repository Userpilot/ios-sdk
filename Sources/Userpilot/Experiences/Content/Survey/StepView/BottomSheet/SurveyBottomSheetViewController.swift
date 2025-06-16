//
//  SurveyBottomSheetViewController.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 03/02/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A specialized view controller that displays a survey bottom sheet experience,
//  controlled by an `SurveyViewModel`. It allows dynamic content rendering,
//  user actions (like closing or triggering deep links), and customizable themes.
//  The view controller handles the user interface of the bottom sheet and binds the
//  experience state from the view model to update content and handle actions.
//

import UIKit

internal class SurveyBottomSheetViewController: BottomSheetViewController {

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
        setContent(content: surveyContainerView, withoutMargin: true)
        registerKeyboardNotifications()
    }

    deinit {
        removeKeyboardNotifications()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.surveyContainerView.resetContentHeight(size)
        }, completion: nil)
    }

}

// MARK: - View Model Binding
extension SurveyBottomSheetViewController {

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
                self?.dismissBottomSheet()
                return
            }
            self.setupGeneralStyle()
            self.surveyContainerView.bindStep(
                withTheme: surveyTheme,
                andContent: surveyContent,
                withLocal: self.surveyViewModel.isRTL,
                isDialogContent: false,
                andParentViewController: self,
                withSurveyContainerViewDelegate: self
            )
        }

        // trigger bind next survey step
        surveyViewModel.bindNextSurveyStep = { [weak self] in
            self?.surveyContainerView.bindStep(currentStep: self?.surveyViewModel.currentStep ?? 0)
        }

        // triger close survey
        surveyViewModel.closeSurvey = { [weak self] in
            self?.dismissBottomSheet()
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

extension SurveyBottomSheetViewController: UPExperience {
    func triggerCloseExpereince(manualClose: Bool) {
        dismissBottomSheet()
    }
}

// MARK: - SurveyContainerViewDelegate

extension SurveyBottomSheetViewController: SurveyContainerViewDelegate {

    func onClose() {
        surveyViewModel.onSurveyDismissed()
        dismissBottomSheet()
    }

    func onAction(_ answer: Any?, _ answerPayload: Payload) {
        surveyViewModel.moveToNextSurveyStep(answer, answerPayload)
    }

}
