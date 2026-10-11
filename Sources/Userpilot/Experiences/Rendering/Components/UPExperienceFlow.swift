//
//  UPExperienceFlow.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Maps backend sections and lines into reusable declarative flow components.
//

import SwiftUI

internal struct UPExperienceFlow: View {
    @ObservedObject var state: ExperienceRenderState
    let model: ExperienceViewModel
    let width: CGFloat
    let region: ExperienceRenderRegion
    var stepIndex: Int?

    private var index: Int { stepIndex ?? model.currentStep }

    private var theme: ExperienceTheme {
        model.flowContent?.type == .carousel
            ? model.carouselTheme[safe: index] ?? ExperienceTheme() : model.slideOutTheme
    }

    var body: some View {
        VStack(spacing: UPExperienceLayout.spacing) {
            if region == .header, theme.isDismissButtonEnabled {
                UPExperienceDismiss(
                    color: theme.isDismissButtonColorManual
                        ? theme.dismissButtonColor : theme.backgroundColorAsString.invertColor().color,
                    action: state.userClose)
            }
            if region != .header, let step = model.flowContent?.steps[safe: index] {
                UPExperienceSections(
                    step: step, theme: theme, loader: model.imageLoader,
                    width: width, region: region, action: {
                        guard index == model.currentStep else { return }
                        state.flowAction()
                    }
                )
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

/// The same line mapping is shared by carousel and slideout, independent of their native host.
internal struct UPExperienceSections: View {
    let step: Step
    let theme: ExperienceTheme
    let loader: ImageLoading
    let width: CGFloat
    let region: ExperienceRenderRegion
    let action: () -> Void

    private var sections: [[Line]] {
        step.sections.map { section in
            section.lines.filter { ($0.type == .button) == (region == .footer) }
        }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: UPExperienceLayout.spacing) {
            ForEach(sections.indices, id: \.self) { sectionIndex in
                VStack(spacing: UPExperienceLayout.spacing) {
                    ForEach(sections[sectionIndex].indices, id: \.self) { lineIndex in
                        lineView(sections[sectionIndex][lineIndex])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func lineView(_ line: Line) -> some View {
        switch line.type {
        case .heading, .paragraph:
            richText(line, width: width)
        case .image:
            image(line)
        case .iconText:
            HStack(alignment: .top, spacing: 12) {
                if let icon = line.attrs?.icon {
                    UPExperienceImage(
                        url: icon, loader: loader,
                        size: ThemeHandler.DefaultValues.iconImageSize, alt: line.attrs?.alt ?? "")
                }
                richText(line, width: max(1, width - ThemeHandler.DefaultValues.iconImageSize.width - 12))
            }
        case .button:
            UPExperienceButton(
                title: line.content?.first?.text ?? "", foreground: theme.buttonTextColor,
                background: theme.buttonBackgroundColor, fontFamily: theme.fontFamily,
                radius: theme.buttonBorderRadius, borderColor: theme.buttonBorderColor,
                borderWidth: theme.buttonBorderWidth, fontSize: buttonFontSize(line),
                bold: line.content?.first?.marks?.contains { $0.type == "bold" } == true,
                italic: line.content?.first?.marks?.contains { $0.type == "italic" } == true,
                textAlignment: buttonTextAlignment(line),
                alignment: buttonAlignment(line), action: action)
        }
    }

    private func richText(_ line: Line, width: CGFloat) -> some View {
        let text = UPExperienceRichText(line: line, theme: theme, width: width)
        return text.frame(height: max(1, text.measuredHeight))
    }

    @ViewBuilder
    private func image(_ line: Line) -> some View {
        if let url = line.attrs?.src {
            let requested = getImageSize(for: line)
            let scale = min(1, width / max(1, requested.width))
            UPExperienceImage(
                url: url, loader: loader, blurHash: line.attrs?.hash,
                size: CGSize(width: requested.width * scale, height: requested.height * scale),
                loadingSize: requested,
                contentMode: line.attrs?.imageScale ?? .scaleAspectFit,
                radius: line.attrs?.imageRadius ?? 0, alt: line.attrs?.alt ?? "")
        }
    }

    private func buttonFontSize(_ line: Line) -> CGFloat {
        line.content?.first?.marks?.first { $0.type == ThemeHandler.StyleName.textStyle }?
            .attrs?.fontSize?.toFontSize ?? CGFloat(ThemeHandler.DefaultValues.normalTextSize)
    }

    private func buttonTextAlignment(_ line: Line) -> TextAlignment {
        switch line.buttonAlignment {
        case .left: return .leading
        case .right: return .trailing
        default: return .center
        }
    }

    private func buttonAlignment(_ line: Line) -> Alignment {
        switch line.buttonAlignment {
        case .left: return .leading
        case .right: return .trailing
        default: return .center
        }
    }
}
