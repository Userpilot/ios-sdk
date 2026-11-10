//
//  UPExperienceProgress.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Step progress for carousels, step surveys and NPS, drawn as dots or as a bar.
//

import SwiftUI

/// Step progress for carousels, step surveys and NPS, drawn as dots or as a bar.
internal struct UPExperienceProgress: View {
    @SwiftUI.Environment(\.experienceStyle) private var style
    let count: Int
    let current: Int

    var body: some View {
        Group {
            if style.dots {
                // Dots fill up to and including the current step; the rest fade to 20%.
                HStack(spacing: UPExperienceLayout.dotSpacing) {
                    ForEach(0..<max(0, count), id: \.self) { index in
                        Circle()
                            .fill(Color(index <= current ? style.progressColor : style.inactiveProgressColor
                                .withAlphaComponent(UPExperienceLayout.progressInactiveOpacity)))
                            .frame(width: UPExperienceLayout.dotSize, height: UPExperienceLayout.dotSize)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 20)
            } else {
                // The bar's filled share is the steps reached so far.
                GeometryReader { geometry in
                    Capsule().fill(Color(style.progressColor))
                        .frame(width: geometry.size.width * CGFloat(min(current + 1, count)) / CGFloat(max(1, count)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: UPExperienceLayout.progressBarHeight)
            }
        }
        .contentShape(Rectangle())
        // VoiceOver reads one "Step x of y" instead of every dot.
        .accessibilityElement(children: .ignore)
        .accessibility(label: Text("Step \(min(current + 1, count)) of \(count)"))
    }
}
