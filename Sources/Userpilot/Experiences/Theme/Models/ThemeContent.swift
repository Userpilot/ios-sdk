//  ThemeContent.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Represents the configuration and content for experiences base theme.
//

import Foundation
import UIKit

// MARK: - ThemeResponse

// swiftlint:disable file_length
internal struct ThemeContent: Decodable {
    let id: Int?
    let themeData: ThemeData?

    private enum CodingKeys: String, CodingKey {
        case id
        case themeData = "theme_data"
    }
}

// MARK: - ThemeData

internal struct ThemeData: Decodable {
    let carousel: ExperienceTheme?
    let slideOut: ExperienceTheme?
    let survey: SurveyTheme?

    private enum CodingKeys: String, CodingKey {
        case carousel
        case slideOut = "slideout"
        case survey
    }

    var isDialogExperience: Bool {
        slideOut?.general?.contentAlignment == .center
    }

    var isDialogSurvey: Bool {
        survey?.general?.position == .center
    }

}

// MARK: - CarouselTheme

internal struct ExperienceTheme: Decodable {
    var button: ButtonStyle?
    var colors: ColorsStyle?
    var dismissContent: DismissContentStyle?
    var general: GeneralStyle?
    var progress: ProgressStyle?
    var backdrop: Backdrop?

    private enum CodingKeys: String, CodingKey {
        case button, colors, general, progress, backdrop
        case dismissContent = "dismiss_content"
    }

    // General
    var fontFamily: String? {
        general?.fontFamily
    }

    var contentAlignment: ContentAlignmentType {
        general?.contentAlignment ?? .top
    }

    var backgroundColor: UIColor {
        colors?.backgroundColor?.color ?? .white
    }

    var backgroundColorAsString: String {
        colors?.backgroundColor ?? ThemeHandler.DefaultValues.whiteColor
    }

    var isLightTheme: Bool {
        backgroundColor.isLightColor()
    }

    // Text
    var textColor: UIColor {
        colors?.textColor?.color ?? .black
    }

    var titleTextColor: UIColor {
        colors?.titleColor?.color ?? .black
    }

    // Button
    var buttonBackgroundColor: UIColor {
        button?.backgroundColor?.color ?? .black
    }

    var buttonTextColor: UIColor {
        button?.labelColor?.color ?? .white
    }

    var buttonBorderColor: UIColor {
        button?.borderColor?.color ?? .black
    }

    var buttonBorderRadius: CGFloat {
        CGFloat(button?.borderRadius ?? ThemeHandler.StyleValues.borderRadius)
    }

    var buttonBorderWidth: CGFloat {
        CGFloat(button?.borderWidth ?? 0)
    }

    // Dismiss Content
    var isDismissButtonEnabled: Bool {
        dismissContent?.enabled ?? false
    }

    var isDismissButtonColorManual: Bool {
        dismissContent?.colorType == .manual
    }

    var dismissButtonColor: UIColor {
        dismissContent?.color?.color ?? .black
    }

    // Progress
    var isStepsProgressEnabled: Bool {
        progress?.enabled ?? false
    }

    var isStepsProgressColorManual: Bool {
        progress?.colorType == .manual
    }

    var stepsProgressColor: UIColor {
        progress?.color?.color ?? .black
    }

    var stepsProgressColorAsString: String {
        progress?.color ?? ThemeHandler.DefaultValues.blackColor
    }

    // Backdrop
    var backdropColor: UIColor {
        backdrop?.color?.color ?? .black
    }

    var backdropEnabled: Bool {
        backdrop?.enabled ?? true
    }

    var backdropOpacity: CGFloat {
        CGFloat(CGFloat(backdrop?.opacity ?? ThemeHandler.DefaultValues.dimSlideOutDegree) / 100)
    }

    var backdropBackground: UIColor {
        backdropColor.withOpacity(backdropOpacity)
    }

}

// MARK: - BackdropStyle

internal struct Backdrop: Decodable {
    let color: String?
    let enabled: Bool?
    let opacity: Int?
}

// MARK: - ButtonStyle

internal struct ButtonStyle: Decodable {
    let backgroundColor: String?
    let labelColor: String?
    let borderColor: String?
    let borderWidth: Int?
    let borderRadius: Int?

    private enum CodingKeys: String, CodingKey {
        case backgroundColor = "background_color"
        case labelColor = "label_color"
        case borderColor = "border_color"
        case borderWidth = "border_width"
        case borderRadius = "border_radius"
    }
}

// MARK: - ColorsStyle

internal struct ColorsStyle: Decodable {
    let backgroundColor: String?
    let textColor: String?
    let titleColor: String?

    private enum CodingKeys: String, CodingKey {
        case backgroundColor = "background_color"
        case textColor = "text_color"
        case titleColor = "title_color"
    }
}

