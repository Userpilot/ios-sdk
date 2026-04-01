//
//  Content.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 19/08/2024.
//

import Foundation

enum Content {
    case identify
    case screens
    case events
    case configurations
    case eventsLog
    case autoCapture

    var title: String {
        switch self {
        case .identify:
            return "identify_title".localized
        case .screens:
            return "screens_title".localized
        case .events:
            return "events_title".localized
        case .configurations:
            return "configurations_title".localized
        case .eventsLog:
            return "logs".localized
        case .autoCapture:
            return "Auto Capture Test"
        }
    }
}
