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

extension SurveyListViewController {

    /// Configures general views constraints.
    func setupViews() {
        isModalInPresentation = true
        buildViewHierarchy()
        view.addTapGesture { [weak self] in
            self?.view.endEditing(true)
        }
        applyLiquidGlassChrome()
    }

    /// Paints the survey's background, as Liquid Glass or an opaque themed fill.
    ///
    /// This screen is full-screen, and it was originally excluded from glass on the assumption
    /// that a full-screen surface has nothing behind it to refract. That was wrong: the SDK
    /// renders inside its own overlay window above the host app, so a full-screen glass surface
    /// refracts the host app's UI — confirmed during the iOS 26 spike. Excluding it also left the
    /// full-screen survey inconsistent with the full-screen carousel, which does use glass.
    ///
    /// Gated on `.fullScreen`, alongside the carousel step card rather than the sheets and dialogs:
    /// this covers the whole screen with no backdrop between it and the host app, which is the
    /// legibility risk that opt-in exists to gate. `liquidGlassSheetsAndDialogs` does not reach it.
    ///
    /// Resolved centrally rather than built here: this used to construct a tinted material directly,
    /// so a survey list never saw `liquidGlassDefaultBackground` and never pinned an appearance from
    /// the theme's colour.
    private func applySurfaceBackground(theme: SurveyTheme) {
        glassBackground?.removeFromSuperview()
        glassBackground = nil

        let style = surveyViewModel.glassResolver.surfaceStyle(
            for: .fullScreen,
            themeBackground: theme.backgroundColor,
            themeBackdrop: .clear,
            themeBackdropEnabled: false,
            appearance: traitCollection.userInterfaceStyle
        )
        glassBackground = UPGlassEffectView.install(style.fill, in: view)
    }

    // MARK: - Liquid Glass chrome

    /// Applies the iOS 26 scroll edge effect so survey content fades where it meets the
    /// action button, instead of being cut off at a hard line.
    ///
    /// Pure rendering: it changes nothing about layout, so it cannot reflow or clip content.
    ///
    /// The content scrolls *beneath* the action button, so the effect has something to fade.
    /// `SurveyListViewController+Layout` pins the scroll view to the safe area when it floats; this
    /// adds the effect itself, the room the content needs to clear the button, and the button's
    /// registration as the element the effect shapes itself around.
    ///
    /// An earlier attempt floated the button by patching the XIB's constraints at runtime and was
    /// reverted for introducing layout ambiguity — see `scrollViewBottomConstraint()`.
    private func applyLiquidGlassChrome() {
        let resolver = surveyViewModel.glassResolver
        buttonDismiss.glassResolver = resolver
        actionButton.glassResolver = resolver
        scrollView.applyUPBottomScrollEdgeEffect(allowsGlass: floatsActionButton)

        // Without this the last question would rest permanently underneath the button. The
        // keyboard handling adjusts from this value rather than from zero.
        let clearance = scrollViewBottomClearance
        scrollView.contentInset.bottom = clearance
        scrollView.verticalScrollIndicatorInsets.bottom = clearance

        actionButton.registerUPScrollEdgeContainer(
            for: scrollView,
            edge: .bottom,
            allowsGlass: floatsActionButton
        )
    }

    /// Configures the general style for the carousel experience view.
    /// Sets up background color, dismiss button visibility, and step progress indicator.
    func setupGeneralStyle() {
        // Get the theme for the current step index.
        guard let theme = surveyViewModel.surveyTheme else { return }

        // update status bar color
        setNeedsStatusBarAppearanceUpdate()

        // update background
        applySurfaceBackground(theme: theme)

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
    func closeExperience(completion: (() -> Void)? = nil) {
        surveyViewModel.onSurveyDismissed()
        dismiss(animated: true) { [weak self] in
            if let completion {
                completion()
            } else {
                self?.surveyViewModel.onExperienceDismissalCompleted()
            }
        }
    }

    /// trigger thank you message & close the experience
    func showThankYouMessage() {
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            let willPresentThankYouMessage = self.surveyViewModel.showThankYouMessage()
            if !willPresentThankYouMessage {
                self.surveyViewModel.onExperienceDismissalCompleted()
            }
        }
    }
}

// MARK: - Bind custom views to the survey list view

extension SurveyListViewController {
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
                singleInputView.glassResolver = surveyViewModel.glassResolver
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
