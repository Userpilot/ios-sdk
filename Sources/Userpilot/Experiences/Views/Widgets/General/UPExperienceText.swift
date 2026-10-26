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

    var body: some View {
        Text(text)
            .experienceFont(fontFamily, size: size, bold: bold)
            .foregroundColor(Color(color))
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
