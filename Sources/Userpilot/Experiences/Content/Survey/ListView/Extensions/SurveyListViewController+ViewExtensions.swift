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

    /// Setup UI locale depending on Experience content
    func setupLocale() {

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
        actionButton.updateEnableState(isEnabled: false)
        delay(1) { [weak self] in
            self?.checkActionButtonState()
        }
    }

    /// Process survey form answers.
    func processSurvey() {
        if actionButton.isEnabled {
            var answersPayload: [[String: Any]?] = []

            for index in 0..<containerView.subviews.count {
                let childView = containerView.subviews[index]
                if let experienceView = childView as? UPExperienceView {
                    answersPayload.append(experienceView.getAnswer())
                }
            }

            surveyViewModel.onSurveySubmitted(answersPayload: answersPayload)
            showThankYouMessage()
        }
    }

    /// Update button enabled state on views state updates
    func checkActionButtonState() {
        var isValidForm = true

        for index in 0..<containerView.subviews.count {
            let childView = containerView.subviews[index]
            if let experienceView = childView as? UPExperienceView {
                if !isValidForm {
                    break
                }
                isValidForm = experienceView.isValidAnswer()
            }
        }

        actionButton.updateEnableState(isEnabled: isValidForm)
    }

    /// Closes the carousel experience view and triggers the onDismiss event.
    func closeExperience() {
        surveyViewModel.onSurveyDismissed()
        dismiss(animated: true)
    }

    /// trigger thank you message & close the experience
    func showThankYouMessage() {
        closeExperience()
        surveyViewModel.showThankYouMessage()
    }
}

// MARK: - Bind custom views to the survey list view

internal extension SurveyListViewController {
    func bindSurveyViews() {
        guard
            let surveyContent = surveyViewModel.surveyContent,
            let surveyTheme = surveyViewModel.surveyTheme
        else { return }

        surveyContent.modules.forEach { surveryStep in
            switch surveryStep.type {
            case .likert:
                let likertView = UPLikertView()
                likertView.setupView(
                    surveyStep: surveryStep,
                    surveyTheme: surveyTheme,
                    viewStateProtocol: self
                )
                containerView.addArrangedSubview(likertView)

            case .multipleChoice:
                let multipleChoiceView = UPMultipleChoiceView()
                multipleChoiceView.setupView(
                    surveyStep: surveryStep,
                    surveyTheme: surveyTheme,
                    viewStateProtocol: self
                )
                containerView.addArrangedSubview(multipleChoiceView)

            case .openText:
                let openTextView = UPOpenTextView()
                openTextView.setupView(
                    surveyStep: surveryStep,
                    surveyTheme: surveyTheme,
                    viewStateProtocol: self
                )
                containerView.addArrangedSubview(openTextView)

            case .singleInput:
                let singleInputView = UPSingleInputView()
                singleInputView.setupView(
                    surveyStep: surveryStep,
                    surveyTheme: surveyTheme,
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
