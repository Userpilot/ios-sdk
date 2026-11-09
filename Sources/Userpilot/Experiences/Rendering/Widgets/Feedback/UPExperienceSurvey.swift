//
//  UPExperienceSurvey.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Composes list and step surveys from the shared survey components.
//

import SwiftUI

/// A list survey (every question at once) or a step survey (one question per step) for one region, with its
/// submit button and step progress.
internal struct UPExperienceSurvey: View {
    @ObservedObject var state: ExperienceRenderState
    let model: SurveyViewModel
    let width: CGFloat
    let region: ExperienceRenderRegion

    var body: some View {
        Group {
            if let survey = model.surveyContent, let theme = model.surveyTheme {
                // The body holds only questions, so its spacing is the gap between list questions.
                VStack(spacing: region == .content ? UPExperienceLayout.questionSpacing : UPExperienceLayout.spacing) {
                    if region == .header {
                        UPExperienceClose(color: theme.textColor, action: state.userClose)
                    }
                    // A list survey shows every question at once; a step survey shows the current one.
                    if region == .content, survey.type == .list {
                        ForEach(survey.modules.filter { $0.type != .completed }, id: \.id) { step in
                            UPExperienceSurveyQuestion(
                                state: state, answerModel: state.answerModel(for: step), step: step, theme: theme,
                                width: width)
                        }
                    } else if region == .content, let step = survey.modules[safe: model.currentStep] {
                        UPExperienceSurveyQuestion(
                            state: state, answerModel: state.answerModel(for: step), step: step, theme: theme,
                            width: width
                        // A new question is a new view, so pickers and focus don't carry over.
                        ).id(step.id)
                    }
                    if region == .footer {
                        UPExperienceButton(
                            title: buttonTitle(survey),
                            foreground: theme.buttonTextColor,
                            background: theme.primaryColor, fontFamily: theme.fontFamily,
                            enabled: state.canSubmit, action: state.submitSurvey)
                    }
                    // Dot progress sits under the button; the bar style is drawn at the top of the card.
                    if region == .footer, survey.type == .step, theme.isStepsProgressEnabled,
                        theme.isStepsProgressBallType,
                        !survey.hasBranchingLogic,
                        survey.modules[safe: model.currentStep]?.type != .completed {
                        UPExperienceProgress(
                            count: survey.modules.count, current: model.currentStep,
                            color: theme.stepsProgressColor,
                            inactiveColor: theme.inactiveProgressColor)
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
}
