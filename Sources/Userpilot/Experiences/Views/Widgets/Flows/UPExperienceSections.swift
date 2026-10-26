//
//  UPExperienceSections.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Lays out one flow step's sections: text, images, icon rows and buttons.
//

import SwiftUI

/// The same line mapping is shared by carousel and slideout, independent of their native host.
internal struct UPExperienceSections: View {
    let state: ExperienceRenderState
    let step: Step
    let theme: ExperienceTheme
    let loader: ImageLoading
    let width: CGFloat
    let region: ExperienceRenderRegion
    let action: () -> Void

    private var sections: [[Line]] {
        // Buttons go to the pinned footer; everything else scrolls in the body.
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
                    let size = ThemeHandler.DefaultValues.iconImageSize
                    UPExperienceImage(
                        model: state.imageModel(url: icon, blurHash: nil, size: size, loader: loader),
                        size: size, alt: line.attrs?.alt ?? "")
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
        UPExperienceRichText(line: line, theme: theme, width: width)
    }

    @ViewBuilder
    private func image(_ line: Line) -> some View {
        if let url = line.attrs?.src {
            // Decode and display share the authored size for this width; never a SwiftUI layout proposal.
            let size = line.imageSize(fitting: width)
            UPExperienceImage(
                model: state.imageModel(url: url, blurHash: line.attrs?.hash, size: size, loader: loader),
                size: size, stretches: line.attrs?.style?.objectFit == "fill",
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
