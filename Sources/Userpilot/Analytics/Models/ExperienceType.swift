//
//  ExperienceType.swift
//  Userpilot SDK
//
//  Created by Userpilot on 03/02/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Identifies flow/survey categories used in screen history and content refreshes.
//

/// Flow/survey categories used for screen history and post-dismissal refreshes.
/// NPS eligibility is tracked separately by ExperiencesPublisher.
internal enum ExperienceType {
    case flow
    case survey
}
