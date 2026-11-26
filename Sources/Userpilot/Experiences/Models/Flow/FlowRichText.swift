//
//  FlowRichText.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines flow rich text, sizing and text style values.
//

import Foundation
import UIKit

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
            return "\(Constants.Theme.defaultTextMargin)\(content?.first?.text ?? "")"
        } else if buttonAlignment == .right {
            return "\(content?.first?.text ?? "")\(Constants.Theme.defaultTextMargin)"
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

internal enum ContentType: String, Codable {
    case carousel
    case slideout

    /// A Flow segment's tooltip steps, set only by the `FlowWalk` projection. Not a wire value: a payload
    /// sending `"type": "tooltip"` fails decoding, so its survey or NPS siblings still decode.
    case tooltip

    /// A mobile Flow: mixed tooltip, modal and slideout steps, delivered per screen (`steps_count`).
    case flow

    /// Decodes wire values only: `tooltip` throws like an unknown value.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard rawValue != ContentType.tooltip.rawValue, let type = ContentType(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Expected a wire content type but was \(rawValue)"
            )
        }
        self = type
    }
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
