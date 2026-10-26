//
//  Line+Rendering.swift
//  Userpilot SDK
//
//  Created by Userpilot on 26/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Turns a flow line into styled text runs: the one styling source for SwiftUI text and link text views.
//

import SwiftUI
import UIKit

/// One styled span of a flow line, before the user's text size is applied.
internal struct UPTextRun: Equatable {
    let text: String
    let size: CGFloat
    let bold: Bool
    let italic: Bool
    let color: UIColor
    let link: URL?
}

internal extension Line {
    /// The legacy text rules: headings are bold, titled and sized by level; paragraphs take the
    /// `textStyle` mark's size and colour; a link mark on any line is blue, underlined and tappable.
    func textRuns(theme: ExperienceTheme) -> [UPTextRun] {
        (content ?? []).compactMap { content in
            guard let text = content.text else { return nil }
            let marks = content.marks ?? []
            // A link mark makes the whole span a link; a bad href leaves plain text.
            let link = marks.first { $0.type == ThemeHandler.StyleName.textLink }?
                .attrs?.href.flatMap(URL.init(string:))
            if type == .heading {
                return UPTextRun(
                    text: text,
                    size: CGFloat(attrs?.level?.fontSize() ?? ThemeHandler.DefaultValues.headerTextSize),
                    bold: true, italic: false,
                    color: link == nil ? theme.titleTextColor : .blue, link: link)
            }
            let style = marks.first { $0.type == ThemeHandler.StyleName.textStyle }?.attrs
            return UPTextRun(
                text: text,
                size: style?.fontSize?.toFontSize ?? CGFloat(ThemeHandler.DefaultValues.normalTextSize),
                bold: marks.contains { $0.type == ThemeHandler.StyleName.textBold },
                italic: marks.contains { $0.type == ThemeHandler.StyleName.textItalic },
                color: link == nil ? style?.color?.color ?? theme.textColor : .blue, link: link)
        }
    }

    /// Absolute, as UILabel drew it; defaults to centre.
    var runAlignment: NSTextAlignment {
        attrs?.textAlign?.textAlignment() ?? .center
    }

    /// The shared iOS/Android rule, applied to the width the parent passes in (never the screen):
    /// both `auto` → natural size; both numeric → that size; either way, wider than `width` takes
    /// `width` at the natural aspect. Anything else → 300 × 300. The result is then shrunk to fit.
    func imageSize(fitting width: CGFloat) -> CGSize {
        let fallback = ThemeHandler.DefaultValues.imageSize
        let natural = CGSize(width: CGFloat(attrs?.actualSize?.width ?? Int(fallback)),
                             height: CGFloat(attrs?.actualSize?.height ?? Int(fallback)))
        let atWidthWithNaturalAspect = CGSize(width: width, height: width * natural.height / max(1, natural.width))
        let size: CGSize
        if attrs?.style?.width == "auto" && attrs?.style?.height == "auto" {
            size = natural.width > width ? atWidthWithNaturalAspect : natural
        } else if let authoredWidth = attrs?.style?.width?.toSize, let authoredHeight = attrs?.style?.height?.toSize {
            size = authoredWidth > width
                ? atWidthWithNaturalAspect : CGSize(width: authoredWidth, height: authoredHeight)
        } else {
            size = CGSize(width: fallback, height: fallback)
        }
        // Anything still wider than the space shrinks to it, keeping its own aspect.
        guard size.width > width, size.width > 0 else { return size }
        return CGSize(width: width, height: width * size.height / size.width)
    }
}

internal extension Array where Element == UPTextRun {
    var hasLink: Bool { contains { $0.link != nil } }

    /// Fonts come from the shared resolver at the given size category, so nothing scales twice.
    func attributedString(
        family: String?, category: ContentSizeCategory, alignment: NSTextAlignment
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        let string = NSMutableAttributedString()
        for run in self {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: UPExperienceStyle.font(
                    family: family, size: run.size, bold: run.bold, italic: run.italic, category: category),
                .foregroundColor: run.color,
                .paragraphStyle: paragraph
            ]
            if let link = run.link {
                attributes[.link] = link
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            string.append(NSAttributedString(string: run.text, attributes: attributes))
        }
        return string
    }
}
