//
//  UPExperienceText.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Themed text in the theme's font family at the resolved size.
//

import SwiftUI

/// Themed text in the theme family at the resolved size.
internal struct UPExperienceText: View {
    let text: String
    let color: UIColor
    let fontFamily: String?
    var size: CGFloat = CGFloat(ThemeHandler.DefaultValues.normalTextSize)
    var bold = false
    var alignment: TextAlignment = .leading
    /// Appended in its own color, such as the red asterisk after a required question.
    var suffix = ""
    var suffixColor: UIColor = .red

    var body: some View {
        (Text(text).foregroundColor(Color(color)) + Text(suffix).foregroundColor(Color(suffixColor)))
            .experienceFont(fontFamily, size: size, bold: bold)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }
}
