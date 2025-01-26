//  CarouselExperienceViewController.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2021 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Represents the configuration and content of a carousel.
//

import Foundation
import UIKit

/*
 This class encapsulates data related to a carousel, including its type, order,
 steps, theme, and configuration settings.

 - Properties:
    - `token`: The experience token.
    - `type`: The type of the experience, represented as a `ContentType`.
    - `steps`: A list of `Step` objects that make up the carousel's content.
    - `mobileTheme`: An optional `MobileTheme` that defines the visual style for the carousel.
    - `configuration`: The `Configuration` settings that apply to the carousel.
 */

// MARK: - CarouselData

internal struct FlowContentData: Codable {
    let flowContent: FlowContent

    private enum CodingKeys: String, CodingKey {
        case flowContent = "mobile_contents"
    }
}

internal struct FlowContent: Codable {
    let id: Int
    let token: String
    let type: ContentType
    let steps: [Step]
    let mobileTheme: ContentMobileTheme
    let screens: [String]
    let screenType: ScreenType
    let localeCode: String

    private enum CodingKeys: String, CodingKey {
        case id, token, type, steps
        case mobileTheme = "theme_data"
        case screens
        case screenType = "screen_type"
        case localeCode = "locale_code"
    }

    // General
    var baseThemeID: Int {
        mobileTheme.id
    }
    // General
    var isForAllScreens: Bool {
        screenType == .all
    }

}

// MARK: - Configuration

internal struct ContentMobileTheme: Codable {
    let id: Int
    let themeData: ExperienceTheme?

    private enum CodingKeys: String, CodingKey {
        case id = "theme_id"
        case themeData = "theme_data"
    }
}

// MARK: - Step

internal struct Step: Codable {
    let id: Int
    let order: Int
    let sections: [Section]
    let buttonAction: ButtonAction?
    let mobileTheme: ExperienceTheme?

    private enum CodingKeys: String, CodingKey {
        case id, order, sections
        case buttonAction = "button_action"
        case mobileTheme = "theme_data"
    }
}

// MARK: - Section

internal struct Section: Codable {
    let lines: [Line]
}

// MARK: - Line

internal struct Line: Codable {
    let type: LineType
    let attrs: Attributes?
    let content: [Content]?

    private enum CodingKeys: String, CodingKey {
        case type, attrs, content
    }

    var buttonAlignment: UIControl.ContentHorizontalAlignment {
        return attrs?.textAlign?.buttonAlignment() ?? .center
    }

    var buttonTitle: String {
        if buttonAlignment == .left {
            return "\(ThemeHandler.DefaultValues.defaultTextMargin)\(content?.first?.text ?? "")"
        } else if buttonAlignment == .right {
            return "\(content?.first?.text ?? "")\(ThemeHandler.DefaultValues.defaultTextMargin)"
        } else {
            return content?.first?.text ?? ""
        }
    }
}

// MARK: - Attributes

internal struct Attributes: Codable {
    let textAlign: TextAlignmentType?
    let level: HeaderType?
    let src: String?
    let icon: String?
    let alt: String?
    let hash: String?
    let style: Style?
    let actualSize: ActualSize?

    private enum CodingKeys: String, CodingKey {
        case textAlign = "text_align"
        case actualSize = "actual_size"
        case level, src, icon, alt, hash, style
    }

    var imageScale: UIView.ContentMode {
        style?.objectFit == "fill" ? .scaleToFill : .scaleAspectFit
    }

    var imageRadius: CGFloat {
        CGFloat(style?.borderRadius ?? 0)
    }

}

// MARK: - ActualSize

internal struct ActualSize: Codable {
    let height: Int?
    let width: Int?
}

// MARK: - Style

internal struct Style: Codable {
    let height: String?
    let width: String?
    let objectFit: String?
    let borderRadius: Int?

    private enum CodingKeys: String, CodingKey {
        case objectFit = "object_fit"
        case borderRadius = "border_radius"
        case height, width
    }
}

// MARK: - Content

internal struct Content: Codable {
    let text: String?
    let marks: [Mark]?

    private enum CodingKeys: String, CodingKey {
        case text, marks
    }
}

// MARK: - Mark

internal struct Mark: Codable {
    let type: String?
    let attrs: MarkAttributes?

    private enum CodingKeys: String, CodingKey {
        case type, attrs
    }
}

// MARK: - MarkAttributes

internal struct MarkAttributes: Codable {
    let fontSize: String?
    let href: String?
    let color: String?

    private enum CodingKeys: String, CodingKey {
        case fontSize = "font_size"
        case href, color
    }
}

// MARK: - ButtonAction

internal struct ButtonAction: Codable {
    let buttonAction: String?
    let deepLink: String?

    private enum CodingKeys: String, CodingKey {
        case buttonAction = "button_action"
        case deepLink = "ios_deep_link"
    }
}

// MARK: - CarouselType

internal enum ScreenType: String, Codable {
    case all
    case selected
}

internal enum ContentType: String, Codable {
    case carousel
    case slideout
}

// MARK: - LineType

internal enum LineType: String, Codable {
    case heading = "heading"
    case paragraph = "paragraph"
    case image = "image"
    case button = "button"
    case iconText = "icon_bullet_list"
}

// MARK: - HeaderType

internal enum HeaderType: String, Codable {
    case headerOne = "h1"
    case headerTwo = "h2"
    case headerThree = "h3"

    func fontSize() -> Int {
        switch self {
        case .headerOne: return 28
        case .headerTwo: return 24
        case .headerThree: return 20
        }
    }
}

// MARK: - TextAlignmentType

internal enum TextAlignmentType: String, Codable {
    case center
    case right
    case left

    func textAlignment() -> NSTextAlignment {
        switch self {
        case .center: return .center
        case .right: return .right
        case .left: return .left
        }
    }

    func buttonAlignment() -> UIControl.ContentHorizontalAlignment {
        switch self {
        case .center: return .center
        case .right: return .right
        case .left: return .left
        }
    }
}

// MARK: - String Extension for JSON Deserialization

internal extension String {
    /// Converts a JSON string into a `FlowContentData` object using `JSONDecoder`.
    func toFlowContent() -> FlowContentData? {
        if let mobileContent: FlowContentData = self.toObject() {
            return mobileContent
        } else {
            return nil
        }
    }

    /// Converts a JSON string into an array of `FlowContentData` objects using `JSONDecoder`.
    func toCarouselList() -> [FlowContentData]? {
        if let carouselDataList: [FlowContentData] = self.toArray() {
            return carouselDataList
        } else {
            return nil
        }
    }
}
