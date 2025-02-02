//
//  SurveyDialogViewController.swift
//  Userpilot
//
//  Created by Motasem Hamed on 30/01/2025.
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
        setContent(content: surveyContainerView)
    }

//    /// Handle screen rotation
//    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//        super.viewWillTransition(to: size, with: coordinator)
//        coordinator.animate(alongsideTransition: { [weak self] _ in
//            guard let self else { return }
//            self.slideOutContainerView.resetContentHeight(size)
//            self.resetWidth(size)
//        }, completion: nil)
//    }
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
                self?.dismissDialog()
                return
            }
            self.setupGeneralStyle()
            self.surveyContainerView.bindStep(
                withTheme: surveyTheme,
                andContent: surveyContent,
                withLocal: self.surveyViewModel.isRTL,
                surveyContainerViewDelegate: self
            )
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
    func triggerCloseExpereince() {
        dismissDialog()
    }
}

// MARK: - UPExperience

extension SurveyDialogViewController: SurveyContainerViewDelegate {
    
    func onClose() {

    }

    func onAction(_ answer: Any?, _ answerPayload: Payload) {
        // surveyViewModel.moveToNextSurveyStep(answer, answerPayload)
    }

    func onOpenLink() {

    }
}
