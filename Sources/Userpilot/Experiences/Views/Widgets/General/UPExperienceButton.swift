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

internal struct UPExperienceButton: View {
    let title: String
    let foreground: UIColor
    let background: UIColor
    let fontFamily: String?
    var radius: CGFloat = 12
    var borderColor: UIColor = .clear
    var borderWidth: CGFloat = 0
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
                .experienceFont(fontFamily, size: fontSize, bold: bold, italic: italic)
                .multilineTextAlignment(textAlignment)
                // Long titles wrap onto more lines instead of truncating.
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(Color(foreground))
        }
        .buttonStyle(UPExperienceButtonStyle(
            background: background, radius: radius, borderColor: borderColor, borderWidth: borderWidth,
            enabled: enabled, alignment: alignment))
        .disabled(!enabled)
    }
}
