//
//  UPExperienceFlow.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  One flow step for a carousel page or slideout: close control, sections and progress.
//

import SwiftUI

internal struct UPExperienceFlow: View {
    @ObservedObject var state: ExperienceRenderState
    let model: ExperienceViewModel
    let width: CGFloat
    let region: ExperienceRenderRegion
    var stepIndex: Int?

    // Carousel pages pass their own index; a slideout follows the current step.
    private var index: Int { stepIndex ?? model.currentStep }

    private var theme: ExperienceTheme {
        model.flowContent?.type == .carousel
            ? model.carouselTheme[safe: index] ?? ExperienceTheme() : model.slideOutTheme
    }

    var body: some View {
        VStack(spacing: UPExperienceLayout.spacing) {
            if region == .header, theme.isDismissButtonEnabled {
                // Without an authored color, the close icon contrasts with the background.
                UPExperienceDismiss(
                    color: theme.isDismissButtonColorManual
                        ? theme.dismissButtonColor : theme.backgroundColorAsString.invertColor().color,
                    action: state.userClose)
            }
            if region != .header, let step = model.flowContent?.steps[safe: index] {
                UPExperienceSections(
                    state: state, step: step, theme: theme, loader: model.imageLoader,
                    width: width, region: region, action: {
                        // Ignore a tap on a neighbouring page that is still sliding out.
                        guard index == model.currentStep else { return }
                        state.flowAction()
                    }
                )
                // A new step is a new view, so no state carries over from the previous one.
                .id(index)
            }
            if region == .footer, theme.isStepsProgressEnabled, model.carouselStepsCount > 1 {
                UPExperienceProgress(
                    count: model.carouselStepsCount, current: index,
                    color: theme.isStepsProgressColorManual
                        ? theme.stepsProgressColor : theme.backgroundColorAsString.invertColor().color)
            }
        }
    }
}
