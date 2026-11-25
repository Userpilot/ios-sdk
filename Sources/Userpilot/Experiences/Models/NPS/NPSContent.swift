//
//  NPSContent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Decodes NPS content, feedback options and presentation settings received from the backend.
//

import Foundation
import UIKit

// MARK: - NPSContentData
internal struct NPSContentData: Codable {
    // A response can contain another content type; absence is not a decoding failure.
    let npsContent: NPSContent?

    enum CodingKeys: String, CodingKey {
        case npsContent = "nps"
    }
}

// MARK: - NPSContent
internal struct NPSContent: Codable {
    let localeCode: String
    let timeDelay: Int
    let content: NPSStep
    let npsTheme: NPSTheme
    let screens: [String]
    let screenType: ScreenType

    private enum CodingKeys: String, CodingKey {
        case content, screens
        case npsTheme = "theme_data"
        case screenType = "screen_type"
        case localeCode = "locale_code"
        case timeDelay = "time_delay"
    }

    var isForAllScreens: Bool {
        return screenType == .all
    }

    var delayDuration: TimeInterval {
        return TimeInterval(timeDelay)
    }
}

// MARK: - String Extension for JSON Deserialization

internal extension String {
    /// Converts a JSON string into an `NPSContentData`; a failure is logged through `logger` and returns `nil`.
    func toNPSContent(logger: Logging? = nil) -> NPSContentData? {
        let data: NPSContentData? = toObject(logger: logger)
        return data?.npsContent == nil ? nil : data
    }
}
