//
//  UPExperienceButton.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Shared declarative actions, dismiss controls and progress for every experience family.
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

    private var fontTraits: [UIFontDescriptor.SymbolicTraits] {
        (bold ? [.traitBold] : []) + (italic ? [.traitItalic] : [])
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(
                    Font(
                        UIFont.matching(
                            fontName: fontFamily,
                            fontWeight: fontTraits, fontSize: fontSize))
                )
                .multilineTextAlignment(textAlignment)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(Color(foreground))
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: UPButtonView.buttonHeight, alignment: alignment)
                .background(Color(background).opacity(enabled ? 1 : 0.2))
                .clipShape(RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color(borderColor), lineWidth: borderWidth))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!enabled)
    }
}

internal struct UPExperienceDismiss: View {
    let color: UIColor
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(color))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibility(label: Text("Close"))
        }
    }
}

internal struct UPExperienceProgress: View {
    let count: Int
    let current: Int
    let color: UIColor
    var balls = true
    var inactiveColor: UIColor?

    var body: some View {
        Group {
            if balls {
                HStack(spacing: 6) {
                    ForEach(0..<max(0, count), id: \.self) { index in
                        Circle()
                            .fill(Color(index <= current ? color : (inactiveColor ?? color).withAlphaComponent(0.2)))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 20)
            } else {
                GeometryReader { geometry in
                    Capsule().fill(Color(color))
                        .frame(width: geometry.size.width * CGFloat(min(current + 1, count)) / CGFloat(max(1, count)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: ThemeHandler.DefaultValues.stepsProgressBarHeight)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibility(label: Text("Step \(min(current + 1, count)) of \(count)"))
    }
}
