//
//  NPSTheme.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines NPS styling and its native computed defaults.
//

import Foundation
import UIKit

// MARK: - NPSTheme
internal struct NPSTheme: Codable {
    let general: NPSThemeGeneral?
    let font: NPSThemeText?
    let box: NPSThemeBox?
    let progress: ProgressBarTheme?

    enum CodingKeys: String, CodingKey {
        case general = "main"
        case font = "text"
        case box
        case progress = "progress_bar"
    }

    var logo: String? {
        return general?.logo
    }

    // Computed Properties
    var backgroundColor: UIColor {
        general?.backgroundColor?.color ?? .white
    }

    var backgroundColorAsString: String {
        general?.backgroundColor ?? "#ffffff"
    }

    var primaryColor: UIColor {
        general?.primary?.color ?? .black
    }

    var primaryColorAsString: String {
        general?.primary ?? "#000000"
    }

    var secondaryColor: UIColor {
        primaryColor.withAlphaComponent(0.2)
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

    var fontFamily: String? {
        font?.fontFamily
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

    // radius
    var borderRadius: CGFloat {
        CGFloat(box?.radius ?? 24)
    }
}

// MARK: - NPSThemeGeneral
internal struct NPSThemeGeneral: Codable {
    let backgroundColor: String?
    let logo: String?
    /// Missing or null uses the existing black primary-color fallback.
    let primary: String?

    enum CodingKeys: String, CodingKey {
        case logo, primary
        case backgroundColor = "background_color"
    }
}

// MARK: - NPSThemeText
internal struct NPSThemeText: Codable {
    let fontColor: String?
    let colorType: ColorType?
    let fontFamily: String?

    enum CodingKeys: String, CodingKey {
        case fontColor = "font_color"
        case colorType = "font_color_type"
        case fontFamily = "font_family"
    }

}

// MARK: - NPSThemeBox
internal struct NPSThemeBox: Codable {
    let radius: Int?
}

internal struct ProgressBarTheme: Codable {
    let enabled: Bool?
    let color: String?
    let colorType: ColorType?
    let type: ProgressStyleType?

    private enum CodingKeys: String, CodingKey {
        case enabled, type
        case color = "font_color"
        case colorType = "font_color_type"
    }
}
