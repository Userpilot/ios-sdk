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
            return "identify_title".localized
        case .screens:
            return "screens_title".localized
        case .events:
            return "events_title".localized
        }
    }
}

postfix operator ~
postfix func ~ (string: String) -> String {
    return NSLocalizedString(string, comment: "")
}
