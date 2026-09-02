//
//  PreviewExperience.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 03/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Models preview experience payload and query parameters for preview content.
//
// MARK: - Query Parameters

internal struct PreviewExperienceQueryParams {
    let baseUrl: String
    let appToken: String
    let contentType: String
    let contentId: String
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
