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

/// The survey's thank-you screen, shown from its final completion module.
internal struct UPExperienceThankYou: View {
    @ObservedObject var state: ExperienceRenderState
    let survey: SurveyContent
    let theme: SurveyTheme
    let region: ExperienceRenderRegion

    var body: some View {
        VStack(spacing: UPExperienceLayout.spacing) {
            if region == .header {
                UPExperienceClose(action: state.userClose)
            }
            // The survey's final "completed" module holds the thank-you text and button.
            if let step = survey.modules.last {
                if region == .content {
                    UPExperienceText(
                        text: step.question ?? "",
                        size: CGFloat(ThemeHandler.DefaultValues.surveyTitleTextSize), bold: true)
                    UPExperienceText(text: step.subheader ?? "")
                }
                if region == .footer {
                    UPExperienceButton(
                        title: step.buttonLabel ?? "Next",
                        action: state.finishThankYou)
                }
            }
        }
    }
}
