//
//  UPExperienceThankYou.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The survey's thank-you screen, shown from its final completion module.
//

import SwiftUI

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
            // The survey's final "completed" module holds the thank-you text and button.
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
