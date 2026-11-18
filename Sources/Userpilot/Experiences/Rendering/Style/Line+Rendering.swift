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
    func textRuns(style: UPExperienceStyle) -> [UPTextRun] {
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
                    color: link == nil ? style.title : .blue, link: link)
            }
            let attrs = marks.first { $0.type == ThemeHandler.StyleName.textStyle }?.attrs
            return UPTextRun(
                text: text,
                size: attrs?.fontSize?.toFontSize ?? CGFloat(ThemeHandler.DefaultValues.normalTextSize),
                bold: marks.contains { $0.type == ThemeHandler.StyleName.textBold },
                italic: marks.contains { $0.type == ThemeHandler.StyleName.textItalic },
                color: link == nil ? attrs?.color?.color ?? style.text : .blue, link: link)
        }
    }

    /// Absolute, as UILabel drew it; defaults to centre.
    var runAlignment: NSTextAlignment {
        attrs?.textAlign?.textAlignment() ?? .center
    }

    /// The shared iOS/Android rule for the frame an image line takes, from the payload alone, applied to the
    /// width the parent passes in (never the screen). `style.width` and `style.height` are CSS lengths: points
    /// (`"120"`, `"120px"`), or for the width a percentage of `width` (`"100%"`). Anything else, a percentage
    /// height and a missing `style` included, is `auto`: that side follows the `actual_size` aspect, and both
    /// `auto` is the `actual_size` itself. Both set and wider than `width` → `width` at the `actual_size`
    /// aspect. Without `actual_size`, a backend fault, the image is taken as 300 × 300. The result is then
    /// shrunk to fit.
    func imageSize(fitting width: CGFloat) -> CGSize {
        let fallback = ThemeHandler.DefaultValues.imageSize
        let natural = attrs?.naturalSize ?? CGSize(width: fallback, height: fallback)
        let size: CGSize
        switch (attrs?.style?.width?.cssLength(percentOf: width), attrs?.style?.height?.cssLength(percentOf: nil)) {
        case let (authoredWidth?, authoredHeight?):
            size = authoredWidth > width
                ? natural.scaled(toWidth: width) : CGSize(width: authoredWidth, height: authoredHeight)
        case let (authoredWidth?, nil):
            size = natural.scaled(toWidth: authoredWidth)
        case let (nil, authoredHeight?):
            size = natural.scaled(toHeight: authoredHeight)
        case (nil, nil):
            size = natural
        }
        // Anything still wider than the space shrinks to it, keeping its own aspect.
        return size.width > width ? size.scaled(toWidth: width) : size
    }

    /// Where the blur and the image draw inside `frame`. A contained picture is the largest box of the
    /// `actual_size` aspect that fits, centred, so `border_radius` rounds the picture rather than the empty
    /// bands a frame of another aspect leaves beside it. `fill`, `cover`, and a missing `actual_size` take
    /// the whole frame.
    func pictureSize(in frame: CGSize) -> CGSize {
        let fit = attrs?.style?.objectFit
        guard let natural = attrs?.naturalSize, fit != "fill", fit != "cover" else { return frame }
        let scale = min(frame.width / natural.width, frame.height / natural.height)
        return CGSize(width: natural.width * scale, height: natural.height * scale)
    }
}

private extension Attributes {
    /// The image's own size from the payload; nil when the backend sent none it could measure.
    var naturalSize: CGSize? {
        guard let width = actualSize?.width, let height = actualSize?.height, width > 0, height > 0 else { return nil }
        return CGSize(width: width, height: height)
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
                .font: ExperienceFonts.font(
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
