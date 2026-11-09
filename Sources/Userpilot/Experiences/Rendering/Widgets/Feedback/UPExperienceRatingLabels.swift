//
//  UPExperienceRatingLabels.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The low and high score captions under a survey rating or NPS scale.
//

import SwiftUI

/// The low and high score captions under a rating or NPS scale, at its two ends.
internal struct UPExperienceRatingLabels: View {
    let low: String?
    let high: String?
    let color: UIColor
    let fontFamily: String?

    var body: some View {
        HStack(alignment: .top) {
            UPExperienceText(
                text: low ?? "", color: color, fontFamily: fontFamily, size: UPExperienceLayout.scaleLabelSize)
            UPExperienceText(
                text: high ?? "", color: color, fontFamily: fontFamily, size: UPExperienceLayout.scaleLabelSize,
                alignment: .trailing)
        }
    }
}