// MARK: - DismissContentStyle

internal struct DismissContentStyle: Decodable {
    let color: String?
    let colorType: ColorType?
    let enabled: Bool?

    private enum CodingKeys: String, CodingKey {
        case color, enabled
        case colorType = "color_type"
    }
}

// MARK: - GeneralStyle

internal struct GeneralStyle: Decodable {
    let contentAlignment: ContentAlignmentType?
    let fontFamily: String?

    private enum CodingKeys: String, CodingKey {
        case contentAlignment = "content_alignment"
        case fontFamily = "font_family"
    }
}

// MARK: - ProgressStyle

internal struct ProgressStyle: Decodable {
    let color: String?
    let colorType: ColorType?
    let enabled: Bool?
    let type: ProgressStyleType?

    private enum CodingKeys: String, CodingKey {
        case color, enabled
        case colorType = "color_type"
        case type
    }
}

// MARK: - ContentAlignmentType

internal enum ContentAlignmentType: String, Decodable {
    case middle
    case center
    case top
    case bottom
}

// Survey Theme //

// MARK: - SurveyTheme

internal struct SurveyTheme: Decodable {
    let general: SurveyGeneral?
    let font: SurveyFont?
    let progress: ProgressStyle?
    let backdrop: Backdrop?

    // Computed Properties
    var backgroundColor: UIColor {
        general?.backgroundColor?.color ?? .white
    }

    var backgroundColorAsString: String {
        general?.backgroundColor ?? "#ffffff"
    }

    var isLightTheme: Bool {
        backgroundColor.isLightColor()
    }

    var primaryColor: UIColor {
        general?.primaryColor?.color ?? .black
    }

    var primaryColorAsString: String {
        general?.primaryColor ?? "#000000"
    }

    var secondaryColor: UIColor {
        primaryColor.withAlphaComponent(0.2)
    }

    var secondaryColorAsString: String {
        secondaryColor.toHexStringWithAlpha(alpha: 0.2)
    }

    var textColor: UIColor {
        if font?.colorType == .manual {
            font?.fontColor?.color ?? .black
        } else {
            backgroundColorAsString.invertColor().color
        }
    }

    var textSecondaryColorAlpha80: UIColor {
        textColor.withAlphaComponent(0.8)
    }

    var textSecondaryColor: UIColor {
        textColor.withAlphaComponent(0.2)
    }

    var fontFamily: String? {
        font?.fontFamily
    }

    // Backdrop
    var backdropColor: UIColor {
        backdrop?.color?.color ?? .black
    }

    var backdropEnabled: Bool {
        backdrop?.enabled ?? true
    }

    var backdropOpacity: CGFloat {
        CGFloat(CGFloat(backdrop?.opacity ?? ThemeHandler.DefaultValues.dimSlideOutDegree) / 100)
    }

    var backdropBackground: UIColor {
        backdropColor.withOpacity(backdropOpacity)
    }

    // progress
    var isStepsProgressEnabled: Bool {
        progress?.enabled ?? false
    }

    var isStepsProgressBallType: Bool {
        progress?.type == .ball
    }

    var stepsProgressColor: UIColor {
        progress?.color?.color ?? .black
    }

    var stepsProgressColorAsString: String {
        progress?.color ?? ThemeHandler.DefaultValues.blackColor
    }

    // corner
    var isBottomSheetSurvey: Bool {
        general?.position == .bottom
    }

    // Border
    var borderRadius: CGFloat {
        CGFloat(general?.cornerRadius ?? 12)
    }

}

// MARK: - SurveyGeneral

internal struct SurveyGeneral: Decodable {
    let position: SurveyPosition?
    let primaryColor: String?
    let backgroundColor: String?
    let cornerRadius: Int?

    private enum CodingKeys: String, CodingKey {
        case position = "default_position"
        case primaryColor = "primary_color"
        case backgroundColor = "background_color"
        case cornerRadius = "corner_radius"
    }
}

// MARK: - SurveyFont

internal struct SurveyFont: Decodable {
    let fontFamily: String?
    let fontColor: String?
    let colorType: ColorType?

    private enum CodingKeys: String, CodingKey {
        case fontFamily = "font_family"
        case fontColor = "font_color"
        case colorType = "color_type"
    }
}

// MARK: - SurveyBoxBorder

internal enum SurveyPosition: String, Decodable {
    case center
    case bottom
}

internal enum ProgressStyleType: String, Decodable {
    case bar
    case ball
}

internal enum ColorType: String, Decodable {
    case manual
    case automatic
}

// MARK: - Extension to deserialize a String into a ThemeResponse object

internal extension String {
    func toMobileTheme() -> ThemeContent? {
        if let themeContent: ThemeContent = self.toObject() {
            return themeContent
        } else {
            return nil
        }
    }
}
