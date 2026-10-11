//
//  UPExperienceSurvey.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Composes list, step and thank-you experiences from the same survey components.
//

import SwiftUI

internal struct UPExperienceSurvey: View {
    @ObservedObject var state: ExperienceRenderState
    let model: SurveyViewModel
    let width: CGFloat
    let region: ExperienceRenderRegion

    var body: some View {
        Group {
            if let survey = model.surveyContent, let theme = model.surveyTheme {
                VStack(spacing: UPExperienceLayout.spacing) {
                    if region == .header {
                        UPExperienceDismiss(color: theme.textColor, action: state.userClose)
                    }
                    if region == .content, survey.type == .list {
                        ForEach(survey.modules.filter { $0.type != .completed }, id: \.id) { step in
                            UPExperienceSurveyQuestion(state: state, step: step, theme: theme, width: width)
                        }
                    } else if region == .content, let step = survey.modules[safe: model.currentStep] {
                        UPExperienceSurveyQuestion(state: state, step: step, theme: theme, width: width).id(step.id)
                    }
                    if region == .footer {
                        UPExperienceButton(
                            title: buttonTitle(survey),
                            foreground: theme.primaryColorAsString.invertColor().color,
                            background: theme.primaryColor, fontFamily: theme.fontFamily,
                            enabled: isValid(survey), action: state.submitSurvey)
                    }
                    if region == .footer, survey.type == .step, theme.isStepsProgressEnabled,
                        theme.isStepsProgressBallType,
                        !survey.hasBranchingLogic,
                        survey.modules[safe: model.currentStep]?.type != .completed {
                        UPExperienceProgress(
                            count: survey.modules.count, current: model.currentStep,
                            color: theme.stepsProgressColor,
                            inactiveColor: theme.isStepsProgressColorManual
                                ? theme.stepsProgressColor : theme.backgroundColorAsString.invertColor().color)
                    }
                }
            }
        }
    }

    private func buttonTitle(_ survey: SurveyContent) -> String {
        survey.type == .list
            ? survey.metadata?.buttonLabel ?? "Next"
            : survey.modules[safe: model.currentStep]?.buttonLabel ?? "Next"
    }

    private func isValid(_ survey: SurveyContent) -> Bool {
        let questions =
            survey.type == .list
            ? survey.modules
            : survey.modules[safe: model.currentStep].map { [$0] } ?? []
        return questions.allSatisfy { state.answer(for: $0).isValid(for: $0) }
    }
}

internal struct UPExperienceThankYou: View {
    @ObservedObject var state: ExperienceRenderState
    let survey: SurveyContent
    let theme: SurveyTheme
    let region: ExperienceRenderRegion

    var body: some View {
        VStack(spacing: UPExperienceLayout.spacing) {
            if region == .header {
                UPExperienceDismiss(color: theme.textColor, action: state.userClose)
            }
            if let step = survey.modules.last {
                if region == .content {
                    UPExperienceText(
                        text: step.question ?? "", color: theme.textColor, fontFamily: theme.fontFamily,
                        size: CGFloat(ThemeHandler.DefaultValues.surveyTitleTextSize), bold: true)
                    UPExperienceText(text: step.subheader ?? "", color: theme.textColor, fontFamily: theme.fontFamily)
                }
                if region == .footer {
                    UPExperienceButton(
                        title: step.buttonLabel ?? "Next",
                        foreground: theme.primaryColorAsString.invertColor().color,
                        background: theme.primaryColor, fontFamily: theme.fontFamily,
                        action: state.finishThankYou)
                }
            }
        }
    }
}
