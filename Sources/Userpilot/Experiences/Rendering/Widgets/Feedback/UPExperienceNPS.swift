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

/// The NPS card for one region: the dismiss chip in the header; the score, follow-up or thank-you stage in the
/// body and footer; and the stage dots.
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
                            UPExperienceDismissAction(
                                title: closeTitle(content), action: state.userClose)
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
                            count: 2, current: state.npsStep)
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
            VStack(spacing: UPExperienceLayout.scaleLabelSpacing) {
                UPExperienceRating(
                    count: ThemeHandler.DefaultValues.npsDefaultLikertViewCount, selected: state.npsScore,
                    type: .numbers, zeroBasedLabels: true, width: width,
                    onSelect: state.selectNPSScore)
                UPExperienceRatingLabels(
                    low: content.content.survey.lowScore, high: content.content.survey.highScore)
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
                    placeholder: content.content.followUp.placeholder ?? "")
            }
            if region == .footer {
                HStack(spacing: 12) {
                    UPExperienceButton(
                        title: content.content.followUp.updateScore ?? "Update score",
                        secondary: true,
                        action: state.updateNPSScore)
                    UPExperienceButton(
                        title: content.content.followUp.submit ?? "Submit"
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
                UPExperienceText(text: completed.subheader ?? "")
            }
            // The thank-you button is optional; without it the user closes with the chip.
            if region == .footer, completed.button.enabled {
                UPExperienceButton(
                    title: completed.button.buttonText ?? "Done",
                    action: state.finishNPS)
            }
        }
    }

    private func title(_ text: String, _ theme: NPSTheme) -> some View {
        UPExperienceText(
            text: text,
            size: CGFloat(ThemeHandler.DefaultValues.surveyTitleTextSize), bold: true)
    }
}
