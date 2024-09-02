//
//  EventType.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// EventType Event details holder
//

import Foundation

/*
 UserPilot track event type include
 
 event -> Track events
 screen -> Track screens opened
 identify -> Track grouping as a company member user
 */
enum EventType: Equatable {

    case event(String)
    case screen(String)
    case identify(String)

    var caseName: String {
        switch self {
        case .event:
            return EventCaseNameConstants.EVENT
        case .screen:
            return EventCaseNameConstants.SCREEN
        case .identify:
            return EventCaseNameConstants.IDENTIFY
        }
    }

    var eventName: String {
        switch self {
        case let .event(eventName):
            return "\(eventName)"
        case .screen:
            return EventNameConstants.SCREEN
        case .identify:
            return EventNameConstants.IDENTIFY
        }
    }

    var title: String {
        switch self {
        case let .event(eventName):
            return eventName
        case let .screen(title):
            return "Screen (\(title))"
        case let .identify(userId):
            return "Identify \(userId)"
        }
    }

    var isEvent: Bool {
        return self.caseName == EventCaseNameConstants.EVENT
    }

    var isScreenEvent: Bool {
        return self.caseName == EventCaseNameConstants.SCREEN
    }

    var isIdentifyEvent: Bool {
        return self.caseName == EventCaseNameConstants.IDENTIFY
    }

    var userID: String? {
        if case let .identify(userID) = self {
            return userID
        } else {
            return nil
        }
    }
}
