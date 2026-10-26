//
//  UPExperienceRichText.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Draws one flow line's styled text runs, choosing SwiftUI text or the link text view.
//

import SwiftUI

/// Flow text. Plain lines are SwiftUI `Text`; only a line with a link uses a plain `UITextView`,
/// because iOS 13 SwiftUI can't tap one word inside a `Text`. Both draw the same runs.
internal struct UPExperienceRichText: View {
    @SwiftUI.Environment(\.sizeCategory) private var sizeCategory
    @SwiftUI.Environment(\.layoutDirection) private var layoutDirection
    let line: Line
    let theme: ExperienceTheme
    let width: CGFloat

    var body: some View {
        let runs = line.textRuns(theme: theme)
        return Group {
            if runs.hasLink {
                linkText(runs)
            } else {
                plainText(runs)
            }
        }
    }

    private func plainText(_ runs: [UPTextRun]) -> some View {
        // Joined `Text` values wrap as one paragraph while each run keeps its own font and color.
        runs.reduce(Text(verbatim: "")) { text, run in
            text + Text(verbatim: run.text)
                .font(Font(UPExperienceStyle.font(
                    family: theme.fontFamily, size: run.size, bold: run.bold, italic: run.italic,
                    category: sizeCategory)))
                .foregroundColor(Color(run.color))
        }
        .multilineTextAlignment(textAlignment)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        // Headings appear in VoiceOver's Headings rotor.
        .accessibility(addTraits: line.type == .heading ? .isHeader : [])
    }

    private func linkText(_ runs: [UPTextRun]) -> some View {
        let string = runs.attributedString(
            family: theme.fontFamily, category: sizeCategory, alignment: line.runAlignment)
        return UPExperienceLinkText(string: string, isHeading: line.type == .heading)
            .frame(width: width, height: UPExperienceLinkText.height(of: string, width: width))
    }

    /// UILabel drew `left`/`right` as absolute sides; keep them absolute under RTL.
    private var textAlignment: TextAlignment {
        switch line.runAlignment {
        case .left: return layoutDirection == .rightToLeft ? .trailing : .leading
        case .right: return layoutDirection == .rightToLeft ? .leading : .trailing
        default: return .center
        }
    }

    private var frameAlignment: Alignment {
        switch textAlignment {
        case .leading: return .leading
        case .trailing: return .trailing
        default: return .center
        }
    }
}
