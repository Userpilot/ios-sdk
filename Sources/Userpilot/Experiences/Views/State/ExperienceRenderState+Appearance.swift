//
//  ExperienceRenderState+Appearance.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Theme-derived appearance for the current content: colors, direction, close control and progress.
//

import SwiftUI
import UIKit

extension ExperienceRenderState {
    /// The header region holds the close control.
    var hasHeader: Bool { showsCloseControl }

    /// Flows show one when their theme enables it; surveys, NPS and thank-you screens always do.
    var showsCloseControl: Bool {
        if case .flow(let model) = content { return flowTheme(model).isDismissButtonEnabled }
        return true
    }

    var topProgress: UPExperienceProgress? {
        switch content {
        // Bar progress only; dots are drawn in the footer. Branching surveys have no fixed step count.
        case .survey(let model):
            guard let survey = model.surveyContent, let theme = model.surveyTheme,
                survey.type == .step, !survey.hasBranchingLogic, theme.isStepsProgressEnabled,
                !theme.isStepsProgressBallType, survey.modules[safe: model.currentStep]?.type != .completed
            else { return nil }
            return UPExperienceProgress(count: survey.modules.count, current: model.currentStep,
                                        color: theme.stepsProgressColor, showsDots: false)
        // NPS has two stages (score, feedback); the bar hides on the thank-you stage.
        case .nps(let model):
            guard let theme = model.npsTheme, theme.isStepsProgressEnabled,
                !theme.isStepsProgressBallType, npsStep < 2 else { return nil }
            return UPExperienceProgress(count: 2, current: npsStep,
                                        color: theme.isStepsProgressColorManual
                                            ? theme.stepsProgressColor : theme.primaryColor, showsDots: false)
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
        // NPS themes have no backdrop setting; it always dims the app.
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

    // Only carousel pages honor the theme's vertical alignment; everything else is top-aligned.
    var verticalAlignment: ContentAlignmentType {
        guard case .flow(let model) = content, model.flowContent?.type == .carousel else { return .top }
        return flowTheme(model).contentAlignment
    }

    // Carousels theme each page separately; a slideout has one theme.
    private func flowTheme(_ model: ExperienceViewModel) -> ExperienceTheme {
        model.flowContent?.type == .carousel
            ? model.carouselTheme[safe: model.currentStep] ?? ExperienceTheme() : model.slideOutTheme
    }
}
