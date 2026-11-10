//
//  UPExperienceButton.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The themed action button shared by every experience family.
//

import SwiftUI

/// The themed action button shared by flows, surveys and NPS: at least `buttonHeight` tall, growing with its text.
internal struct UPExperienceButton: View {
    @SwiftUI.Environment(\.experienceStyle) private var style
    let title: String
    /// An outlined button in the text color, such as NPS's "Change score" (Android: `secondary`).
    var secondary = false
    var enabled = true
    var fontSize: CGFloat = 16
    var bold = true
    var italic = false
    var textAlignment: TextAlignment = .center
    var alignment: Alignment = .center
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .experienceFont(style.fontName, size: fontSize, bold: bold, italic: italic)
                .multilineTextAlignment(textAlignment)
                // Long titles wrap onto more lines instead of truncating.
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(Color(secondary ? style.text : style.buttonText))
        }
        .buttonStyle(UPExperienceButtonStyle(
            background: secondary ? .clear : style.primary, radius: style.buttonRadius,
            borderColor: secondary ? ThemeHandler.DefaultValues.grayColor : style.border,
            borderWidth: secondary ? 1 : style.borderWidth,
            enabled: enabled, alignment: alignment))
        .disabled(!enabled)
    }
}
