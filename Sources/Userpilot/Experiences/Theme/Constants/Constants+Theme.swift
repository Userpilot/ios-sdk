//
//  Constants+Theme.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Native experience styling defaults, layout values and rich-text style names.
//

import UIKit

extension Constants {

    /// Shared presentation values; theme resolution and caching belong to ThemeHandler.
    enum Theme {
        // Carousels & Slide out
        static let delayTimeForExperience = 0.5
        static let delayTimeForDeepLink = 0.25
        static let headerTextSize = 16
        static let normalTextSize = 16
        static let dimSlideOutDegree = 40
        static var slideOutContentMaxHeightPercentage: CGFloat {
            if isLandscape {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    return CGFloat(0.65)
                } else {
                    return CGFloat(0.4)
                }
            } else {
                return CGFloat(0.55)
            }
        }
        static var leftRightMargin: CGFloat {
            if isLandscape {
                return CGFloat(70)
            } else {
                return 0
            }
        }
        static let blackColor = "#000000"
        static let whiteColor = "#FFFFFF"
        static let grayColor = "#ACB5BD".color
        static let distanceBetweenSections = CGFloat(12)
        static let smallDistanceBetweenSections = CGFloat(8)
        static let contentMargin = CGFloat(20)
        static let contentTopMargin = CGFloat(10)
        static let contentBottomMargin = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(30) : CGFloat(20)
        static let buttonBottomMarginWithStepProgress = UIDevice.current.userInterfaceIdiom == .pad
        ? CGFloat(62) : CGFloat(52)
        static let buttonBottomMarginWithoutStepProgress = UIDevice.current.userInterfaceIdiom == .pad
        ? CGFloat(35) : CGFloat(25)
        static let carouselContentTopMargin = CGFloat(65)

        static let slideOutCornerRadius = CGFloat(12)
        static let blurImageSize = CGSize(width: 64, height: 64)
        static let iconImageSize = CGSize(width: iconImageDimensions, height: iconImageDimensions)
        static let defaultTextMargin = "   "
        static let imageSize = CGFloat(300)
        static let closeButtonAlpha = 0.8
        static let dismissButtonMargin = CGFloat(10)
        /// The height of `UPStepsBarProgressView`. Its layers are fully rounded,
        /// so this also drives their corner radius.
        static let stepsProgressBarHeight = CGFloat(5)
        /// The height of a `UPStepsProgressView` dots row.
        static let stepsProgressDotsHeight = CGFloat(20)
        /// The text size of a `UPStepsCounterView`, which takes the dots' row.
        static let stepsCounterTextSize = CGFloat(12)
        static let iconImageDimensions = 38
        static let npsImageDimensions = 100

        /// NPS dismiss (close) button chip styling.
        /// The chip is a translucent overlay on top of the NPS background: it darkens that background —
        /// more softly on near white backgrounds (brightness above 85%), where a light gray chip is enough
        /// — and lightens it instead when the background is already too dark to be darkened further
        /// (brightness below 25%). The title color follows the color the chip resolves to.
        static let npsDismissButtonDarkenOpacity = CGFloat(0.35)
        static let npsDismissButtonSoftDarkenOpacity = CGFloat(0.16)
        static let npsDismissButtonLightenOpacity = CGFloat(0.15)
        static let npsDismissLightBackgroundBrightness = CGFloat(0.85)
        static let npsDismissDarkBackgroundBrightness = CGFloat(0.25)
        static let npsDismissButtonHeight = CGFloat(34)
        static let npsDismissButtonTextSize = CGFloat(14)

        /// NPS header layout: the steps progress bar sits at the very top of the sheet and the dismiss
        /// button hangs below its container, so the button needs a margin to clear the bar.
        static let npsProgressBarTopInset = CGFloat(20)
        static let npsDismissButtonTopMargin = CGFloat(8)
        static let npsDismissButtonBottomOverhang = CGFloat(10)

        /// Survey
        static let surveyItemRatingMinWidth: Int = 80
        static let surveyContentTopMargin: Int = 16
        static let surveyTitleTextSize: CGFloat = 16
        static let surveyDescriptionTextSize: CGFloat = 13
        static let surveyHighLowTextSize: CGFloat = 12
        static let surveyPromptButtonTextSize: CGFloat = 12
        static let surveyDescriptionTextTopMargin: Int = 10
        static let surveyDefaultLikertViewCount: Int = 10
        static let npsDefaultLikertViewCount: Int = 11
        static let surveyMaxTextFieldCharCount: Int = 500
        static let surveyPromptViewButtonMargin: Int = 50
        static let surveyContentTopMargin24: Int = 24
        static let surveyLikertViewMaxCount: Int = 10
        static let surveyOpenTextEditTextHeight: Int = 80
        static let surveyTextSize = 14

        static let surveySingleTextDefaultCountryCode: String = "+1"
        static let surveySingleTextMaxLength: Int = 50
        static let surveyOtherChoice: String = "other"
        static let surveyOtherChoiceTag = 101

        static let textStyle = "textStyle"
        static let textLink = "link"
        static let textBold = "bold"
        static let textItalic = "italic"

        static let manual = "manual"
        static let borderRadius = 0

        // Tooltips
        /// Gap between the target and the card.
        static let tooltipGap: CGFloat = 8
        /// Minimum distance from the card to the screen edges.
        static let tooltipEdgeMargin: CGFloat = 16
        static let tooltipPointerWidth: CGFloat = 16
        static let tooltipPointerHeight: CGFloat = 8
        /// How far the lit hole extends beyond the target.
        static let tooltipHighlightPadding: CGFloat = 4
        static let tooltipHighlightCornerRadius: CGFloat = 4
        static let tooltipCornerRadius: CGFloat = 12
        /// Delays between target lookups, in milliseconds, consumed in order rather than as a total deadline.
        static let tooltipRetryIntervals = [300, 600, 900, 1_200]
        /// Gap between the two lookups that must agree before a found target reveals.
        static let tooltipStillnessInterval: TimeInterval = 0.1
        /// Longest wait for a moving target to stop; after it the tooltip reveals at the latest position.
        static let tooltipStillnessTimeout: TimeInterval = 2
        /// How far, in points, a target may shift between two lookups and still count as still.
        static let tooltipStillnessTolerance: CGFloat = 0.5
        /// A held Flow overlay's park fade, its return and its dim blend; matches the reposition glide.
        static let tooltipFlowFadeDuration: TimeInterval = 0.3
    }
}
