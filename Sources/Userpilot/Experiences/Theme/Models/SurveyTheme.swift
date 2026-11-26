//
//  SurveyTheme.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines survey styling and its native computed defaults.
//

import Foundation
import UIKit

// Survey Theme //

// MARK: - SurveyTheme

internal struct SurveyTheme: Codable {
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
        CGFloat(backdrop?.opacity ?? Constants.Theme.dimSlideOutDegree) / 100
    }

    var backdropBackground: UIColor {
        backdropColor.withOpacity(backdropOpacity)
    }

    // progress
    var isStepsProgressEnabled: Bool {
        progress?.enabled ?? false
    }

    var isStepsProgressColorManual: Bool {
        progress?.colorType == .manual
    }

    var isStepsProgressBallType: Bool {
        progress?.type == .ball
    }

    var stepsProgressColor: UIColor {
        progress?.color?.color ?? .black
    }

    var stepsProgressColorAsString: String {
        progress?.color ?? Constants.Theme.blackColor
    }

    // corner
    var isBottomSheetSurvey: Bool {
        general?.position == .bottom
    }

    // Border
    var borderRadius: CGFloat {
        CGFloat(general?.cornerRadius ?? 24)
    }

}

// MARK: - SurveyGeneral

internal struct SurveyGeneral: Codable {
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

internal struct SurveyFont: Codable {
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

internal enum SurveyPosition: String, Codable {
    case center
    case bottom
}
