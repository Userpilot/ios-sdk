//
//  PreviewExperience.swift
//  Userpilot SDK
//
//  Created by Userpilot on 03/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Models preview experience payload and query parameters for preview content.
//

import Foundation

// MARK: - Query Parameters

internal struct PreviewExperienceQueryParams {
    let baseUrl: String
    let appToken: String
    let contentType: String
    let contentId: String
}

internal extension PreviewExperienceQueryParams {
    /// Preserves URLComponents encoding and the base URL fallback used by preview requests.
    var requestURL: String {
        var components = URLComponents(string: baseUrl)
        components?.queryItems = [
            URLQueryItem(name: "app_token", value: appToken),
            URLQueryItem(name: "content_type", value: contentType),
            URLQueryItem(name: "content_id", value: contentId)
        ]
        return components?.url?.absoluteString ?? baseUrl
    }
}

// MARK: - Preview Experience Model

internal struct PreviewExperience: Decodable {
    let flow: FlowContent?
    let survey: SurveyContent?
    let contentType: String?
    let theme: ThemeContent?

    private enum CodingKeys: String, CodingKey {
        case flow = "mobile_content"
        case contentType = "content_type"
        case survey, theme
    }
}

// MARK: - String Extension for JSON Deserialization

internal extension String {
    /// Converts a JSON string into a `FlowContentData` object using `JSONDecoder`.
    func toPreviewExperience() -> PreviewExperience? {
        if let previewExperience: PreviewExperience = self.toObject() {
            return previewExperience
        } else {
            return nil
        }
    }
}
