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
    let mobileTheme: MobileTheme?

    private enum CodingKeys: String, CodingKey {
        case mobileTheme = "mobile_theme"
    }
}

// MARK: - MobileTheme

internal struct MobileTheme: Codable {
    let id: Int?
    let themeData: ThemeData?

    private enum CodingKeys: String, CodingKey {
        case id
        case themeData = "theme_data"
    }
}

// MARK: - ThemeData

internal struct ThemeData: Codable {
    let carousel: CarouselTheme?

    // General
    var fontFamily: String? {
        carousel?.general?.fontFamily
    }

    var contentAlignment: ContentAlignmentType {
        carousel?.general?.contentAlignment ?? .top
    }

    var backgroundColor: UIColor {
        carousel?.colors?.backgroundColor?.color ?? .white
    }

    var backgroundColorAsString: String {
        carousel?.colors?.backgroundColor ?? ""
    }

    // Text
    var textColor: UIColor {
        carousel?.colors?.textColor?.color ?? .black
    }

    var titleTextColor: UIColor {
        carousel?.colors?.titleColor?.color ?? .black
    }

    // Button
    var buttonBackgroundColor: UIColor {
        carousel?.button?.backgroundColor?.color ?? .black
    }

    var buttonTextColor: UIColor {
        carousel?.button?.labelColor?.color ?? .white
    }

    var buttonBorderColor: UIColor {
        carousel?.button?.borderColor?.color ?? .black
    }

    var buttonBorderRadius: CGFloat {
        CGFloat(carousel?.button?.borderRadius ?? ThemeHandler.StyleValues.borderRadius)
    }

    var buttonBorderWidth: CGFloat {
        CGFloat(carousel?.button?.borderWidth ?? 0)
    }

    // Dismiss Content
    var isDismissButtonEnabled: Bool {
        carousel?.dismissContent?.enabled ?? false
    }

    var isDismissButtonColorManual: Bool {
        carousel?.dismissContent?.colorType == ThemeHandler.StyleValues.manual
    }

    var dismissButtonColor: UIColor {
        carousel?.dismissContent?.color?.color ?? .black
    }

    // Progress
    var isStepsProgressEnabled: Bool {
        carousel?.progress?.enabled ?? false
    }

    var isStepsProgressColorManual: Bool {
        carousel?.progress?.colorType == ThemeHandler.StyleValues.manual
    }

    var stepsProgressColor: UIColor {
        carousel?.progress?.color?.color ?? .black
    }

    var stepsProgressColorAsString: String {
        carousel?.progress?.color ?? ThemeHandler.DefaultValues.blackColor
    }

    private enum CodingKeys: String, CodingKey {
        case carousel
    }
}

// MARK: - CarouselTheme

internal struct CarouselTheme: Codable {
    let button: ButtonStyle?
    let colors: ColorsStyle?
    let dismissContent: DismissContentStyle?
    let general: GeneralStyle?
    let progress: ProgressStyle?

    private enum CodingKeys: String, CodingKey {
        case button, colors, general, progress
        case dismissContent = "dismiss_content"
    }
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
    case center
    case top
}

// MARK: - Extension to deserialize a String into a ThemeResponse object

extension String {
    func toMobileTheme() -> ThemeContent? {
        if let themeContent: ThemeContent = self.toObject() {
            return themeContent
        }else {
            return nil
        }
    }
}
