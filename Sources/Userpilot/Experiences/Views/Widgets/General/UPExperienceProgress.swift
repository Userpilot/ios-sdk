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

internal struct UPExperienceProgress: View {
    let count: Int
    let current: Int
    let color: UIColor
    var showsDots = true
    var inactiveColor: UIColor?

    var body: some View {
        Group {
            if showsDots {
                // Dots fill up to and including the current step; the rest fade to 20%.
                HStack(spacing: 6) {
                    ForEach(0..<max(0, count), id: \.self) { index in
                        Circle()
                            .fill(Color(index <= current ? color : (inactiveColor ?? color).withAlphaComponent(0.2)))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 20)
            } else {
                // The bar's filled share is the steps reached so far.
                GeometryReader { geometry in
                    Capsule().fill(Color(color))
                        .frame(width: geometry.size.width * CGFloat(min(current + 1, count)) / CGFloat(max(1, count)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: ThemeHandler.DefaultValues.stepsProgressBarHeight)
            }
        }
        .contentShape(Rectangle())
        // VoiceOver reads one "Step x of y" instead of every dot.
        .accessibilityElement(children: .ignore)
        .accessibility(label: Text("Step \(min(current + 1, count)) of \(count)"))
    }
}
