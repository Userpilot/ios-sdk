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

/// The part of a card a view draws: the fixed header (close and progress), the scrolling body, or the fixed footer
/// (actions).
internal enum ExperienceRenderRegion { case header, content, footer }

/// The card for one experience region: its content for the flow, survey or NPS, inside the card's margins and
/// background, with the step's progress and close control where the region shows them.
internal struct UPExperienceRootView: View {
    @ObservedObject var state: ExperienceRenderState
    let width: CGFloat
    var region: ExperienceRenderRegion = .content
    /// Room above the close symbol and below the footer; dialogs and sheets keep more than full-screen content.
    var edgeSpacing: CGFloat = UPExperienceLayout.spacing
    /// The screen sides a sheet's content keeps clear of (cutout, rounded corners); the bar progress runs across them.
    var sideInsets: UIEdgeInsets = .zero

    var body: some View {
        // The host mounts this view three times (header, body, footer); each draws only its own region.
        VStack(spacing: 0) {
            if state.isReady {
                // The bar-style progress sits flush at the top of the card, above the header padding, and runs
                // from one edge of the card to the other. Screen sides, so mirrored for right-to-left content.
                if region == .header, let progress = state.topProgress {
                    progress
                        .padding(.leading, -(state.isRTL ? sideInsets.right : sideInsets.left))
                        .padding(.trailing, -(state.isRTL ? sideInsets.left : sideInsets.right))
                }
                content
                    .padding(.horizontal, UPExperienceLayout.contentMargin)
                    .padding(.top, topPadding)
                    .padding(.bottom, region == .footer ? edgeSpacing : verticalPadding)
            }
        }
        .frame(width: width)
        .environment(\.experienceStyle, state.currentStyle)
        // Direction comes from the experience content, not the host app.
        .environment(\.layoutDirection, state.isRTL ? .rightToLeft : .leftToRight)
        .experienceTextSize(scalingEnabled: state.textScaling)
        // Nothing is tappable once the card starts closing.
        .disabled(state.isClosing)
    }

    // An empty header collapses to zero height instead of leaving a padded gap.
    private var verticalPadding: CGFloat {
        region == .content || (region == .header && !state.hasHeader) ? 0 : UPExperienceLayout.spacing
    }

    private var topPadding: CGFloat {
        region == .header && state.hasHeader ? state.headerTopPadding(edge: edgeSpacing) : verticalPadding
    }

    @ViewBuilder
    private var content: some View {
        let contentWidth = max(1, width - UPExperienceLayout.contentMargin * 2)
        switch state.content {
        case .flow(let model): UPExperienceFlow(state: state, model: model, width: contentWidth, region: region)
        case .survey(let model): UPExperienceSurvey(state: state, model: model, width: contentWidth, region: region)
        case .nps(let model): UPExperienceNPS(state: state, model: model, width: contentWidth, region: region)
        case .thankYou(let survey, let theme):
            UPExperienceThankYou(state: state, survey: survey, theme: theme, region: region)
        }
    }
}
