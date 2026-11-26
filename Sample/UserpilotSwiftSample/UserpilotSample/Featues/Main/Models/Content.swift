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
    case debug
    case builder
    case tooltips
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
        case .debug:
            return "Debug"
        case .builder:
            return "Builder"
        case .tooltips:
            return "Tooltips"
        case .autoCapture:
            return "Auto Capture"
        }
    }

    var symbolName: String {
        switch self {
        case .configurations:
            return "gearshape"
        case .identify:
            return "person.crop.circle"
        case .screens:
            return "rectangle.on.rectangle"
        case .events:
            return "bolt"
        case .eventsLog:
            return "list.bullet.rectangle"
        case .debug:
            return "ant"
        case .builder:
            return "square.grid.2x2"
        case .autoCapture:
            return "hand.tap"
        case .tooltips:
            return "bubble.left.and.bubble.right"
        }
    }
}
