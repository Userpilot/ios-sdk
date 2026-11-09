//
//  UPExperienceDismissAction.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The text chip that dismisses an NPS ("Not now", "Close").
//

import SwiftUI

/// The dismiss chip, shaded against the card as in the previous release and on Android. Scaled text grows the chip
/// instead of clipping, and taps reach Apple's 44 pt target around it without changing the layout.
internal struct UPExperienceDismissAction: View {
    let title: String
    let background: UIColor
    let cardRadius: CGFloat
    let fontFamily: String?
    let action: () -> Void

    var body: some View {
        let height = ThemeHandler.DefaultValues.npsDismissButtonHeight
        let overlay = Self.dismissChipOverlay(brightness: background.perceivedBrightness())
        return Button(action: action) {
            Text(title)
                .experienceFont(fontFamily, size: ThemeHandler.DefaultValues.npsDismissButtonTextSize)
                .foregroundColor(Color(overlay.withAlphaComponent(1)))
                .padding(.horizontal, ThemeHandler.DefaultValues.npsDismissButtonPadding)
                .frame(minHeight: height)
                .background(Color(overlay))
                .clipShape(RoundedRectangle(
                    cornerRadius: min(cardRadius, ThemeHandler.DefaultValues.npsDismissButtonMaxCornerRadius)))
                // Taps reach 5 pt past the chip's top and bottom.
                .contentShape(Rectangle().inset(by: (height - UPExperienceLayout.touchTargetSize) / 2))
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// The chip over a background of this perceived `brightness` (0 to 1): light over dark, dark otherwise.
    static func dismissChipOverlay(brightness: CGFloat) -> UIColor {
        if brightness < ThemeHandler.DefaultValues.npsDismissDarkBackgroundBrightness {
            return UIColor.white.withAlphaComponent(ThemeHandler.DefaultValues.npsDismissButtonLightenOpacity)
        }
        return UIColor.black.withAlphaComponent(
            brightness > ThemeHandler.DefaultValues.npsDismissLightBackgroundBrightness
                ? ThemeHandler.DefaultValues.npsDismissButtonSoftDarkenOpacity
                : ThemeHandler.DefaultValues.npsDismissButtonDarkenOpacity)
    }
}
