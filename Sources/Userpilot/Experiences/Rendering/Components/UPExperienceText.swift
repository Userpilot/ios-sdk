//
//  UPExperienceText.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Renders themed text with a narrow UIKit bridge for attributed text and inline links on iOS 13.
//

import SwiftUI

/// Plain content uses SwiftUI; rich flow text retains the SDK's attributed string and link behavior.
internal struct UPExperienceText: View {
    let text: String
    let color: UIColor
    let fontFamily: String?
    var size: CGFloat = CGFloat(ThemeHandler.DefaultValues.normalTextSize)
    var bold = false
    var alignment: TextAlignment = .leading

    var body: some View {
        Text(text)
            .font(Font(UIFont.matching(fontName: fontFamily, fontWeight: bold ? [.traitBold] : [], fontSize: size)))
            .foregroundColor(Color(color))
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

internal struct UPExperienceRichText: UIViewRepresentable {
    let line: Line
    let theme: ExperienceTheme
    let width: CGFloat

    func makeUIView(context: Context) -> UPTextView {
        let label = UPTextView()
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UPTextView, context: Context) {
        label.gestureRecognizers?.forEach { label.removeGestureRecognizer($0) }
        label.preferredMaxLayoutWidth = width
        label.setupView(line: line, theme: theme)
    }

    /// iOS 13 representables have no proposed-size callback. Measure with the same styled label.
    var measuredHeight: CGFloat {
        let label = UPTextView()
        label.setupView(line: line, theme: theme)
        return ceil(label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }
}
