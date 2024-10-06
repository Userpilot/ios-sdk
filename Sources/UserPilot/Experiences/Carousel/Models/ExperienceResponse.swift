//
//  File.swift
//  
//
//  Created by Motasem Hamed on 29/09/2024.
//

import Foundation
import UIKit

// MARK: - CarouselData
internal struct CarouselData: Codable {
    let type: CarouselType
    let order: Int
    let steps: [Step]
    let mobileTheme: MobileTheme?
    let configuration: Configuration

    private enum CodingKeys: String, CodingKey {
        case type, order, steps
        case mobileTheme = "mobile_theme"
        case configuration
    }
}

// MARK: - Configuration
internal struct Configuration: Codable {
    let targeting: Targeting
}

// MARK: - Targeting
internal struct Targeting: Codable {
    let screens: [String]
}

// MARK: - Step
internal struct Step: Codable {
    let id: Int
    let order: Int
    let sections: [Section]
    let buttonAction: ButtonAction?
    let mobileTheme: MobileTheme?

    private enum CodingKeys: String, CodingKey {
        case id, order, sections
        case buttonAction = "button_action"
        case mobileTheme = "mobile_theme"
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
}

// MARK: - Attributes
internal struct Attributes: Codable {
    let textAlign: TextAlignmentType?
    let level: HeaderType?
    let src: String?
    let icon: String?

    private enum CodingKeys: String, CodingKey {
        case textAlign = "text_align"
        case level, src, icon
    }
}

// MARK: - Content
internal struct Content: Codable {
    let text: String?
    let type: String
    let marks: [Mark]?

    private enum CodingKeys: String, CodingKey {
        case text, type, marks
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
    let fontSize: Int?
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
        case deepLink = "deep_link"
    }
}

// MARK: - CarouselType
internal enum CarouselType: String, Codable {
    case carousel
    case slider
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

    func fontSize() -> Int {
        switch self {
        case .headerOne: return 25
        case .headerTwo: return 20
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
extension String {
    /// Converts a JSON string into a `CarouselData` object using `JSONDecoder`.
    func toCarousel() -> CarouselData? {
        let decoder = JSONDecoder()
        return try? decoder.decode(CarouselData.self, from: Data(self.utf8))
    }

    /// Converts a JSON string into an array of `CarouselData` objects using `JSONDecoder`.
    func toCarouselList() -> [CarouselData]? {
        let decoder = JSONDecoder()
        do {
            let decodedData = try decoder.decode([CarouselData].self, from: Data(self.utf8))
            return decodedData
        } catch {
            // Use a switch statement to handle different types of DecodingError
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("Key '\(key)' not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    // Print the properties of the type mismatch error
                    print("Type '\(type)' mismatch:")
                    print("  Expected type: \(type)")
                    print("  Contextual info: \(context.debugDescription)")
                    print("  Coding path: \(context.codingPath)")
                    print("  Debug description: \(context.debugDescription)")
                case .valueNotFound(let value, let context):
                    print("Value '\(value)' not found: \(context.debugDescription)")
                @unknown default:
                    print("Unknown decoding error: \(error)")
                }
            } else {
                // If the error is not a DecodingError, print its description
                print("Failed to decode JSON: \(error.localizedDescription)")
            }
            return nil
        }
    }
}
