//
//  ExperienceTheme.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines experience styling and its native computed defaults.
//

import Foundation
import UIKit

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
        colors?.backgroundColor ?? Constants.Theme.whiteColor
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
        CGFloat(button?.borderRadius ?? Constants.Theme.borderRadius)
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
        progress?.color ?? Constants.Theme.blackColor
    }

    /// `bar` draws a bar along the step's top edge. Read by Flow steps only.
    var isStepsProgressBar: Bool {
        (progress?.style ?? progress?.type) == .bar
    }

    /// `counter` draws `2 of 3` where the dots go; `dots` and `ball` draw dots. Read by Flow steps only.
    var isStepsProgressCounter: Bool {
        (progress?.style ?? progress?.type) == .counter
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
    let colorType: ColorType?
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
    let colorType: ColorType?
    let enabled: Bool?
    let type: ProgressStyleType?
    /// The Flow theme names its progress style `style` (`dots`/`counter`/`bar`); survey themes send `type`.
    /// A `var` so the memberwise initializer defaults it to nil for callers that only set `type`.
    var style: ProgressStyleType?

    private enum CodingKeys: String, CodingKey {
        case color, enabled
        case colorType = "color_type"
        case type, style
    }
}

// MARK: - ContentAlignmentType

internal enum ContentAlignmentType: String, Codable {
    case middle
    case center
    case top
    case bottom
}
