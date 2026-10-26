//
//  UPExperienceButtonStyle.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The themed button shape and its pressed and disabled looks.
//

import SwiftUI

/// Themed action shape; the whole shape is tappable. It dims while pressed, and by half when disabled,
/// as the plain style did.
internal struct UPExperienceButtonStyle: SwiftUI.ButtonStyle {
    let background: UIColor
    var radius: CGFloat = 12
    var borderColor: UIColor = .clear
    var borderWidth: CGFloat = 0
    var enabled = true
    var alignment: Alignment = .center

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: UPExperienceLayout.buttonHeight, alignment: alignment)
            // Disabled: the fill fades to 20%, then the whole button to 50%, matching the old look.
            .background(Color(background).opacity(enabled ? 1 : 0.2))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color(borderColor), lineWidth: borderWidth))
            .contentShape(RoundedRectangle(cornerRadius: radius))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.5)
    }
}
