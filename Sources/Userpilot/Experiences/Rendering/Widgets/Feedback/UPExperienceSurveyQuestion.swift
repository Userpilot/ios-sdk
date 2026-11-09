//
//  UPExperienceSurveyQuestion.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  One survey question: its title, description and the answer control for its type.
//

import SwiftUI

/// One question: its title, description and answer control, spaced as on Android. Observes only its own answer, so
/// typing in one question doesn't redraw the others.
internal struct UPExperienceSurveyQuestion: View {
    let state: ExperienceRenderState
    @ObservedObject var answerModel: SurveyAnswerModel
    let step: SurveyStep
    let theme: SurveyTheme
    let width: CGFloat

    var body: some View {
        // Title, description just under it, then the answer control.
        VStack(alignment: .leading, spacing: 0) {
            // Required questions are marked with a red asterisk.
            UPExperienceText(
                text: step.question ?? "",
                color: theme.textColor, fontFamily: theme.fontFamily,
                size: CGFloat(ThemeHandler.DefaultValues.surveyTitleTextSize), bold: true,
                suffix: step.isRequired == true ? " *" : "")
            if let subtitle = step.subheader, !subtitle.isEmpty {
                UPExperienceText(
                    text: subtitle, color: theme.textColor, fontFamily: theme.fontFamily,
                    size: CGFloat(ThemeHandler.DefaultValues.surveyDescriptionTextSize))
                    .padding(.top, UPExperienceLayout.titleSpacing)
            }
            control
                .padding(.top, UPExperienceLayout.controlSpacing)
        }
    }

    @ViewBuilder
    private var control: some View {
        switch step.type {
        case .likert:
            VStack(spacing: UPExperienceLayout.scaleLabelSpacing) {
                UPExperienceRating(
                    items: step.ratingItems, selected: answerModel.value.rating,
                    primary: theme.primaryColor, filledContent: theme.buttonTextColor,
                    textColor: theme.textColor, fontFamily: theme.fontFamily, width: width
                ) { rating in
                    state.updateAnswer(for: step) { $0.rating = rating }
                }
                UPExperienceRatingLabels(
                    low: step.metadata?.lowScore, high: step.metadata?.highScore,
                    color: theme.textColor, fontFamily: theme.fontFamily)
            }
        case .multipleChoice:
            UPExperienceMultipleChoice(state: state, answerModel: answerModel, step: step, theme: theme)
        case .openText, .singleInput:
            UPExperienceQuestionInput(state: state, answerModel: answerModel, step: step, theme: theme)
        case .completed:
            EmptyView()
        }
    }
}
