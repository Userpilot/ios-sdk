//  CarouselExperienceViewController.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  Represents the configuration and content for experiences base theme.
//

import Foundation
import UIKit

// MARK: - ThemeResponse

internal struct ThemeContent: Codable {
    let id: Int?
    let themeData: ThemeData?

    private enum CodingKeys: String, CodingKey {
        case id
        case themeData = "theme_data"
    }
}

// MARK: - ThemeData

internal struct ThemeData: Codable {
    let carousel: ExperienceTheme?
    let slideOut: ExperienceTheme?

    private enum CodingKeys: String, CodingKey {
        case carousel
        case slideOut = "slideout"
    }

    var isDialogExperience: Bool {
        slideOut?.general?.contentAlignment == .center
    }
}

// MARK: - CarouselTheme

internal struct ExperienceTheme: Codable {
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
        dismissContent?.colorType == ThemeHandler.StyleValues.manual
    }

    var dismissButtonColor: UIColor {
        dismissContent?.color?.color ?? .black
    }

    // Progress
    var isStepsProgressEnabled: Bool {
        progress?.enabled ?? false
    }

    var isStepsProgressColorManual: Bool {
        progress?.colorType == ThemeHandler.StyleValues.manual
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
        CGFloat(CGFloat(backdrop?.opacity ?? ThemeHandler.DefaultValues.dimDegree) / 100)
    }

    var backdropBackground: UIColor {
        backdropColor.withOpacity(backdropOpacity)
    }

}

// MARK: - BackdropStyle

internal struct Backdrop: Codable {
    let color: String?
    let enabled: Bool?
    let opacity: Int?
}

// MARK: - ButtonStyle

internal struct ButtonStyle: Codable {
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

internal struct ColorsStyle: Codable {
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

internal struct DismissContentStyle: Codable {
    let color: String?
    let colorType: String?
    let enabled: Bool?

    private enum CodingKeys: String, CodingKey {
        case color, enabled
        case colorType = "color_type"
    }
}

// MARK: - GeneralStyle

internal struct GeneralStyle: Codable {
    let contentAlignment: ContentAlignmentType?
    let fontFamily: String?

    private enum CodingKeys: String, CodingKey {
        case contentAlignment = "content_alignment"
        case fontFamily = "font_family"
    }
}

// MARK: - ProgressStyle

internal struct ProgressStyle: Codable {
    let color: String?
    let colorType: String?
    let enabled: Bool?

    private enum CodingKeys: String, CodingKey {
        case color, enabled
        case colorType = "color_type"
    }
}

// MARK: - ContentAlignmentType

internal enum ContentAlignmentType: String, Codable {
    case middle
    case center
    case top
    case bottom
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
