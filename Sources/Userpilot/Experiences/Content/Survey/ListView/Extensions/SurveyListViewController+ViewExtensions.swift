//
//  SurveyListViewController+ViewExtensions.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This extension provides methods to handle the setup and interactions for
//  the survey experience, including configuring the view themes, managing
//  action button bindings and setup questions.
//

import Foundation
import UIKit

internal extension SurveyListViewController {

    /// Configures general views constraints.
    func setupViews() {
        isModalInPresentation = true
        view.addTapGesture { [weak self] in
            self?.view.endEditing(true)
        }
    }

    /// Configures the general style for the carousel experience view.
    /// Sets up background color, dismiss button visibility, and step progress indicator.
    func setupGeneralStyle() {
        // Get the theme for the current step index.
        guard let theme = surveyViewModel.surveyTheme else { return }

        // update status bar color
        setNeedsStatusBarAppearanceUpdate()

        // update background
        view.backgroundColor = theme.backgroundColor

        // Configure the dismiss button based on the theme settings.
        buttonDismiss.setupView(theme: theme)

        // Set up the action button with the step's button configuration and theme.
        actionButton.setupViews(
            title: surveyViewModel.surveyContent?.metadata?.buttonLabel ?? "Next",
            theme: theme
        ) { [weak self] _ in
            self?.processSurvey()
        }
        actionButton.updateEnableState(isEnabled: !surveyViewModel.isAnyQuestionRequired())
    }

    /// Process survey form answers.
    func processSurvey() {
        guard actionButton.isEnabled else { return }

        let answersPayload = containerView.subviews
            .compactMap { ($0 as? UPExperienceView)?.getAnswerPayload() }

        surveyViewModel.onSurveyListSubmitted(answersPayload: answersPayload)
        showThankYouMessage()
    }

    /// Update button enabled state based on views' validation status.
    func checkActionButtonState() {
        let isValidForm = containerView.subviews
            .compactMap { $0 as? UPExperienceView }
            .allSatisfy { $0.isValidAnswer() }

        actionButton.updateEnableState(isEnabled: isValidForm)
    }

    /// Closes the carousel experience view and triggers the onDismiss event.
    func closeExperience() {
        surveyViewModel.onSurveyDismissed()
        dismiss(animated: true)
    }

    /// trigger thank you message & close the experience
    func showThankYouMessage() {
        dismiss(animated: true)
        surveyViewModel.showThankYouMessage()
    }
}

// MARK: - Bind custom views to the survey list view

internal extension SurveyListViewController {
    // swiftlint:disable:next function_body_length
    func bindSurveyViews() {
        guard
            let surveyContent = surveyViewModel.surveyContent,
            let surveyTheme = surveyViewModel.surveyTheme
        else { return }

        surveyContent.modules.forEach { surveryStep in
            switch surveryStep.type {
            case .likert:
                let likertView = UPLikertView(margin: 20)
                likertView.setupView(
                    surveyStep: surveryStep,
                    surveyTheme: surveyTheme,
                    isListView: true,
                    isDialog: false,
                    isRTL: surveyViewModel.isRTL,
                    viewStateProtocol: self
                )
                containerView.addArrangedSubview(likertView)

            case .multipleChoice:
                let multipleChoiceView = UPMultipleChoiceView(margin: 20)
                multipleChoiceView.setupView(
                    surveyStep: surveryStep,
                    surveyTheme: surveyTheme,
                    isListView: true,
                    isRTL: surveyViewModel.isRTL,
                    viewStateProtocol: self
                )
                containerView.addArrangedSubview(multipleChoiceView)

            case .openText:
                let openTextView = UPOpenTextView(margin: 20)
                openTextView.setupView(
                    surveyStep: surveryStep,
                    surveyTheme: surveyTheme,
                    isListView: true,
                    isRTL: surveyViewModel.isRTL,
                    viewStateProtocol: self
                )
                containerView.addArrangedSubview(openTextView)

            case .singleInput:
                let singleInputView = UPSingleInputView(margin: 20)
                singleInputView.setupView(
                    surveyStep: surveryStep,
                    surveyTheme: surveyTheme,
                    isListView: true,
                    isRTL: surveyViewModel.isRTL,
                    viewStateProtocol: self,
                    parentViewController: self
                )
                containerView.addArrangedSubview(singleInputView)

            default:
                break
            }
        }
    }
}
