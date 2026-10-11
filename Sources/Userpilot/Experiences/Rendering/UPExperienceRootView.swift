//
//  UPExperienceRootView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Assembles experience components from prepared content while observing one presentation state owner.
//

import SwiftUI

internal enum ExperienceRenderRegion { case header, content, footer }

/// Shared element rhythm; native card margins remain separate from authored content.
internal enum UPExperienceLayout {
    static let spacing: CGFloat = 16
    static let sheetMargin: CGFloat = 16
}

internal struct UPExperienceRootView: View {
    @ObservedObject var state: ExperienceRenderState
    let width: CGFloat
    var region: ExperienceRenderRegion = .content

    var body: some View {
        VStack(spacing: 0) {
            if state.isReady {
                if region == .header, let progress = state.topProgress {
                    progress
                }
                content
                    .padding(.horizontal, ThemeHandler.DefaultValues.contentMargin)
                    .padding(.vertical, verticalPadding)
            }
        }
        .frame(width: width)
        .environment(\.layoutDirection, state.isRTL ? .rightToLeft : .leftToRight)
        .disabled(state.isClosing)
    }

    private var verticalPadding: CGFloat {
        region == .content || (region == .header && !state.hasHeader) ? 0 : UPExperienceLayout.spacing
    }

    @ViewBuilder
    private var content: some View {
        let contentWidth = max(1, width - ThemeHandler.DefaultValues.contentMargin * 2)
        switch state.content {
        case .flow(let model): UPExperienceFlow(state: state, model: model, width: contentWidth, region: region)
        case .survey(let model): UPExperienceSurvey(state: state, model: model, width: contentWidth, region: region)
        case .nps(let model): UPExperienceNPS(state: state, model: model, width: contentWidth, region: region)
        case .thankYou(let survey, let theme):
            UPExperienceThankYou(state: state, survey: survey, theme: theme, region: region)
        }
    }
}

extension ExperienceRenderState {
    var hasHeader: Bool {
        if case .flow(let model) = content { return flowTheme(model).isDismissButtonEnabled }
        return true
    }

    var topProgress: UPExperienceProgress? {
        switch content {
        case .survey(let model):
            guard let survey = model.surveyContent, let theme = model.surveyTheme,
                survey.type == .step, !survey.hasBranchingLogic, theme.isStepsProgressEnabled,
                !theme.isStepsProgressBallType, survey.modules[safe: model.currentStep]?.type != .completed
            else { return nil }
            return UPExperienceProgress(count: survey.modules.count, current: model.currentStep,
                                        color: theme.stepsProgressColor, balls: false)
        case .nps(let model):
            guard let theme = model.npsTheme, theme.isStepsProgressEnabled,
                !theme.isStepsProgressBallType, npsStep < 2 else { return nil }
            return UPExperienceProgress(count: 2, current: npsStep,
                                        color: theme.isStepsProgressColorManual
                                            ? theme.stepsProgressColor : theme.primaryColor, balls: false)
        default: return nil
        }
    }

    var isRTL: Bool {
        switch content {
        case .flow(let model): return model.isRTL
        case .survey(let model): return model.isRTL
        case .nps(let model): return model.isRTL
        case .thankYou(let survey, _): return survey.localeCode.isRTL == true
        }
    }

    var backgroundColor: UIColor {
        switch content {
        case .flow(let model): return flowTheme(model).backgroundColor
        case .survey(let model): return model.surveyTheme?.backgroundColor ?? .white
        case .nps(let model): return model.npsTheme?.backgroundColor ?? .white
        case .thankYou(_, let theme): return theme.backgroundColor
        }
    }

    var backdropColor: UIColor {
        switch content {
        case .flow(let model):
            let theme = flowTheme(model)
            return theme.backdropEnabled ? theme.backdropBackground : .clear
        case .survey(let model):
            guard let theme = model.surveyTheme else { return .clear }
            return theme.backdropEnabled ? theme.backdropBackground : .clear
        case .nps: return UIColor.black.withAlphaComponent(0.4)
        case .thankYou(_, let theme): return theme.backdropEnabled ? theme.backdropBackground : .clear
        }
    }

    var cornerRadius: CGFloat {
        switch content {
        case .flow: return 24
        case .survey(let model): return model.surveyTheme?.borderRadius ?? 24
        case .nps(let model): return model.npsTheme?.borderRadius ?? 24
        case .thankYou(_, let theme): return theme.borderRadius
        }
    }

    var verticalAlignment: ContentAlignmentType {
        guard case .flow(let model) = content, model.flowContent?.type == .carousel else { return .top }
        return flowTheme(model).contentAlignment
    }

    private func flowTheme(_ model: ExperienceViewModel) -> ExperienceTheme {
        model.flowContent?.type == .carousel
            ? model.carouselTheme[safe: model.currentStep] ?? ExperienceTheme() : model.slideOutTheme
    }
}
