//
//  UPExperienceNPS.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Composes NPS score, follow-up and completion from reusable declarative primitives.
//

import SwiftUI

internal struct UPExperienceNPS: View {
    @ObservedObject var state: ExperienceRenderState
    let model: NPSViewModel
    let width: CGFloat
    let region: ExperienceRenderRegion

    var body: some View {
        Group {
            if let content = model.npsContent, let theme = model.npsTheme {
                VStack(spacing: UPExperienceLayout.spacing) {
                    // NPS closes with a labelled chip ("Ask me later", "Close") rather than an icon.
                    if region == .header {
                        HStack {
                            Spacer()
                            Button(action: state.userClose) {
                                Text(closeTitle(content))
                                    .experienceFont(theme.fontFamily, size: UPExperienceLayout.bodySize)
                            }
                            .foregroundColor(Color(theme.textColor))
                            .padding(12)
                            .background(Color(theme.textColor).opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                    // Stage 0 scores, 1 asks for feedback, 2 thanks. Only the score stage has no footer.
                    if region == .content, state.npsStep == 0 {
                        score(content, theme)
                    } else if region != .header, state.npsStep == 1 {
                        followUp(content, theme)
                    } else if region != .header, state.npsStep == 2, let completed = state.completedData {
                        completion(completed, theme)
                    }
                    if region == .footer, theme.isStepsProgressEnabled,
                        theme.isStepsProgressBallType, state.npsStep < 2 {
                        UPExperienceProgress(
                            count: 2, current: state.npsStep,
                            color: theme.isStepsProgressColorManual
                                ? theme.stepsProgressColor : theme.primaryColor,
                            inactiveColor: theme.isStepsProgressColorManual
                                ? theme.stepsProgressColor : theme.backgroundColorAsString.invertColor().color)
                    }
                }
            }
        }
    }

    private func closeTitle(_ content: NPSContent) -> String {
        switch state.npsStep {
        case 0: return content.content.survey.askMeLater ?? "Ask me later"
        case 1: return content.content.followUp.close ?? "Close"
        default: return state.completedData?.button.close ?? "Close"
        }
    }

    private func score(_ content: NPSContent, _ theme: NPSTheme) -> some View {
        VStack(spacing: UPExperienceLayout.spacing) {
            if let logo = theme.logo, !logo.isEmpty {
                let size = CGSize(width: 100, height: 100)
                UPExperienceImage(
                    model: state.imageModel(url: logo, blurHash: nil, size: size, loader: model.imageLoader),
                    size: size)
            }
            title(content.content.survey.question ?? "", theme)
            UPExperienceRating(
                items: UPRatingItem.npsScale, selected: state.npsScore,
                primary: theme.primaryColor, textColor: theme.textColor,
                fontFamily: theme.fontFamily, width: width, onSelect: state.selectNPSScore)
            HStack(alignment: .top) {
                UPExperienceText(
                    text: content.content.survey.lowScore ?? "", color: theme.textColor,
                    fontFamily: theme.fontFamily, size: UPExperienceLayout.footnoteSize)
                UPExperienceText(
                    text: content.content.survey.highScore ?? "", color: theme.textColor,
                    fontFamily: theme.fontFamily, size: UPExperienceLayout.footnoteSize, alignment: .trailing)
            }
        }
    }

    private func followUp(_ content: NPSContent, _ theme: NPSTheme) -> some View {
        VStack(spacing: UPExperienceLayout.spacing) {
            if region == .content {
                title(state.followUp?.question ?? "", theme)
                UPExperienceTextArea(
                    // The state trims the feedback to 500 characters as it's typed.
                    text: SwiftUI.Binding(get: { state.npsFeedback }, set: { state.npsFeedback = $0 }),
                    textColor: theme.textColor, placeholderColor: theme.textSecondaryColorAlpha80,
                    fontFamily: theme.fontFamily, placeholder: content.content.followUp.placeholder ?? "")
            }
            if region == .footer {
                HStack(spacing: 12) {
                    UPExperienceButton(
                        title: content.content.followUp.updateScore ?? "Update score",
                        foreground: theme.textColor, background: .clear, fontFamily: theme.fontFamily,
                        borderColor: ThemeHandler.DefaultValues.grayColor, borderWidth: 1,
                        action: state.updateNPSScore)
                    UPExperienceButton(
                        title: content.content.followUp.submit ?? "Submit",
                        foreground: theme.primaryColorAsString.invertColor().color,
                        background: theme.primaryColor, fontFamily: theme.fontFamily
                    ) {
                        state.submitNPS()
                    }
                }
            }
        }
    }

    private func completion(_ completed: CompletedData, _ theme: NPSTheme) -> some View {
        VStack(spacing: UPExperienceLayout.spacing) {
            if region == .content {
                title(completed.header ?? "", theme)
                UPExperienceText(text: completed.subheader ?? "", color: theme.textColor, fontFamily: theme.fontFamily)
            }
            // The thank-you button is optional; without it the user closes with the chip.
            if region == .footer, completed.button.enabled {
                UPExperienceButton(
                    title: completed.button.buttonText ?? "Done",
                    foreground: theme.primaryColorAsString.invertColor().color,
                    background: theme.primaryColor, fontFamily: theme.fontFamily,
                    action: state.finishNPS)
            }
        }
    }

    private func title(_ text: String, _ theme: NPSTheme) -> some View {
        UPExperienceText(
            text: text, color: theme.textColor, fontFamily: theme.fontFamily,
            size: CGFloat(ThemeHandler.DefaultValues.surveyTitleTextSize), bold: true)
    }
}
