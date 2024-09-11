//
//  Content.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 19/08/2024.
//

import Foundation

enum Content {
    case identify
    case screens
    case events

    var title: String {
        switch self {
        case .identify:
            return "User & Anonymous"
        case .screens:
            return "Track screens"
        case .events:
            return "Track events"
        }
    }
}
